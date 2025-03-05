import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flip_card/flip_card.dart';

import '../screens/subscription_screen.dart';

class MenuScreen extends StatefulWidget {
  @override
  _MenuScreenState createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _selectedCategory = 'Veg';
  List<Map<String, dynamic>> _menus = [];
  DateTime _currentDate = DateTime.now();
  final List<String> _categories = ['Veg', 'South Indian', 'North Indian'];
  bool _activeSubscription = false;
  String? _subscriptionPlan;
  DateTime? _subscriptionStartDate;
  DateTime? _subscriptionEndDate;
  bool _isPaused = false;
  int _pausedDays = 0;
  bool _isStudentVerified = false;

  @override
  void initState() {
    super.initState();
    print('Current Date: $_currentDate');
    _fetchMenus();
    _fetchUserData();
    _scheduleDailyUpdate();
  }

  Future<void> _fetchMenus() async {
    try {
      QuerySnapshot querySnapshot =
          await _firestore
              .collection('menus')
              .where('category', isEqualTo: _selectedCategory)
              .orderBy('weekNumber')
              .get();

      setState(() {
        _menus =
            querySnapshot.docs
                .map((doc) => doc.data() as Map<String, dynamic>)
                .toList();
      });
    } catch (e) {
      print('Error fetching menus: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load menus: $e')));
    }
  }

  Future<void> _fetchUserData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot doc =
            await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          setState(() {
            _activeSubscription = doc['activeSubscription'] ?? false;
            _subscriptionPlan = doc['subscriptionPlan'];
            _subscriptionStartDate =
                doc['subscriptionStartDate'] != null
                    ? (doc['subscriptionStartDate'] as Timestamp).toDate()
                    : null;
            _subscriptionEndDate =
                doc['subscriptionEndDate'] != null
                    ? (doc['subscriptionEndDate'] as Timestamp).toDate()
                    : null;
            _isPaused = doc['isPaused'] ?? false;
            _pausedDays = doc['pausedDays'] ?? 0;
            _isStudentVerified = doc['studentDetails']?['isVerified'] ?? false;

            // Check expiration and auto-remove subscription
            if (_activeSubscription &&
                _subscriptionEndDate != null &&
                _currentDate.isAfter(_subscriptionEndDate!)) {
              _activeSubscription = false;
              _firestore.collection('users').doc(user.uid).update({
                'activeSubscription': false,
                'subscriptionPlan': FieldValue.delete(),
                'subscriptionStartDate': FieldValue.delete(),
                'subscriptionEndDate': FieldValue.delete(),
                'isPaused': FieldValue.delete(),
                'pausedDays': FieldValue.delete(),
              });
            }
          });
        }
      } catch (e) {
        print('Error fetching user data: $e');
      }
    }
  }

  void _scheduleDailyUpdate() {
    final now = DateTime.now();
    var scheduledTime = DateTime(now.year, now.month, now.day, 21, 0);
    if (now.isAfter(scheduledTime)) {
      scheduledTime = scheduledTime.add(Duration(days: 1));
    }
    final duration = scheduledTime.difference(now);

    Future.delayed(duration, () {
      setState(() {
        _currentDate = DateTime.now();
        print('Updated Current Date: $_currentDate');
        _fetchMenus();
        _fetchUserData();
      });
      _scheduleDailyUpdate();
    });
  }

  bool _canPauseOrPlay() {
    final now = DateTime.now();
    final hour = now.hour;
    return !(hour >= 21 || hour < 9);
  }

  Future<void> _togglePause() async {
    User? user = _auth.currentUser;
    if (user != null && _activeSubscription && _subscriptionEndDate != null) {
      setState(() {
        _isPaused = !_isPaused;
        if (_isPaused) {
          _pausedDays++;
          _subscriptionEndDate = _subscriptionEndDate!.add(Duration(days: 1));
        }
      });
      try {
        await _firestore.collection('users').doc(user.uid).update({
          'isPaused': _isPaused,
          'pausedDays': _pausedDays,
          'subscriptionEndDate': Timestamp.fromDate(_subscriptionEndDate!),
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update pause status: $e')),
        );
      }
    }
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
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategory = category;
                          _fetchMenus();
                        });
                      },
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
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Text(
                  'Subscription: ${_activeSubscription ? 'Active ${_subscriptionPlan != null ? "($_subscriptionPlan)" : ""}${_subscriptionStartDate != null ? " - Starts ${_subscriptionStartDate!.day}/${_subscriptionStartDate!.month}/${_subscriptionStartDate!.year}" : ""}${_subscriptionEndDate != null ? " - Ends ${_subscriptionEndDate!.day}/${_subscriptionEndDate!.month}/${_subscriptionEndDate!.year}" : ""}' : 'Pending or Not Subscribed'}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if (_activeSubscription) ...[
                  SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: _canPauseOrPlay() ? _togglePause : null,
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
                      SizedBox(width: 10),
                      Text(
                        'Paused Days: $_pausedDays',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Expanded(child: _buildTimeline()),
          Padding(
            padding: EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () {
                if (_activeSubscription) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('You already have an active plan')),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SubscriptionScreen(),
                    ),
                  ).then((_) => _fetchUserData());
                }
              },
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
                    : 'Subscribe Plan Now',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Remaining methods (_buildTimeline, _buildDayItem, _buildMealItem) unchanged for brevity
  Widget _buildTimeline() {
    final daysOfWeek = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    final allDays = List.generate(35, (index) {
      final dayOffset = index - 7;
      final date = _currentDate.add(Duration(days: dayOffset));
      print('Day $index: $date');
      return date;
    });

    final weeks = List.generate(5, (weekIndex) {
      return allDays.sublist(weekIndex * 7, (weekIndex + 1) * 7);
    });

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
                ...weeks[weekIndex].asMap().entries.map((entry) {
                  final dayIndex = entry.key;
                  final date = entry.value;
                  return _buildDayItem(date, daysOfWeek[date.weekday - 1]);
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDayItem(DateTime date, String day) {
    final isPastDay = date.isBefore(_currentDate);
    final isCurrentDay =
        date.day == _currentDate.day &&
        date.month == _currentDate.month &&
        date.year == _currentDate.year;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$day\n${date.day}/${date.month}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isCurrentDay ? Colors.green : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: _buildMealItem(date, day, 'Lunch', isPastDay, isCurrentDay),
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
            child: _buildMealItem(date, day, 'Dinner', isPastDay, isCurrentDay),
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
  ) {
    final menu = _menus.firstWhere(
      (menu) => menu['weekNumber'] == date.weekOfYear,
      orElse: () => {},
    );

    final items = menu['items'] as List<dynamic>? ?? [];
    final item = items.firstWhere(
      (item) => item['day'] == day && item['mealType'] == mealType,
      orElse: () => {},
    );

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
      back: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: DecorationImage(
              image:
                  item['imageUrl'] != null
                      ? NetworkImage(item['imageUrl'])
                      : AssetImage('assets/placeholder.png') as ImageProvider,
              fit: BoxFit.cover,
            ),
          ),
        ),
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
    final weekNumber = (difference(firstMonday).inDays / 7).floor() + 1;
    return weekNumber;
  }
}
