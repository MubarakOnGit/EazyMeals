import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Singleton pattern
  static final OrderService _instance = OrderService._internal();
  factory OrderService() => _instance;
  OrderService._internal();

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
} 