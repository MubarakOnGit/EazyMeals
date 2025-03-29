import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

class PausePlayController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RxBool isPaused = false.obs;
  final RxBool isPausedPreview = false.obs;
  final Rx<DateTime?> subscriptionEndDate = Rx<DateTime?>(null);
  final Rx<DateTime?> tempEndDate = Rx<DateTime?>(null);
  String? currentUserId;

  @override
  void onInit() {
    super.onInit();
    _setupAuthListener();
  }

  void _setupAuthListener() {
    _auth.authStateChanges().listen((User? user) {
      if (user != null && user.uid != currentUserId) {
        currentUserId = user.uid;
        _listenToPauseState();
      } else if (user == null) {
        currentUserId = null;
        isPaused.value = false;
        isPausedPreview.value = false;
        subscriptionEndDate.value = null;
        tempEndDate.value = null;
      }
    });
  }

  void _listenToPauseState() {
    if (currentUserId != null) {
      _firestore.collection('users').doc(currentUserId).snapshots().listen((
        doc,
      ) {
        if (doc.exists) {
          final data = doc.data() ?? {};
          isPaused.value = data['isPaused'] ?? false;
          subscriptionEndDate.value =
              data['subscriptionEndDate'] != null
                  ? (data['subscriptionEndDate'] as Timestamp).toDate()
                  : null;
          // Apply preview if paused
          tempEndDate.value =
              isPaused.value && subscriptionEndDate.value != null
                  ? subscriptionEndDate.value!.add(const Duration(days: 1))
                  : subscriptionEndDate.value;
          isPausedPreview.value = isPaused.value;
          print(
            'Pause state synced: isPaused=${isPaused.value}, tempEndDate=${tempEndDate.value}',
          );
        }
      }, onError: (e) => print('Error listening to pause state: $e'));
    }
  }

  Future<void> togglePausePlay(bool isSubscribed) async {
    final user = _auth.currentUser;
    if (user == null || !isSubscribed || subscriptionEndDate.value == null) {
      print(
        'Exiting early: user=$user, isSubscribed=$isSubscribed, subEndDate=${subscriptionEndDate.value}',
      );
      return;
    }

    final now = DateTime.now();
    if (now.hour >= 9 && now.hour < 22) {
      final newIsPausedPreview = !isPausedPreview.value;
      isPausedPreview.value = newIsPausedPreview;

      if (newIsPausedPreview) {
        tempEndDate.value = subscriptionEndDate.value!.add(
          const Duration(days: 1),
        );
        Get.snackbar('Paused', 'Food delivery paused for tomorrow');
        print('Paused - tempEndDate updated to: ${tempEndDate.value}');
      } else {
        tempEndDate.value = subscriptionEndDate.value;
        Get.snackbar('Resumed', 'Food delivery resumed for tomorrow');
        print('Resumed - tempEndDate reset to: ${tempEndDate.value}');
      }

      try {
        await _firestore.collection('users').doc(user.uid).update({
          'isPaused': newIsPausedPreview,
        });
        print('Firestore updated: isPaused=$newIsPausedPreview');
      } catch (e) {
        isPausedPreview.value = !newIsPausedPreview;
        tempEndDate.value = subscriptionEndDate.value;
        Get.snackbar('Error', 'Failed to update pause status: $e');
        print('Toggle pause/play error: $e');
      }
    } else {
      Get.snackbar('Info', 'You can only pause or play between 9 AM - 10 PM');
    }
  }

  String getPauseStatus() {
    return isPausedPreview.value
        ? 'Paused for tomorrow'
        : 'Active for tomorrow';
  }
}
