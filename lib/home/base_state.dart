import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/app_service.dart';

abstract class BaseState<T extends StatefulWidget> extends State<T> {
  final AppService _appService = AppService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Common state variables
  bool isSubscribed = false;
  DateTime? subscriptionStartDate;
  DateTime? subscriptionEndDate;
  bool isStudentVerified = false;
  String? activeAddress;
  bool isPaused = false;
  File? _profileImage;
  Timer? _dailyRefreshTimer;
  StreamSubscription? _orderSubscription;

  // Getters for Firebase instances
  User? get currentUser => _auth.currentUser;
  FirebaseFirestore get firestore => _firestore;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _scheduleDailyOrderCheck();
  }

  Future<void> _loadInitialData() async {
    await _loadUserData();
    await _loadProfileImage();
  }

  Future<void> _loadUserData() async {
    final userData = await _appService.getUserData();
    if (mounted) {
      setState(() {
        isSubscribed = userData['activeSubscription'] ?? false;
        isStudentVerified = userData.containsKey('studentDetails')
            ? (userData['studentDetails']['isVerified'] ?? false)
            : false;
        activeAddress = userData['activeAddress'] != null
            ? (userData['activeAddress'] is String
                ? userData['activeAddress'] as String
                : userData['activeAddress'].toString())
            : null;
        isPaused = userData['isPaused'] ?? false;
        subscriptionStartDate = userData['subscriptionStartDate'] != null
            ? (userData['subscriptionStartDate'] as Timestamp).toDate()
            : null;
        subscriptionEndDate = userData['subscriptionEndDate'] != null
            ? (userData['subscriptionEndDate'] as Timestamp).toDate()
            : null;
      });
    }
  }

  Future<void> _loadProfileImage() async {
    final image = await _appService.getProfileImage();
    if (mounted) {
      setState(() => _profileImage = image);
    }
  }

  void _scheduleDailyOrderCheck() {
    final now = DateTime.now();
    var next9AM = DateTime(now.year, now.month, now.day, 9, 0);
    if (now.isAfter(next9AM)) {
      next9AM = next9AM.add(const Duration(days: 1));
    }
    final durationUntil9AM = next9AM.difference(now);

    _dailyRefreshTimer?.cancel();
    _dailyRefreshTimer = Timer(durationUntil9AM, () {
      _startOrderListener();
      _dailyRefreshTimer = Timer.periodic(const Duration(days: 1), (_) {
        _startOrderListener();
      });
    });
  }

  void _startOrderListener() {
    _orderSubscription?.cancel();
    _orderSubscription = _appService.getTodayOrders().listen(
      (snapshot) {
        if (mounted) {
          onOrderUpdate(snapshot);
        }
      },
      onError: (e) => print('Order listener error: $e'),
    );
  }

  // Abstract methods that must be implemented by child classes
  void onOrderUpdate(QuerySnapshot snapshot);

  // Common methods for child classes to use
  Future<void> updateProfileImage(File imageFile) async {
    await _appService.updateProfileImage(imageFile);
    await _loadProfileImage();
  }

  Future<void> toggleSubscriptionPause(bool isPaused) async {
    await _appService.togglePauseSubscription(isPaused);
    await _loadUserData();
  }

  Future<void> updateStudentVerification(bool isVerified) async {
    await _appService.updateStudentVerification(isVerified);
    await _loadUserData();
  }

  Future<void> updateActiveAddress(String address) async {
    await _appService.updateActiveAddress(address);
    await _loadUserData();
  }

  Future<void> cancelOrder(String orderId) async {
    await _appService.cancelOrder(orderId);
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    await _appService.updateOrderStatus(orderId, status);
  }

  Future<void> createOrder(Map<String, dynamic> orderData) async {
    await _appService.createOrder(orderData);
  }

  Future<void> cancelPendingOrders() async {
    await _appService.cancelPendingOrders();
  }

  Future<void> loadUserData() async {
    await _loadUserData();
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<void> deactivateSubscription() async {
    await _appService.deactivateSubscription();
    await _loadUserData();
  }

  @override
  void dispose() {
    _dailyRefreshTimer?.cancel();
    _orderSubscription?.cancel();
    super.dispose();
  }
} 