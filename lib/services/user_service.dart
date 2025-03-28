import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class UserService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Singleton pattern
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  Future<Map<String, dynamic>> getUserData() async {
    final user = _auth.currentUser;
    if (user == null) return {};

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      return doc.data() ?? {};
    } catch (e) {
      print('Error getting user data: $e');
      return {};
    }
  }

  Future<void> updateUserData(Map<String, dynamic> data) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).update(data);
    } catch (e) {
      print('Error updating user data: $e');
      rethrow;
    }
  }

  Future<void> updateProfileImage(File imageFile) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final imagePath = '${directory.path}/profile_image.jpg';
      await imageFile.copy(imagePath);
    } catch (e) {
      print('Error updating profile image: $e');
      rethrow;
    }
  }

  Future<File?> getProfileImage() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final imagePath = '${directory.path}/profile_image.jpg';
      final file = File(imagePath);
      if (await file.exists()) {
        return file;
      }
    } catch (e) {
      print('Error getting profile image: $e');
    }
    return null;
  }

  Future<void> updateSubscriptionStatus({
    required bool isActive,
    DateTime? startDate,
    DateTime? endDate,
    String? plan,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final data = {
      'activeSubscription': isActive,
      if (startDate != null) 'subscriptionStartDate': Timestamp.fromDate(startDate),
      if (endDate != null) 'subscriptionEndDate': Timestamp.fromDate(endDate),
      if (plan != null) 'subscriptionPlan': plan,
    };

    await updateUserData(data);
  }

  Future<void> updateStudentVerification(bool isVerified) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await updateUserData({
      'studentDetails': {
        'isVerified': isVerified,
        'verifiedAt': Timestamp.now(),
      }
    });
  }

  Future<void> updateActiveAddress(String address) async {
    await updateUserData({'activeAddress': address});
  }

  Future<void> togglePauseSubscription(bool isPaused) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final data = {
      'isPaused': isPaused,
      if (isPaused) 'pausedAt': Timestamp.now(),
    };

    await updateUserData(data);
  }
} 