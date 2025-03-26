import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

class OrderController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Reactive variables for today's order status
  RxString todayOrderStatus = 'Pending Delivery'.obs;
  RxBool isTodayOrderDelivered = false.obs;
  RxString todayLunchStatus = 'Pending Delivery'.obs;
  RxString todayDinnerStatus = 'Pending Delivery'.obs;

  // Reactive lists for order tracking
  RxList<Map<String, dynamic>> todayOrders = <Map<String, dynamic>>[].obs;
  RxList<Map<String, dynamic>> pastOrders = <Map<String, dynamic>>[].obs;
  RxList<Map<String, dynamic>> upcomingOrders = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    _bindOrderStreams();
  }

  void _bindOrderStreams() {
    final user = _auth.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day, 0, 0);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    // Stream for today's orders
    _firestore
        .collection('orders')
        .where('userId', isEqualTo: user.uid)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(todayEnd))
        .snapshots()
        .listen((snapshot) {
          todayOrders.clear();
          for (var doc in snapshot.docs) {
            final data = doc.data();
            data['id'] = doc.id;
            todayOrders.add(data);
          }
          _updateTodayStatus();
        });

    // Stream for past orders
    _firestore
        .collection('orders')
        .where('userId', isEqualTo: user.uid)
        .where('date', isLessThan: Timestamp.fromDate(todayStart))
        .orderBy('date', descending: true)
        .snapshots()
        .listen((snapshot) {
          pastOrders.clear();
          for (var doc in snapshot.docs) {
            final data = doc.data();
            data['id'] = doc.id;
            pastOrders.add(data);
          }
        });

    // Stream for upcoming orders
    _firestore
        .collection('orders')
        .where('userId', isEqualTo: user.uid)
        .where('date', isGreaterThan: Timestamp.fromDate(todayEnd))
        .orderBy('date')
        .snapshots()
        .listen((snapshot) {
          upcomingOrders.clear();
          for (var doc in snapshot.docs) {
            final data = doc.data();
            data['id'] = doc.id;
            upcomingOrders.add(data);
          }
        });
  }

  void _updateTodayStatus() {
    if (todayOrders.isEmpty) {
      todayOrderStatus.value = 'No Orders';
      isTodayOrderDelivered.value = false;
      todayLunchStatus.value = 'No Lunch';
      todayDinnerStatus.value = 'No Dinner';
      return;
    }

    // Check for Lunch and Dinner separately
    bool hasLunch = false;
    bool hasDinner = false;
    bool allDelivered = true;

    for (var order in todayOrders) {
      final status = order['status'] as String? ?? 'Pending Delivery';
      final mealType = order['mealType'] as String? ?? '';

      if (mealType == 'Lunch') {
        hasLunch = true;
        todayLunchStatus.value = status;
        if (status != 'Delivered') allDelivered = false;
      } else if (mealType == 'Dinner') {
        hasDinner = true;
        todayDinnerStatus.value = status;
        if (status != 'Delivered') allDelivered = false;
      }
    }

    // Overall status
    todayOrderStatus.value = allDelivered ? 'Delivered' : 'Pending Delivery';
    isTodayOrderDelivered.value = allDelivered;

    // If no specific meal type, set to 'No X'
    if (!hasLunch) todayLunchStatus.value = 'No Lunch';
    if (!hasDinner) todayDinnerStatus.value = 'No Dinner';
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'status': status,
        'updatedAt': Timestamp.now(),
      });
      // Status will auto-update via stream, no need to manually set here
    } catch (e) {
      Get.snackbar('Error', 'Failed to update order status: $e');
    }
  }

  Map<String, dynamic> getOrderData() {
    return {
      'today': todayOrders,
      'past': pastOrders,
      'upcoming': upcomingOrders,
    };
  }
}
