import 'package:chat_app/search_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'direct_messages.dart';
import 'login_screen.dart';
import 'ProfileScreen.dart';

class HomeScreen extends StatefulWidget {
  final User user;

  HomeScreen({required this.user});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late User _currentUser;
  int _selectedIndex = 0;
  bool _showArchived = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => LoginScreen(),
        ),
      );
    } catch (e) {
      print('Error during logout: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logout failed. Please try again.'),
          backgroundColor: Colors.red[400],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _showOptionsDialog(String chatId, bool isArchived) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2532),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(
          'Chat Options',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF20A090).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isArchived ? Icons.unarchive : Icons.archive,
                  color: const Color(0xFF20A090),
                ),
              ),
              title: Text(
                isArchived ? 'Unarchive' : 'Archive',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                FirebaseFirestore.instance
                    .collection('chats')
                    .doc(chatId)
                    .update({'archived': !isArchived});

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text(isArchived ? 'Chat unarchived' : 'Chat archived'),
                    backgroundColor: const Color(0xFF20A090),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    action: SnackBarAction(
                      label: 'Undo',
                      textColor: Colors.white,
                      onPressed: () => FirebaseFirestore.instance
                          .collection('chats')
                          .doc(chatId)
                          .update({'archived': isArchived}),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[400]?.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.delete, color: Colors.red[400]),
              ),
              title: Text('Delete', style: TextStyle(color: Colors.red[400])),
              onTap: () async {
                Navigator.pop(context);
                bool confirm = await showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: const Color(0xFF1F2532),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                        title: Text(
                          'Delete Chat',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        content: Text(
                          'Are you sure you want to delete this chat?',
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(
                              'Cancel',
                              style: TextStyle(color: const Color(0xFF20A090)),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: TextButton.styleFrom(
                              backgroundColor:
                                  Colors.red[400]?.withOpacity(0.2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text('Delete',
                                style: TextStyle(color: Colors.red[400])),
                          ),
                        ],
                      ),
                    ) ??
                    false;

                if (confirm) {
                  await FirebaseFirestore.instance
                      .collection('chats')
                      .doc(chatId)
                      .delete();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Chat deleted'),
                      backgroundColor: Colors.red[400],
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScreen() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _buildCurrentScreen(),
    );
  }

  Widget _buildCurrentScreen() {
    switch (_selectedIndex) {
      case 0:
        return _buildChatList();
      case 1:
        return SearchScreen(currentUser: _currentUser);
      case 2:
        return ProfileScreen(user: _currentUser);
      default:
        return _buildChatList();
    }
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1B202D),
      elevation: 0,
      title: Text(
        _getAppBarTitle(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: _buildAppBarActions(),
    );
  }

  String _getAppBarTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Messages';
      case 1:
        return 'Search';
      case 2:
        return 'Profile';
      default:
        return 'Messages';
    }
  }

  List<Widget> _buildAppBarActions() {
    if (_selectedIndex == 0) {
      return [
        Container(
          margin: EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF20A090).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: IconButton(
            icon: Icon(
              _showArchived ? Icons.inbox : Icons.archive,
              color: const Color(0xFF20A090),
            ),
            onPressed: () => setState(() => _showArchived = !_showArchived),
          ),
        ),
        Container(
          margin: EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF20A090).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: IconButton(
            icon: Icon(Icons.search, color: const Color(0xFF20A090)),
            onPressed: () => setState(() => _selectedIndex = 1),
          ),
        ),
      ];
    }
    return [];
  }

  Widget _buildChatList() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1B202D),
            const Color(0xFF161A25),
          ],
        ),
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: _currentUser.uid)
            .where('archived', isEqualTo: _showArchived)
            .orderBy('lastMessageTime', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Something went wrong',
                    style: TextStyle(color: Colors.red[400], fontSize: 16),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(const Color(0xFF20A090)),
              ),
            );
          }

          final chats = snapshot.data!.docs;

          if (chats.isEmpty) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF20A090).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF20A090).withOpacity(0.1),
                              blurRadius: 20,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Icon(
                          _showArchived
                              ? Icons.archive
                              : Icons.chat_bubble_outline,
                          size: 64,
                          color: const Color(0xFF20A090),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _showArchived
                            ? 'No archived conversations'
                            : 'No conversations yet',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (!_showArchived) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Start a new chat by tapping the search icon',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: chats.length,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemBuilder: (context, index) {
              final chat = chats[index].data() as Map<String, dynamic>;
              final chatId = chats[index].id;
              final participants =
                  List<String>.from(chat['participants'] ?? []);
              final isArchived = chat['archived'] ?? false;
              final otherUserId = participants.firstWhere(
                (id) => id != _currentUser.uid,
                orElse: () => '',
              );

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(otherUserId)
                    .get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F2532).withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        title: Container(
                          width: 200,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.grey[800]?.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        leading: CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.grey[800]?.withOpacity(0.5),
                        ),
                      ),
                    );
                  }

                  final userData =
                      userSnapshot.data!.data() as Map<String, dynamic>;
                  final firstName = userData['firstName'] ?? '';
                  final lastName = userData['lastName'] ?? '';
                  final fullName = '$firstName $lastName'.trim();
                  final photoURL = userData['photoURL'];
                  final lastMessage = chat['lastMessage'] ?? '';
                  final lastMessageTime = chat['lastMessageTime'] as Timestamp?;

                  String timeString = '';
                  if (lastMessageTime != null) {
                    final now = DateTime.now();
                    final messageTime = lastMessageTime.toDate();
                    if (messageTime.day == now.day) {
                      timeString =
                          '${messageTime.hour.toString().padLeft(2, '0')}:${messageTime.minute.toString().padLeft(2, '0')}';
                    } else if (messageTime.year == now.year) {
                      timeString =
                          '${messageTime.day} ${_getMonthName(messageTime.month)}';
                    } else {
                      timeString =
                          '${messageTime.day} ${_getMonthName(messageTime.month)} ${messageTime.year}';
                    }
                  }

                  return Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          const Color(0xFF1F2532),
                          const Color(0xFF1B202D),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: GestureDetector(
                        onLongPress: () =>
                            _showOptionsDialog(chatId, isArchived),
                        child: Dismissible(
                          key: Key(chatId),
                          background: Container(
                            decoration: BoxDecoration(
                              color: Colors.red[400],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child:
                                const Icon(Icons.delete, color: Colors.white),
                          ),
                          secondaryBackground: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF20A090),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Icon(
                              isArchived ? Icons.unarchive : Icons.archive,
                              color: Colors.white,
                            ),
                          ),
                          confirmDismiss: (direction) async {
                            if (direction == DismissDirection.startToEnd) {
                              // Delete
                              bool confirm = await showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      backgroundColor: const Color(0xFF1F2532),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      title: Text(
                                        'Delete Chat',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      content: Text(
                                        'Are you sure you want to delete this chat?',
                                        style:
                                            TextStyle(color: Colors.grey[400]),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: Text(
                                            'Cancel',
                                            style: TextStyle(
                                                color: const Color(0xFF20A090)),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          style: TextButton.styleFrom(
                                            backgroundColor: Colors.red[400]
                                                ?.withOpacity(0.2),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: Text('Delete',
                                              style: TextStyle(
                                                  color: Colors.red[400])),
                                        ),
                                      ],
                                    ),
                                  ) ??
                                  false;

                              if (confirm) {
                                await FirebaseFirestore.instance
                                    .collection('chats')
                                    .doc(chatId)
                                    .delete();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Chat deleted'),
                                    backgroundColor: Colors.red[400],
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                );
                                return true;
                              }
                              return false;
                            } else {
                              // Archive/Unarchive
                              await FirebaseFirestore.instance
                                  .collection('chats')
                                  .doc(chatId)
                                  .update({'archived': !isArchived});

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isArchived
                                      ? 'Chat unarchived'
                                      : 'Chat archived'),
                                  backgroundColor: const Color(0xFF20A090),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  action: SnackBarAction(
                                    label: 'Undo',
                                    textColor: Colors.white,
                                    onPressed: () => FirebaseFirestore.instance
                                        .collection('chats')
                                        .doc(chatId)
                                        .update({'archived': isArchived}),
                                  ),
                                ),
                              );
                              return false;
                            }
                          },
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            leading: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                // boxShadow: [
                                //   BoxShadow(
                                //     color: const Color(0xFF20A090)
                                //         .withOpacity(0.3),
                                //     blurRadius: 8,
                                //     offset: const Offset(0, 2),
                                //   ),
                                // ],
                              ),
                              child: CircleAvatar(
                                radius: 28,
                                backgroundColor: const Color(0xFF20A090),
                                backgroundImage: photoURL != null
                                    ? NetworkImage(photoURL)
                                    : null,
                                child: photoURL == null
                                    ? Text(
                                        firstName.isNotEmpty
                                            ? firstName[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            title: Text(
                              fullName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                lastMessage,
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  timeString,
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
                                  ),
                                ),
                                if (isArchived) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF20A090)
                                          .withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Archived',
                                      style: TextStyle(
                                        color: Color(0xFF20A090),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatScreen(
                                    chatId: chatId,
                                    currentUser: _currentUser,
                                    otherUserName: fullName,
                                    otherUserId: otherUserId,
                                    otherUserPhotoUrl: photoURL,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B202D),
      appBar: _buildAppBar(),
      body: _buildScreen(),
      bottomNavigationBar: Container(
        height: 64,
        decoration: BoxDecoration(
          color: const Color(0xFF1B202D),

          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,

          selectedItemColor: const Color(0xFF20A090),
          unselectedItemColor: Colors.grey,
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.chat),
              label: 'Inbox',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search),
              label: 'Search',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }
}
