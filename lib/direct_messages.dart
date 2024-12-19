import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

import 'draftService.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final User currentUser;
  final String otherUserName;
  final String? otherUserPhotoUrl;
  final String otherUserId;

  ChatScreen({
    required this.chatId,
    required this.currentUser,
    required this.otherUserName,
    required this.otherUserId,
    this.otherUserPhotoUrl,
  });

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isUploading = false;
  Timer? _saveTimer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _markMessagesAsRead();
    _loadDraft(); // Call new method
    _messageController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    // Save draft immediately when disposing
    if (_messageController.text.isNotEmpty) {
      DraftService.saveDraft(widget.chatId, _messageController.text);
    }
    _saveTimer?.cancel();
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    super.dispose();
  }


  Future<void> _loadDraft() async {
    final draft = await DraftService.getDraft(widget.chatId);
    if (mounted) {
      setState(() {
        _messageController.text = draft;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSubmit() async {
    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      await _sendMessage();
      _messageController.clear();
      await DraftService.deleteDraft(widget.chatId);
    }
  }


  void _onTextChanged() {
    _saveTimer?.cancel();
    _saveTimer = Timer(Duration(milliseconds: 500), () async {
      await DraftService.saveDraft(widget.chatId, _messageController.text);
    });
  }

  Future<void> _sendMessage({String? imageUrl}) async {
    final text = _messageController.text.trim();
    if (text.isEmpty && imageUrl == null) return;

    final message = {
      'senderId': widget.currentUser.uid,
      'timestamp': FieldValue.serverTimestamp(),
      'type': imageUrl != null ? 'image' : 'text',
      'read': false,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (text.isNotEmpty) 'text': text,
    };

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add(message);

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .update({
      'lastMessage': imageUrl != null ? '📸 Image' : text,
      'lastMessageTime': FieldValue.serverTimestamp(),
    });

    await DraftService.deleteDraft(widget.chatId);
    _messageController.clear();
  }

  void _markMessagesAsRead() {
    FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .where('read', isEqualTo: false)
        .where('senderId', isNotEqualTo: widget.currentUser.uid)
        .get()
        .then((snapshot) {
      for (var doc in snapshot.docs) {
        doc.reference.update({'read': true});
      }
    });
  }

  Future<void> _takePhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      imageQuality: 85,
    );

    if (photo != null) {
      setState(() => _isUploading = true);
      try {
        final ref = FirebaseStorage.instance
            .ref()
            .child('chat_images')
            .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

        await ref.putFile(File(photo.path));
        final imageUrl = await ref.getDownloadURL();
        await _sendMessage(imageUrl: imageUrl);
      } catch (e) {
        print('Error uploading photo: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload photo. Please try again.')),
        );
      }
      setState(() => _isUploading = false);
    }
  }

  Future<void> _shareLocation() async {
    try {
      // Request location permission first
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Location permissions are denied')),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Location permissions are permanently denied')),
        );
        return;
      }

      // Get location once permission is granted
      final position = await Geolocator.getCurrentPosition();
      final message = {
        'senderId': widget.currentUser.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'location',
        'latitude': position.latitude,
        'longitude': position.longitude,
      };

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add(message);

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .update({
        'lastMessage': '📍 Location shared',
        'lastMessageTime': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error sharing location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share location. Please try again.')),
      );
    }
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: Color(0xFF20A090),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF20A090).withOpacity(0.3),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 32,
            ),
          ),
          SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        allowCompression: true,
        withData: true,
      );

      if (result != null) {
        setState(() => _isUploading = true);

        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;
        final fileSize = result.files.single.size;

        // Upload to Firebase Storage
        final ref = FirebaseStorage.instance
            .ref()
            .child('chat_files')
            .child('${DateTime.now().millisecondsSinceEpoch}_$fileName');

        await ref.putFile(file);
        final fileUrl = await ref.getDownloadURL();

        // Send message with file
        final message = {
          'senderId': widget.currentUser.uid,
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'file',
          'fileUrl': fileUrl,
          'fileName': fileName,
        };

        await FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.chatId)
            .collection('messages')
            .add(message);

        await FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.chatId)
            .update({
          'lastMessage': '📎 File: $fileName',
          'lastMessageTime': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error picking file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload file. Please try again.')),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() => _isUploading = true);
      try {
        final ref = FirebaseStorage.instance
            .ref()
            .child('chat_images')
            .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

        await ref.putFile(File(image.path));
        final imageUrl = await ref.getDownloadURL();
        await _sendMessage(imageUrl: imageUrl);
      } catch (e) {
        print('Error uploading image: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image. Please try again.')),
        );
      }
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    _markMessagesAsRead();
    return Scaffold(
      backgroundColor: const Color(0xFF1B202D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B202D),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFF20A090),
              backgroundImage: widget.otherUserPhotoUrl != null
                  ? NetworkImage(widget.otherUserPhotoUrl!)
                  : null,
              child: widget.otherUserPhotoUrl == null
                  ? Text(
                      widget.otherUserName[0].toUpperCase(),
                      style: TextStyle(color: Colors.white),
                    )
                  : null,
            ),
            SizedBox(width: 12),
            Text(
              widget.otherUserName,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('chats')
                      .doc(widget.chatId)
                      .collection('messages')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(child: CircularProgressIndicator());
                    }

                    var messages = snapshot.data!.docs;
                    DateTime? previousDate;

                    return ListView.builder(
                      reverse: true,
                      controller: _scrollController,
                      padding: EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        var message =
                            messages[index].data() as Map<String, dynamic>;
                        bool isMe =
                            message['senderId'] == widget.currentUser.uid;

                        Timestamp? timestamp =
                            message['timestamp'] as Timestamp?;
                        DateTime messageDate =
                            timestamp?.toDate() ?? DateTime.now();

                        bool showDate = false;
                        if (previousDate == null ||
                            !_isSameDay(previousDate!, messageDate)) {
                          showDate = true;
                          previousDate = messageDate;
                        }

                        return Column(
                          children: [
                            if (showDate)
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[800],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _getDateText(messageDate),
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            MessageBubble(
                              message: message,
                              isMe: isMe,
                              time: timestamp != null
                                  ? DateFormat('HH:mm').format(messageDate)
                                  : '',
                              otherUserPhotoUrl: widget.otherUserPhotoUrl,
                              otherUserName: widget.otherUserName,
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              Container(
                padding: EdgeInsets.only(
                  left: 8,
                  right: 8,
                  top: 4,
                  bottom: 20, // Add padding at bottom to lift it up
                ),
                color: Color(0xFF1B202D), // Darker background color
                child: Container(
                  decoration: BoxDecoration(
                    color: Color(0xFF2B3647), // Lighter container color
                    borderRadius: BorderRadius.circular(25),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  margin: EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.attach_file_rounded,
                            color: Colors.grey[400], size: 24),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor:
                                Color(0xFF1B202D), // Darker background
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(28)), // Larger radius
                            ),
                            builder: (context) => Container(
                              padding: EdgeInsets.fromLTRB(
                                  24, 16, 24, 36), // More padding at bottom
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    height: 5,
                                    width: 44,
                                    margin: EdgeInsets.only(bottom: 32),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[600],
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _buildAttachmentOption(
                                        icon: Icons
                                            .photo_camera_rounded, // More modern camera icon
                                        label: 'Camera',
                                        onTap: () {
                                          Navigator.pop(context);
                                          _takePhoto();
                                        },
                                      ),
                                      _buildAttachmentOption(
                                        icon: Icons
                                            .photo_library_rounded, // Better gallery icon
                                        label: 'Gallery',
                                        onTap: () {
                                          Navigator.pop(context);
                                          _pickImage();
                                        },
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 32),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _buildAttachmentOption(
                                        icon: Icons
                                            .file_present_rounded, // Better file icon
                                        label: 'Document',
                                        onTap: () {
                                          Navigator.pop(context);
                                          _pickFile();
                                        },
                                      ),
                                      _buildAttachmentOption(
                                        icon: Icons
                                            .pin_drop_rounded, // Better location icon
                                        label: 'Location',
                                        onTap: () {
                                          Navigator.pop(context);
                                          _shareLocation();
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          style: TextStyle(color: Colors.white),
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _handleSubmit(), // Updated this line
                          decoration: InputDecoration(
                            hintText: 'Message',
                            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 16),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 4),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.send_rounded,
                            color: Color(0xFF20A090), size: 24),
                        onPressed: _handleSubmit,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_isUploading)
            Container(
              color: Colors.black45,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  String _getDateText(DateTime date) {
    DateTime now = DateTime.now();
    if (_isSameDay(date, now)) {
      return 'Today';
    } else if (_isSameDay(date, now.subtract(Duration(days: 1)))) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM d, y').format(date);
    }
  }
}

class MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final String time;
  final String? otherUserPhotoUrl;
  final String otherUserName;

  MessageBubble({
    required this.message,
    required this.isMe,
    required this.time,
    required this.otherUserPhotoUrl,
    required this.otherUserName,
  });

  @override
  Widget build(BuildContext context) {
    final isImageMessage = message['type'] == 'image';

    return Padding(
      padding: EdgeInsets.only(bottom: 8), // Reduced padding
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 12, // Smaller avatar
              backgroundColor: const Color(0xFF20A090),
              backgroundImage: otherUserPhotoUrl != null
                  ? NetworkImage(otherUserPhotoUrl!)
                  : null,
              child: otherUserPhotoUrl == null
                  ? Text(
                      otherUserName[0].toUpperCase(),
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    )
                  : null,
            ),
            SizedBox(width: 6),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  margin: EdgeInsets.only(
                    left: isMe ? 60 : 0,
                    right: isMe ? 0 : 60,
                  ),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width *
                        0.65, // Limit max width
                  ),
                  decoration: isImageMessage
                      ? null
                      : BoxDecoration(
                          color: isMe ? Color(0xFF20A090) : Color(0xA0A69BAA),
                          borderRadius: BorderRadius.circular(
                              14), // Consistent rounded corners
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                  padding: message['type'] == 'text'
                      ? EdgeInsets.fromLTRB(
                          12, 8, 12, 8) // Smaller padding for text
                      : EdgeInsets.all(8), // Smaller padding for other types
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isImageMessage)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            message['imageUrl'],
                            width: 200,
                            height: 200,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  color: Color(0xFF2B3647),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF20A090),
                                    value: progress.expectedTotalBytes != null
                                        ? progress.cumulativeBytesLoaded /
                                            progress.expectedTotalBytes!
                                        : null,
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      else if (message['type'] == 'text')
                        Text(
                          message['text'],
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15, // Slightly smaller font
                          ),
                        )
                      else if (message['type'] == 'location')
                        GestureDetector(
                          onTap: () {
                            final lat = message['latitude'];
                            final lng = message['longitude'];
                            launchUrl(Uri.parse(
                                'https://www.google.com/maps/search/?api=1&query=$lat,$lng'));
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.location_on_rounded,
                                  color: Colors.white, size: 20),
                              SizedBox(width: 6),
                              Text(
                                'Location',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (message['type'] == 'file')
                        GestureDetector(
                          onTap: () {
                            launchUrl(Uri.parse(message['fileUrl']));
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.insert_drive_file_rounded,
                                  color: Colors.white, size: 20),
                              SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  message['fileName'] ?? 'File',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                if (isMe) // Only show read receipts for sender's messages
                  Padding(
                    padding: EdgeInsets.only(top: 2, right: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          time,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          message['read'] == true ? Icons.done_all : Icons.done,
                          size: 14,
                          color: message['read'] == true
                              ? Color(0xFF20A090) // Teal for read
                              : Colors.grey[500], // Grey for delivered
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
