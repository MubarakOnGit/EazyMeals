import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:eazy_meals/utils/menu_utils.dart'; // Adjust path

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
  int _currentDayIndex = 7;
  final List<String> _categories = ['Veg', 'South Indian', 'North Indian'];
  bool _activeSubscription = false;
  DateTime? _subscriptionStartDate;
  DateTime? _subscriptionEndDate;
  bool _isPaused = false;
  int _remainingSeconds = 0;
  Timer? _timer;
  DateTime? _pauseStartTime;
  List<Map<String, String>> dates = [];
  final double itemWidth = 80.0;
  Map<String, bool> expandedCards = {
    'Veg': false,
    'South Indian': false,
    'North Indian': false,
  };
  Map<String, Map<String, dynamic>> _menuCache = {};
  File? _profileImage;

  @override
  void initState() {
    super.initState();
    _scheduleDailyUpdate();
    _schedulePauseCheck();
    _loadInitialState();
    _loadProfileImage();
    dates = _generateDates();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentDay();
      _fetchMenuData();
    });
    _scrollController.addListener(_handleScroll);
  }

  void _handleScroll() {
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
        _fetchMenuData();
      });
    }
  }

  void _scrollToCurrentDay() {
    final targetOffset = itemWidth * (_currentDayIndex - 2);
    _scrollController.jumpTo(
      targetOffset.clamp(0, _scrollController.position.maxScrollExtent),
    );
  }

  Future<void> _fetchMenuData() async {
    String dateStr = MenuUtils.getDateString(_currentDate);
    _menuCache = await MenuUtils.fetchMenuData(
      baseDate: _currentDate,
      dateFilter: dateStr,
    );
    if (mounted) setState(() {});
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
        'date': MenuUtils.getDateString(date),
      });
    }
    return dates;
  }

  String _getWeekday(int weekday) {
    switch (weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
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
        setState(() {
          _activeSubscription = data['activeSubscription'] ?? false;
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
      }
    }
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
        if (mounted && !_isPaused) {
          setState(() {
            _remainingSeconds--;
            if (_remainingSeconds <= 0) {
              _deactivateSubscription();
              timer.cancel();
            }
          });
        } else {
          timer.cancel();
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
        setState(() {
          _currentDate = DateTime.now();
          _fetchMenuData();
        });
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
    return _activeSubscription && (hour >= 9 && hour < 22);
  }

  Future<void> _togglePausePlay() async {
    User? user = _auth.currentUser;
    if (user == null || !_activeSubscription || _subscriptionEndDate == null)
      return;
    bool newIsPaused = !_isPaused;
    if (_canPauseOrPlay()) {
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
        await _firestore.collection('users').doc(user.uid).update({
          'isPaused': newIsPaused,
          'pausedAt': newIsPaused ? Timestamp.now() : FieldValue.delete(),
          'subscriptionEndDate': Timestamp.fromDate(_subscriptionEndDate!),
        });
        if (newIsPaused) {
          await _markNextDayPaused(user.uid);
        } else {
          await _resumeNextDay(user.uid);
        }
      } catch (e) {
        print('Error in togglePausePlay: $e');
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

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
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
          return 'Third Week';
        case 3:
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
        _subscriptionEndDate == null)
      return 1.0;
    final totalDuration =
        _subscriptionEndDate!.difference(_subscriptionStartDate!).inSeconds;
    final elapsed = _currentDate.difference(_subscriptionStartDate!).inSeconds;
    return (totalDuration - elapsed) / totalDuration;
  }

  void _scrollToDate(int index) {
    setState(() {
      _currentDayIndex = index;
      _currentDate = DateTime.now()
          .subtract(Duration(days: 7))
          .add(Duration(days: _currentDayIndex));
      _fetchMenuData();
    });
    final targetOffset = itemWidth * (index - 2);
    _scrollController.animateTo(
      targetOffset.clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  String _formatRemainingDays(int seconds) {
    final days = (seconds ~/ (24 * 3600)).toString();
    return '$days days';
  }

  @override
  Widget build(BuildContext context) {
    if (dates.isEmpty)
      return const Center(child: CircularProgressIndicator(color: Colors.blue));
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatDate(_currentDate),
                              style: TextStyle(
                                color: Colors.blue[900],
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _getRelativeDayText(_currentDayIndex),
                              style: TextStyle(
                                color: Colors.blue[900],
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.blue[100]!,
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
                            radius: 36,
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
                    if (_activeSubscription) ...[
                      const SizedBox(height: 20),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue[50]!, Colors.blue[100]!],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.blue[200]!,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[700]!.withOpacity(
                                          0.2,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.subscriptions,
                                        color: Colors.blue[800],
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Your Subscription',
                                      style: TextStyle(
                                        color: Colors.blue[900],
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                GestureDetector(
                                  onTap: _togglePausePlay,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          _isPaused
                                              ? Colors.red[600]
                                              : Colors.green[600],
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (_isPaused
                                                  ? Colors.red
                                                  : Colors.green)
                                              .withOpacity(0.3),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      _isPaused ? 'Resume' : 'Pause',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  Icons.play_circle_outline,
                                  color: Colors.blue[700],
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Start: ${_subscriptionStartDate != null ? _formatDate(_subscriptionStartDate!) : 'N/A'}',
                                  style: TextStyle(
                                    color: Colors.blue[800],
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.stop_circle_outlined,
                                  color: Colors.blue[700],
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'End: ${_subscriptionEndDate != null ? _formatDate(_subscriptionEndDate!) : 'N/A'}',
                                  style: TextStyle(
                                    color: Colors.blue[800],
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.hourglass_empty,
                                  color: Colors.blue[700],
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Remaining: ${_remainingSeconds > 0 ? _formatRemainingDays(_remainingSeconds) : 'Expired'}',
                                  style: TextStyle(
                                    color: Colors.blue[800],
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  _isPaused
                                      ? Icons.pause_circle_outline
                                      : Icons.play_circle_filled,
                                  color:
                                      _isPaused
                                          ? Colors.red[600]
                                          : Colors.green[600],
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Status: ${_isPaused ? 'Paused' : 'Ongoing'}',
                                  style: TextStyle(
                                    color:
                                        _isPaused
                                            ? Colors.red[600]
                                            : Colors.green[600],
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                height: 120,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListView.builder(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: dates.length,
                  itemBuilder:
                      (context, index) => GestureDetector(
                        onTap: () => _scrollToDate(index),
                        child: _buildDateItem(
                          dates[index]['day']!,
                          dates[index]['weekday']!,
                          index == _currentDayIndex,
                        ),
                      ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Daily Menu',
                        style: TextStyle(
                          color: Colors.blue[900],
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/viewAll'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'View All',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ..._categories
                      .map((category) => _buildMenuCard(category))
                      .toList(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateItem(String date, String day, bool isCurrent) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: itemWidth,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      decoration: BoxDecoration(
        color: isCurrent ? Colors.blue[600] : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        boxShadow:
            isCurrent
                ? [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
                : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            day.substring(0, 3),
            style: TextStyle(
              fontSize: 14,
              color: isCurrent ? Colors.white70 : Colors.blue[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            date,
            style: TextStyle(
              fontSize: 20,
              color: isCurrent ? Colors.white : Colors.blue[900],
              fontWeight: FontWeight.w700,
            ),
          ),
          if (isCurrent) ...[
            const SizedBox(height: 8),
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMenuCard(String category) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: Card(
          elevation: 5,
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
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.restaurant_menu,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          category,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap:
                          () => setState(
                            () =>
                                expandedCards[category] =
                                    !(expandedCards[category] ?? false),
                          ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          expandedCards[category] ?? false
                              ? Icons.expand_less
                              : Icons.expand_more,
                          key: ValueKey(expandedCards[category]),
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildMealRow('Lunch', category),
                const SizedBox(height: 12),
                _buildMealRow('Dinner', category),
                if (expandedCards[category] ?? false) ...[
                  const SizedBox(height: 20),
                  _buildImageSection('Lunch', category),
                  const SizedBox(height: 20),
                  _buildImageSection('Dinner', category),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMealRow(String mealType, String category) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            mealType == 'Lunch' ? Icons.wb_sunny : Icons.nightlight,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mealType,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              _MenuTextWidget(
                mealType: mealType,
                category: category,
                date: _currentDate,
                menuData: _menuCache[category],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageSection(String mealType, String category) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$mealType Image',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        _MenuImageWidget(
          mealType: mealType,
          category: category,
          date: _currentDate,
          menuData: _menuCache[category],
        ),
      ],
    );
  }
}

class _MenuTextWidget extends StatelessWidget {
  final String mealType;
  final String category;
  final DateTime date;
  final Map<String, dynamic>? menuData;

  const _MenuTextWidget({
    required this.mealType,
    required this.category,
    required this.date,
    this.menuData,
  });

  @override
  Widget build(BuildContext context) {
    final items = menuData?['items'] as List<dynamic>? ?? [];
    final dateStr = MenuUtils.getDateString(date);
    final item = items.firstWhere(
      (item) => item['mealType'] == mealType && item['date'] == dateStr,
      orElse: () => {'item': 'Not Available'},
    );
    return Text(
      item['item'],
      style: TextStyle(
        color: Colors.white.withOpacity(0.9),
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _MenuImageWidget extends StatefulWidget {
  final String mealType;
  final String category;
  final DateTime date;
  final Map<String, dynamic>? menuData;

  const _MenuImageWidget({
    required this.mealType,
    required this.category,
    required this.date,
    this.menuData,
  });

  @override
  __MenuImageWidgetState createState() => __MenuImageWidgetState();
}

class __MenuImageWidgetState extends State<_MenuImageWidget> {
  final FlutterSecureStorage _storage = FlutterSecureStorage();

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

  @override
  Widget build(BuildContext context) {
    final items = widget.menuData?['items'] as List<dynamic>? ?? [];
    final dateStr = MenuUtils.getDateString(widget.date);
    final item = items.firstWhere(
      (item) => item['mealType'] == widget.mealType && item['date'] == dateStr,
      orElse: () => {'imageUrl': ''},
    );
    return FutureBuilder<String?>(
      future: _getLocalImagePath(
        item['imageUrl'] ?? '',
        '${widget.mealType.toLowerCase()}-$dateStr-${widget.category}',
      ),
      builder: (context, snapshot) {
        return snapshot.data != null
            ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(snapshot.data!),
                width: 150,
                height: 150,
                fit: BoxFit.cover,
              ),
            )
            : Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'No Image',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
              ),
            );
      },
    );
  }
}
