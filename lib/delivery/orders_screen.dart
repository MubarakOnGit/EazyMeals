// lib/delivery/orders_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DeliveryOrdersScreen extends StatelessWidget {
  final String email;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DeliveryOrdersScreen({required this.email});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day, 0, 0);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return Column(
      children: [
        SizedBox(height: 40),
        Center(
          child: Text(
            'Orders (Today)',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(height: 20),
        Expanded(
          child: StreamBuilder<DocumentSnapshot>(
            stream:
                _firestore.collection('delivery_guys').doc(email).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return CircularProgressIndicator();
              final deliveryData =
                  snapshot.data!.data() as Map<String, dynamic>;
              final assignedUsers = deliveryData['assignedUsers'] ?? [];

              if (assignedUsers.isEmpty) {
                return Center(child: Text('No orders assigned for today'));
              }

              return StreamBuilder<QuerySnapshot>(
                stream:
                    _firestore
                        .collection('orders')
                        .where('userId', whereIn: assignedUsers)
                        .where('status', isEqualTo: 'Pending Delivery')
                        .where(
                          'date',
                          isGreaterThanOrEqualTo: Timestamp.fromDate(
                            startOfDay,
                          ),
                        )
                        .where(
                          'date',
                          isLessThanOrEqualTo: Timestamp.fromDate(endOfDay),
                        )
                        .orderBy('date')
                        .snapshots(),
                builder: (context, orderSnapshot) {
                  if (!orderSnapshot.hasData)
                    return CircularProgressIndicator();
                  final orders = orderSnapshot.data!.docs;

                  return ListView.builder(
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      final orderData = order.data() as Map<String, dynamic>;
                      final date = (orderData['date'] as Timestamp).toDate();

                      return FutureBuilder<DocumentSnapshot>(
                        future:
                            _firestore
                                .collection('users')
                                .doc(orderData['userId'])
                                .get(),
                        builder: (context, userSnapshot) {
                          if (!userSnapshot.hasData)
                            return ListTile(title: Text('Loading...'));
                          final userData =
                              userSnapshot.data!.data() as Map<String, dynamic>;

                          return Card(
                            child: ListTile(
                              title: Text(userData['name'] ?? 'Unknown'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Location: ${userData['activeAddress'] ?? 'N/A'}',
                                  ),
                                  Text(
                                    'Category: ${orderData['category'] ?? 'N/A'}',
                                  ),
                                  Text('Meal: ${orderData['mealType']}'),
                                  Text(
                                    'Time: ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                                  ),
                                ],
                              ),
                              trailing: ElevatedButton(
                                onPressed:
                                    () => _markDelivered(context, order.id),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                                child: Text('Delivered'),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _markDelivered(BuildContext context, String orderId) async {
    await _firestore.collection('orders').doc(orderId).update({
      'status': 'Delivered',
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Order marked as Delivered')));
  }
}
