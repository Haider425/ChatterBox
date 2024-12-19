import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'direct_messages.dart';

class SearchScreen extends StatefulWidget {
  final User currentUser;

  SearchScreen({required this.currentUser});

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _searchQuery = '';
  bool _isSearching = false;

  Future<void> _createOrGetChat(String otherUserId, String otherUserName, String? photoURL) async {
    // First, check if a chat already exists between these users
    final querySnapshot = await FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: widget.currentUser.uid)
        .get();

    String chatId;

    for (var doc in querySnapshot.docs) {
      List<String> participants = List<String>.from(doc['participants']);
      if (participants.contains(otherUserId)) {
        // Chat already exists, navigate to it
        chatId = doc.id;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chatId,
              currentUser: widget.currentUser,
              otherUserName: otherUserName,
              otherUserId: otherUserId,
              otherUserPhotoUrl: photoURL,
            ),
          ),
        );
        return;
      }
    }

    // If no chat exists, create a new one
    final newChatRef = await FirebaseFirestore.instance.collection('chats').add({
      'participants': [widget.currentUser.uid, otherUserId],
      'lastMessage': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'archived': false,
    });

    // Navigate to the new chat
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          chatId: newChatRef.id,
          currentUser: widget.currentUser,
          otherUserName: otherUserName,
          otherUserId: otherUserId,
          otherUserPhotoUrl: photoURL,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search users...',
              hintStyle: TextStyle(color: Colors.grey[400]),
              prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
              filled: true,
              fillColor: Colors.grey[700],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Color(0xFF20A090)),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
                _isSearching = value.isNotEmpty;
              });
            },
          ),
        ),
        Expanded(
          child: _isSearching
              ? StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('searchName', arrayContains: _searchQuery.toLowerCase())
                .limit(20)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (!snapshot.hasData) {
                return Center(child: CircularProgressIndicator());
              }

              final users = snapshot.data!.docs;
              final filteredUsers = users.where((doc) {
                final userData = doc.data() as Map<String, dynamic>;
                return doc.id != widget.currentUser.uid;
              }).toList();

              if (filteredUsers.isEmpty) {
                return Center(
                  child: Text(
                    'No users found',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                );
              }

              return ListView.builder(
                itemCount: filteredUsers.length,
                itemBuilder: (context, index) {
                  final userData = filteredUsers[index].data() as Map<String, dynamic>;
                  final userId = filteredUsers[index].id;
                  final firstName = userData['firstName'] ?? '';
                  final lastName = userData['lastName'] ?? '';
                  final fullName = '$firstName $lastName'.trim();
                  final photoURL = userData['photoURL'];

                  return ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(0xFF20A090),
                      backgroundImage: photoURL != null ? NetworkImage(photoURL) : null,
                      child: photoURL == null
                          ? Text(
                        firstName.isNotEmpty ? firstName[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                          : null,
                    ),
                    title: Text(
                      fullName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () => _createOrGetChat(userId, fullName, photoURL),
                  );
                },
              );
            },
          )
              : Center(
            child: Text(
              'Search for users to start a conversation',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
        ),
      ],
    );
  }
}