// lib/history_screen.dart
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
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _scheduleOrderCancellation();
    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page!.round();
      });
    });
  }

  void _scheduleOrderCancellation() {
    final now = DateTime.now();
    var next12PM = DateTime(now.year, now.month, now.day, 12, 0);
    if (now.isAfter(next12PM)) {
      next12PM = next12PM.add(Duration(days: 1));
    }
    final duration = next12PM.difference(now);

    Timer(duration, () async {
      await _cancelPendingOrders();
      _scheduleOrderCancellation();
    });
  }

  Future<void> _cancelPendingOrders() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists && userDoc['activeSubscription'] == true) {
        QuerySnapshot orders =
            await _firestore
                .collection('orders')
                .where('userId', isEqualTo: user.uid)
                .where('status', isEqualTo: 'Pending Delivery')
                .get();

        for (var doc in orders.docs) {
          DateTime orderDate = (doc['date'] as Timestamp).toDate();
          if (orderDate.day == DateTime.now().day) {
            await doc.reference.update({'status': 'Cancelled'});
            print('Cancelled today\'s pending order for ${user.uid}');
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SizedBox(height: 40),
          Center(
            child: Text(
              'Order History',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap:
                    () => _pageController.animateToPage(
                      0,
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Subscriptions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                          _currentPage == 0
                              ? FontWeight.bold
                              : FontWeight.normal,
                      color: _currentPage == 0 ? Colors.blue : Colors.grey,
                    ),
                  ),
                ),
              ),
              StreamBuilder<DocumentSnapshot>(
                stream:
                    _firestore
                        .collection('users')
                        .doc(_auth.currentUser?.uid)
                        .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return SizedBox.shrink();
                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  final isActive = data['activeSubscription'] ?? false;

                  return isActive
                      ? GestureDetector(
                        onTap:
                            () => _pageController.animateToPage(
                              1,
                              duration: Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            'Orders',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight:
                                  _currentPage == 1
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                              color:
                                  _currentPage == 1 ? Colors.blue : Colors.grey,
                            ),
                          ),
                        ),
                      )
                      : SizedBox.shrink(); // Hide Orders tab if no active subscription
                },
              ),
            ],
          ),
          SizedBox(height: 10),
          Expanded(
            child: PageView(
              controller: _pageController,
              children: [_buildSubscriptionsSection(), _buildOrdersSection()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionsSection() {
    User? user = _auth.currentUser;
    if (user == null) return Center(child: Text('Please log in'));

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Subscriptions',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          StreamBuilder<DocumentSnapshot>(
            stream: _firestore.collection('users').doc(user.uid).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return CircularProgressIndicator();
              final data = snapshot.data!.data() as Map<String, dynamic>;
              final isActive = data['activeSubscription'] ?? false;
              final startDate =
                  data['subscriptionStartDate'] != null
                      ? (data['subscriptionStartDate'] as Timestamp).toDate()
                      : null;
              final endDate =
                  data['subscriptionEndDate'] != null
                      ? (data['subscriptionEndDate'] as Timestamp).toDate()
                      : null;

              return Card(
                color: isActive ? Colors.green[100] : Colors.red[100],
                child: ListTile(
                  title: Text(
                    '${data['subscriptionPlan'] ?? 'No Plan'} (${data['category'] ?? 'N/A'})',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Start: ${startDate != null ? "${startDate.day}/${startDate.month}/${startDate.year}" : 'N/A'}',
                      ),
                      Text(
                        'End: ${endDate != null ? "${endDate.day}/${endDate.month}/${endDate.year}" : 'N/A'}',
                      ),
                      Text('Status: ${isActive ? 'Active' : 'Inactive'}'),
                    ],
                  ),
                ),
              );
            },
          ),
          if (_currentPage == 0) ...[
            SizedBox(height: 20),
            Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Active Orders',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            StreamBuilder<QuerySnapshot>(
              stream:
                  _firestore
                      .collection('orders')
                      .where('userId', isEqualTo: user.uid)
                      .where('status', isEqualTo: 'Pending Delivery')
                      .orderBy('date')
                      .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return CircularProgressIndicator();
                final orders = snapshot.data!.docs;
                return orders.isEmpty
                    ? Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No active orders'),
                    )
                    : ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: orders.length,
                      itemBuilder: (context, index) {
                        final order = orders[index];
                        return _buildOrderTile(order);
                      },
                    );
              },
            ),
            SizedBox(height: 20),
            Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Completed Orders',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            StreamBuilder<QuerySnapshot>(
              stream:
                  _firestore
                      .collection('orders')
                      .where('userId', isEqualTo: user.uid)
                      .where('status', whereIn: ['Delivered', 'Cancelled'])
                      .orderBy('date', descending: true)
                      .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return CircularProgressIndicator();
                final orders = snapshot.data!.docs;
                return orders.isEmpty
                    ? Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No completed orders'),
                    )
                    : ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: orders.length,
                      itemBuilder: (context, index) {
                        final order = orders[index];
                        return _buildOrderTile(order);
                      },
                    );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrdersSection() {
    User? user = _auth.currentUser;
    if (user == null) return Center(child: Text('Please log in'));

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('users').doc(user.uid).snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData)
          return Center(child: CircularProgressIndicator());
        final userData = userSnapshot.data!.data() as Map<String, dynamic>;
        final isActive = userData['activeSubscription'] ?? false;

        if (!isActive) {
          return Center(child: Text('No active subscription to view orders'));
        }

        return StreamBuilder<QuerySnapshot>(
          stream:
              _firestore
                  .collection('orders')
                  .where('userId', isEqualTo: user.uid)
                  .orderBy('date', descending: true)
                  .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData)
              return Center(child: CircularProgressIndicator());
            List<QueryDocumentSnapshot> docs = snapshot.data!.docs;
            List<QueryDocumentSnapshot> pendingOrders =
                docs
                    .where((doc) => doc['status'] == 'Pending Delivery')
                    .toList();
            List<QueryDocumentSnapshot> otherOrders =
                docs
                    .where((doc) => doc['status'] != 'Pending Delivery')
                    .toList();

            return ListView(
              children: [
                ...pendingOrders.map((doc) => _buildOrderTile(doc)),
                ...otherOrders.map((doc) => _buildOrderTile(doc)),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildOrderTile(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final date = (data['date'] as Timestamp).toDate();
    final status = data['status'];

    return Card(
      color:
          status == 'Pending Delivery'
              ? Colors.yellow[100]
              : status == 'Delivered'
              ? Colors.green[100]
              : Colors.red[100],
      child: ListTile(
        title: Text(
          '${data['mealType']} - ${date.day}/${date.month}/${date.year}',
        ),
        subtitle: Text('Status: $status'),
      ),
    );
  }
}
