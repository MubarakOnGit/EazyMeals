import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flip_card/flip_card.dart';
import 'package:path_provider/path_provider.dart';
import '../controllers/banner_controller.dart';
import '../controllers/order_status_controller.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BannerController bannerController = Get.put(BannerController());
  final OrderController orderController = Get.find<OrderController>();
  final TextEditingController _searchController = TextEditingController();
  RxBool isSwitched = false.obs;
  RxBool isChecked = false.obs;
  String userName = 'User';
  File? _profileImage;
  String greeting = 'Good Morning';
  List<Map<String, dynamic>> allItems = [];
  List<Map<String, dynamic>> filteredItems = [];
  bool isSubscribed = false;
  DateTime? subscriptionEndDate;
  bool isStudentVerified = false;
  String? activeAddress;
  DateTime? _pauseStartTime;
  StreamSubscription<QuerySnapshot>? _orderSubscription;
  Timer? _dailyRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadProfileImage();
    _setGreeting();
    _searchController.addListener(_filterItems);
    _startOrderListener(); // Immediate check on app open
    _scheduleDailyOrderCheck(); // Schedule daily refresh
  }

  void _scheduleDailyOrderCheck() {
    final now = DateTime.now();
    var next9AM = DateTime(now.year, now.month, now.day, 9, 0);
    if (now.isAfter(next9AM)) {
      next9AM = next9AM.add(Duration(days: 1)); // Move to tomorrow if past 9 AM
    }
    final durationUntil9AM = next9AM.difference(now);

    _dailyRefreshTimer?.cancel(); // Cancel any existing timer
    _dailyRefreshTimer = Timer(durationUntil9AM, () {
      _startOrderListener();
      _dailyRefreshTimer = Timer.periodic(Duration(days: 1), (_) {
        _startOrderListener();
      });
    });
  }

  void _startOrderListener() {
    _orderSubscription?.cancel(); // Cancel any existing listener
    User? user = _auth.currentUser;
    if (user != null) {
      DateTime now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day, 0, 0);
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

      _orderSubscription = _firestore
          .collection('orders')
          .where('userId', isEqualTo: user.uid)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(todayEnd))
          .snapshots()
          .listen((snapshot) {
            if (snapshot.docs.isNotEmpty) {
              final order = snapshot.docs.first.data() as Map<String, dynamic>;
              final status = order['status'] ?? 'Pending Delivery';
              orderController.updateOrderStatus(status);
              if (status == 'Delivered') {
                _orderSubscription?.cancel();
                _orderSubscription = null; // Stop listening until next 9 AM
              }
            } else {
              orderController.updateOrderStatus('No Order');
            }
          });
    }
  }

  Future<void> _loadUserData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot doc =
            await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          setState(() {
            userName = data['name'] ?? 'User';
            isSubscribed = data['activeSubscription'] ?? false;
            isStudentVerified =
                data.containsKey('studentDetails')
                    ? (data['studentDetails']['isVerified'] ?? false)
                    : false;
            activeAddress =
                data['activeAddress'] != null
                    ? LocationDetails.fromMap(data['activeAddress']).toString()
                    : null;
            isSwitched.value = data['isPaused'] ?? false;
            _pauseStartTime =
                data['pausedAt'] != null
                    ? (data['pausedAt'] as Timestamp).toDate()
                    : null;
            if (isSubscribed && data['subscriptionPlan'] != null) {
              String plan = data['subscriptionPlan'];
              Timestamp? createdAt = data['createdAt'];
              if (createdAt != null) {
                DateTime startDate = createdAt.toDate();
                int days =
                    plan == '1 Week'
                        ? 7
                        : plan == '3 Weeks'
                        ? 21
                        : 28;
                subscriptionEndDate = startDate.add(Duration(days: days));
              }
            }
          });
        }
      } catch (e) {
        print('Error loading user data: $e');
      }
    }
    _initializeItems();
  }

  Future<void> _loadProfileImage() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final imagePath = '${directory.path}/profile_image.jpg';
      final file = File(imagePath);
      if (await file.exists()) setState(() => _profileImage = file);
    } catch (e) {
      print('Error loading profile image: $e');
    }
  }

  void _setGreeting() {
    final now = DateTime.now();
    final hour = now.hour;
    setState(() {
      greeting =
          hour >= 5 && hour < 12
              ? 'Good Morning'
              : hour >= 12 && hour < 17
              ? 'Good Afternoon'
              : hour >= 17 && hour < 20
              ? 'Good Evening'
              : 'Good Night';
    });
  }

  bool _canPauseOrPlay() {
    final now = DateTime.now();
    return isSubscribed && (now.hour >= 9 && now.hour < 22);
  }

  Future<void> _togglePausePlay() async {
    User? user = _auth.currentUser;
    if (user == null || !isSubscribed || subscriptionEndDate == null) return;
    bool newIsPaused = !isSwitched.value;
    if (_canPauseOrPlay()) {
      setState(() {
        if (isSwitched.value && _pauseStartTime != null) {
          final pausedDuration =
              DateTime.now().difference(_pauseStartTime!).inSeconds;
          subscriptionEndDate = subscriptionEndDate!.add(
            Duration(seconds: pausedDuration),
          );
          _pauseStartTime = null;
          isSwitched.value = false;
        } else {
          _pauseStartTime = DateTime.now();
          isSwitched.value = true;
        }
      });
      try {
        await _firestore.collection('users').doc(user.uid).update({
          'isPaused': newIsPaused,
          'pausedAt': newIsPaused ? Timestamp.now() : FieldValue.delete(),
          'subscriptionEndDate': Timestamp.fromDate(subscriptionEndDate!),
        });
        newIsPaused
            ? await _markNextDayPaused(user.uid)
            : await _resumeNextDay(user.uid);
      } catch (e) {
        print('Error in togglePausePlay: $e');
        setState(() => isSwitched.value = !newIsPaused);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update subscription status')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You can only pause or play between 9 AM - 10 PM'),
        ),
      );
    }
  }

  Future<void> _markNextDayPaused(String userId) async {
    final now = DateTime.now();
    final tomorrow = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(Duration(days: 1));
    final tomorrowStart = DateTime(
      tomorrow.year,
      tomorrow.month,
      tomorrow.day,
      0,
      0,
    );
    final tomorrowEnd = DateTime(
      tomorrow.year,
      tomorrow.month,
      tomorrow.day,
      23,
      59,
      59,
    );
    QuerySnapshot orders =
        await _firestore
            .collection('orders')
            .where('userId', isEqualTo: userId)
            .where('status', isEqualTo: 'Pending Delivery')
            .where(
              'date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(tomorrowStart),
            )
            .where('date', isLessThanOrEqualTo: Timestamp.fromDate(tomorrowEnd))
            .get();
    for (var order in orders.docs) {
      await order.reference.update({'status': 'Paused'});
    }
  }

  Future<void> _resumeNextDay(String userId) async {
    final now = DateTime.now();
    final tomorrow = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(Duration(days: 1));
    final tomorrowStart = DateTime(
      tomorrow.year,
      tomorrow.month,
      tomorrow.day,
      0,
      0,
    );
    final tomorrowEnd = DateTime(
      tomorrow.year,
      tomorrow.month,
      tomorrow.day,
      23,
      59,
      59,
    );
    QuerySnapshot orders =
        await _firestore
            .collection('orders')
            .where('userId', isEqualTo: userId)
            .where('status', isEqualTo: 'Paused')
            .where(
              'date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(tomorrowStart),
            )
            .where('date', isLessThanOrEqualTo: Timestamp.fromDate(tomorrowEnd))
            .get();
    for (var order in orders.docs) {
      await order.reference.update({'status': 'Pending Delivery'});
    }
  }

  void _initializeItems() {
    allItems = [
      {
        'title': 'Pause & Play',
        'description':
            'Pause or resume your subscription anytime between 9 AM - 10 PM.',
        'icon': Iconsax.play,
        'extraWidget': Obx(
          () => Switch(
            value: isSwitched.value,
            onChanged: isSubscribed ? (value) => _togglePausePlay() : null,
            activeColor: Colors.blue[600],
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.blue[200],
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
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        'description': 'View the status of your current day\'s order.',
        'icon': Iconsax.truck_fast,
        'extraWidget': Obx(
          () => Icon(
            orderController.todayOrderStatus.value == 'Delivered'
                ? Icons.check_circle
                : Icons.pending,
            color:
                orderController.todayOrderStatus.value == 'Delivered'
                    ? Colors.green
                    : Colors.orange,
            size: 24,
          ),
        ),
      },
      {
        'title':
            isSubscribed && subscriptionEndDate != null
                ? '${subscriptionEndDate!.difference(DateTime.now()).inDays} Days Left'
                : 'No Plan Active',
        'subtitle':
            isSubscribed && subscriptionEndDate != null
                ? 'Ends on ${subscriptionEndDate!.toString().substring(0, 10)}'
                : 'Subscribe to a plan',
        'description': 'Monitor your subscription duration and details.',
        'icon': Iconsax.calendar,
        'extraWidget': Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                value:
                    isSubscribed && subscriptionEndDate != null
                        ? (subscriptionEndDate!
                                    .difference(DateTime.now())
                                    .inDays /
                                (subscriptionEndDate!
                                    .difference(
                                      subscriptionEndDate!.subtract(
                                        Duration(days: 28),
                                      ),
                                    )
                                    .inDays
                                    .abs()))
                            .clamp(0.0, 1.0)
                        : 0.0,
                strokeWidth: 5,
                backgroundColor: Colors.white.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
              ),
            ),
            Text(
              isSubscribed && subscriptionEndDate != null
                  ? '${((subscriptionEndDate!.difference(DateTime.now()).inDays / (subscriptionEndDate!.difference(subscriptionEndDate!.subtract(Duration(days: 28))).inDays.abs())) * 100).round()}%'
                  : '0%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      },
      {
        'title': 'Student Verification',
        'subtitle':
            isStudentVerified
                ? 'Verified (10% off)'
                : 'Verify for 10% discount',
        'description': 'Verify your student status for a 10% discount.',
        'icon': Iconsax.user_edit,
      },
      {
        'title': 'Active Address',
        'subtitle': activeAddress ?? 'Set an address',
        'description': 'Manage addresses for seamless delivery.',
        'icon': Iconsax.location,
      },
      {
        'title': 'Support Us',
        'subtitle': 'Share feedback & report issues',
        'description': 'Help us improve by sharing feedback.',
        'icon': Iconsax.heart,
      },
    ];
    filteredItems = List.from(allItems);
  }

  void _filterItems() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      filteredItems =
          allItems
              .where((item) => item['title'].toLowerCase().contains(query))
              .toList();
    });
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
              expandedHeight: 140,
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
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Hi, $userName!',
                                  style: TextStyle(
                                    color: Colors.blue[900],
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Iconsax.profile_tick,
                                  color: Colors.blue[700],
                                  size: 24,
                                ),
                              ],
                            ),
                            Text(
                              greeting,
                              style: TextStyle(
                                color: Colors.blue[600],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.blue[200]!,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.white,
                            backgroundImage:
                                _profileImage != null
                                    ? FileImage(_profileImage!)
                                    : const AssetImage('assets/profile_pic.jpg')
                                        as ImageProvider,
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
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              centerTitle: true,
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search options...',
                    hintStyle: TextStyle(color: Colors.blue[400], fontSize: 16),
                    prefixIcon: Icon(
                      Iconsax.search_normal,
                      color: Colors.blue[600],
                      size: 20,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: Colors.blue[100]!,
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: Colors.blue[300]!,
                        width: 1.5,
                      ),
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
                  return FlipCard(
                    direction: FlipDirection.HORIZONTAL,
                    front: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      child: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
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
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  if (item['icon'] != null)
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        item['icon'],
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                  if (item['extraWidget'] != null)
                                    item['extraWidget'],
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                item['title']!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              item['subtitle'] is Widget
                                  ? item['subtitle']
                                  : Text(
                                    index == 0
                                        ? (isSubscribed
                                            ? (!_canPauseOrPlay()
                                                ? 'Switch unavailable now'
                                                : (isSwitched.value
                                                    ? 'Paused'
                                                    : 'Active'))
                                            : 'Not subscribed')
                                        : item['subtitle']!,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    back: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
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
                            Text(
                              item['description']!,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                              maxLines: 5,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
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
  LocationDetails(this.address);
  factory LocationDetails.fromMap(Map<String, dynamic> map) =>
      LocationDetails(map['address'] ?? '');
  @override
  String toString() => address;
}
