import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // Correct import
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../utils/menu_utils.dart'; // Adjust path
import '../controllers/pause_play_controller.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ScrollController _scrollController = ScrollController();
  final PausePlayController pausePlayController =
      Get.find<PausePlayController>();
  DateTime _currentDate = DateTime.now();
  int _currentDayIndex = 7;
  final List<String> _categories = const [
    'Veg',
    'South Indian',
    'North Indian',
  ];
  bool _activeSubscription = false;
  DateTime? _subscriptionStartDate;
  int _remainingSeconds = 0;
  Timer? _timer;
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
    _loadInitialState();
    _loadProfileImage();
    dates = _generateDates();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _scrollToCurrentDay();
      await _fetchMenuData();
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
      _currentDayIndex = newIndex;
      _currentDate = DateTime.now()
          .subtract(const Duration(days: 7))
          .add(Duration(days: _currentDayIndex));
      _fetchMenuData();
      setState(() {});
    }
  }

  void _scrollToCurrentDay() {
    final targetOffset = itemWidth * (_currentDayIndex - 2);
    _scrollController.jumpTo(
      targetOffset.clamp(0, _scrollController.position.maxScrollExtent),
    );
  }

  Future<void> _fetchMenuData() async {
    final dateStr = MenuUtils.getDateString(_currentDate);
    if (_menuCache[dateStr] == null) {
      _menuCache = await MenuUtils.fetchMenuData(
        baseDate: _currentDate,
        dateFilter: dateStr,
      );
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  List<Map<String, String>> _generateDates() {
    final List<Map<String, String>> dates = [];
    final baseDate = DateTime.now();
    final startDate = baseDate.subtract(const Duration(days: 7));
    for (int i = 0; i < 35; i++) {
      final date = startDate.add(Duration(days: i));
      dates.add({
        'day': date.day.toString(),
        'weekday': _getWeekday(date.weekday),
        'date': MenuUtils.getDateString(date),
      });
    }
    return dates;
  }

  String _getWeekday(int weekday) {
    return const [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ][weekday - 1];
  }

  Future<void> _loadInitialState() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists && mounted) {
          final data = doc.data() ?? {};
          setState(() {
            _activeSubscription = data['activeSubscription'] ?? false;
            _subscriptionStartDate =
                data['subscriptionStartDate'] != null
                    ? (data['subscriptionStartDate'] as Timestamp).toDate()
                    : null;
            if (_activeSubscription &&
                pausePlayController.subscriptionEndDate.value != null) {
              _remainingSeconds =
                  pausePlayController.subscriptionEndDate.value!
                      .difference(DateTime.now())
                      .inSeconds;
              if (_remainingSeconds > 0 && !pausePlayController.isPaused.value)
                _startTimer();
            }
          });
        }
      } catch (e) {
        print('Error loading initial state: $e');
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

  void _startTimer() {
    _timer?.cancel();
    if (_remainingSeconds > 0 && !pausePlayController.isPaused.value) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted && !pausePlayController.isPaused.value) {
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
    final user = _auth.currentUser;
    if (user != null) {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};
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
        if (mounted) {
          setState(() {
            _activeSubscription = false;
            _timer?.cancel();
          });
        }
      }
    }
  }

  void _scheduleDailyUpdate() {
    final now = DateTime.now();
    var scheduledTime = DateTime(now.year, now.month, now.day, 21, 0);
    if (now.isAfter(scheduledTime)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }
    final duration = scheduledTime.difference(now);
    Timer(duration, () {
      if (mounted) {
        _currentDate = DateTime.now();
        _fetchMenuData();
        setState(() {});
        _scheduleDailyUpdate();
      }
    });
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
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
    final diff = index - 7;
    if (diff == 0) return 'Today';
    if (diff == -1) return 'Yesterday';
    if (diff == 1) return 'Tomorrow';
    final weekDiff = (diff / 7).floor();
    if (diff > 0) {
      return const {
            0: 'This Week',
            1: 'Next Week',
            2: 'Third Week',
            3: 'Fourth Week',
          }[weekDiff] ??
          'Future';
    } else {
      final absWeekDiff = weekDiff.abs();
      return const {0: 'This Week', 1: 'Last Week'}[absWeekDiff] ?? 'Past';
    }
  }

  void _scrollToDate(int index) {
    _currentDayIndex = index;
    _currentDate = DateTime.now()
        .subtract(const Duration(days: 7))
        .add(Duration(days: _currentDayIndex));
    _fetchMenuData();
    final targetOffset = itemWidth * (index - 2);
    _scrollController.animateTo(
      targetOffset.clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
    setState(() {});
  }

  String _formatRemainingDays(int seconds) =>
      '${(seconds ~/ (24 * 3600))} days';

  @override
  Widget build(BuildContext context) {
    if (dates.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Colors.blue));
    }
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _formatDate(_currentDate),
                                style: TextStyle(
                                  color: Colors.blue[900],
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
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
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
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
                                color: Colors.blue.withAlpha(26),
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
                              color: Colors.blue.withAlpha(51),
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
                                Expanded(
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.blue[700]!.withAlpha(
                                            51,
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
                                      Flexible(
                                        child: Text(
                                          'Your Subscription',
                                          style: TextStyle(
                                            color: Colors.blue[900],
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap:
                                      () => pausePlayController.togglePausePlay(
                                        _activeSubscription,
                                      ),
                                  child: Obx(
                                    () => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            pausePlayController.isPaused.value
                                                ? Colors.red[600]
                                                : Colors.green[600],
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: (pausePlayController
                                                        .isPaused
                                                        .value
                                                    ? Colors.red
                                                    : Colors.green)
                                                .withAlpha(77),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        pausePlayController.isPaused.value
                                            ? 'Resume'
                                            : 'Pause',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
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
                                Expanded(
                                  child: Text(
                                    'Start: ${_formatDate(_subscriptionStartDate)}',
                                    style: TextStyle(
                                      color: Colors.blue[800],
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
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
                                Expanded(
                                  child: Obx(
                                    () => Text(
                                      'End: ${_formatDate(pausePlayController.subscriptionEndDate.value)}',
                                      style: TextStyle(
                                        color: Colors.blue[800],
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
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
                                Expanded(
                                  child: Text(
                                    'Remaining: ${_remainingSeconds > 0 ? _formatRemainingDays(_remainingSeconds) : 'Expired'}',
                                    style: TextStyle(
                                      color: Colors.blue[800],
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Obx(
                                  () => Icon(
                                    pausePlayController.isPaused.value
                                        ? Icons.pause_circle_outline
                                        : Icons.play_circle_filled,
                                    color:
                                        pausePlayController.isPaused.value
                                            ? Colors.red[600]
                                            : Colors.green[600],
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Obx(
                                    () => Text(
                                      'Status: ${pausePlayController.isPaused.value ? 'Paused' : 'Ongoing'}',
                                      style: TextStyle(
                                        color:
                                            pausePlayController.isPaused.value
                                                ? Colors.red[600]
                                                : Colors.green[600],
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
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
                      color: Colors.grey.withAlpha(26),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ListView.builder(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: dates.length,
                    itemBuilder:
                        (context, index) => SizedBox(
                          width: itemWidth,
                          child: GestureDetector(
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
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Daily Menu',
                          style: TextStyle(
                            color: Colors.blue[900],
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
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
                  ..._categories.map((category) => _buildMenuCard(category)),
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
                    color: Colors.blue.withAlpha(51),
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
            const SizedBox(
              width: 6,
              height: 6,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
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
                  color: Colors.blue.withAlpha(38),
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
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(51),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.restaurant_menu,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              category,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
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
            color: Colors.white.withAlpha(51),
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
            color: Colors.white.withAlpha(204),
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
        color: Colors.white.withAlpha(230),
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
  State<_MenuImageWidget> createState() => _MenuImageWidgetState();
}

class _MenuImageWidgetState extends State<_MenuImageWidget> {
  final storage = const FlutterSecureStorage(); // Correct instantiation

  Future<String?> _getLocalImagePath(String url, String key) async {
    if (url.isEmpty) return null;
    final storedUrl = await storage.read(key: key);
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
          await storage.write(key: key, value: url);
          return filePath;
        }
      } catch (e) {
        print('Error loading image: $e');
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
                color: Colors.white.withAlpha(26),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'No Image',
                  style: TextStyle(
                    color: Colors.white.withAlpha(153),
                    fontSize: 14,
                  ),
                ),
              ),
            );
      },
    );
  }
}
