import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:get/get.dart';
import '../controllers/order_status_controller.dart';
import '../screens/subscription_screen.dart';

class HistoryScreen extends StatefulWidget {
  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final OrderController orderController = Get.find<OrderController>();
  bool _isDataMissing = false;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  Map<String, bool> _expandedCards = {};

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
              'Are you sure you want to cancel this pending subscription?',
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

  String _formatRemainingDays(int seconds) {
    final days = (seconds ~/ (24 * 3600)).toString();
    return '$days days';
  }

  @override
  Widget build(BuildContext context) {
    User? user = _auth.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.blue.shade900.withOpacity(0.1),
                  Colors.grey[100]!,
                ],
              ),
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              physics: BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      'Your Journey',
                      style: TextStyle(
                        color: Colors.blue.shade900,
                        fontWeight: FontWeight.w700,
                        fontSize: 24,
                      ),
                    ),
                    centerTitle: true,
                  ),
                ),
                SliverToBoxAdapter(
                  child:
                      user == null
                          ? _buildEmptyState('Please log in')
                          : _isDataMissing
                          ? _buildDataInputCard()
                          : StreamBuilder<DocumentSnapshot>(
                            stream:
                                _firestore
                                    .collection('users')
                                    .doc(user.uid)
                                    .snapshots(),
                            builder: (context, userSnapshot) {
                              if (!userSnapshot.hasData) return _buildLoading();
                              if (userSnapshot.hasError)
                                return _buildError('Error loading data');
                              final userData =
                                  userSnapshot.data!.data()
                                      as Map<String, dynamic>? ??
                                  {};
                              return Padding(
                                padding: EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSubscriptionSection(
                                      'Pending Plans',
                                      _buildPendingSubscriptions(user.uid),
                                      Colors.orange,
                                    ),
                                    SizedBox(height: 24),
                                    _buildSubscriptionSection(
                                      'Active Plan',
                                      _buildActiveSubscription(
                                        userData,
                                        user.uid,
                                      ),
                                      Colors.green,
                                    ),
                                    SizedBox(height: 24),
                                    _buildSubscriptionSection(
                                      'Past Plans',
                                      _buildEndedSubscriptions(user.uid),
                                      Colors.red,
                                    ),
                                    SizedBox(height: 80),
                                  ],
                                ),
                              );
                            },
                          ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton.extended(
                onPressed:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SubscriptionScreen(),
                      ),
                    ).then((_) => setState(() {})),
                label: Text(
                  'New Plan',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                icon: Icon(Icons.add, color: Colors.white),
                backgroundColor: Colors.blue.shade900,
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionSection(
    String title,
    Widget content,
    Color accentColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 8, bottom: 12),
          child: Row(
            children: [
              Container(width: 4, height: 24, color: accentColor),
              SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.blue.shade900,
                ),
              ),
            ],
          ),
        ),
        content,
      ],
    );
  }

  Widget _buildPendingSubscriptions(String userId) {
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
        if (!snapshot.hasData) return _buildLoading();
        if (snapshot.hasError)
          return _buildError('Error loading pending plans');
        final pendingSubscriptions = snapshot.data!.docs;
        if (pendingSubscriptions.isEmpty)
          return _buildEmptyState('No pending plans yet');

        return Column(
          children:
              pendingSubscriptions.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                final orderId = data['orderId'] as String? ?? 'Unknown';

                return _buildCard(
                  gradient: null,
                  header: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.pending_actions,
                        color: Colors.orange,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Pending',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  title: '${data['subscriptionPlan']} (${data['category']})',
                  subtitle: data['mealType'],
                  details: [
                    _buildDetailRow(
                      Icons.fingerprint,
                      'ID: $orderId',
                      Colors.grey.shade700,
                    ),
                    _buildDetailRow(
                      Icons.calendar_today,
                      'Requested: ${_formatDate(createdAt)}',
                      Colors.grey.shade700,
                    ),
                    _buildDetailRow(
                      Icons.attach_money,
                      '\$${data['amount']}',
                      Colors.grey.shade700,
                    ),
                  ],
                  action: IconButton(
                    icon: Icon(Icons.cancel, color: Colors.redAccent),
                    onPressed: () => _cancelPendingSubscription(userId, doc.id),
                  ),
                );
              }).toList(),
        );
      },
    );
  }

  Widget _buildActiveSubscription(
    Map<String, dynamic> userData,
    String userId,
  ) {
    final isActive = userData['activeSubscription'] as bool? ?? false;
    if (!isActive ||
        !userData.containsKey('subscriptionPlan') ||
        !userData.containsKey('subscriptionId')) {
      return _buildEmptyState('No active plan');
    }

    final startDate =
        (userData['subscriptionStartDate'] as Timestamp?)?.toDate();
    final endDate = (userData['subscriptionEndDate'] as Timestamp?)?.toDate();
    final subscriptionId = userData['subscriptionId'] as String? ?? '';
    final isPaused = userData['isPaused'] as bool? ?? false;
    final remainingSeconds =
        endDate != null ? endDate.difference(DateTime.now()).inSeconds : 0;

    return _buildCard(
      gradient: LinearGradient(
        colors: [Colors.blue.shade900, Colors.blue.shade700],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      header: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.subscriptions, color: Colors.green, size: 20),
          SizedBox(width: 8),
          Text(
            'Active',
            style: TextStyle(
              color: Colors.green,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      title: '${userData['subscriptionPlan']} (${userData['category']})',
      subtitle: userData['mealType'],
      details: [
        _buildDetailRow(
          Icons.play_circle_outline,
          'Start: ${_formatDate(startDate)}',
          Colors.white70,
        ),
        _buildDetailRow(
          Icons.stop_circle_outlined,
          'End: ${_formatDate(endDate)}',
          Colors.white70,
        ),
        _buildDetailRow(
          Icons.hourglass_empty,
          'Remaining: ${remainingSeconds > 0 ? _formatRemainingDays(remainingSeconds) : 'Expired'}',
          Colors.white70,
        ),
        _buildDetailRow(
          isPaused ? Icons.pause_circle_outline : Icons.play_circle_filled,
          'Status: ${isPaused ? 'Paused' : 'Ongoing'}',
          isPaused ? Colors.red : Colors.green,
        ),
      ],
      expandableContent: _buildOrderDetails(userId, subscriptionId),
      isExpandable: true,
      cardKey: subscriptionId,
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
        if (!snapshot.hasData) return _buildLoading();
        if (snapshot.hasError) return _buildError('Error loading past plans');
        if (snapshot.data!.docs.isEmpty)
          return _buildEmptyState('No past plans');

        return Column(
          children:
              snapshot.data!.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final startDate =
                    (data['subscriptionStartDate'] as Timestamp?)?.toDate();
                final endDate =
                    (data['subscriptionEndDate'] as Timestamp?)?.toDate();
                final subscriptionId = data['subscriptionId'] as String? ?? '';

                return _buildCard(
                  gradient: LinearGradient(
                    colors: [Colors.grey.shade800, Colors.grey.shade700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  header: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Ended',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  title: '${data['subscriptionPlan']} (${data['category']})',
                  subtitle: data['mealType'],
                  details: [
                    _buildDetailRow(
                      Icons.fingerprint,
                      'ID: $subscriptionId',
                      Colors.white70,
                    ),
                    _buildDetailRow(
                      Icons.calendar_today,
                      'Valid: ${_formatDate(startDate)} - ${_formatDate(endDate)}',
                      Colors.white70,
                    ),
                    _buildDetailRow(
                      Icons.cancel,
                      'Status: Cancelled',
                      Colors.red,
                    ),
                  ],
                );
              }).toList(),
        );
      },
    );
  }

  Widget _buildCard({
    Gradient? gradient,
    required Widget header,
    required String title,
    required String subtitle,
    required List<Widget> details,
    Widget? action,
    Widget? expandableContent,
    bool isExpandable = false,
    String? cardKey,
  }) {
    final isExpanded = _expandedCards[cardKey] ?? false;
    final effectiveTextColor =
        gradient == null ? Colors.blue.shade900 : Colors.white;

    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      margin: EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? Colors.white : null,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      header,
                      SizedBox(height: 12),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: effectiveTextColor,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color:
                              gradient == null
                                  ? Colors.grey.shade700
                                  : Colors.white70,
                        ),
                      ),
                      SizedBox(height: 12),
                      ...details,
                    ],
                  ),
                ),
                if (action != null) action,
                if (isExpandable)
                  IconButton(
                    icon: Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: effectiveTextColor,
                    ),
                    onPressed:
                        () => setState(
                          () => _expandedCards[cardKey!] = !isExpanded,
                        ),
                  ),
              ],
            ),
          ),
          if (isExpanded && expandableContent != null)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
              ),
              child: expandableContent,
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text, Color textColor) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: textColor),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDetails(String userId, String subscriptionId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today’s Order',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.blue.shade900,
          ),
        ),
        SizedBox(height: 8),
        Obx(
          () => Container(
            margin: EdgeInsets.symmetric(vertical: 4),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 6),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      orderController.todayOrderStatus.value == 'No Order'
                          ? 'No order for today'
                          : 'Today\'s Meal', // Placeholder; fetch mealType if needed
                      style: TextStyle(
                        color: Colors.blue.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _formatDate(DateTime.now()),
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Text(
                  orderController.todayOrderStatus.value,
                  style: TextStyle(
                    color: _getStatusColor(
                      orderController.todayOrderStatus.value,
                    ),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 12),
        Text(
          'Past Orders',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.blue.shade900,
          ),
        ),
        SizedBox(height: 8),
        _buildOrderStream(userId, subscriptionId, [
          'Delivered',
          'Cancelled',
          'Paused',
        ], true),
        SizedBox(height: 12),
        Text(
          'Upcoming Orders',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.blue.shade900,
          ),
        ),
        SizedBox(height: 8),
        _buildOrderStream(userId, subscriptionId, ['Pending Delivery'], false),
      ],
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
            style: TextStyle(color: Colors.grey.shade700),
          );
        }
        return Column(
          children:
              snapshot.data!.docs.map((doc) {
                final order = doc.data() as Map<String, dynamic>;
                final status = order['status'];
                return _buildOrderTile(order, status);
              }).toList(),
        );
      },
    );
  }

  Widget _buildOrderTile(Map<String, dynamic> order, String status) {
    final date = (order['date'] as Timestamp?)?.toDate();
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 6),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order['mealType'] ?? 'Unknown Meal',
                style: TextStyle(
                  color: Colors.blue.shade900,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                _formatDate(date ?? DateTime.now()),
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
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

  Widget _buildDataInputCard() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade800,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10),
          ],
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Let’s Get Started',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Your Name',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Icon(Icons.person, color: Colors.grey.shade700),
              ),
              style: TextStyle(color: Colors.black),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Icon(Icons.phone, color: Colors.grey.shade700),
              ),
              keyboardType: TextInputType.phone,
              style: TextStyle(color: Colors.black),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveUserData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade900,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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
    );
  }

  Widget _buildEmptyState(String message) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: Text(
          message,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 16,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: Text(message, style: TextStyle(color: Colors.redAccent)),
      ),
    );
  }

  Widget _buildLoading() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: CircularProgressIndicator(color: Colors.blue.shade900),
      ),
    );
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
