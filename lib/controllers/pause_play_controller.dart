import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

class PausePlayController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RxBool isPaused = false.obs;
  final Rx<DateTime?> pauseStartTime = Rx<DateTime?>(null);
  final Rx<DateTime?> subscriptionEndDate = Rx<DateTime?>(null);

  @override
  void onInit() {
    super.onInit();
    _listenToPauseState();
  }

  void _listenToPauseState() {
    final user = _auth.currentUser;
    if (user != null) {
      _firestore.collection('users').doc(user.uid).snapshots().listen((doc) {
        if (doc.exists) {
          final data = doc.data() ?? {};
          isPaused.value = data['isPaused'] ?? false;
          pauseStartTime.value =
              data['pausedAt'] != null
                  ? (data['pausedAt'] as Timestamp).toDate()
                  : null;
          subscriptionEndDate.value =
              data['subscriptionEndDate'] != null
                  ? (data['subscriptionEndDate'] as Timestamp).toDate()
                  : null;
        }
      }, onError: (e) => print('Error listening to pause state: $e'));
    }
  }

  Future<void> togglePausePlay(bool isSubscribed) async {
    final user = _auth.currentUser;
    if (user == null || !isSubscribed || subscriptionEndDate.value == null)
      return;

    final now = DateTime.now();
    if (now.hour >= 9 && now.hour < 22) {
      final newIsPaused = !isPaused.value;
      if (newIsPaused) {
        pauseStartTime.value = now;
      } else if (pauseStartTime.value != null) {
        final pausedDuration = now.difference(pauseStartTime.value!).inSeconds;
        subscriptionEndDate.value = subscriptionEndDate.value!.add(
          Duration(seconds: pausedDuration),
        );
        pauseStartTime.value = null;
      }

      try {
        await _firestore.collection('users').doc(user.uid).update({
          'isPaused': newIsPaused,
          'pausedAt': newIsPaused ? Timestamp.now() : FieldValue.delete(),
          'subscriptionEndDate': Timestamp.fromDate(subscriptionEndDate.value!),
        });
        if (newIsPaused) {
          await markNextDayPaused(user.uid);
        } else {
          await resumeNextDay(user.uid);
        }
      } catch (e) {
        Get.snackbar('Error', 'Failed to update subscription status: $e');
        print('Toggle pause/play error: $e');
      }
    } else {
      Get.snackbar('Info', 'You can only pause or play between 9 AM - 10 PM');
    }
  }

  Future<void> markNextDayPaused(String userId) async {
    final now = DateTime.now();
    final tomorrow = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));
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

    try {
      final orders =
          await _firestore
              .collection('orders')
              .where('userId', isEqualTo: userId)
              .where('status', isEqualTo: 'Pending Delivery')
              .where(
                'date',
                isGreaterThanOrEqualTo: Timestamp.fromDate(tomorrowStart),
              )
              .where(
                'date',
                isLessThanOrEqualTo: Timestamp.fromDate(tomorrowEnd),
              )
              .get();
      for (var order in orders.docs) {
        await order.reference.update({'status': 'Paused'});
      }
    } catch (e) {
      print('Error marking next day paused: $e');
    }
  }

  Future<void> resumeNextDay(String userId) async {
    final now = DateTime.now();
    final tomorrow = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));
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

    try {
      final orders =
          await _firestore
              .collection('orders')
              .where('userId', isEqualTo: userId)
              .where('status', isEqualTo: 'Paused')
              .where(
                'date',
                isGreaterThanOrEqualTo: Timestamp.fromDate(tomorrowStart),
              )
              .where(
                'date',
                isLessThanOrEqualTo: Timestamp.fromDate(tomorrowEnd),
              )
              .get();
      for (var order in orders.docs) {
        await order.reference.update({'status': 'Pending Delivery'});
      }
    } catch (e) {
      print('Error resuming next day: $e');
    }
  }
}
