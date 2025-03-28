import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:get/get.dart';
import '../controllers/order_status_controller.dart';
import '../screens/subscription_screen.dart';
import 'base_state.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends BaseState<HistoryScreen> {
  final OrderController orderController = Get.find<OrderController>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _isDataMissing = false;
  final Map<String, bool> _expandedCards = {};

  @override
  void initState() {
    super.initState();
    _scheduleOrderCancellation();
    _checkUserData();
  }

  @override
  void onOrderUpdate(QuerySnapshot snapshot) {
    if (mounted) {
      setState(() {
        // Update UI based on order changes
      });
    }
  }

  void _scheduleOrderCancellation() {
    final now = DateTime.now();
    var next12PM = DateTime(now.year, now.month, now.day, 12, 0);
    if (now.isAfter(next12PM)) next12PM = next12PM.add(const Duration(days: 1));
    final duration = next12PM.difference(now);

    Timer(duration, () async {
      await _cancelPendingOrders();
      if (mounted) _scheduleOrderCancellation();
    });
  }

  Future<void> _cancelPendingOrders() async {
    final user = currentUser;
    if (user != null) {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day, 0, 0);
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final userDoc = await firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};
      final subscriptionId = userData['subscriptionId'] as String? ?? '';

      final orders =
          await firestore
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

      final batch = firestore.batch();
      for (var doc in orders.docs) {
        batch.update(doc.reference, {'status': 'Cancelled'});
      }
      await batch.commit();
    }
  }

  Future<void> _checkUserData() async {
    final user = currentUser;
    if (user != null) {
      final userDoc = await firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};
      final name = userData['name'] as String?;
      final phone = userData['phone'] as String?;

      if (mounted) {
        setState(
          () =>
              _isDataMissing =
                  name == null ||
                  phone == null ||
                  name.isEmpty ||
                  phone.isEmpty,
        );
      }
    }
  }

  Future<void> _saveUserData() async {
    final user = currentUser;
    if (user != null) {
      if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please fill in all fields')),
          );
        }
        return;
      }

      await firestore.collection('users').doc(user.uid).set({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
      }, SetOptions(merge: true));

      if (mounted) setState(() => _isDataMissing = false);
    }
  }

  Future<void> _cancelPendingSubscription(String userId, String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirm Cancellation'),
            content: const Text(
              'Are you sure you want to cancel this pending subscription?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Yes'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      await firestore
          .collection('users')
          .doc(userId)
          .collection('pendingOrders')
          .doc(docId)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pending subscription cancelled successfully'),
          ),
        );
      }
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

  String _formatRemainingDays(int seconds) =>
      '${(seconds ~/ (24 * 3600))} days';

  @override
  Widget build(BuildContext context) {
    final user = currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.blue[900]!.withAlpha(26), Colors.grey[100]!],
              ),
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      'Your Plans',
                      style: TextStyle(
                        color: Colors.blue[900],
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
                                firestore
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
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSubscriptionSection(
                                      'Pending Plans',
                                      _buildPendingSubscriptions(user.uid),
                                      Colors.orange,
                                    ),
                                    const SizedBox(height: 24),
                                    _buildSubscriptionSection(
                                      'Active Plan',
                                      _buildActiveSubscription(
                                        userData,
                                        user.uid,
                                      ),
                                      Colors.green,
                                    ),
                                    const SizedBox(height: 24),
                                    _buildSubscriptionSection(
                                      'Past Plans',
                                      _buildEndedSubscriptions(user.uid),
                                      Colors.red,
                                    ),
                                    const SizedBox(height: 80),
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
                label: const Text(
                  'New Plan',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                icon: const Icon(Icons.add, color: Colors.white),
                backgroundColor: Colors.blue[900],
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
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Row(
            children: [
              Container(width: 4, height: 24, color: accentColor),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.blue[900],
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
          firestore
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
                      const Icon(
                        Icons.pending_actions,
                        color: Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
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
                      Colors.grey[700]!,
                    ),
                    _buildDetailRow(
                      Icons.calendar_today,
                      'Requested: ${_formatDate(createdAt)}',
                      Colors.grey[700]!,
                    ),
                    _buildDetailRow(
                      Icons.attach_money,
                      '\$${data['amount']}',
                      Colors.grey[700]!,
                    ),
                  ],
                  action: IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.redAccent),
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
        colors: [Colors.blue[900]!, Colors.blue[700]!],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      header: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.subscriptions, color: Colors.green, size: 20),
          const SizedBox(width: 8),
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
          firestore
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
                    colors: [Colors.grey[800]!, Colors.grey[700]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  header: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.history, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
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
        gradient == null ? Colors.blue[900]! : Colors.white;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? Colors.white : null,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      header,
                      const SizedBox(height: 12),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: effectiveTextColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color:
                              gradient == null
                                  ? Colors.grey[700]
                                  : Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 12),
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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: const BorderRadius.vertical(
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: textColor),
          const SizedBox(width: 8),
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
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day, 0, 0);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Today's Orders",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.blue[900],
          ),
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream:
              firestore
                  .collection('orders')
                  .where('userId', isEqualTo: userId)
                  .where('subscriptionId', isEqualTo: subscriptionId)
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
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              );
            }
            final orders = snapshot.data!.docs;
            if (orders.isEmpty) {
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.grey.withAlpha(26), blurRadius: 6),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No orders for today',
                          style: TextStyle(
                            color: Colors.blue[900],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _formatDate(DateTime.now()),
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'No Order',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }
            return Column(
              children:
                  orders.map((doc) {
                    final order = doc.data() as Map<String, dynamic>;
                    final status = order['status'] as String;
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withAlpha(26),
                            blurRadius: 6,
                          ),
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
                                  color: Colors.blue[900],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                _formatDate(DateTime.now()),
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 12,
                                ),
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
                  }).toList(),
            );
          },
        ),
        const SizedBox(height: 12),
        Text(
          'Past Orders',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.blue[900],
          ),
        ),
        const SizedBox(height: 8),
        _buildOrderStream(userId, subscriptionId, const [
          'Delivered',
          'Cancelled',
          'Paused',
        ], true),
        const SizedBox(height: 12),
        Text(
          'Upcoming Orders',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.blue[900],
          ),
        ),
        const SizedBox(height: 8),
        _buildOrderStream(userId, subscriptionId, const [
          'Pending Delivery',
        ], false),
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
          firestore
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
            style: TextStyle(color: Colors.grey[700]),
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
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.withAlpha(26), blurRadius: 6)],
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
                  color: Colors.blue[900],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                _formatDate(date ?? DateTime.now()),
                style: TextStyle(color: Colors.grey[700], fontSize: 12),
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
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(51), blurRadius: 10),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              "Let's Get Started",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Your Name',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Icon(Icons.person, color: Colors.grey[700]),
              ),
              style: const TextStyle(color: Colors.black),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Icon(Icons.phone, color: Colors.grey[700]),
              ),
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.black),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveUserData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[900],
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              child: const Text(
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
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Text(
          message,
          style: TextStyle(
            color: Colors.grey[700],
            fontSize: 16,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Text(message, style: const TextStyle(color: Colors.redAccent)),
      ),
    );
  }

  Widget _buildLoading() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(child: CircularProgressIndicator(color: Colors.blue[900])),
    );
  }

  Color _getStatusColor(String status) {
    return switch (status) {
      'Pending Delivery' => Colors.yellow[800]!,
      'Delivered' => Colors.green,
      'Cancelled' => Colors.red,
      'Ended' => Colors.red,
      'Paused' => Colors.orange,
      'No Order' => Colors.grey,
      _ => Colors.grey,
    };
  }
}
