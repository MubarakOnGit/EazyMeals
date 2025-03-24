import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OrderController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  RxString todayOrderStatus = 'Pending Delivery'.obs; // Default status
  RxBool isTodayOrderDelivered = false.obs;

  void updateOrderStatus(String status) {
    todayOrderStatus.value = status;
    isTodayOrderDelivered.value = status == 'Delivered';
  }
}
