import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class AppService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Singleton pattern
  static final AppService _instance = AppService._internal();
  factory AppService() => _instance;
  AppService._internal();

  // User related operations
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

  // Profile image operations
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

  // Subscription operations
  Future<void> activateSubscription({
    required String plan,
    required DateTime startDate,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final endDate = startDate.add(Duration(
        days: plan == '1 Week' ? 7 : plan == '3 Weeks' ? 21 : 28,
      ));

      await _firestore.collection('users').doc(user.uid).update({
        'activeSubscription': true,
        'subscriptionPlan': plan,
        'subscriptionStartDate': Timestamp.fromDate(startDate),
        'subscriptionEndDate': Timestamp.fromDate(endDate),
        'isPaused': false,
      });

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('pastSubscriptions')
          .add({
        'plan': plan,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'status': 'Active',
      });
    } catch (e) {
      print('Error activating subscription: $e');
      rethrow;
    }
  }

  Future<void> deactivateSubscription() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      if (userData['activeSubscription'] == true) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('pastSubscriptions')
            .add({
          'plan': userData['subscriptionPlan'],
          'startDate': userData['subscriptionStartDate'],
          'endDate': Timestamp.now(),
          'status': 'Ended',
          'endedNaturally': true,
        });

        await _firestore.collection('users').doc(user.uid).update({
          'activeSubscription': false,
          'subscriptionPlan': FieldValue.delete(),
          'subscriptionStartDate': FieldValue.delete(),
          'subscriptionEndDate': FieldValue.delete(),
          'isPaused': FieldValue.delete(),
          'pausedAt': FieldValue.delete(),
        });
      }
    } catch (e) {
      print('Error deactivating subscription: $e');
      rethrow;
    }
  }

  Future<void> togglePauseSubscription(bool isPaused) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'isPaused': isPaused,
        if (isPaused) 'pausedAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error toggling subscription pause: $e');
      rethrow;
    }
  }

  // Order operations
  Stream<QuerySnapshot> getTodayOrders() {
    final user = _auth.currentUser;
    if (user == null) return Stream.empty();

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day, 0, 0);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return _firestore
        .collection('orders')
        .where('userId', isEqualTo: user.uid)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(todayEnd))
        .snapshots();
  }

  Future<void> cancelOrder(String orderId) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'status': 'Cancelled',
        'cancelledAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error cancelling order: $e');
      rethrow;
    }
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'status': status,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error updating order status: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getOrderHistory() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final snapshot = await _firestore
          .collection('orders')
          .where('userId', isEqualTo: user.uid)
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      print('Error getting order history: $e');
      return [];
    }
  }

  Future<void> createOrder(Map<String, dynamic> orderData) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('orders').add({
        ...orderData,
        'userId': user.uid,
        'date': Timestamp.now(),
        'status': 'Pending',
      });
    } catch (e) {
      print('Error creating order: $e');
      rethrow;
    }
  }

  Future<void> cancelPendingOrders() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day, 0, 0);
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final orders = await _firestore
          .collection('orders')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'Pending')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(todayEnd))
          .get();

      final batch = _firestore.batch();
      for (var doc in orders.docs) {
        batch.update(doc.reference, {
          'status': 'Cancelled',
          'cancelledAt': Timestamp.now(),
        });
      }
      await batch.commit();
    } catch (e) {
      print('Error cancelling pending orders: $e');
      rethrow;
    }
  }

  // Student verification
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

  // Address management
  Future<void> updateActiveAddress(String address) async {
    await updateUserData({'activeAddress': address});
  }
} 