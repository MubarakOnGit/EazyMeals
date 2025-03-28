import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SubscriptionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Singleton pattern
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

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

      // Add to past subscriptions
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
        // Add to past subscriptions
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

        // Update user document
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

  Future<List<Map<String, dynamic>>> getPastSubscriptions() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('pastSubscriptions')
          .orderBy('startDate', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      print('Error getting past subscriptions: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getCurrentSubscription() async {
    final user = _auth.currentUser;
    if (user == null) return {};

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final data = doc.data() ?? {};

      return {
        'isActive': data['activeSubscription'] ?? false,
        'plan': data['subscriptionPlan'],
        'startDate': data['subscriptionStartDate'],
        'endDate': data['subscriptionEndDate'],
        'isPaused': data['isPaused'] ?? false,
        'pausedAt': data['pausedAt'],
      };
    } catch (e) {
      print('Error getting current subscription: $e');
      return {};
    }
  }
} 