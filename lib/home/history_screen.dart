import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../screens/subscription_screen.dart'; // Adjust path as needed

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

      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() as Map<String, dynamic>? ?? {};
      String subscriptionId = userData['subscriptionId'] as String? ?? '';

      QuerySnapshot orders =
          await _firestore
              .collection('orders')
              .where('userId', isEqualTo: user.uid)
              .where('subscriptionId', isEqualTo: subscriptionId)
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

  Future<void> _cancelPendingSubscription(String userId, String docId) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Confirm Cancellation'),
            content: Text(
              'Are you sure you want to cancel this pending subscription? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Yes'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('pendingOrders')
          .doc(docId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pending subscription cancelled successfully')),
      );
      print('Pending subscription $docId cancelled and deleted');
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
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(
            'Your Plan',
            style: TextStyle(color: Colors.blue.shade900),
          ),
          backgroundColor: Colors.white,
          centerTitle: true,
        ),
        body: Center(child: Text('Please log in')),
      );
    }

    if (_isDataMissing) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(
            'Your Plan',
            style: TextStyle(color: Colors.blue.shade900),
          ),
          backgroundColor: Colors.white,
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Your Plan', style: TextStyle(color: Colors.blue.shade900)),
        backgroundColor: Colors.white,
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('users').doc(user.uid).snapshots(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) {
            print('No snapshot data yet');
            return Center(child: CircularProgressIndicator());
          }
          if (userSnapshot.hasError) {
            print('Snapshot error: ${userSnapshot.error}');
            return Center(child: Text('Error loading data'));
          }
          final userData =
              userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
          print('User Data: $userData'); // Log for debugging

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Pending Subscriptions',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
                _buildPendingSubscriptionsSection(user.uid),
                Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Active Subscriptions',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
                _buildActiveSubscriptionSection(userData, user.uid),
                SizedBox(height: 20),
                Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Ended Subscriptions',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
                _buildEndedSubscriptions(user.uid),
                SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed:
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => SubscriptionScreen()),
            ).then((_) => setState(() {})),
        label: Text('Subscribe a Plan', style: TextStyle(color: Colors.white)),
        icon: Icon(Icons.add, color: Colors.white),
        backgroundColor: Colors.blue.shade900,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildPendingSubscriptionsSection(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          _firestore
              .collection('users')
              .doc(userId)
              .collection('pendingOrders')
              .where('status', isEqualTo: 'Pending Payment')
              .orderBy('createdAt', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return Center(child: CircularProgressIndicator());
        if (snapshot.hasError) {
          print('Error fetching pending subscriptions: ${snapshot.error}');
          return Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Error loading pending subscriptions',
              style: TextStyle(color: Colors.red),
            ),
          );
        }
        final pendingSubscriptions = snapshot.data!.docs;
        if (pendingSubscriptions.isEmpty) {
          return Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'No pending subscriptions',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return Column(
          children:
              pendingSubscriptions.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                final orderId = data['orderId'] as String? ?? 'Unknown';

                return Card(
                  elevation: 2,
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Subscription ID: $orderId',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                              Text(
                                '${data['subscriptionPlan']} (${data['category']}) - ${data['mealType']}',
                                style: TextStyle(fontSize: 14),
                              ),
                              Text(
                                'Amount: \$${data['amount']}',
                                style: TextStyle(fontSize: 14),
                              ),
                              Text(
                                'Requested: ${createdAt != null ? "${createdAt.day}/${createdAt.month}/${createdAt.year}" : 'N/A'}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                'Status: ${data['status']}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.cancel, color: Colors.red),
                          onPressed:
                              () => _cancelPendingSubscription(userId, doc.id),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
        );
      },
    );
  }

  Widget _buildActiveSubscriptionSection(
    Map<String, dynamic> userData,
    String userId,
  ) {
    final isActive = userData['activeSubscription'] as bool? ?? false;
    if (!isActive ||
        !userData.containsKey('subscriptionPlan') ||
        !userData.containsKey('subscriptionId')) {
      print(
        'No active subscription - isActive: $isActive, hasPlan: ${userData.containsKey('subscriptionPlan')}, hasId: ${userData.containsKey('subscriptionId')}',
      );
      return Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          'No active subscription',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    return _buildActiveSubscriptionCard(userData, userId);
  }

  Widget _buildActiveSubscriptionCard(
    Map<String, dynamic> userData,
    String userId,
  ) {
    final startDate =
        (userData['subscriptionStartDate'] as Timestamp?)?.toDate();
    final endDate = (userData['subscriptionEndDate'] as Timestamp?)?.toDate();
    final subscriptionId = userData['subscriptionId'] as String? ?? '';
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day, 0, 0);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    if (startDate == null || endDate == null || subscriptionId.isEmpty) {
      print(
        'Incomplete data: startDate=$startDate, endDate=$endDate, subscriptionId=$subscriptionId',
      );
      return Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          'Subscription data incomplete',
          style: TextStyle(color: Colors.red),
        ),
      );
    }

    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade900, Colors.blue.shade700],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${userData['subscriptionPlan']} (${userData['category']}) - ${userData['mealType']}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.orange,
                    ),
                    onPressed: () => setState(() => _isExpanded = !_isExpanded),
                  ),
                ],
              ),
              Text(
                'Start: ${startDate.day}/${startDate.month}/${startDate.year} - End: ${endDate.day}/${endDate.month}/${endDate.year}',
                style: TextStyle(fontSize: 14, color: Colors.white),
              ),
              SizedBox(height: 10),
              StreamBuilder<QuerySnapshot>(
                stream:
                    _firestore
                        .collection('orders')
                        .where('userId', isEqualTo: userId)
                        .where('subscriptionId', isEqualTo: subscriptionId)
                        .where(
                          'date',
                          isGreaterThanOrEqualTo: Timestamp.fromDate(
                            todayStart,
                          ),
                        )
                        .where(
                          'date',
                          isLessThanOrEqualTo: Timestamp.fromDate(todayEnd),
                        )
                        .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Text(
                      'Loading today\'s order...',
                      style: TextStyle(color: Colors.white),
                    );
                  }
                  final orders = snapshot.data!.docs;
                  if (orders.isEmpty) {
                    return Text(
                      'No order for today',
                      style: TextStyle(color: Colors.white),
                    );
                  }

                  final order = orders.first.data() as Map<String, dynamic>;
                  final status = order['status'] ?? 'Unknown';

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Today\'s Order: ${order['mealType']}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                StreamBuilder<QuerySnapshot>(
                  stream:
                      _firestore
                          .collection('orders')
                          .where('userId', isEqualTo: userId)
                          .where('subscriptionId', isEqualTo: subscriptionId)
                          .where(
                            'status',
                            whereIn: ['Delivered', 'Cancelled', 'Paused'],
                          )
                          .orderBy('date', descending: true)
                          .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData)
                      return CircularProgressIndicator(color: Colors.white);
                    final orders = snapshot.data!.docs;
                    if (orders.isEmpty) {
                      return Text(
                        'No completed, cancelled, or paused orders for this subscription',
                        style: TextStyle(color: Colors.white),
                      );
                    }
                    return Column(
                      children:
                          orders.map((doc) => _buildOrderTile(doc)).toList(),
                    );
                  },
                ),
                SizedBox(height: 10),
                Text(
                  'Upcoming Orders',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                StreamBuilder<QuerySnapshot>(
                  stream:
                      _firestore
                          .collection('orders')
                          .where('userId', isEqualTo: userId)
                          .where('subscriptionId', isEqualTo: subscriptionId)
                          .where(
                            'date',
                            isGreaterThan: Timestamp.fromDate(todayEnd),
                          )
                          .where(
                            'date',
                            isLessThanOrEqualTo: Timestamp.fromDate(endDate),
                          )
                          .orderBy('date', descending: false)
                          .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData)
                      return CircularProgressIndicator(color: Colors.white);
                    final orders = snapshot.data!.docs;
                    if (orders.isEmpty) {
                      return Text(
                        'No upcoming orders',
                        style: TextStyle(color: Colors.white),
                      );
                    }
                    return Column(
                      children:
                          orders.map((doc) => _buildOrderTile(doc)).toList(),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEndedSubscriptions(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          _firestore
              .collection('users')
              .doc(userId)
              .collection('pastSubscriptions')
              .orderBy('subscriptionEndDate', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return Center(child: CircularProgressIndicator());
        if (snapshot.hasError) {
          print('Error fetching past subscriptions: ${snapshot.error}');
          return Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Error loading ended subscriptions',
              style: TextStyle(color: Colors.red),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'You don\'t have any previous subscriptions',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        final pastSubscriptions = snapshot.data!.docs;
        return Column(
          children:
              pastSubscriptions.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final startDate =
                    (data['subscriptionStartDate'] as Timestamp?)?.toDate();
                final endDate =
                    (data['subscriptionEndDate'] as Timestamp?)?.toDate();
                final status =
                    data['status'] as String? ??
                    (data['endedNaturally'] == true ? 'Ended' : 'Cancelled');

                return Card(
                  elevation: 4,
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade900, Colors.blue.shade700],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${data['subscriptionPlan']} (${data['category']}) - ${data['mealType']}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Start: ${startDate != null ? "${startDate.day}/${startDate.month}/${startDate.year}" : 'N/A'} - End: ${endDate != null ? "${endDate.day}/${endDate.month}/${endDate.year}" : 'N/A'}',
                            style: TextStyle(fontSize: 14, color: Colors.white),
                          ),
                          Text(
                            'Status: $status',
                            style: TextStyle(fontSize: 14, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
        );
      },
    );
  }

  Widget _buildOrderTile(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final date = (data['date'] as Timestamp?)?.toDate();
    final status = data['status'] ?? 'Unknown';

    return ListTile(
      title: Text(
        '${data['mealType']} - ${date != null ? "${date.day}/${date.month}/${date.year}" : 'N/A'}',
        style: TextStyle(color: Colors.white),
      ),
      subtitle: Text(
        'Status: $status',
        style: TextStyle(color: _getStatusColor(status)),
      ),
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
