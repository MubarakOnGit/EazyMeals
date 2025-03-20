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

    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        title: Text(
          'Your Plan',
          style: TextStyle(
            color: Colors.blue.shade900,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.grey.shade900,
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.grey.shade900, Colors.grey.shade900],
          ),
        ),
        child:
            user == null
                ? Center(
                  child: Text(
                    'Please log in',
                    style: TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                )
                : _isDataMissing
                ? Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    color: Colors.grey.shade800,
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          Text(
                            'Delivery Information',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 20),
                          TextField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: 'Name',
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.1),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            style: TextStyle(color: Colors.white),
                          ),
                          SizedBox(height: 20),
                          TextField(
                            controller: _phoneController,
                            decoration: InputDecoration(
                              labelText: 'Phone Number',
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.1),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            keyboardType: TextInputType.phone,
                            style: TextStyle(color: Colors.white),
                          ),
                          SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _saveUserData,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade900,
                              padding: EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                            ),
                            child: Text(
                              'Save',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                : StreamBuilder<DocumentSnapshot>(
                  stream:
                      _firestore.collection('users').doc(user.uid).snapshots(),
                  builder: (context, userSnapshot) {
                    if (!userSnapshot.hasData) {
                      return Center(
                        child: CircularProgressIndicator(color: Colors.blue),
                      );
                    }
                    if (userSnapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error loading data',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      );
                    }
                    final userData =
                        userSnapshot.data!.data() as Map<String, dynamic>? ??
                        {};

                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle('Pending Subscriptions'),
                          _buildPendingSubscriptionsSection(user.uid),
                          _buildSectionTitle('Active Subscriptions'),
                          _buildActiveSubscriptionSection(userData, user.uid),
                          _buildSectionTitle('Ended Subscriptions'),
                          _buildEndedSubscriptions(user.uid),
                          SizedBox(height: 80),
                        ],
                      ),
                    );
                  },
                ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed:
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => SubscriptionScreen()),
            ).then((_) => setState(() {})),
        label: Text(
          'New Plan',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        icon: Icon(Icons.add, color: Colors.white),
        backgroundColor: Colors.blue.shade900,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
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
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator(color: Colors.blue));
        }
        if (snapshot.hasError) {
          return _buildErrorText('Error loading pending subscriptions');
        }
        final pendingSubscriptions = snapshot.data!.docs;
        if (pendingSubscriptions.isEmpty) {
          return _buildEmptyText('No pending subscriptions');
        }

        return Column(
          children:
              pendingSubscriptions.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                final orderId = data['orderId'] as String? ?? 'Unknown';

                return Container(
                  height: 220,
                  width: double.infinity,
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.grey.shade800, Colors.grey.shade700],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'PENDING',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Icon(Icons.wifi, color: Colors.white70),
                            ],
                          ),
                          SizedBox(height: 16),
                          Text(
                            '${data['subscriptionPlan']} (${data['category']})',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            data['mealType'],
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          Spacer(),
                          Text(
                            'Subscription Id: $orderId',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              letterSpacing: 2,
                            ),
                          ),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Requested: ${createdAt?.toString().substring(0, 10) ?? 'N/A'}',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '\$${data['amount']}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Positioned(
                        right: 0,
                        top: 40,
                        child: Icon(
                          Icons.account_balance_wallet,
                          color: Colors.white.withOpacity(0.1),
                          size: 60,
                        ),
                      ),
                      Positioned(
                        right: 10,
                        bottom: 40,
                        child: IconButton(
                          icon: Icon(Icons.cancel, color: Colors.redAccent),
                          onPressed:
                              () => _cancelPendingSubscription(userId, doc.id),
                        ),
                      ),
                    ],
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
      return _buildEmptyText('No active subscription');
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

    return Column(
      children: [
        Container(
          height: 220,
          width: double.infinity,
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade900, Colors.blue.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ACTIVE',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Icon(Icons.wifi, color: Colors.white70),
                    ],
                  ),
                  SizedBox(height: 16),
                  Text(
                    '${userData['subscriptionPlan']} (${userData['category']})',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    userData['mealType'],
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  Spacer(),
                  Text(
                    'Subscription Id: $subscriptionId',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'Valid: ${startDate?.toString().substring(0, 10) ?? 'N/A'} - ${endDate?.toString().substring(0, 10) ?? 'N/A'}',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _isExpanded ? Icons.expand_less : Icons.expand_more,
                          color: Colors.white,
                        ),
                        onPressed:
                            () => setState(() => _isExpanded = !_isExpanded),
                      ),
                    ],
                  ),
                ],
              ),
              Positioned(
                right: 0,
                top: 40,
                child: Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white.withOpacity(0.1),
                  size: 60,
                ),
              ),
            ],
          ),
        ),
        if (_isExpanded)
          Container(
            width: double.infinity,
            margin: EdgeInsets.symmetric(horizontal: 16),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade800.withOpacity(0.9),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order Details',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                StreamBuilder<QuerySnapshot>(
                  stream:
                      _firestore
                          .collection('orders')
                          .where('userId', isEqualTo: userId)
                          .where('subscriptionId', isEqualTo: subscriptionId)
                          .where(
                            'date',
                            isGreaterThanOrEqualTo: Timestamp.fromDate(
                              DateTime.now().subtract(Duration(days: 1)),
                            ),
                          )
                          .where(
                            'date',
                            isLessThanOrEqualTo: Timestamp.fromDate(
                              DateTime.now(),
                            ),
                          )
                          .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return _buildLoading();
                    }
                    final orders = snapshot.data!.docs;
                    if (orders.isEmpty) {
                      return Text(
                        'No order for today',
                        style: TextStyle(color: Colors.white70),
                      );
                    }
                    final order = orders.first.data() as Map<String, dynamic>;
                    final status = order['status'] ?? 'Unknown';
                    return _buildOrderTileWithStatus(order, status);
                  },
                ),
                SizedBox(height: 8),
                Text(
                  'Past Orders',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                _buildOrderStream(userId, subscriptionId, [
                  'Delivered',
                  'Cancelled',
                  'Paused',
                ], true),
                SizedBox(height: 8),
                Text(
                  'Upcoming Orders',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                _buildOrderStream(userId, subscriptionId, [
                  'Pending Delivery',
                ], false),
              ],
            ),
          ),
      ],
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
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator(color: Colors.blue));
        }
        if (snapshot.hasError) {
          return _buildErrorText('Error loading ended subscriptions');
        }
        if (snapshot.data!.docs.isEmpty) {
          return _buildEmptyText('No previous subscriptions');
        }

        return Column(
          children:
              snapshot.data!.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final startDate =
                    (data['subscriptionStartDate'] as Timestamp?)?.toDate();
                final endDate =
                    (data['subscriptionEndDate'] as Timestamp?)?.toDate();
                final subscriptionId = data['subscriptionId'] as String? ?? '';

                return Container(
                  height: 200,
                  width: double.infinity,
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.grey.shade800, Colors.grey.shade700],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'ENDED',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Icon(Icons.wifi, color: Colors.white70),
                            ],
                          ),
                          SizedBox(height: 16),
                          Text(
                            '${data['subscriptionPlan']} (${data['category']})',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            data['mealType'],
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          Spacer(),
                          Text(
                            'Subscription Id: $subscriptionId',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              letterSpacing: 2,
                            ),
                          ),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  'Valid: ${startDate?.toString().substring(0, 10) ?? 'N/A'} - ${endDate?.toString().substring(0, 10) ?? 'N/A'}',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                'Status: Cancelled',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Positioned(
                        right: 0,
                        top: 40,
                        child: Icon(
                          Icons.account_balance_wallet,
                          color: Colors.white.withOpacity(0.1),
                          size: 60,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
        );
      },
    );
  }

  Widget _buildOrderStream(
    String userId,
    String subscriptionId,
    List<String> statuses,
    bool isPast,
  ) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          _firestore
              .collection('orders')
              .where('userId', isEqualTo: userId)
              .where('subscriptionId', isEqualTo: subscriptionId)
              .where('status', whereIn: statuses)
              .orderBy('date', descending: isPast)
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _buildLoading();
        if (snapshot.data!.docs.isEmpty) {
          return Text(
            isPast ? 'No past orders' : 'No upcoming orders',
            style: TextStyle(color: Colors.white70),
          );
        }
        return Column(
          children:
              snapshot.data!.docs.map((doc) => _buildOrderTile(doc)).toList(),
        );
      },
    );
  }

  Widget _buildOrderTile(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final date = (data['date'] as Timestamp?)?.toDate();
    final status = data['status'] ?? 'Unknown';

    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data['mealType'],
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                date?.toString().substring(0, 10) ?? 'N/A',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          Text(
            status,
            style: TextStyle(
              color: _getStatusColor(status),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderTileWithStatus(Map<String, dynamic> order, String status) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Today's: ${order['mealType']}",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                DateTime.now().toString().substring(0, 10),
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          Text(
            status,
            style: TextStyle(
              color: _getStatusColor(status),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyText(String text) {
    return Padding(
      padding: EdgeInsets.all(16.0),
      child: Text(
        text,
        style: TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
      ),
    );
  }

  Widget _buildErrorText(String text) {
    return Padding(
      padding: EdgeInsets.all(16.0),
      child: Text(text, style: TextStyle(color: Colors.redAccent)),
    );
  }

  Widget _buildLoading() {
    return Padding(
      padding: EdgeInsets.all(8.0),
      child: CircularProgressIndicator(color: Colors.white),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Pending Delivery':
        return Icons.hourglass_empty;
      case 'Delivered':
        return Icons.check_circle;
      case 'Cancelled':
        return Icons.cancel;
      case 'Paused':
        return Icons.pause_circle;
      default:
        return Icons.help;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending Delivery':
        return Colors.yellow[800]!;
      case 'Delivered':
        return Colors.green;
      case 'Cancelled':
      case 'Ended':
        return Colors.red;
      case 'Paused':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
