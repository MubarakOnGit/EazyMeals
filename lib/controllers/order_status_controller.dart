import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OrderController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  RxString todayOrderStatus = 'Pending Delivery'.obs; // Default status
  RxBool isTodayOrderDelivered = false.obs;

  void updateOrderStatus(String status) {
    todayOrderStatus.value = status;
    isTodayOrderDelivered.value = status == 'Delivered';
  }

  // Optional: Fallback to fetch data if HistoryScreen isn't visited
  void startListeningToTodayOrder() {
    User? user = _auth.currentUser;
    if (user != null) {
      DateTime now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day, 0, 0);
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

      _firestore
          .collection('orders')
          .where('userId', isEqualTo: user.uid)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(todayEnd))
          .snapshots()
          .listen((snapshot) {
            if (snapshot.docs.isNotEmpty) {
              final order = snapshot.docs.first.data() as Map<String, dynamic>;
              todayOrderStatus.value = order['status'] ?? 'Pending Delivery';
              isTodayOrderDelivered.value =
                  todayOrderStatus.value == 'Delivered';
            } else {
              todayOrderStatus.value = 'No Order';
              isTodayOrderDelivered.value = false;
            }
          });
    }
  }
}
