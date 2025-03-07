import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flip_card/flip_card.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../screens/subscription_screen.dart';

class MenuScreen extends StatefulWidget {
  @override
  _MenuScreenState createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterSecureStorage _storage = FlutterSecureStorage();
  String _selectedCategory = 'Veg';
  DateTime _currentDate = DateTime.now();
  final List<String> _categories = ['Veg', 'South Indian', 'North Indian'];
  bool _activeSubscription = false;
  String? _subscriptionPlan;
  DateTime? _subscriptionStartDate;
  DateTime? _subscriptionEndDate;
  bool _isPaused = false;
  int _remainingSeconds = 0;
  Timer? _timer;
  DateTime? _pauseStartTime;

  @override
  void initState() {
    super.initState();
    _scheduleDailyUpdate();
    _schedulePauseCheck();
    _loadInitialState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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
          print('Downloaded and saved image for $key: $filePath');
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

  void _deactivateSubscription() async {
    User? user = _auth.currentUser;
    if (user != null) {
      setState(() {
        _activeSubscription = false;
        _timer?.cancel();
      });
      await _firestore.collection('users').doc(user.uid).update({
        'activeSubscription': false,
        'subscriptionPlan': FieldValue.delete(),
        'subscriptionStartDate': FieldValue.delete(),
        'subscriptionEndDate': FieldValue.delete(),
        'isPaused': FieldValue.delete(),
        'pausedAt': FieldValue.delete(),
      });
      print('Subscription deactivated for ${user.uid}');
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
    if (user == null || !_activeSubscription || _subscriptionEndDate == null) {
      print(
        'Cannot toggle: user=$user, active=$_activeSubscription, endDate=$_subscriptionEndDate',
      );
      return;
    }

    print('Toggling pause/play. Current state: isPaused=$_isPaused');
    bool newIsPaused = !_isPaused; // Calculate new state first

    setState(() {
      if (_isPaused) {
        // Resuming
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
          print(
            'Resuming: new endDate=$_subscriptionEndDate, remainingSeconds=$_remainingSeconds',
          );
        }
      } else {
        // Pausing
        _isPaused = true;
        _pauseStartTime = DateTime.now();
        _timer?.cancel();
        print('Pausing: pauseStartTime=$_pauseStartTime');
      }
    });

    try {
      final batch = _firestore.batch();
      final userDocRef = _firestore.collection('users').doc(user.uid);
      batch.update(userDocRef, {
        'isPaused': newIsPaused, // Use the new state here
        'pausedAt': newIsPaused ? Timestamp.now() : FieldValue.delete(),
        'subscriptionEndDate': Timestamp.fromDate(_subscriptionEndDate!),
      });

      if (newIsPaused) {
        await _markNextDayPaused(user.uid);
      } else {
        await _resumeNextDay(user.uid);
      }

      await batch.commit();
      print('Firestore updated successfully: isPaused=$newIsPaused');
    } catch (e) {
      print('Error in togglePausePlay: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() {
        _isPaused = !newIsPaused; // Revert to previous state on failure
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
    print('Paused ${orders.docs.length} orders for tomorrow');
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
    print('Resumed ${orders.docs.length} orders for tomorrow');
  }

  String _formatRemainingTime() {
    if (_subscriptionEndDate == null) return 'N/A';
    final duration = _subscriptionEndDate!.difference(_currentDate);
    final days = (duration.inSeconds / 86400).ceil();
    return days <= 0 ? 'Expired' : '$days day${days > 1 ? 's' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Menu Timeline'),
        backgroundColor: Colors.blue,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Wrap(
              spacing: 12,
              alignment: WrapAlignment.center,
              children:
                  _categories.map((category) {
                    return ChoiceChip(
                      label: Text(category),
                      selected: _selectedCategory == category,
                      onSelected:
                          (selected) =>
                              setState(() => _selectedCategory = category),
                      selectedColor: Colors.blue,
                      labelStyle: TextStyle(
                        color:
                            _selectedCategory == category
                                ? Colors.white
                                : Colors.black,
                      ),
                    );
                  }).toList(),
            ),
          ),
          StreamBuilder<DocumentSnapshot>(
            stream:
                _firestore
                    .collection('users')
                    .doc(_auth.currentUser?.uid)
                    .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return Center(child: CircularProgressIndicator());
              final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
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
              // Sync _isPaused only if it hasn’t been changed locally
              if (data['isPaused'] != null && !_isPaused != data['isPaused']) {
                _isPaused = data['isPaused'];
              }
              _pauseStartTime =
                  data['pausedAt'] != null
                      ? (data['pausedAt'] as Timestamp).toDate()
                      : null;

              if (_activeSubscription && _subscriptionEndDate != null) {
                _remainingSeconds =
                    _subscriptionEndDate!.difference(_currentDate).inSeconds;
                if (_remainingSeconds > 0 && !_isPaused && _timer == null)
                  _startTimer();
              } else {
                _timer?.cancel();
                _timer = null;
              }

              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Text(
                      'Subscription: ${_activeSubscription ? 'Active ${_subscriptionPlan ?? ""}${_subscriptionStartDate != null ? " - Starts ${_subscriptionStartDate!.day}/${_subscriptionStartDate!.month}/${_subscriptionStartDate!.year}" : ""}${_subscriptionEndDate != null ? " - Ends ${_subscriptionEndDate!.day}/${_subscriptionEndDate!.month}/${_subscriptionEndDate!.year}" : ""}' : 'Pending or Not Subscribed'}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_activeSubscription) ...[
                      SizedBox(height: 10),
                      Text(
                        'Time Left: ${_formatRemainingTime()}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed:
                                _canPauseOrPlay() ? _togglePausePlay : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _isPaused ? Colors.green : Colors.orange,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              _isPaused ? 'Play' : 'Pause',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  _firestore
                      .collection('menus')
                      .where('category', isEqualTo: _selectedCategory)
                      .where(
                        'weekNumber',
                        isGreaterThanOrEqualTo:
                            _currentDate.subtract(Duration(days: 7)).weekOfYear,
                      )
                      .where(
                        'weekNumber',
                        isLessThanOrEqualTo:
                            _currentDate.add(Duration(days: 28)).weekOfYear,
                      )
                      .orderBy('weekNumber')
                      .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return Center(child: CircularProgressIndicator());
                final menus =
                    snapshot.data!.docs
                        .map((doc) => doc.data() as Map<String, dynamic>)
                        .toList();
                return _buildTimeline(menus);
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed:
                  _activeSubscription
                      ? null
                      : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SubscriptionScreen(),
                        ),
                      ).then((_) => setState(() {})),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _activeSubscription ? Colors.grey : Colors.blue,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _activeSubscription
                    ? 'Already Subscribed'
                    : 'Request Subscription',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(List<Map<String, dynamic>> menus) {
    final daysOfWeek = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final allDays = List.generate(
      35,
      (index) => _currentDate.add(Duration(days: index - 7)),
    );
    final weeks = List.generate(
      5,
      (weekIndex) => allDays.sublist(weekIndex * 7, (weekIndex + 1) * 7),
    );

    return ListView.builder(
      itemCount: weeks.length,
      itemBuilder: (context, weekIndex) {
        final weekLabel =
            weekIndex == 0 ? 'Previous Week' : 'Week ${weekIndex}';
        return Card(
          elevation: 4,
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  weekLabel,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12),
                ...weeks[weekIndex].map(
                  (date) =>
                      _buildDayItem(date, daysOfWeek[date.weekday - 1], menus),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDayItem(
    DateTime date,
    String day,
    List<Map<String, dynamic>> menus,
  ) {
    final isPastDay = date.isBefore(_currentDate);
    final isCurrentDay =
        date.day == _currentDate.day &&
        date.month == _currentDate.month &&
        date.year == _currentDate.year;
    final isNextDay =
        date.day == _currentDate.add(Duration(days: 1)).day &&
        date.month == _currentDate.add(Duration(days: 1)).month &&
        date.year == _currentDate.add(Duration(days: 1)).year;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  '$day\n${date.day}/${date.month}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isCurrentDay ? Colors.green : Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (isNextDay && _isPaused)
                  Icon(Icons.pause, color: Colors.red, size: 20),
              ],
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: _buildMealItem(
              date,
              day,
              'Lunch',
              isPastDay,
              isCurrentDay,
              menus,
            ),
          ),
          Container(
            width: 2,
            height: 100,
            color: Colors.grey[300],
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (isCurrentDay)
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _buildMealItem(
              date,
              day,
              'Dinner',
              isPastDay,
              isCurrentDay,
              menus,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealItem(
    DateTime date,
    String day,
    String mealType,
    bool isPastDay,
    bool isCurrentDay,
    List<Map<String, dynamic>> menus,
  ) {
    final menu = menus.firstWhere(
      (menu) => menu['weekNumber'] == date.weekOfYear,
      orElse: () => {},
    );
    final items = menu['items'] as List<dynamic>? ?? [];
    final item = items.firstWhere(
      (item) => item['day'] == day && item['mealType'] == mealType,
      orElse: () => {},
    );
    final key = 'image-$day-$mealType-${date.weekOfYear}-$_selectedCategory';

    return FlipCard(
      fill: Fill.fillBack,
      direction: FlipDirection.HORIZONTAL,
      front: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        color:
            isPastDay
                ? Colors.grey[200]
                : isCurrentDay
                ? Colors.green[50]
                : Colors.blue[50],
        child: Padding(
          padding: EdgeInsets.all(12),
          child: SizedBox(
            height: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  mealType,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color:
                        isPastDay
                            ? Colors.grey
                            : isCurrentDay
                            ? Colors.green[800]
                            : Colors.blue[800],
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  item['item'] ?? 'No item',
                  style: TextStyle(
                    fontSize: 14,
                    color: isPastDay ? Colors.grey : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      back: FutureBuilder<String?>(
        future: _getLocalImagePath(item['imageUrl'] ?? '', key),
        builder: (context, snapshot) {
          final localImagePath = snapshot.data;
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                image: DecorationImage(
                  image:
                      localImagePath != null &&
                              File(localImagePath).existsSync()
                          ? FileImage(File(localImagePath))
                          : AssetImage('assets/placeholder.png')
                              as ImageProvider,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

extension DateTimeExtension on DateTime {
  int get weekOfYear {
    final startOfYear = DateTime(year, 1, 1);
    final firstMonday = startOfYear.add(
      Duration(days: (8 - startOfYear.weekday) % 7),
    );
    return (difference(firstMonday).inDays / 7).floor() + 1;
  }
}
