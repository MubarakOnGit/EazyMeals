// lib/manager/history_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManagerHistoryScreen extends StatefulWidget {
  @override
  _ManagerHistoryScreenState createState() => _ManagerHistoryScreenState();
}

class _ManagerHistoryScreenState extends State<ManagerHistoryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _selectedUserId;
  String _searchQuery = '';
  String _filterStatus = 'All';
  DateTime? _filterDate;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentDayStart = DateTime(now.year, now.month, now.day, 0, 0);

    return Column(
      children: [
        SizedBox(height: 40),
        Center(
          child: Text(
            'Order History',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(height: 10),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search by name or email',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
          ),
        ),
        SizedBox(height: 10),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  setState(() {
                    _filterDate = picked;
                  });
                },
                child: Text(
                  _filterDate == null
                      ? 'Filter by Date'
                      : '${_filterDate!.day}/${_filterDate!.month}/${_filterDate!.year}',
                ),
              ),
              DropdownButton<String>(
                value: _filterStatus,
                items:
                    ['All', 'Pending', 'Delivered', 'Paused']
                        .map(
                          (status) => DropdownMenuItem(
                            value: status,
                            child: Text(status),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  setState(() {
                    _filterStatus = value!;
                  });
                },
              ),
            ],
          ),
        ),
        SizedBox(height: 10),
        Container(
          height: 100,
          child: StreamBuilder<QuerySnapshot>(
            stream:
                _firestore
                    .collection('users')
                    .where('activeSubscription', isEqualTo: true)
                    .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return CircularProgressIndicator();
              final users =
                  snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = (data['name'] ?? '').toString().toLowerCase();
                    final email =
                        (data['email'] ?? '').toString().toLowerCase();
                    return name.contains(_searchQuery) ||
                        email.contains(_searchQuery);
                  }).toList();

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  final data = user.data() as Map<String, dynamic>;
                  final isSelected = _selectedUserId == user.id;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedUserId = user.id;
                      });
                    },
                    child: Container(
                      width: 120,
                      margin: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Card(
                        color: isSelected ? Colors.blue[100] : Colors.grey[200],
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                data['name'] ?? 'Unknown',
                                style: TextStyle(fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 4),
                              Text(
                                data['email'] ?? 'N/A',
                                style: TextStyle(fontSize: 12),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        SizedBox(height: 10),
        Expanded(
          child:
              _selectedUserId == null
                  ? Center(child: Text('Select a user to view orders'))
                  : StreamBuilder<QuerySnapshot>(
                    stream:
                        _firestore
                            .collection('orders')
                            .where('userId', isEqualTo: _selectedUserId)
                            .orderBy('date')
                            .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return CircularProgressIndicator();
                      var orders = snapshot.data!.docs;

                      // Apply filters
                      if (_filterStatus != 'All') {
                        orders =
                            orders.where((doc) {
                              final status = doc['status'];
                              return _filterStatus == 'Pending'
                                  ? status == 'Pending Delivery'
                                  : _filterStatus == 'Delivered'
                                  ? status == 'Delivered'
                                  : status == 'Paused';
                            }).toList();
                      }
                      if (_filterDate != null) {
                        orders =
                            orders.where((doc) {
                              final date = (doc['date'] as Timestamp).toDate();
                              return date.day == _filterDate!.day &&
                                  date.month == _filterDate!.month &&
                                  date.year == _filterDate!.year;
                            }).toList();
                      }

                      // Group orders by week
                      Map<int, List<QueryDocumentSnapshot>> ordersByWeek = {};
                      for (var order in orders) {
                        final date = (order['date'] as Timestamp).toDate();
                        final weekNumber = date.weekOfYear;
                        ordersByWeek[weekNumber] ??= [];
                        ordersByWeek[weekNumber]!.add(order);
                      }

                      final sortedWeeks =
                          ordersByWeek.keys.toList()..sort((a, b) {
                            final aDate =
                                ordersByWeek[a]![0]['date'] as Timestamp;
                            final bDate =
                                ordersByWeek[b]![0]['date'] as Timestamp;
                            return bDate.compareTo(aDate); // Descending order
                          });

                      return ListView.builder(
                        itemCount: sortedWeeks.length,
                        itemBuilder: (context, weekIndex) {
                          final weekNumber = sortedWeeks[weekIndex];
                          final weekOrders =
                              ordersByWeek[weekNumber]!..sort((a, b) {
                                final aDate = (a['date'] as Timestamp).toDate();
                                final bDate = (b['date'] as Timestamp).toDate();
                                return bDate.compareTo(
                                  aDate,
                                ); // Current day at top
                              });

                          return ExpansionTile(
                            title: Text('Week $weekNumber'),
                            children:
                                weekOrders.map((order) {
                                  final orderData =
                                      order.data() as Map<String, dynamic>;
                                  final date =
                                      (orderData['date'] as Timestamp).toDate();
                                  final status = orderData['status'];
                                  final isCurrentDay =
                                      date.day == now.day &&
                                      date.month == now.month &&
                                      date.year == now.year;

                                  return Card(
                                    color:
                                        status == 'Paused'
                                            ? Colors.red[100]
                                            : status == 'Pending Delivery'
                                            ? Colors.yellow[100]
                                            : status == 'Delivered'
                                            ? Colors.green[100]
                                            : Colors.grey[200],
                                    child: ListTile(
                                      title: Text(
                                        '${orderData['mealType']} - ${date.day}/${date.month}/${date.year}',
                                      ),
                                      subtitle: Text('Status: $status'),
                                      trailing:
                                          status == 'Pending Delivery' &&
                                                  isCurrentDay
                                              ? Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  ElevatedButton(
                                                    onPressed:
                                                        () => _markOrder(
                                                          context,
                                                          order.id,
                                                          'Delivered',
                                                        ),
                                                    style:
                                                        ElevatedButton.styleFrom(
                                                          backgroundColor:
                                                              Colors.green,
                                                        ),
                                                    child: Text('Delivered'),
                                                  ),
                                                  SizedBox(width: 10),
                                                  ElevatedButton(
                                                    onPressed:
                                                        () => _markOrder(
                                                          context,
                                                          order.id,
                                                          'Cancelled',
                                                        ),
                                                    style:
                                                        ElevatedButton.styleFrom(
                                                          backgroundColor:
                                                              Colors.red,
                                                        ),
                                                    child: Text('Cancel'),
                                                  ),
                                                ],
                                              )
                                              : status == 'Paused'
                                              ? Text(
                                                'Paused',
                                                style: TextStyle(
                                                  color: Colors.red,
                                                ),
                                              )
                                              : null,
                                    ),
                                  );
                                }).toList(),
                          );
                        },
                      );
                    },
                  ),
        ),
      ],
    );
  }

  void _markOrder(BuildContext context, String orderId, String status) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Confirm $status'),
            content: Text(
              'Are you sure you want to mark this order as $status?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await FirebaseFirestore.instance
                      .collection('orders')
                      .doc(orderId)
                      .update({'status': status});
                  Navigator.pop(context);
                },
                child: Text('Confirm'),
              ),
            ],
          ),
    );
  }
}

extension DateTimeExtension on DateTime {
  int get weekOfYear {
    final startOfYear = DateTime(year, 1, 1);
    final firstMonday = startOfYear.add(
      Duration(days: (8 - startOfYear.weekday) % 7),
    );
    final weekNumber = (difference(firstMonday).inDays / 7).floor() + 1;
    return weekNumber;
  }
}
