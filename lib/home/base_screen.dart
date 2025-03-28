import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:get/get.dart';

abstract class BaseScreen extends StatefulWidget {
  const BaseScreen({super.key});

  @override
  BaseScreenState createState();
}

abstract class BaseScreenState<T extends BaseScreen> extends State<T> {
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
  StreamSubscription<QuerySnapshot>? _orderSubscription;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadProfileImage();
    _scheduleDailyOrderCheck();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists && mounted) {
          final data = doc.data() ?? {};
          setState(() {
            isSubscribed = data['activeSubscription'] ?? false;
            isStudentVerified = data.containsKey('studentDetails')
                ? (data['studentDetails']['isVerified'] ?? false)
                : false;
            activeAddress = data['activeAddress'] != null
                ? (data['activeAddress'] is String
                    ? data['activeAddress'] as String
                    : data['activeAddress'].toString())
                : null;
            isPaused = data['isPaused'] ?? false;
            subscriptionStartDate = data['subscriptionStartDate'] != null
                ? (data['subscriptionStartDate'] as Timestamp).toDate()
                : null;
            subscriptionEndDate = data['subscriptionEndDate'] != null
                ? (data['subscriptionEndDate'] as Timestamp).toDate()
                : null;
          });
        }
      } catch (e) {
        print('Error loading user data: $e');
      }
    }
  }

  Future<void> _loadProfileImage() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final imagePath = '${directory.path}/profile_image.jpg';
      final file = File(imagePath);
      if (await file.exists() && mounted) {
        setState(() => _profileImage = file);
      }
    } catch (e) {
      print('Error loading profile image: $e');
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
    final user = _auth.currentUser;
    if (user != null) {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day, 0, 0);
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

      _orderSubscription = _firestore
          .collection('orders')
          .where('userId', isEqualTo: user.uid)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(todayEnd))
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          onOrderUpdate(snapshot);
        }
      }, onError: (e) => print('Order listener error: $e'));
    }
  }

  // Abstract methods that must be implemented by child classes
  void onOrderUpdate(QuerySnapshot snapshot);
  Widget buildScreen(BuildContext context);

  @override
  void dispose() {
    _dailyRefreshTimer?.cancel();
    _orderSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return buildScreen(context);
  }
} 