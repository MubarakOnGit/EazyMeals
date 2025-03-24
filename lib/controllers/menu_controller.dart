import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../utils/menu_utils.dart'; // Adjust path
import '../controllers/pause_play_controller.dart';

class MenuController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ScrollController scrollController = ScrollController();
  final PausePlayController pausePlayController =
      Get.find<PausePlayController>();
  final Rx<DateTime> currentDate = DateTime.now().obs;
  final RxInt currentDayIndex = 7.obs;
  final List<String> categories = const ['Veg', 'South Indian', 'North Indian'];
  final RxBool activeSubscription = false.obs;
  final Rx<DateTime?> subscriptionStartDate = Rx<DateTime?>(null);
  final RxInt remainingSeconds = 0.obs;
  final RxList<Map<String, String>> dates = <Map<String, String>>[].obs;
  final double itemWidth = 80.0;
  final RxMap<String, bool> expandedCards =
      {'Veg': false, 'South Indian': false, 'North Indian': false}.obs;
  final RxMap<String, Map<String, dynamic>> menuCache =
      <String, Map<String, dynamic>>{}.obs;
  final Rx<File?> profileImage = Rx<File?>(null);
  Timer? _timer;

  @override
  void onInit() {
    super.onInit();
    dates.value = generateDates();
    loadInitialState();
    loadProfileImage();
    scrollToCurrentDay();
    fetchMenuData();
    scrollController.addListener(handleScroll);
    scheduleDailyUpdate();
  }

  @override
  void onClose() {
    _timer?.cancel();
    scrollController.dispose();
    super.onClose();
  }

  void handleScroll() {
    final offset = scrollController.offset;
    final viewportWidth = Get.mediaQuery.size.width;
    final centerOffset = offset + (viewportWidth / 2) - (itemWidth / 2);
    final newIndex = (centerOffset / itemWidth).round().clamp(
      0,
      dates.length - 1,
    );

    if (newIndex != currentDayIndex.value) {
      currentDayIndex.value = newIndex;
      currentDate.value = DateTime.now()
          .subtract(const Duration(days: 7))
          .add(Duration(days: currentDayIndex.value));
      fetchMenuData();
    }
  }

  void scrollToCurrentDay() {
    final targetOffset = itemWidth * (currentDayIndex.value - 2);
    scrollController.jumpTo(
      targetOffset.clamp(0, scrollController.position.maxScrollExtent),
    );
  }

  Future<void> fetchMenuData() async {
    final dateStr = MenuUtils.getDateString(currentDate.value);
    if (menuCache[dateStr] == null) {
      menuCache.value = await MenuUtils.fetchMenuData(
        baseDate: currentDate.value,
        dateFilter: dateStr,
      );
    }
  }

  List<Map<String, String>> generateDates() {
    final List<Map<String, String>> dates = [];
    final baseDate = DateTime.now();
    final startDate = baseDate.subtract(const Duration(days: 7));
    for (int i = 0; i < 35; i++) {
      final date = startDate.add(Duration(days: i));
      dates.add({
        'day': date.day.toString(),
        'weekday': getWeekday(date.weekday),
        'date': MenuUtils.getDateString(date),
      });
    }
    return dates;
  }

  String getWeekday(int weekday) {
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

  Future<void> loadInitialState() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data() ?? {};
          activeSubscription.value = data['activeSubscription'] ?? false;
          subscriptionStartDate.value =
              data['subscriptionStartDate'] != null
                  ? (data['subscriptionStartDate'] as Timestamp).toDate()
                  : null;
          if (activeSubscription.value &&
              pausePlayController.subscriptionEndDate.value != null) {
            remainingSeconds.value =
                pausePlayController.subscriptionEndDate.value!
                    .difference(currentDate.value)
                    .inSeconds;
            if (remainingSeconds.value > 0 &&
                !pausePlayController.isPaused.value)
              startTimer();
          }
        }
      } catch (e) {
        print('Error loading initial state: $e');
      }
    }
  }

  Future<void> loadProfileImage() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final imagePath = '${directory.path}/profile_image.jpg';
      final file = File(imagePath);
      if (await file.exists()) profileImage.value = file;
    } catch (e) {
      print('Error loading profile image: $e');
    }
  }

  void startTimer() {
    _timer?.cancel();
    if (remainingSeconds.value > 0 && !pausePlayController.isPaused.value) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!pausePlayController.isPaused.value) {
          remainingSeconds.value--;
          if (remainingSeconds.value <= 0) {
            deactivateSubscription();
            timer.cancel();
          }
        } else {
          timer.cancel();
        }
      });
    }
  }

  Future<void> deactivateSubscription() async {
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
        activeSubscription.value = false;
        _timer?.cancel();
      }
    }
  }

  void scheduleDailyUpdate() {
    final now = DateTime.now();
    var scheduledTime = DateTime(now.year, now.month, now.day, 21, 0);
    if (now.isAfter(scheduledTime))
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    final duration = scheduledTime.difference(now);
    Timer(duration, () {
      currentDate.value = DateTime.now();
      fetchMenuData();
      scheduleDailyUpdate();
    });
  }

  String formatDate(DateTime? date) {
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

  String getRelativeDayText(int index) {
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

  void scrollToDate(int index) {
    currentDayIndex.value = index;
    currentDate.value = DateTime.now()
        .subtract(const Duration(days: 7))
        .add(Duration(days: currentDayIndex.value));
    fetchMenuData();
    final targetOffset = itemWidth * (index - 2);
    scrollController.animateTo(
      targetOffset.clamp(0, scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  String formatRemainingDays(int seconds) => '${(seconds ~/ (24 * 3600))} days';

  Widget buildDateItem(String date, String day, bool isCurrent) {
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

  Widget buildMenuCard(String category) {
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
            child: Obx(
              () => Column(
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
                            () =>
                                expandedCards[category] =
                                    !(expandedCards[category] ?? false),
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
                  buildMealRow('Lunch', category),
                  const SizedBox(height: 12),
                  buildMealRow('Dinner', category),
                  if (expandedCards[category] ?? false) ...[
                    const SizedBox(height: 20),
                    buildImageSection('Lunch', category),
                    const SizedBox(height: 20),
                    buildImageSection('Dinner', category),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildMealRow(String mealType, String category) {
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
                date: currentDate.value,
                menuData: menuCache[category],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildImageSection(String mealType, String category) {
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
          date: currentDate.value,
          menuData: menuCache[category],
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
