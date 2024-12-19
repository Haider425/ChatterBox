import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:io';

class FirebaseAuthHelper {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  static Future<void> _saveTokenToUser(String userId) async {
    final fcmToken = await FirebaseMessaging.instance.getToken();
    print('FCM Token: $fcmToken');
    if (fcmToken != null) {
      await _db.collection('users').doc(userId).set({
        'fcmToken': fcmToken,
        'lastActive': FieldValue.serverTimestamp(),
        'status': 'online',
      }, SetOptions(merge: true));  // Use merge option to update only these fields
    }
  }

  static Future<User?> registerUsingEmailPassword({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    File? profileImage,
  }) async {
    FirebaseAuth auth = FirebaseAuth.instance;
    User? user;

    try {
      UserCredential userCredential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      user = userCredential.user;

      if (user != null) {
        // Save FCM token after successful login
        await _saveTokenToUser(user.uid);

        String photoURL = '';
        if (profileImage != null) {
          // Upload profile image asynchronously without blocking user creation
          String path = 'profile_images/${user.uid}.jpg';
          Reference ref = _storage.ref().child(path);
          await ref.putFile(profileImage);
          photoURL = await ref.getDownloadURL();
        }

        // Create user document in Firestore
        await _db.collection('users').doc(user.uid).set({
          'firstName': firstName,
          'lastName': lastName,
          'email': email,
          'emailVerified': user.emailVerified,
          'photoURL': photoURL,
          'fcmToken': await FirebaseMessaging.instance.getToken(),
          'createdAt': FieldValue.serverTimestamp(),
          'lastActive': FieldValue.serverTimestamp(),
          'status': 'online',
          'uid': user.uid,
          'searchName': [
            firstName.toLowerCase(),
            lastName.toLowerCase(),
            '${firstName.toLowerCase()} ${lastName.toLowerCase()}'
          ],
        }).catchError((error) {
          print("Error saving user to Firestore: $error");
        });


        // Update profile
        await user.updateProfile(
          displayName: '$firstName $lastName',
          photoURL: photoURL,
        );

        await user.reload();
        user = auth.currentUser;
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        print('The password provided is too weak.');
      } else if (e.code == 'email-already-in-use') {
        print('The account already exists for that email.');
      }
    } catch (e) {
      print(e);
    }

    return user;
  }

  static Future<User?> signInUsingEmailPassword({
    required String email,
    required String password,
  }) async {
    FirebaseAuth auth = FirebaseAuth.instance;
    User? user;

    try {
      UserCredential userCredential = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      user = userCredential.user;

      if (user != null) {
        // Save FCM token after successful login
        await _saveTokenToUser(user.uid);
      }

    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        print('No user found for that email.');
      } else if (e.code == 'wrong-password') {
        print('Wrong password provided.');
      }
    }

    return user;
  }
}
