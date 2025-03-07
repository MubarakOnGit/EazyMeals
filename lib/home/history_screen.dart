import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class HistoryScreen extends StatefulWidget {
  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isExpanded = false;
  bool _isDataMissing = false;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scheduleOrderCancellation();
    _checkUserData();
  }

  void _scheduleOrderCancellation() {
    final now = DateTime.now();
    var next12PM = DateTime(now.year, now.month, now.day, 12, 0);
    if (now.isAfter(next12PM)) next12PM = next12PM.add(Duration(days: 1));
    final duration = next12PM.difference(now);

    Timer(duration, () async {
      await _cancelPendingOrders();
      if (mounted) _scheduleOrderCancellation();
    });
  }

  Future<void> _cancelPendingOrders() async {
    User? user = _auth.currentUser;
    if (user != null) {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day, 0, 0);
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

      QuerySnapshot orders =
          await _firestore
              .collection('orders')
              .where('userId', isEqualTo: user.uid)
              .where('status', isEqualTo: 'Pending Delivery')
              .where(
                'date',
                isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart),
              )
              .where('date', isLessThanOrEqualTo: Timestamp.fromDate(todayEnd))
              .get();

      final batch = _firestore.batch();
      for (var doc in orders.docs) {
        batch.update(doc.reference, {'status': 'Cancelled'});
      }
      await batch.commit();
      print('Cancelled ${orders.docs.length} pending orders for today');
    }
  }

  Future<void> _checkUserData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() as Map<String, dynamic>? ?? {};
      final name = userData['name'] as String?;
      final phone = userData['phone'] as String?;

      if (name == null || phone == null || name.isEmpty || phone.isEmpty) {
        setState(() => _isDataMissing = true);
      } else {
        setState(() => _isDataMissing = false);
      }
    }
  }

  Future<void> _saveUserData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Please fill in all fields')));
        return;
      }

      await _firestore.collection('users').doc(user.uid).set({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
      }, SetOptions(merge: true));

      setState(() => _isDataMissing = false);
      print('User data saved for ${user.uid}');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    User? user = _auth.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Order History'),
          backgroundColor: Colors.blue,
          centerTitle: true,
        ),
        body: Center(child: Text('Please log in')),
      );
    }

    if (_isDataMissing) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Order History'),
          backgroundColor: Colors.blue,
          centerTitle: true,
        ),
        body: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'We need some information for delivery',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 20),
              TextField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveUserData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: Text('Save', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Order History'),
        backgroundColor: Colors.blue,
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('users').doc(user.uid).snapshots(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData)
            return Center(child: CircularProgressIndicator());
          final userData =
              userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
          final hasSubscriptionData =
              userData.containsKey('subscriptionPlan') ||
              userData.containsKey('activeSubscription');

          if (!hasSubscriptionData) {
            return Center(
              child: Text(
                'This page is empty',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Active Subscriptions',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                _buildActiveSubscriptionSection(userData, user.uid),
                SizedBox(height: 20),
                Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Ended Subscriptions',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                _buildEndedSubscriptions(userData, user.uid),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActiveSubscriptionSection(
    Map<String, dynamic> userData,
    String userId,
  ) {
    final isActive = userData['activeSubscription'] as bool? ?? false;
    if (!isActive)
      return Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No active subscription'),
      );
    return _buildActiveSubscriptionCard(userData, userId);
  }

  Widget _buildActiveSubscriptionCard(
    Map<String, dynamic> userData,
    String userId,
  ) {
    final startDate =
        (userData['subscriptionStartDate'] as Timestamp?)?.toDate();
    final endDate = (userData['subscriptionEndDate'] as Timestamp?)?.toDate();
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day, 0, 0);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final tomorrowStart = DateTime(now.year, now.month, now.day + 1, 0, 0);
    final tomorrowEnd = DateTime(now.year, now.month, now.day + 1, 23, 59, 59);

    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${userData['subscriptionPlan'] ?? 'Unknown Plan'} (${userData['category'] ?? 'N/A'}) - ${userData['mealType'] ?? 'N/A'}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                  ),
                  onPressed: () => setState(() => _isExpanded = !_isExpanded),
                ),
              ],
            ),
            Text(
              'Start: ${startDate != null ? "${startDate.day}/${startDate.month}/${startDate.year}" : 'N/A'} - End: ${endDate != null ? "${endDate.day}/${endDate.month}/${endDate.year}" : 'N/A'}',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(
              stream:
                  _firestore
                      .collection('orders')
                      .where('userId', isEqualTo: userId)
                      .where(
                        'date',
                        isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart),
                      )
                      .where(
                        'date',
                        isLessThanOrEqualTo: Timestamp.fromDate(todayEnd),
                      )
                      .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Text('Loading today\'s order...');
                final orders = snapshot.data!.docs;
                print('Today\'s orders fetched: ${orders.length}');
                if (orders.isEmpty) return Text('No order for today');

                final order = orders.first.data() as Map<String, dynamic>;
                final status = order['status'] ?? 'Unknown';
                print('Today\'s order status: $status');

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today\'s Order: ${order['mealType'] ?? 'N/A'}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Status: $status',
                      style: TextStyle(
                        fontSize: 14,
                        color: _getStatusColor(status),
                      ),
                    ),
                  ],
                );
              },
            ),
            if (_isExpanded) ...[
              SizedBox(height: 10),
              Text(
                'Completed/Cancelled/Paused Orders',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              StreamBuilder<QuerySnapshot>(
                stream:
                    _firestore
                        .collection('orders')
                        .where('userId', isEqualTo: userId)
                        .where(
                          'status',
                          whereIn: ['Delivered', 'Cancelled', 'Paused'],
                        )
                        .orderBy('date', descending: true)
                        .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return CircularProgressIndicator();
                  final orders = snapshot.data!.docs;
                  print(
                    'Completed/Cancelled/Paused orders fetched: ${orders.length}',
                  );
                  return orders.isEmpty
                      ? Text('No completed, cancelled, or paused orders')
                      : Column(
                        children:
                            orders.map((doc) => _buildOrderTile(doc)).toList(),
                      );
                },
              ),
              SizedBox(height: 10),
              Text(
                'Upcoming Orders',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              StreamBuilder<QuerySnapshot>(
                stream:
                    _firestore
                        .collection('orders')
                        .where('userId', isEqualTo: userId)
                        .where(
                          'date',
                          isGreaterThanOrEqualTo: Timestamp.fromDate(
                            tomorrowStart,
                          ),
                        )
                        .where(
                          'date',
                          isLessThanOrEqualTo: Timestamp.fromDate(tomorrowEnd),
                        )
                        .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return CircularProgressIndicator();
                  final orders = snapshot.data!.docs;
                  print('Upcoming orders fetched: ${orders.length}');
                  for (var order in orders) {
                    final data = order.data() as Map<String, dynamic>;
                    print(
                      'Upcoming order: ${data['mealType']} - Status: ${data['status']} - Date: ${(data['date'] as Timestamp).toDate()}',
                    );
                  }
                  return orders.isEmpty
                      ? Text('No upcoming orders for tomorrow')
                      : Column(
                        children:
                            orders.map((doc) => _buildOrderTile(doc)).toList(),
                      );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEndedSubscriptions(
    Map<String, dynamic> userData,
    String userId,
  ) {
    final isActive = userData['activeSubscription'] as bool? ?? false;
    final startDate =
        (userData['subscriptionStartDate'] as Timestamp?)?.toDate();
    final endDate = (userData['subscriptionEndDate'] as Timestamp?)?.toDate();

    if (isActive || (startDate == null && endDate == null)) {
      return Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No ended subscriptions'),
      );
    }

    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${userData['subscriptionPlan'] ?? 'Unknown Plan'} (${userData['category'] ?? 'N/A'}) - ${userData['mealType'] ?? 'N/A'}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Start: ${startDate != null ? "${startDate.day}/${startDate.month}/${startDate.year}" : 'N/A'} - End: ${endDate != null ? "${endDate.day}/${endDate.month}/${endDate.year}" : 'N/A'}',
              style: TextStyle(fontSize: 14),
            ),
            Text(
              'Status: Ended',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderTile(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final date = (data['date'] as Timestamp?)?.toDate();
    final status = data['status'] ?? 'Unknown';

    return ListTile(
      title: Text(
        '${data['mealType'] ?? 'N/A'} - ${date != null ? "${date.day}/${date.month}/${date.year}" : 'N/A'}',
      ),
      subtitle: Text('Status: $status'),
      tileColor: _getStatusColor(status).withOpacity(0.1),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending Delivery':
        return Colors.yellow[800]!;
      case 'Delivered':
        return Colors.green;
      case 'Cancelled':
        return Colors.red;
      case 'Paused':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
