import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flip_card/flip_card.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/order_status_controller.dart';
import '../controllers/pause_play_controller.dart';
import '../home/address_management_screen.dart';
import '../home/student_verification_survey.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final OrderController orderController = Get.find<OrderController>();
  final PausePlayController pausePlayController =
      Get.find<PausePlayController>();
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
  bool _isDataLoaded = false; // Prevent duplicate calls
  int _loadCounter = 0; // Track _loadUserData calls

  @override
  void initState() {
    super.initState();
    if (!_isDataLoaded) {
      _loadUserData();
      _isDataLoaded = true;
    }
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
    if (user == null) {
      print('No authenticated user found');
      return;
    }
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
          // Rely on OrderController's streams
        }, onError: (e) => print('Order listener error: $e'));
  }

  Future<void> _loadUserData() async {
    _loadCounter++;
    print('Loading user data - Call #$_loadCounter');
    final user = _auth.currentUser;
    if (user == null) {
      print('No authenticated user found');
      return;
    }
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        final data = doc.data() ?? {};
        print('Full Firestore data: $data');
        setState(() {
          print('Raw name: ${data['name']}');
          userName = data['name'] is String ? data['name'] as String : 'User';
          print('Raw activeSubscription: ${data['activeSubscription']}');
          isSubscribed =
              data['activeSubscription'] is bool
                  ? data['activeSubscription'] as bool
                  : false;
          print('Raw studentDetails: ${data['studentDetails']}');
          isStudentVerified =
              data.containsKey('studentDetails')
                  ? (data['studentDetails'] is Map
                      ? (data['studentDetails']['isVerified'] ?? false)
                      : false)
                  : false;
          print('Raw activeAddress: ${data['activeAddress']}');
          if (data['activeAddress'] != null) {
            if (data['activeAddress'] is String) {
              activeAddress = data['activeAddress'] as String;
            } else if (data['activeAddress'] is Map<String, dynamic>) {
              final addressMap = data['activeAddress'] as Map<String, dynamic>;
              activeAddress =
                  addressMap['address']?.toString() ??
                  addressMap['street']?.toString() ??
                  'No address set';
            } else {
              print(
                'Unexpected activeAddress type: ${data['activeAddress'].runtimeType}',
              );
              activeAddress = 'No address set';
            }
          } else {
            activeAddress = null;
          }
          print('Processed activeAddress: $activeAddress');
          if (isSubscribed && data['subscriptionPlan'] != null) {
            print('Raw subscriptionPlan: ${data['subscriptionPlan']}');
            final plan =
                data['subscriptionPlan'] is String
                    ? data['subscriptionPlan'] as String
                    : data['subscriptionPlan'].toString();
            print('Processed subscriptionPlan: $plan');
            print(
              'Raw subscriptionStartDate: ${data['subscriptionStartDate']}',
            );
            final startDate =
                (data['subscriptionStartDate'] is Timestamp
                    ? (data['subscriptionStartDate'] as Timestamp).toDate()
                    : null);
            if (startDate != null) {
              final days =
                  plan == '1 Week'
                      ? 7
                      : plan == '3 Weeks'
                      ? 21
                      : 28;
              subscriptionEndDate = startDate.add(Duration(days: days));
              pausePlayController.subscriptionEndDate.value =
                  subscriptionEndDate;
            }
          }
          print(
            'Loaded user data: isSubscribed=$isSubscribed, subEndDate=$subscriptionEndDate',
          );
        });
      }
    } catch (e, stackTrace) {
      print('Error loading user data: $e - Full stack trace: $stackTrace');
      rethrow;
    }
    try {
      _initializeItems();
    } catch (e, stackTrace) {
      print('Error in _initializeItems: $e - Full stack trace: $stackTrace');
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
        'description':
            'Pause or resume your subscription anytime between 9 AM - 10 PM.',
        'icon': Iconsax.play,
        'hasExtraWidget': true,
        'hasReactiveSubtitle': true,
      },
      {
        'title': 'Today\'s Order',
        'description': 'View the status of your current day\'s order.',
        'icon': Icons.delivery_dining,
        'hasExtraWidget': true,
        'hasReactiveSubtitle': true,
      },
      {
        'title': 'Subscription Status',
        'description': 'Monitor your subscription duration and details.',
        'icon': Iconsax.calendar,
        'hasExtraWidget': true,
        'hasReactiveTitle': true,
        'hasReactiveSubtitle': true,
      },
      {
        'title': 'Student Verification',
        'description': 'Verify your student status for a 10% discount.',
        'icon': Icons.school,
        'hasNavigation': !isStudentVerified,
      },
      {
        'title': 'Active Address',
        'description': 'Manage addresses for seamless delivery.',
        'icon': Iconsax.location,
        'hasNavigation': true,
      },
      {
        'title': 'Support Us',
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
        filteredItems =
            allItems
                .where(
                  (item) =>
                      (item['title'] as String).toLowerCase().contains(query),
                )
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
                                        fontSize:
                                            MediaQuery.of(context).size.width *
                                            0.07,
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
                                  fontSize:
                                      MediaQuery.of(context).size.width * 0.04,
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
                              border: Border.all(
                                color: Colors.blue[200]!,
                                width: 2,
                              ),
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
                              backgroundImage:
                                  _profileImage != null
                                      ? FileImage(_profileImage!)
                                      : const AssetImage(
                                            'assets/profile_pic.jpg',
                                          )
                                          as ImageProvider,
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
                  return GestureDetector(
                    onTap:
                        item['hasNavigation'] == true
                            ? () => _navigateToScreen(item['title'] as String)
                            : null,
                    child: FlipCard(
                      flipOnTouch: false,
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
                            child: Stack(
                              children: [
                                Column(
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
                                              color: Colors.white.withAlpha(51),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Icon(
                                              item['icon'] as IconData,
                                              color: Colors.white,
                                              size: 24,
                                            ),
                                          ),
                                        if (item['hasExtraWidget'] == true)
                                          _buildExtraWidget(
                                            item['title'] as String,
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Flexible(
                                      child:
                                          item['hasReactiveTitle'] == true
                                              ? _buildReactiveTitle(
                                                item['title'] as String,
                                              )
                                              : Text(
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
                                    Flexible(
                                      child:
                                          item['hasReactiveSubtitle'] == true
                                              ? _buildReactiveSubtitle(
                                                item['title'] as String,
                                              )
                                              : Text(
                                                _getStaticSubtitle(
                                                  item['title'] as String,
                                                ),
                                                style: TextStyle(
                                                  color: Colors.white.withAlpha(
                                                    204,
                                                  ),
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                    ),
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
                                else if (item['title'] ==
                                        'Student Verification' &&
                                    isStudentVerified)
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

  Widget _buildExtraWidget(String title) {
    switch (title) {
      case 'Pause & Play':
        return Obx(
          () => Switch(
            value: pausePlayController.isPaused.value,
            onChanged:
                isSubscribed
                    ? (value) =>
                        pausePlayController.togglePausePlay(isSubscribed)
                    : null,
            activeColor: Colors.white.withOpacity(0.9),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.white.withOpacity(0.2),
          ),
        );
      case 'Today\'s Order':
        return Obx(
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
        );
      case 'Subscription Status':
        final daysLeft =
            subscriptionEndDate != null
                ? subscriptionEndDate!
                        .difference(DateTime.now())
                        .inDays
                        .clamp(0, 28) /
                    28
                : 0.0;
        return SizedBox(
          width: 50,
          height: 50,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: isSubscribed ? daysLeft : 0.0,
                strokeWidth: 5,
                backgroundColor: Colors.white.withAlpha(51),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
              ),
              Text(
                isSubscribed && subscriptionEndDate != null
                    ? '${(daysLeft * 100).round()}%'
                    : '0%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildReactiveTitle(String title) {
    if (title == 'Subscription Status') {
      return Obx(() {
        final endDate =
            pausePlayController.subscriptionEndDate.value ??
            subscriptionEndDate;
        final text =
            endDate != null && endDate.isAfter(DateTime.now())
                ? '${endDate.difference(DateTime.now()).inDays} Days Left'
                : 'No Plan Active';
        return Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        );
      });
    }
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildReactiveSubtitle(String title) {
    switch (title) {
      case 'Pause & Play':
        return Obx(
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
        );
      case 'Today\'s Order':
        return GetBuilder<OrderController>(
          builder:
              (controller) => Text(
                isSubscribed
                    ? controller.todayOrderStatus.value.isNotEmpty
                        ? controller.todayOrderStatus.value
                        : 'No order today'
                    : 'Subscribe to see today\'s order',
                style: TextStyle(
                  color: Colors.white.withAlpha(204),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
        );
      case 'Subscription Status':
        return Obx(
          () => Text(
            isSubscribed &&
                    pausePlayController.subscriptionEndDate.value != null
                ? 'Ends on ${pausePlayController.subscriptionEndDate.value!.toString().substring(0, 10)}'
                : 'Subscribe to a plan',
            style: TextStyle(
              color: Colors.white.withAlpha(204),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        );
      default:
        return Text(
          _getStaticSubtitle(title),
          style: TextStyle(
            color: Colors.white.withAlpha(204),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        );
    }
  }

  String _getStaticSubtitle(String title) {
    switch (title) {
      case 'Student Verification':
        return isStudentVerified
            ? 'Verified (10% off)'
            : 'Verify for 10% discount';
      case 'Active Address':
        return activeAddress ?? 'Set an address';
      case 'Support Us':
        return 'Share feedback & report issues';
      default:
        return '';
    }
  }
}

class LocationDetails {
  final String address;
  const LocationDetails(this.address);
  factory LocationDetails.fromMap(Map<String, dynamic> map) =>
      LocationDetails(map['address'] ?? '');
  @override
  String toString() => address;
}
