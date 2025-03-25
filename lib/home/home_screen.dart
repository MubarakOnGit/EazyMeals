import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'address_management_screen.dart';
import 'student_verification_survey.dart';
import 'package:flip_card/flip_card.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/order_status_controller.dart';
import '../controllers/pause_play_controller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final OrderController orderController = Get.find<OrderController>();
  final PausePlayController pausePlayController = Get.find<PausePlayController>();
  final TextEditingController _searchController = TextEditingController();
  String userName = 'User';
  File? _profileImage;
  String greeting = 'Good Morning';
  List<Map<String, dynamic>> allItems = [];
  List<Map<String, dynamic>> filteredItems = [];
  bool isSubscribed = false;
  DateTime? subscriptionEndDate;
  bool isStudentVerified = false;
  String? activeAddress;
  StreamSubscription<QuerySnapshot>? _orderSubscription;
  Timer? _dailyRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadProfileImage();
    _setGreeting();
    _searchController.addListener(_filterItems);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startOrderListener();
      _scheduleDailyOrderCheck();
    });
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
          .listen(
            (snapshot) {
          if (snapshot.docs.isNotEmpty && mounted) {
            final order = snapshot.docs.first.data();
            final status = order['status'] ?? 'Pending Delivery';
            orderController.updateOrderStatus(status);
            if (status == 'Delivered') {
              _orderSubscription?.cancel();
              _orderSubscription = null;
            }
          } else if (mounted) {
            orderController.updateOrderStatus('No Order');
          }
        },
        onError: (e) => print('Order listener error: $e'),
      );
    }
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists && mounted) {
          final data = doc.data() ?? {};
          setState(() {
            userName = data['name'] ?? 'User';
            isSubscribed = data['activeSubscription'] ?? false;
            isStudentVerified = data.containsKey('studentDetails')
                ? (data['studentDetails']['isVerified'] ?? false)
                : false;
            activeAddress = data['activeAddress'] != null
                ? (data['activeAddress'] is String
                ? data['activeAddress'] as String
                : LocationDetails.fromMap(data['activeAddress'] as Map<String, dynamic>).toString())
                : null;
            if (isSubscribed && data['subscriptionPlan'] != null) {
              final plan = data['subscriptionPlan'] as String;
              final createdAt = data['createdAt'] as Timestamp?;
              if (createdAt != null) {
                final startDate = createdAt.toDate();
                final days = plan == '1 Week' ? 7 : plan == '3 Weeks' ? 21 : 28;
                subscriptionEndDate = startDate.add(Duration(days: days));
                pausePlayController.subscriptionEndDate.value = subscriptionEndDate;
              }
            }
            print('Loaded user data: isSubscribed=$isSubscribed, subEndDate=$subscriptionEndDate');
          });
        }
      } catch (e) {
        print('Error loading user data: $e');
      }
      _initializeItems();
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

  void _setGreeting() {
    final now = DateTime.now();
    final hour = now.hour;
    if (mounted) {
      setState(() {
        greeting = hour >= 5 && hour < 12
            ? 'Good Morning'
            : hour >= 12 && hour < 17
            ? 'Good Afternoon'
            : hour >= 17 && hour < 20
            ? 'Good Evening'
            : 'Good Night';
      });
    }
  }

  void _navigateToScreen(String title) {
    print('Navigating to: $title');
    switch (title) {
      case 'Student Verification':
        if (!isStudentVerified) {
          Get.to(() => StudentVerificationSurvey());
        }
        break;
      case 'Active Address':
        Get.to(() => AddressManagementScreen());
        break;
      case 'Support Us':
        _launchWhatsApp();
        break;
      default:
        print('No navigation defined for: $title');
    }
  }

  void _launchWhatsApp() async {
    const phoneNumber = '+995500900095';
    const message = 'Hello, I need support!';
    final url = 'https://wa.me/$phoneNumber?text=${Uri.encodeFull(message)}';

    if (await canLaunch(url)) {
      await launch(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch WhatsApp')),
      );
    }
  }

  void _initializeItems() {
    allItems = [
      {
        'title': 'Pause & Play',
        'description': 'Pause or resume your subscription anytime between 9 AM - 10 PM.',
        'icon': Iconsax.play,
        'extraWidget': Obx(
              () => Switch(
            value: pausePlayController.isPaused.value,
            onChanged: isSubscribed
                ? (value) => pausePlayController.togglePausePlay(isSubscribed)
                : null,
            activeColor: Colors.white.withOpacity(0.9),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.white.withOpacity(0.2),
          ),
        ),
        'subtitle': Obx(
              () => Text(
            isSubscribed
                ? (DateTime.now().hour >= 9 && DateTime.now().hour < 22
                ? (pausePlayController.isPaused.value ? 'Paused' : 'Active')
                : 'Switch unavailable now')
                : 'Not subscribed',
            style: TextStyle(
              color: Colors.white.withAlpha(204),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      },
      {
        'title': 'Today\'s Order',
        'subtitle': Obx(
              () => Text(
            isSubscribed
                ? orderController.todayOrderStatus.value
                : 'Subscribe to see today\'s order',
            style: TextStyle(
              color: Colors.white.withAlpha(204),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        'description': 'View the status of your current day\'s order.',
        'icon': Icons.delivery_dining,
        'extraWidget': Obx(
              () => Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              orderController.todayOrderStatus.value == 'Delivered'
                  ? Icons.check_circle
                  : Icons.pending,
              color: Colors.white.withOpacity(0.9),
              size: 24,
            ),
          ),
        ),
      },
      {
        'title': isSubscribed && subscriptionEndDate != null
            ? '${subscriptionEndDate!.difference(DateTime.now()).inDays} Days Left'
            : 'No Plan Active',
        'subtitle': Text(
          isSubscribed && subscriptionEndDate != null
              ? 'Ends on ${subscriptionEndDate!.toString().substring(0, 10)}'
              : 'Subscribe to a plan',
          style: TextStyle(
            color: Colors.white.withAlpha(204),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        'description': 'Monitor your subscription duration and details.',
        'icon': Iconsax.calendar,
        'extraWidget': SizedBox(
          width: 50,
          height: 50,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: isSubscribed && subscriptionEndDate != null
                    ? (subscriptionEndDate!.difference(DateTime.now()).inDays /
                    (subscriptionEndDate!
                        .difference(
                      subscriptionEndDate!.subtract(const Duration(days: 28)),
                    )
                        .inDays
                        .abs()))
                    .clamp(0.0, 1.0)
                    : 0.0,
                strokeWidth: 5,
                backgroundColor: Colors.white.withAlpha(51),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
              ),
              FittedBox(
                child: Text(
                  isSubscribed && subscriptionEndDate != null
                      ? '${((subscriptionEndDate!.difference(DateTime.now()).inDays / (subscriptionEndDate!.difference(subscriptionEndDate!.subtract(const Duration(days: 28))).inDays.abs())) * 100).round()}%'
                      : '0%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      },
      {
        'title': 'Student Verification',
        'subtitle': Text(
          isStudentVerified ? 'Verified (10% off)' : 'Verify for 10% discount',
          style: TextStyle(
            color: Colors.white.withAlpha(204),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        'description': 'Verify your student status for a 10% discount.',
        'icon': Icons.school,
        'hasNavigation': !isStudentVerified,
      },
      {
        'title': 'Active Address',
        'subtitle': Text(
          activeAddress ?? 'Set an address',
          style: TextStyle(
            color: Colors.white.withAlpha(204),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        'description': 'Manage addresses for seamless delivery.',
        'icon': Iconsax.location,
        'hasNavigation': true,
      },
      {
        'title': 'Support Us',
        'subtitle': Text(
          'Share feedback & report issues',
          style: TextStyle(
            color: Colors.white.withAlpha(204),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        'description': 'Help us improve by sharing feedback.',
        'icon': Iconsax.heart,
        'hasNavigation': true,
      },
    ];
    filteredItems = List.from(allItems);
  }

  void _filterItems() {
    final query = _searchController.text.toLowerCase();
    if (mounted) {
      setState(() {
        filteredItems = allItems
            .where((item) => (item['title'] as String).toLowerCase().contains(query))
            .toList();
      });
    }
  }

  @override
  void dispose() {
    _orderSubscription?.cancel();
    _dailyRefreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              backgroundColor: Colors.white,
              pinned: true,
              elevation: 0,
              expandedHeight: MediaQuery.of(context).size.height * 0.22,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue[50]!, Colors.white],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          flex: 2,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Hi, $userName!',
                                      style: TextStyle(
                                        color: Colors.blue[900],
                                        fontSize: MediaQuery.of(context).size.width * 0.07,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                greeting,
                                style: TextStyle(
                                  color: Colors.blue[600],
                                  fontSize: MediaQuery.of(context).size.width * 0.04,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                        Flexible(
                          flex: 1,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.blue[200]!, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withAlpha(26),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.white,
                              backgroundImage: _profileImage != null
                                  ? FileImage(_profileImage!)
                                  : const AssetImage('assets/profile_pic.jpg') as ImageProvider,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              title: Text(
                'Home',
                style: TextStyle(
                  color: Colors.blue[900],
                  fontSize: MediaQuery.of(context).size.width * 0.05,
                  fontWeight: FontWeight.w700,
                ),
              ),
              centerTitle: true,
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search options...',
                    hintStyle: TextStyle(color: Colors.blue[400], fontSize: 16),
                    prefixIcon: Icon(Iconsax.search_normal, color: Colors.blue[600], size: 20),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.blue[100]!, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.blue[300]!, width: 1.5),
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.75,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final item = filteredItems[index];
                  return GestureDetector(
                    onTap: item['hasNavigation'] == true ? () => _navigateToScreen(item['title'] as String) : null,
                    child: FlipCard(
                      flipOnTouch: false,
                      direction: FlipDirection.HORIZONTAL,
                      front: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        child: Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.blue[700]!, Colors.blue[900]!],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Stack(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        if (item['icon'] != null)
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withAlpha(51),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Icon(
                                              item['icon'] as IconData,
                                              color: Colors.white,
                                              size: 24,
                                            ),
                                          ),
                                        if (item['extraWidget'] != null) Flexible(child: item['extraWidget'] as Widget),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Flexible(
                                      child: Text(
                                        item['title'] as String,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Flexible(child: item['subtitle'] as Widget),
                                  ],
                                ),
                                if (item['hasNavigation'] == true)
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.arrow_circle_right,
                                        color: Colors.white.withOpacity(0.9),
                                        size: 24,
                                      ),
                                    ),
                                  )
                                else if (item['title'] == 'Student Verification' && isStudentVerified)
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.check_circle,
                                        color: Colors.white.withOpacity(0.9),
                                        size: 24,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      back: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.blue[700]!, Colors.blue[900]!],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  item['description'] as String,
                                  style: TextStyle(
                                    color: Colors.white.withAlpha(230),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  maxLines: 5,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }, childCount: filteredItems.length),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LocationDetails {
  final String address;
  const LocationDetails(this.address);
  factory LocationDetails.fromMap(Map<String, dynamic> map) => LocationDetails(map['address'] ?? '');
  @override
  String toString() => address;
}