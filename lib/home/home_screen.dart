import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'address_management_screen.dart';
import 'student_verification_survey.dart';
import 'package:flip_card/flip_card.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'base_state.dart';
import 'package:get/get.dart';
import '../controllers/order_status_controller.dart';
import '../controllers/pause_play_controller.dart';
import '../controllers/profile_controller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends BaseState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final OrderController orderController = Get.find<OrderController>();
  final PausePlayController pausePlayController =
      Get.find<PausePlayController>();
  final ProfileController profileController = Get.find<ProfileController>();
  String userName = 'User';
  String greeting = 'Good Morning';
  List<Map<String, dynamic>> allItems = [];
  List<Map<String, dynamic>> filteredItems = [];
  EnhancedLocationDetails? _activeEnhancedAddress;
  bool _isStudentVerified = false;
  StreamSubscription<QuerySnapshot>? _orderSubscription;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterItems);
    _setGreeting();
    profileController.loadProfileImage();
    _loadUserName();
    _loadActiveAddress();
    _initializeItems();
    _setupOrderListener();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _orderSubscription?.cancel();
    super.dispose();
  }

  void _setupOrderListener() {
    final user = currentUser;
    if (user != null) {
      print('Setting up order listener for user: ${user.uid}');
      // Get today’s date range
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day, 0, 0);
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

      // Fetch subscriptionId from user data
      firestore
          .collection('users')
          .doc(user.uid)
          .get()
          .then((doc) {
            if (doc.exists) {
              final userData = doc.data() ?? {};
              final subscriptionId =
                  userData['subscriptionId'] as String? ?? '';
              print('Subscription ID: $subscriptionId');

              _orderSubscription = firestore
                  .collection('orders')
                  .where('userId', isEqualTo: user.uid)
                  .where('subscriptionId', isEqualTo: subscriptionId)
                  .where(
                    'date',
                    isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart),
                  )
                  .where(
                    'date',
                    isLessThanOrEqualTo: Timestamp.fromDate(todayEnd),
                  )
                  .snapshots()
                  .listen(
                    onOrderUpdate,
                    onError: (e) => print('Order listener error: $e'),
                  );
            } else {
              print('User document not found');
              orderController.updateOrderStatus('No Order');
            }
          })
          .catchError((e) {
            print('Error fetching user data: $e');
            orderController.updateOrderStatus('No Order');
          });
    } else {
      print('No user logged in, cannot setup order listener');
      orderController.updateOrderStatus('No Order');
    }
  }

  @override
  void onOrderUpdate(QuerySnapshot snapshot) {
    print('Order snapshot received: ${snapshot.docs.length} docs');
    if (snapshot.docs.isNotEmpty) {
      bool allDelivered = true;
      for (var doc in snapshot.docs) {
        final order = doc.data() as Map<String, dynamic>;
        final status = order['status'] ?? 'Pending Delivery';
        print('Order ID: ${doc.id}, Status: $status');
        if (status != 'Delivered') {
          allDelivered = false;
          break;
        }
      }
      final newStatus = allDelivered ? 'Delivered' : 'Pending Delivery';
      print('Updating order status to: $newStatus');
      orderController.updateOrderStatus(newStatus);
    } else {
      print('No orders found for today');
      orderController.updateOrderStatus('No Order');
    }
  }

  @override
  String? get activeAddress => _activeEnhancedAddress?.location.address;

  @override
  set activeAddress(String? value) {
    if (value != null && _activeEnhancedAddress != null) {
      _activeEnhancedAddress = EnhancedLocationDetails(
        location: LocationDetails(
          latitude: _activeEnhancedAddress!.location.latitude,
          longitude: _activeEnhancedAddress!.location.longitude,
          address: value,
          street: _activeEnhancedAddress!.location.street,
          city: _activeEnhancedAddress!.location.city,
          country: _activeEnhancedAddress!.location.country,
        ),
        addressType: _activeEnhancedAddress!.addressType,
        buildingName: _activeEnhancedAddress!.buildingName,
        floorNumber: _activeEnhancedAddress!.floorNumber,
        doorNumber: _activeEnhancedAddress!.doorNumber,
        phoneNumber: _activeEnhancedAddress!.phoneNumber,
        additionalInfo: _activeEnhancedAddress!.additionalInfo,
        entranceLatitude: _activeEnhancedAddress!.entranceLatitude,
        entranceLongitude: _activeEnhancedAddress!.entranceLongitude,
      );
    } else {
      _activeEnhancedAddress = null;
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadUserName() async {
    final user = currentUser;
    if (user != null) {
      try {
        final doc = await firestore.collection('users').doc(user.uid).get();
        if (doc.exists && mounted) {
          final data = doc.data() ?? {};
          setState(() {
            userName = data['name'] is String ? data['name'] : 'User';
          });
        }
      } catch (e) {
        print('Error loading user name: $e');
      }
    }
  }

  Future<void> _loadActiveAddress() async {
    final user = currentUser;
    if (user != null) {
      try {
        final doc = await firestore.collection('users').doc(user.uid).get();
        if (doc.exists &&
            doc.data() != null &&
            doc.data()!['activeAddress'] != null &&
            mounted) {
          setState(() {
            _activeEnhancedAddress = EnhancedLocationDetails.fromMap(
              doc.data()!['activeAddress'] as Map<String, dynamic>,
            );
          });
        }
      } catch (e) {
        print('Error loading active address: $e');
      }
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
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StudentVerificationSurvey(),
            ),
          );
        }
        break;
      case 'Active Address':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AddressManagementScreen()),
        ).then((_) => _loadActiveAddress());
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

  void _filterItems() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredItems =
          allItems.where((item) {
            return item['name'].toString().toLowerCase().contains(query);
          }).toList();
    });
  }

  void _togglePausePlay(bool subscribed) async {
    if (!subscribed ||
        subscriptionStartDate == null ||
        DateTime.now().isBefore(subscriptionStartDate!)) {
      return;
    }
    final now = DateTime.now();
    if (now.hour < 9 || now.hour >= 22) {
      return;
    }

    await pausePlayController.togglePausePlay(subscribed);
  }

  void _initializeItems() {
    allItems = [
      {
        'name': 'Pause & Play',
        'title': 'Pause & Play',
        'description':
            'Pause or resume your subscription anytime between 9 AM - 10 PM.',
        'icon': Iconsax.play,
        'hasExtraWidget': true,
        'hasReactiveSubtitle': true,
      },
      {
        'name': 'Today\'s Order',
        'title': 'Today\'s Order',
        'description': 'View the status of your current day\'s order.',
        'icon': Icons.delivery_dining,
        'hasExtraWidget': true,
        'hasReactiveSubtitle': true,
      },
      {
        'name': 'Subscription Status',
        'title': 'Subscription Status',
        'description': 'Monitor your subscription duration and details.',
        'icon': Iconsax.calendar,
        'hasExtraWidget': true,
        'hasReactiveTitle': true,
        'hasReactiveSubtitle': true,
      },
      {
        'name': 'Student Verification',
        'title': 'Student Verification',
        'description': 'Verify your student status for a 10% discount.',
        'icon': Icons.school,
        'hasNavigation': !isStudentVerified,
      },
      {
        'name': 'Active Address',
        'title': 'Active Address',
        'description': 'Manage addresses for seamless delivery.',
        'icon': Iconsax.location,
        'hasNavigation': true,
      },
      {
        'name': 'Support Us',
        'title': 'Support Us',
        'description': 'Help us improve by sharing feedback.',
        'icon': Iconsax.heart,
        'hasNavigation': true,
      },
    ];
    filteredItems = List.from(allItems);
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
                          child: Obx(
                            () => AnimatedContainer(
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
                                    profileController.profileImage.value != null
                                        ? FileImage(
                                          profileController.profileImage.value!,
                                        )
                                        : const AssetImage(
                                              'assets/profile_pic.jpg',
                                            )
                                            as ImageProvider,
                              ),
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
                  return _buildGridItem(filteredItems[index]);
                }, childCount: filteredItems.length),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExtraWidget(String title) {
    if (!isSubscribed) {
      switch (title) {
        case 'Pause & Play':
          return Switch(
            value: false,
            onChanged: null,
            activeColor: Colors.white.withOpacity(0.9),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.white.withOpacity(0.2),
          );
        case 'Today\'s Order':
          return Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.pending,
              color: Colors.white.withOpacity(0.9),
              size: 24,
            ),
          );
        case 'Subscription Status':
          return SizedBox(
            width: 50,
            height: 50,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: 0.0,
                  strokeWidth: 5,
                  backgroundColor: Colors.white.withAlpha(51),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Colors.orange,
                  ),
                ),
                const Text(
                  '0%',
                  style: TextStyle(
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

    switch (title) {
      case 'Pause & Play':
        final now = DateTime.now();
        final isOutsideHours = now.hour < 9 || now.hour >= 22;
        if (isOutsideHours) {
          return Switch(
            value: pausePlayController.isPaused.value,
            onChanged: null,
            activeColor: Colors.white.withOpacity(0.9),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.white.withOpacity(0.2),
          );
        } else {
          return Obx(
            () => Switch(
              value: pausePlayController.isPaused.value,
              onChanged:
                  (value) => pausePlayController.togglePausePlay(isSubscribed),
              activeColor: Colors.white.withOpacity(0.9),
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: Colors.white.withOpacity(0.2),
            ),
          );
        }
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
        return Obx(() {
          final endDate = pausePlayController.subscriptionEndDate.value;
          final daysLeft =
              endDate != null
                  ? endDate.difference(DateTime.now()).inDays.clamp(0, 28) / 28
                  : 0.0;
          return SizedBox(
            width: 50,
            height: 50,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: daysLeft,
                  strokeWidth: 5,
                  backgroundColor: Colors.white.withAlpha(51),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Colors.orange,
                  ),
                ),
                Text(
                  '${(daysLeft * 100).round()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        });
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildReactiveTitle(String title) {
    if (!isSubscribed && title == 'Subscription Status') {
      return const Text(
        'No Plan Active',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    if (title == 'Subscription Status' && isSubscribed) {
      return Obx(() {
        final endDate = pausePlayController.subscriptionEndDate.value;
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
    if (!isSubscribed) {
      switch (title) {
        case 'Pause & Play':
          return const Text(
            'Not subscribed',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          );
        case 'Today\'s Order':
          return const Text(
            'Subscribe to see today\'s order',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          );
        case 'Subscription Status':
          return const Text(
            'Subscribe to a plan',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          );
        default:
          return Text(
            _getStaticSubtitle(title),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          );
      }
    }

    switch (title) {
      case 'Pause & Play':
        final now = DateTime.now();
        final isOutsideHours = now.hour < 9 || now.hour >= 22;
        if (isOutsideHours) {
          return const Text(
            'Cannot switch between 10pm - 9am',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          );
        } else {
          return Obx(
            () => Text(
              pausePlayController.isPaused.value ? 'Paused' : 'Active',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }
      case 'Today\'s Order':
        return Obx(
          () => Text(
            orderController.todayOrderStatus.value.isNotEmpty
                ? orderController.todayOrderStatus.value
                : 'No order today',
            style: const TextStyle(
              color: Colors.white,
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
            pausePlayController.subscriptionEndDate.value != null
                ? 'Ends on ${pausePlayController.subscriptionEndDate.value!.toString().substring(0, 10)}'
                : 'Subscribe to a plan',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        );
      case 'Active Address':
        return Text(
          _activeEnhancedAddress != null
              ? '${_activeEnhancedAddress!.addressType}: ${_activeEnhancedAddress!.location.address}'
              : 'No active address set',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        );
      default:
        return Text(
          _getStaticSubtitle(title),
          style: const TextStyle(
            color: Colors.white,
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

  Widget _buildGridItem(Map<String, dynamic> item) {
    final now = DateTime.now();
    final isOutsideHours = now.hour < 9 || now.hour >= 22;
    final isPausePlayRestricted =
        item['title'] == 'Pause & Play' && isSubscribed && isOutsideHours;

    return GestureDetector(
      onTap:
          (item['title'] == 'Student Verification' && isStudentVerified) ||
                  isPausePlayRestricted
              ? null
              : item['hasNavigation'] == true
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
                          if (item['hasExtraWidget'] == true)
                            _buildExtraWidget(item['title'] as String),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Flexible(
                        child: _buildReactiveTitle(item['title'] as String),
                      ),
                      const SizedBox(height: 8),
                      Flexible(
                        child: _buildReactiveSubtitle(item['title'] as String),
                      ),
                    ],
                  ),
                  if (item['hasNavigation'] == true &&
                      !(item['title'] == 'Student Verification' &&
                          isStudentVerified))
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
                  else if (item['title'] == 'Student Verification' &&
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
                    item['title'] == 'Pause & Play' &&
                            isSubscribed &&
                            (DateTime.now().hour < 9 ||
                                DateTime.now().hour >= 22)
                        ? 'Cannot switch pause or play between these times'
                        : item['description'] as String,
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
  }

  Widget _buildStudentCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[900]!, Colors.blue[700]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withAlpha(51),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.pushNamed(context, '/student-verification'),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(26),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isStudentVerified ? Icons.verified : Icons.school,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isStudentVerified
                            ? 'Student Verified'
                            : 'Student Verification',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isStudentVerified
                            ? 'Your student status has been verified'
                            : 'Verify your student status to get 10% discount',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withAlpha(179),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _isStudentVerified
                      ? Icons.check_circle
                      : Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EnhancedLocationDetails {
  final LocationDetails location;
  final String addressType;
  final String buildingName;
  final String floorNumber;
  final String doorNumber;
  final String phoneNumber;
  final String? additionalInfo;
  final double entranceLatitude;
  final double entranceLongitude;

  EnhancedLocationDetails({
    required this.location,
    required this.addressType,
    required this.buildingName,
    required this.floorNumber,
    required this.doorNumber,
    required this.phoneNumber,
    this.additionalInfo,
    required this.entranceLatitude,
    required this.entranceLongitude,
  });

  Map<String, dynamic> toMap() => {
    'location': location.toMap(),
    'addressType': addressType,
    'buildingName': buildingName,
    'floorNumber': floorNumber,
    'doorNumber': doorNumber,
    'phoneNumber': phoneNumber,
    'additionalInfo': additionalInfo,
    'entranceLatitude': entranceLatitude,
    'entranceLongitude': entranceLongitude,
  };

  factory EnhancedLocationDetails.fromMap(Map<String, dynamic> map) {
    return EnhancedLocationDetails(
      location: LocationDetails.fromMap(
        map['location'] as Map<String, dynamic>,
      ),
      addressType: map['addressType'] as String,
      buildingName: map['buildingName'] ?? '',
      floorNumber: map['floorNumber'] ?? '',
      doorNumber: map['doorNumber'] ?? '',
      phoneNumber: map['phoneNumber'] as String,
      additionalInfo: map['additionalInfo'] as String?,
      entranceLatitude: map['entranceLatitude'] as double,
      entranceLongitude: map['entranceLongitude'] as double,
    );
  }
}

class LocationDetails {
  final double latitude;
  final double longitude;
  final String address;
  final String street;
  final String city;
  final String country;

  const LocationDetails({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.street,
    required this.city,
    required this.country,
  });

  Map<String, dynamic> toMap() => {
    'latitude': latitude,
    'longitude': longitude,
    'address': address,
    'street': street,
    'city': city,
    'country': country,
  };

  factory LocationDetails.fromMap(Map<String, dynamic> map) => LocationDetails(
    latitude: map['latitude'] as double? ?? 0.0,
    longitude: map['longitude'] as double? ?? 0.0,
    address: map['address'] as String? ?? '',
    street: map['street'] as String? ?? '',
    city: map['city'] as String? ?? '',
    country: map['country'] as String? ?? '',
  );

  @override
  String toString() => address;
}
