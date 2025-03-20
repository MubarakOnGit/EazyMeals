import 'dart:io';
import 'package:flip_card/flip_card.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iconsax/iconsax.dart';
import 'package:path_provider/path_provider.dart';
import '../controllers/banner_controller.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BannerController bannerController = Get.put(BannerController());
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
  bool isTodayOrderDelivered = false;
  DateTime? _pauseStartTime;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadProfileImage();
    _setGreeting();
    _searchController.addListener(_filterItems);
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
            _checkTodayOrderStatus(user.uid);
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
      if (await file.exists()) {
        setState(() => _profileImage = file);
      }
    } catch (e) {
      print('Error loading profile image: $e');
    }
  }

  void _setGreeting() {
    final now = DateTime.now();
    final hour = now.hour;
    setState(() {
      if (hour >= 5 && hour < 12) {
        greeting = 'Good Morning';
      } else if (hour >= 12 && hour < 17) {
        greeting = 'Good Afternoon';
      } else if (hour >= 17 && hour < 20) {
        greeting = 'Good Evening';
      } else {
        greeting = 'Good Night';
      }
    });
  }

  Future<void> _checkTodayOrderStatus(String uid) async {
    try {
      DateTime now = DateTime.now();
      String today = '${now.year}-${now.month}-${now.day}';
      DocumentSnapshot orderDoc =
          await _firestore
              .collection('users')
              .doc(uid)
              .collection('orders')
              .doc(today)
              .get();
      if (orderDoc.exists) {
        final data = orderDoc.data() as Map<String, dynamic>;
        isTodayOrderDelivered = data['delivered'] ?? false;
        isChecked.value = isTodayOrderDelivered;
      }
    } catch (e) {
      print('Error checking order status: $e');
    }
  }

  bool _canPauseOrPlay() {
    final now = DateTime.now();
    final hour = now.hour;
    return isSubscribed && (hour >= 9 && hour < 22); // Allowed 9 AM - 10 PM
  }

  Future<void> _togglePausePlay() async {
    User? user = _auth.currentUser;
    if (user == null || !isSubscribed || subscriptionEndDate == null) return;

    bool newIsPaused = !isSwitched.value;
    if (_canPauseOrPlay()) {
      setState(() {
        if (isSwitched.value) {
          if (_pauseStartTime != null) {
            final pausedDuration =
                DateTime.now().difference(_pauseStartTime!).inSeconds;
            subscriptionEndDate = subscriptionEndDate!.add(
              Duration(seconds: pausedDuration),
            );
            _pauseStartTime = null;
          }
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

        if (newIsPaused) {
          await _markNextDayPaused(user.uid);
        } else {
          await _resumeNextDay(user.uid);
        }
        _initializeItems(); // Refresh subtitle
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
    bool isRestrictedTime = !_canPauseOrPlay();
    allItems = [
      {
        'title': 'Pause and Play',
        'subtitle':
            isSubscribed
                ? (isRestrictedTime
                    ? 'You are currently ${isSwitched.value ? 'paused' : 'ongoing'}, you can’t switch between these times'
                    : (isSwitched.value
                        ? 'You are currently paused'
                        : 'You are currently ongoing'))
                : 'Currently not subscribed',
        'description':
            'You can pause and play your subscription according to your wishes this way you can save the money and the dish',
        'icon': Iconsax.play,
        'secondaryIcon': Iconsax.arrow_circle_right,
        'extraWidget': Obx(
          () => Switch(
            value: isSwitched.value,
            onChanged: isSubscribed ? (value) => _togglePausePlay() : null,
            activeColor: Colors.blue.shade200,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.blue.shade900,
          ),
        ),
      },
      {
        'title': 'Today\'s Order',
        'subtitle':
            isSubscribed
                ? 'Check your order status'
                : 'You are not subscribed to any plan yet',
        'description':
            'You can see the current day\'s order status from here you can also check the orders page for more information',
        'icon': null,
        'secondaryIcon': Iconsax.arrow_circle_right,
        'extraWidget': Obx(
          () => Checkbox(
            value: isChecked.value,
            onChanged: isSubscribed ? null : (value) {},
            activeColor: Colors.blue.shade200,
            checkColor: Colors.blue.shade900,
            side: BorderSide(
              color: isChecked.value ? Colors.blue.shade200 : Colors.orange,
              width: 1.5,
            ),
            fillColor: MaterialStateProperty.resolveWith((states) {
              if (!states.contains(MaterialState.selected)) {
                return Colors.blue.shade900;
              }
              return null;
            }),
          ),
        ),
      },
      {
        'title':
            isSubscribed && subscriptionEndDate != null
                ? '${subscriptionEndDate!.difference(DateTime.now()).inDays} Days Left'
                : '0 Days Left',
        'subtitle':
            isSubscribed
                ? 'Your plan ends on ${subscriptionEndDate?.toString().substring(0, 10) ?? ''}'
                : 'Subscribe to a plan',
        'description': 'Check the orders section for more details',
        'icon': null,
        'secondaryIcon': Iconsax.arrow_circle_right,
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
                backgroundColor: Colors.white30,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
              ),
            ),
            Text(
              isSubscribed && subscriptionEndDate != null
                  ? '${((subscriptionEndDate!.difference(DateTime.now()).inDays / (subscriptionEndDate!.difference(subscriptionEndDate!.subtract(Duration(days: 28))).inDays.abs())) * 100).round()}%'
                  : '0%',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
      },
      {
        'title': 'Student Verification',
        'subtitle':
            isStudentVerified
                ? 'You are verified (10% discount active)'
                : 'Complete your student verification to get 10% discount',
        'description':
            'Complete your student verification with your university ID to get 10% discount',
        'icon': Iconsax.user_edit,
        'secondaryIcon': Iconsax.arrow_circle_right,
        'extraWidget': null,
      },
      {
        'title': 'Your Active Address',
        'subtitle': activeAddress ?? 'No active address set',
        'description':
            'You can add multiple addresses and set to an active address then our team can easily reach you in your place',
        'icon': Iconsax.location,
        'secondaryIcon': Iconsax.arrow_circle_right,
        'extraWidget': null,
      },
      {
        'title': 'Support Us',
        'subtitle': 'Report bugs as well as inform your feedback',
        'description':
            'Please feel free to inform your ideas and feedbacks, also don\'t forget to report an issue if you find anything',
        'icon': Iconsax.heart,
        'secondaryIcon': Iconsax.arrow_circle_right,
        'extraWidget': null,
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.grey.shade900,
        elevation: 0,
        title: Center(
          child: Text(
            'Home',
            style: TextStyle(
              color: Colors.blue[900],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10.0),
            child: CircleAvatar(
              radius: 18,
              backgroundImage:
                  _profileImage != null
                      ? FileImage(_profileImage!)
                      : AssetImage('assets/profile_pic.jpg') as ImageProvider,
            ),
          ),
        ],
      ),
      backgroundColor: Colors.grey.shade900,
      body: SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hi $userName!👋🏼',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Text(
                        greeting,
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: TextField(
                          controller: _searchController,
                          cursorColor: Colors.transparent,
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.search, color: Colors.blue),
                            hintText: 'Search...',
                            hintStyle: TextStyle(color: Colors.blue.shade500),
                            filled: true,
                            fillColor: Colors.grey[300],
                            border: InputBorder.none,
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide.none,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide.none,
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    '  Browse',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: GridView.builder(
                    physics: NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 5,
                      mainAxisSpacing: 5,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      Gradient gradient = LinearGradient(
                        colors: [Colors.blue.shade900, Colors.blue.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      );

                      return FlipCard(
                        direction: FlipDirection.HORIZONTAL,
                        front: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 2,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: gradient,
                            ),
                            child: Stack(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (filteredItems[index]['extraWidget'] !=
                                              null &&
                                          index != 0 &&
                                          index != 1)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 10,
                                          ),
                                          child:
                                              filteredItems[index]['extraWidget'],
                                        ),
                                      if (filteredItems[index]['extraWidget'] !=
                                              null &&
                                          index != 0 &&
                                          index != 1)
                                        SizedBox(height: 10),
                                      Text(
                                        filteredItems[index]['title']!,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(height: 10),
                                      Text(
                                        filteredItems[index]['subtitle']!,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white.withOpacity(0.8),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 2,
                                      ),
                                    ],
                                  ),
                                ),
                                if (filteredItems[index]['icon'] != null)
                                  Positioned(
                                    top: 10,
                                    left: 10,
                                    child: Icon(
                                      filteredItems[index]['icon'],
                                      color: Colors.orange,
                                      size: 30,
                                    ),
                                  ),
                                if (index == 1 &&
                                    filteredItems[index]['extraWidget'] != null)
                                  Positioned(
                                    top: 10,
                                    left: 10,
                                    child: filteredItems[index]['extraWidget'],
                                  ),
                                if (filteredItems[index]['secondaryIcon'] !=
                                    null)
                                  Positioned(
                                    top: 15,
                                    right: 15,
                                    child: Icon(
                                      filteredItems[index]['secondaryIcon'],
                                      color: Colors.blue.shade200,
                                      size: 30,
                                    ),
                                  ),
                                if (index == 0 &&
                                    filteredItems[index]['extraWidget'] != null)
                                  Positioned(
                                    top: 5,
                                    right: 5,
                                    child: filteredItems[index]['extraWidget'],
                                  ),
                              ],
                            ),
                          ),
                        ),
                        back: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 2,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: gradient,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    filteredItems[index]['description']!,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Placeholder class for LocationDetails since the original wasn't provided
class LocationDetails {
  final String address;
  LocationDetails(this.address);
  factory LocationDetails.fromMap(Map<String, dynamic> map) {
    return LocationDetails(map['address'] ?? '');
  }
  @override
  String toString() => address;
}
