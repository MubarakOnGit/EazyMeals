import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Add a user document
  Future<void> addUserData(String userId, String name) async {
    await _db.collection('users').doc(userId).set({
      'name': name,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Fetch user data
  Future<DocumentSnapshot> getUserData(String userId) async {
    return await _db.collection('users').doc(userId).get();
  }

  // Update user data
  Future<void> updateUserData(String userId, Map<String, dynamic> data) async {
    await _db.collection('users').doc(userId).update(data);
  }
}
