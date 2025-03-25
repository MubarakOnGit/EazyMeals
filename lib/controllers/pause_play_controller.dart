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
          print('Pause state updated: isPaused=${isPaused.value}');
        }
      }, onError: (e) => print('Error listening to pause state: $e'));
    }
  }

  Future<void> togglePausePlay(bool isSubscribed) async {
    final user = _auth.currentUser;
    print('togglePausePlay called, isSubscribed: $isSubscribed');
    if (user == null || !isSubscribed || subscriptionEndDate.value == null) {
      print(
        'Exiting early: user=$user, isSubscribed=$isSubscribed, subEndDate=${subscriptionEndDate.value}',
      );
      return;
    }

    final now = DateTime.now();
    print('Current time: $now, Hour: ${now.hour}');
    if (now.hour >= 9 && now.hour < 22) {
      final newIsPaused = !isPaused.value;
      print('Toggling to: $newIsPaused');
      isPaused.value = newIsPaused; // Update local state immediately

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
        print('Updating Firestore with isPaused: $newIsPaused');
        await _firestore.collection('users').doc(user.uid).update({
          'isPaused': newIsPaused,
          'pausedAt': newIsPaused ? Timestamp.now() : FieldValue.delete(),
          'subscriptionEndDate': Timestamp.fromDate(subscriptionEndDate.value!),
        });
        print('Firestore updated successfully');
        if (newIsPaused) {
          await markNextDayPaused(user.uid);
        } else {
          await resumeNextDay(user.uid);
        }
      } catch (e) {
        isPaused.value = !newIsPaused; // Revert on error
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
