import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../screens/subscription_screen.dart';
import 'view_all_screen.dart';

class MenuScreen extends StatefulWidget {
  @override
  _MenuScreenState createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterSecureStorage _storage = FlutterSecureStorage();
  final ScrollController _scrollController = ScrollController();
  DateTime _currentDate = DateTime.now();
  int _currentDayIndex = 7; // Default to today
  final List<String> _categories = ['Veg', 'South Indian', 'North Indian'];
  bool _activeSubscription = false;
  String? _subscriptionPlan;
  DateTime? _subscriptionStartDate;
  DateTime? _subscriptionEndDate;
  bool _isPaused = false;
  int _remainingSeconds = 0;
  Timer? _timer;
  DateTime? _pauseStartTime;
  List<Map<String, String>> dates = [];
  final double itemWidth = 76.0;
  Map<String, bool> expandedCards = {
    'Veg': false,
    'South Indian': false,
    'North Indian': false,
  };
  Map<String, bool> _shouldAnimateText = {}; // Control animation per category

  @override
  void initState() {
    super.initState();
    _scheduleDailyUpdate();
    _schedulePauseCheck();
    _loadInitialState();
    dates = _generateDates();
    _initializeAnimationState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.jumpTo(itemWidth * (_currentDayIndex - 2));
    });

    _scrollController.addListener(() {
      final offset = _scrollController.offset;
      final viewportWidth = MediaQuery.of(context).size.width;
      final centerOffset = offset + (viewportWidth / 2) - (itemWidth / 2);
      final newIndex = (centerOffset / itemWidth).round().clamp(
        0,
        dates.length - 1,
      );
      if (newIndex != _currentDayIndex) {
        setState(() {
          _currentDayIndex = newIndex;
          _currentDate = DateTime.now()
              .subtract(Duration(days: 7))
              .add(Duration(days: _currentDayIndex));
          _triggerTextAnimation(); // Trigger animation only on day change
        });
      }
    });
  }

  void _initializeAnimationState() {
    for (var category in _categories) {
      _shouldAnimateText[category] = false; // Start with no animation
    }
  }

  void _triggerTextAnimation() {
    setState(() {
      for (var category in _categories) {
        _shouldAnimateText[category] = true; // Trigger animation
      }
    });
    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          for (var category in _categories) {
            _shouldAnimateText[category] = false; // End animation
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  List<Map<String, String>> _generateDates() {
    List<Map<String, String>> dates = [];
    DateTime baseDate = DateTime.now();
    DateTime startDate = baseDate.subtract(Duration(days: 7));
    for (int i = 0; i < 35; i++) {
      DateTime date = startDate.add(Duration(days: i));
      dates.add({
        'day': date.day.toString(),
        'weekday': _getWeekday(date.weekday),
      });
    }
    return dates;
  }

  String _getWeekday(int weekday) {
    switch (weekday) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return '';
    }
  }

  Future<void> _loadInitialState() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        print('User data loaded: $data');
        setState(() {
          _activeSubscription = data['activeSubscription'] ?? false;
          _subscriptionPlan = data['subscriptionPlan'];
          _subscriptionStartDate =
              data['subscriptionStartDate'] != null
                  ? (data['subscriptionStartDate'] as Timestamp).toDate()
                  : null;
          _subscriptionEndDate =
              data['subscriptionEndDate'] != null
                  ? (data['subscriptionEndDate'] as Timestamp).toDate()
                  : null;
          _isPaused = data['isPaused'] ?? false;
          _pauseStartTime =
              data['pausedAt'] != null
                  ? (data['pausedAt'] as Timestamp).toDate()
                  : null;
          if (_activeSubscription && _subscriptionEndDate != null) {
            _remainingSeconds =
                _subscriptionEndDate!.difference(_currentDate).inSeconds;
            if (_remainingSeconds > 0 && !_isPaused) _startTimer();
          }
        });
      } else {
        print('No user document found for ${user.uid}');
      }
    }
  }

  Future<String?> _getLocalImagePath(String url, String key) async {
    if (url.isEmpty) return null;
    final storedUrl = await _storage.read(key: key);
    final directory = await getApplicationDocumentsDirectory();
    final fileName = url.hashCode.toString();
    final filePath = '${directory.path}/$fileName.jpg';
    final file = File(filePath);

    if (storedUrl == url && file.existsSync()) {
      return filePath;
    } else if (storedUrl != url) {
      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          await file.writeAsBytes(response.bodyBytes);
          await _storage.write(key: key, value: url);
          return filePath;
        }
      } catch (e) {
        print('Error downloading image for $key: $e');
      }
    }
    return null;
  }

  void _startTimer() {
    _timer?.cancel();
    if (_remainingSeconds > 0 && !_isPaused) {
      _timer = Timer.periodic(Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _remainingSeconds--;
            if (_remainingSeconds <= 0) {
              _deactivateSubscription();
              timer.cancel();
            }
          });
        }
      });
    }
  }

  Future<void> _deactivateSubscription() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() as Map<String, dynamic>? ?? {};

      if (userData['activeSubscription'] == true) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('pastSubscriptions')
            .add({
              'subscriptionPlan': userData['subscriptionPlan'],
              'category': userData['category'],
              'mealType': userData['mealType'],
              'subscriptionStartDate': userData['subscriptionStartDate'],
              'subscriptionEndDate': Timestamp.now(),
              'endedNaturally': true,
            });

        await _firestore.collection('users').doc(user.uid).update({
          'activeSubscription': false,
          'subscriptionPlan': FieldValue.delete(),
          'subscriptionStartDate': FieldValue.delete(),
          'subscriptionEndDate': FieldValue.delete(),
          'isPaused': FieldValue.delete(),
          'pausedAt': FieldValue.delete(),
        });

        setState(() {
          _activeSubscription = false;
          _timer?.cancel();
        });
        print('Subscription ended naturally and archived for ${user.uid}');
      }
    }
  }

  void _scheduleDailyUpdate() {
    final now = DateTime.now();
    var scheduledTime = DateTime(now.year, now.month, now.day, 21, 0);
    if (now.isAfter(scheduledTime))
      scheduledTime = scheduledTime.add(Duration(days: 1));
    final duration = scheduledTime.difference(now);

    Future.delayed(duration, () {
      if (mounted) {
        setState(() => _currentDate = DateTime.now());
        _scheduleDailyUpdate();
      }
    });
  }

  void _schedulePauseCheck() {
    final now = DateTime.now();
    var next930PM = DateTime(now.year, now.month, now.day, 21, 30);
    if (now.isAfter(next930PM)) next930PM = next930PM.add(Duration(days: 1));
    final duration = next930PM.difference(now);

    Timer(duration, () async {
      User? user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot doc =
            await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists &&
            doc['activeSubscription'] == true &&
            doc['isPaused'] == true) {
          await _markNextDayPaused(user.uid);
        }
      }
      if (mounted) _schedulePauseCheck();
    });
  }

  bool _canPauseOrPlay() {
    final now = DateTime.now();
    final hour = now.hour;
    return _activeSubscription && (hour >= 9 && hour < 21);
  }

  void _togglePausePlay() async {
    User? user = _auth.currentUser;
    if (user == null || !_activeSubscription || _subscriptionEndDate == null)
      return;

    bool newIsPaused = !_isPaused;
    setState(() {
      if (_isPaused) {
        if (_pauseStartTime != null) {
          final pausedDuration =
              DateTime.now().difference(_pauseStartTime!).inSeconds;
          _subscriptionEndDate = _subscriptionEndDate!.add(
            Duration(seconds: pausedDuration),
          );
          _remainingSeconds =
              _subscriptionEndDate!.difference(_currentDate).inSeconds;
          _isPaused = false;
          _pauseStartTime = null;
          _startTimer();
        }
      } else {
        _isPaused = true;
        _pauseStartTime = DateTime.now();
        _timer?.cancel();
      }
    });

    try {
      final batch = _firestore.batch();
      final userDocRef = _firestore.collection('users').doc(user.uid);
      batch.update(userDocRef, {
        'isPaused': newIsPaused,
        'pausedAt': newIsPaused ? Timestamp.now() : FieldValue.delete(),
        'subscriptionEndDate': Timestamp.fromDate(_subscriptionEndDate!),
      });

      if (newIsPaused) {
        await _markNextDayPaused(user.uid);
      } else {
        await _resumeNextDay(user.uid);
      }

      await batch.commit();
    } catch (e) {
      print('Error in togglePausePlay: $e');
      setState(() {
        _isPaused = !newIsPaused;
        if (!_isPaused) _startTimer();
      });
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

    final batch = _firestore.batch();
    for (var order in orders.docs) {
      batch.update(order.reference, {'status': 'Paused'});
    }
    await batch.commit();
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

    final batch = _firestore.batch();
    for (var order in orders.docs) {
      batch.update(order.reference, {'status': 'Pending Delivery'});
    }
    await batch.commit();
  }

  String _formatDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _getRelativeDayText(int index) {
    int diff = index - 7;
    if (diff == 0) return 'Today';
    if (diff == -1) return 'Yesterday';
    if (diff == 1) return 'Tomorrow';
    int weekDiff = (diff / 7).floor();
    if (diff > 0) {
      switch (weekDiff) {
        case 0:
          return 'This Week';
        case 1:
          return 'Next Week';
        case 2:
          return 'Second Week';
        case 3:
          return 'Third Week';
        case 4:
          return 'Fourth Week';
        default:
          return 'Future';
      }
    } else {
      switch (weekDiff.abs()) {
        case 0:
          return 'This Week';
        case 1:
          return 'Last Week';
        default:
          return 'Past';
      }
    }
  }

  double _getStartingProgress() {
    if (!_activeSubscription ||
        _subscriptionStartDate == null ||
        _subscriptionEndDate == null) {
      return 1.0;
    }
    final totalDuration =
        _subscriptionEndDate!.difference(_subscriptionStartDate!).inSeconds;
    final elapsed = _currentDate.difference(_subscriptionStartDate!).inSeconds;
    return (totalDuration - elapsed) / totalDuration;
  }

  double _getInverseProgress(double progress) {
    return 1.0 - progress;
  }

  @override
  Widget build(BuildContext context) {
    if (dates.isEmpty) {
      return Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildAnimatedDateText(_formatDate(_currentDate)),
                        SizedBox(height: 2),
                        _buildAnimatedRelativeText(
                          _getRelativeDayText(_currentDayIndex),
                        ),
                      ],
                    ),
                    CircleAvatar(
                      radius: 40,
                      backgroundImage: AssetImage('assets/profile_pic.jpg'),
                    ),
                  ],
                ),
              ),
              Container(
                height: 130,
                child: ListView.builder(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  itemCount: dates.length,
                  itemBuilder: (context, index) {
                    return _buildDateItem(
                      dates[index]['day']!,
                      dates[index]['weekday']!,
                      index == _currentDayIndex,
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildProgressColumn(
                        progress:
                            _activeSubscription ? _getStartingProgress() : 1.0,
                        centerText:
                            _activeSubscription &&
                                    _subscriptionStartDate != null
                                ? '${_subscriptionStartDate!.day}/${_subscriptionStartDate!.month}'
                                : '0',
                        bottomText: 'Starting Date',
                      ),
                      Container(
                        height: 60,
                        width: 1,
                        color: Colors.grey.withOpacity(0.3),
                        margin: EdgeInsets.symmetric(vertical: 10),
                      ),
                      _activeSubscription
                          ? _buildPlayPauseColumn()
                          : _buildSubscribeButton(context),
                      Container(
                        height: 60,
                        width: 1,
                        color: Colors.grey.withOpacity(0.3),
                        margin: EdgeInsets.symmetric(vertical: 10),
                      ),
                      _buildProgressColumn(
                        progress:
                            _activeSubscription
                                ? _getInverseProgress(_getStartingProgress())
                                : 0.0,
                        centerText:
                            _activeSubscription && _subscriptionEndDate != null
                                ? '${_subscriptionEndDate!.day}/${_subscriptionEndDate!.month}'
                                : '0',
                        bottomText: 'Ending Date',
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Menu',
                      style: TextStyle(
                        color: Colors.blue.shade900,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    GestureDetector(
                      onTap:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ViewAllScreen(),
                            ),
                          ),
                      child: Text(
                        'View All',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children:
                      _categories.map((category) {
                        return StreamBuilder<QuerySnapshot>(
                          stream:
                              _firestore
                                  .collection('menus')
                                  .where('category', isEqualTo: category)
                                  .where(
                                    'weekNumber',
                                    isGreaterThanOrEqualTo:
                                        _currentDate
                                            .subtract(Duration(days: 7))
                                            .weekOfYearForMenuScreen,
                                  )
                                  .where(
                                    'weekNumber',
                                    isLessThanOrEqualTo:
                                        _currentDate
                                            .add(Duration(days: 28))
                                            .weekOfYearForMenuScreen,
                                  )
                                  .orderBy('weekNumber')
                                  .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return SizedBox.shrink();
                            }
                            if (snapshot.hasError) {
                              print(
                                'Error loading menu for $category: ${snapshot.error}',
                              );
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Text(
                                  'Error loading $category menu',
                                  style: TextStyle(color: Colors.red),
                                ),
                              );
                            }
                            if (!snapshot.hasData || snapshot.data == null) {
                              print('No menu data for $category');
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _buildCard([], category),
                              );
                            }
                            final menus =
                                snapshot.data!.docs
                                    .map(
                                      (doc) =>
                                          doc.data() as Map<String, dynamic>,
                                    )
                                    .toList();
                            print(
                              'Menus loaded for $category: ${menus.length}',
                            );
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _buildCard(menus, category),
                            );
                          },
                        );
                      }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedDateText(String text) {
    return TweenAnimationBuilder(
      key: ValueKey(text),
      tween: IntTween(begin: 0, end: text.length),
      duration: Duration(milliseconds: 500),
      builder: (context, int value, child) {
        return Text(
          text.substring(0, value),
          style: TextStyle(color: Colors.blue.shade900, fontSize: 16),
        );
      },
    );
  }

  Widget _buildAnimatedRelativeText(String text) {
    return TweenAnimationBuilder(
      key: ValueKey(text),
      tween: IntTween(begin: 0, end: text.length),
      duration: Duration(milliseconds: 500),
      builder: (context, int value, child) {
        return Text(
          text.substring(0, value),
          style: TextStyle(
            color: Colors.blue.shade900,
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        );
      },
    );
  }

  Widget _buildDateItem(String date, String day, bool isCurrent) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Container(
        width: 60,
        decoration: BoxDecoration(
          color: isCurrent ? Colors.blue[900] : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          boxShadow:
              isCurrent
                  ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: Offset(3, 1),
                    ),
                  ]
                  : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              date,
              style: TextStyle(
                fontSize: 18,
                color: isCurrent ? Colors.white : Colors.black,
              ),
            ),
            SizedBox(height: 4),
            Text(
              day,
              style: TextStyle(
                fontSize: 14,
                color: isCurrent ? Colors.white : Colors.black,
              ),
            ),
            if (isCurrent) ...[
              SizedBox(height: 25),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgressColumn({
    required double progress,
    required String centerText,
    required String bottomText,
  }) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 8,
                color: Colors.blue.shade900,
                backgroundColor: Colors.grey.shade200,
              ),
            ),
            Text(
              centerText,
              style: TextStyle(
                color: Colors.blue.shade900,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Text(bottomText, style: TextStyle(fontSize: 14)),
      ],
    );
  }

  Widget _buildPlayPauseColumn() {
    return Column(
      children: [
        GestureDetector(
          onTap: _canPauseOrPlay() ? _togglePausePlay : null,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: 0.5,
                  strokeWidth: 8,
                  color: Colors.blue.shade900,
                  backgroundColor: Colors.grey.shade200,
                ),
              ),
              Icon(
                _isPaused ? Icons.pause : Icons.play_arrow,
                color: Colors.blue.shade900,
                size: 30,
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        Text(_isPaused ? 'Paused' : 'Ongoing', style: TextStyle(fontSize: 14)),
      ],
    );
  }

  Widget _buildSubscribeButton(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed:
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SubscriptionScreen()),
              ).then((_) => setState(() {})),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade900,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text('Subscribe', style: TextStyle(color: Colors.white)),
        ),
        SizedBox(height: 8),
        Text('Not Subscribed', style: TextStyle(fontSize: 14)),
      ],
    );
  }

  Widget _buildCard(List<Map<String, dynamic>> menus, String category) {
    bool isExpanded = expandedCards[category] ?? false;
    final selectedDate = _currentDate
        .subtract(Duration(days: 7))
        .add(Duration(days: _currentDayIndex));
    final menu = menus.firstWhere(
      (menu) => menu['weekNumber'] == selectedDate.weekOfYearForMenuScreen,
      orElse: () => {'items': []},
    );
    final items = menu['items'] as List<dynamic>? ?? [];
    final lunchItem = items.firstWhere(
      (item) =>
          item['mealType'] == 'Lunch' &&
          item['day'] == _getWeekday(selectedDate.weekday),
      orElse: () => {'item': 'No item', 'imageUrl': ''},
    );
    final dinnerItem = items.firstWhere(
      (item) =>
          item['mealType'] == 'Dinner' &&
          item['day'] == _getWeekday(selectedDate.weekday),
      orElse: () => {'item': 'No item', 'imageUrl': ''},
    );

    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade900, Colors.blue.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                category,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              GestureDetector(
                onTap:
                    () => setState(() => expandedCards[category] = !isExpanded),
                child: Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _shouldAnimateText[category]!
              ? _buildAnimatedMenuText('Lunch: ${lunchItem['item']}', category)
              : Text(
                'Lunch: ${lunchItem['item']}',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
          SizedBox(height: 8),
          _shouldAnimateText[category]!
              ? _buildAnimatedMenuText(
                'Dinner: ${dinnerItem['item']}',
                category,
              )
              : Text(
                'Dinner: ${dinnerItem['item']}',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
          if (isExpanded) ...[
            SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lunch Image:',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                SizedBox(height: 8),
                FutureBuilder<String?>(
                  future: _getLocalImagePath(
                    lunchItem['imageUrl'] ?? '',
                    'lunch-${selectedDate.weekOfYearForMenuScreen}-$category',
                  ),
                  builder: (context, snapshot) {
                    return snapshot.data != null
                        ? Image.file(
                          File(snapshot.data!),
                          width: 150,
                          height: 150,
                          fit: BoxFit.cover,
                        )
                        : Image.asset(
                          'assets/placeholder.png',
                          width: 150,
                          height: 150,
                          fit: BoxFit.cover,
                        );
                  },
                ),
                SizedBox(height: 16),
                Text(
                  'Dinner Image:',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                SizedBox(height: 8),
                FutureBuilder<String?>(
                  future: _getLocalImagePath(
                    dinnerItem['imageUrl'] ?? '',
                    'dinner-${selectedDate.weekOfYearForMenuScreen}-$category',
                  ),
                  builder: (context, snapshot) {
                    return snapshot.data != null
                        ? Image.file(
                          File(snapshot.data!),
                          width: 150,
                          height: 150,
                          fit: BoxFit.cover,
                        )
                        : Image.asset(
                          'assets/placeholder.png',
                          width: 150,
                          height: 150,
                          fit: BoxFit.cover,
                        );
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnimatedMenuText(String text, String category) {
    return TweenAnimationBuilder(
      key: ValueKey('$text-$category-$_currentDayIndex'),
      tween: IntTween(begin: 0, end: text.length),
      duration: Duration(milliseconds: 500),
      builder: (context, int value, child) {
        return Text(
          text.substring(0, value),
          style: TextStyle(fontSize: 16, color: Colors.white),
        );
      },
      onEnd: () {
        if (mounted) setState(() => _shouldAnimateText[category] = false);
      },
    );
  }
}

extension DateTimeMenuScreenExtension on DateTime {
  int get weekOfYearForMenuScreen {
    final startOfYear = DateTime(year, 1, 1);
    final firstMonday = startOfYear.add(
      Duration(days: (8 - startOfYear.weekday) % 7),
    );
    return (difference(firstMonday).inDays / 7).floor() + 1;
  }
}
