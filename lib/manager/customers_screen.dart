import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart'; // For generating unique subscription IDs

class CustomersScreen extends StatefulWidget {
  @override
  _CustomersScreenState createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = Uuid(); // For generating unique subscription IDs

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Customers'),
        backgroundColor: Colors.blue,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return Center(child: CircularProgressIndicator());
          final users = snapshot.data!.docs;
          if (users.isEmpty) {
            return Center(
              child: Text(
                'This page is empty',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final userData = user.data() as Map<String, dynamic>? ?? {};
              final userId = user.id;
              final isActive = userData['activeSubscription'] as bool? ?? false;
              final isPaused = userData['isPaused'] as bool? ?? false;

              return ListTile(
                title: Text(userData['name'] as String? ?? 'Unnamed'),
                subtitle: Text(
                  'Email: ${userData['email'] as String? ?? 'No email'}',
                ),
                trailing:
                    isActive
                        ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                isPaused ? Icons.play_arrow : Icons.pause,
                              ),
                              color: isPaused ? Colors.green : Colors.orange,
                              onPressed:
                                  () => _togglePausePlay(userId, isPaused),
                            ),
                            IconButton(
                              icon: Icon(Icons.power_off),
                              color: Colors.red,
                              onPressed: () => _confirmDeactivate(userId),
                            ),
                          ],
                        )
                        : ElevatedButton(
                          onPressed:
                              () => _showActivationDialog(userId, userData),
                          child: Text('Activate'),
                        ),
              );
            },
          );
        },
      ),
    );
  }

  void _showActivationDialog(String userId, Map<String, dynamic> userData) {
    String category = userData['category'] as String? ?? 'Veg';
    String mealType = userData['mealType'] as String? ?? 'Lunch';
    String plan = userData['subscriptionPlan'] as String? ?? '1 Week';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Activate Subscription'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<String>(
                    value: category,
                    onChanged: (value) => setState(() => category = value!),
                    items:
                        ['Veg', 'South Indian', 'North Indian']
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            )
                            .toList(),
                  ),
                  DropdownButton<String>(
                    value: mealType,
                    onChanged: (value) => setState(() => mealType = value!),
                    items:
                        ['Lunch', 'Dinner', 'Both']
                            .map(
                              (m) => DropdownMenuItem(value: m, child: Text(m)),
                            )
                            .toList(),
                  ),
                  DropdownButton<String>(
                    value: plan,
                    onChanged: (value) => setState(() => plan = value!),
                    items:
                        ['1 Week', '3 Weeks', '4 Weeks']
                            .map(
                              (p) => DropdownMenuItem(value: p, child: Text(p)),
                            )
                            .toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed:
                      () => _confirmActivate(userId, category, mealType, plan),
                  child: Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmActivate(
    String userId,
    String category,
    String mealType,
    String plan,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Confirm Activation'),
            content: Text(
              'Are you sure you want to activate this subscription?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    DocumentSnapshot userDoc =
                        await _firestore.collection('users').doc(userId).get();
                    final userData =
                        userDoc.data() as Map<String, dynamic>? ?? {};
                    String? pendingOrderId =
                        userData['pendingOrderId'] as String?;

                    await _activateSubscription(
                      userId,
                      category,
                      mealType,
                      plan,
                      pendingOrderId: pendingOrderId,
                    );
                    Navigator.pop(context); // Close confirmation
                    Navigator.pop(context); // Close activation dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Subscription activated successfully'),
                      ),
                    );
                  } catch (e) {
                    print('Error activating subscription: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to activate subscription: $e'),
                      ),
                    );
                  }
                },
                child: Text('Yes'),
              ),
            ],
          ),
    );
  }

  Future<void> _activateSubscription(
    String userId,
    String category,
    String mealType,
    String plan, {
    String? pendingOrderId,
  }) async {
    final now = DateTime.now();
    int durationDays;
    switch (plan) {
      case '1 Week':
        durationDays = 7;
        break;
      case '3 Weeks':
        durationDays = 21;
        break;
      case '4 Weeks':
        durationDays = 28;
        break;
      default:
        durationDays = 7;
    }

    DateTime startDate = now;
    DateTime endDate = startDate.add(Duration(days: durationDays));
    String subscriptionId = _uuid.v4();

    await _firestore.runTransaction((transaction) async {
      DocumentReference userRef = _firestore.collection('users').doc(userId);

      transaction.set(userRef, {
        'activeSubscription': true,
        'subscriptionId': subscriptionId,
        'subscriptionPlan': plan,
        'category': category,
        'mealType': mealType,
        'subscriptionStartDate': Timestamp.fromDate(startDate),
        'subscriptionEndDate': Timestamp.fromDate(endDate),
        'isPaused': false,
        'pausedAt': null,
        'pendingOrderId': FieldValue.delete(), // Clear pending ID
      }, SetOptions(merge: true));

      final batch = _firestore.batch();
      for (int i = 0; i < durationDays; i++) {
        DateTime orderDate = startDate.add(Duration(days: i));
        DocumentReference orderRef = _firestore.collection('orders').doc();
        batch.set(orderRef, {
          'userId': userId,
          'subscriptionId': subscriptionId,
          'category': category,
          'mealType': mealType,
          'date': Timestamp.fromDate(orderDate),
          'status': 'Pending Delivery',
        });
      }
      await batch.commit();

      // Mark pending order as completed if provided
      if (pendingOrderId != null) {
        DocumentReference pendingOrderRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('pendingOrders')
            .doc(pendingOrderId);
        transaction.update(pendingOrderRef, {
          'status': 'Completed',
          'subscriptionId': subscriptionId,
          'activatedAt': Timestamp.now(),
        });
      }
    });

    print(
      'Subscription activated for $userId: $plan, ID: $subscriptionId, Start: $startDate, End: $endDate, Orders: $durationDays',
    );
  }

  void _confirmDeactivate(String userId) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Confirm Deactivation'),
            content: Text(
              'Are you sure you want to deactivate this subscription? All pending orders will be cancelled.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await _deactivateSubscription(userId);
                  Navigator.pop(context);
                },
                child: Text('Yes'),
              ),
            ],
          ),
    );
  }

  Future<void> _deactivateSubscription(String userId) async {
    DocumentSnapshot userDoc =
        await _firestore.collection('users').doc(userId).get();
    final userData = userDoc.data() as Map<String, dynamic>? ?? {};

    if (userData['activeSubscription'] == true) {
      String subscriptionId = userData['subscriptionId'] as String? ?? '';

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('pastSubscriptions')
          .add({
            'subscriptionId': subscriptionId,
            'subscriptionPlan': userData['subscriptionPlan'],
            'category': userData['category'],
            'mealType': userData['mealType'],
            'subscriptionStartDate': userData['subscriptionStartDate'],
            'subscriptionEndDate': Timestamp.now(),
            'status': 'Cancelled',
            'cancelledAt': Timestamp.now(),
          });

      await _firestore.collection('users').doc(userId).update({
        'activeSubscription': false,
        'subscriptionId': FieldValue.delete(),
        'subscriptionPlan': FieldValue.delete(),
        'subscriptionStartDate': FieldValue.delete(),
        'subscriptionEndDate': FieldValue.delete(),
        'isPaused': FieldValue.delete(),
        'pausedAt': FieldValue.delete(),
      });

      await _cancelRemainingOrders(userId, subscriptionId);
      print(
        'Subscription cancelled and archived for $userId, ID: $subscriptionId',
      );
    }
  }

  void _togglePausePlay(String userId, bool isPaused) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Confirm ${isPaused ? 'Play' : 'Pause'}'),
            content: Text(
              'Are you sure you want to ${isPaused ? 'resume' : 'pause'} this subscription?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await _setPausePlay(userId, !isPaused);
                  Navigator.pop(context);
                },
                child: Text('Yes'),
              ),
            ],
          ),
    );
  }

  Future<void> _setPausePlay(String userId, bool pause) async {
    if (pause) {
      await _firestore.collection('users').doc(userId).update({
        'isPaused': true,
        'pausedAt': Timestamp.now(),
      });
      await _markNextDayPaused(userId);
    } else {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data() as Map<String, dynamic>? ?? {};
      DateTime? pausedAt = (userData['pausedAt'] as Timestamp?)?.toDate();
      DateTime? endDate =
          (userData['subscriptionEndDate'] as Timestamp?)?.toDate();

      if (pausedAt != null && endDate != null) {
        final pausedDuration = DateTime.now().difference(pausedAt).inSeconds;
        endDate = endDate.add(Duration(seconds: pausedDuration));
      }

      await _firestore.collection('users').doc(userId).update({
        'isPaused': false,
        'pausedAt': FieldValue.delete(),
        'subscriptionEndDate':
            endDate != null ? Timestamp.fromDate(endDate) : FieldValue.delete(),
      });
      await _resumeNextDay(userId);
    }
    print('Subscription ${pause ? 'paused' : 'resumed'} for $userId');
  }

  Future<void> _markNextDayPaused(String userId) async {
    final now = DateTime.now();
    final tomorrow = now.add(Duration(days: 1));
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

    DocumentSnapshot userDoc =
        await _firestore.collection('users').doc(userId).get();
    final userData = userDoc.data() as Map<String, dynamic>? ?? {};
    String subscriptionId = userData['subscriptionId'] as String? ?? '';

    QuerySnapshot orders =
        await _firestore
            .collection('orders')
            .where('userId', isEqualTo: userId)
            .where('subscriptionId', isEqualTo: subscriptionId)
            .where('status', isEqualTo: 'Pending Delivery')
            .where(
              'date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(tomorrowStart),
            )
            .where('date', isLessThanOrEqualTo: Timestamp.fromDate(tomorrowEnd))
            .get();

    for (var order in orders.docs) {
      await order.reference.update({'status': 'Paused'});
      print('Marked next day\'s order as Paused for $userId');
    }
  }

  Future<void> _resumeNextDay(String userId) async {
    final now = DateTime.now();
    final tomorrow = now.add(Duration(days: 1));
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

    DocumentSnapshot userDoc =
        await _firestore.collection('users').doc(userId).get();
    final userData = userDoc.data() as Map<String, dynamic>? ?? {};
    String subscriptionId = userData['subscriptionId'] as String? ?? '';

    QuerySnapshot orders =
        await _firestore
            .collection('orders')
            .where('userId', isEqualTo: userId)
            .where('subscriptionId', isEqualTo: subscriptionId)
            .where('status', isEqualTo: 'Paused')
            .where(
              'date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(tomorrowStart),
            )
            .where('date', isLessThanOrEqualTo: Timestamp.fromDate(tomorrowEnd))
            .get();

    for (var order in orders.docs) {
      await order.reference.update({'status': 'Pending Delivery'});
      print('Resumed next day\'s order for $userId');
    }
  }

  Future<void> _cancelRemainingOrders(
    String userId,
    String subscriptionId,
  ) async {
    QuerySnapshot orders =
        await _firestore
            .collection('orders')
            .where('userId', isEqualTo: userId)
            .where('subscriptionId', isEqualTo: subscriptionId)
            .where('status', isEqualTo: 'Pending Delivery')
            .get();

    for (var doc in orders.docs) {
      await doc.reference.update({'status': 'Cancelled'});
      print('Cancelled remaining order: ${doc.id}');
    }
  }
}
