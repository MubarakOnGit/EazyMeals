// lib/delivery/history_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DeliveryHistoryScreen extends StatelessWidget {
  final String email;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DeliveryHistoryScreen({required this.email});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 40),
        Center(
          child: Text(
            'History',
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
                return Center(child: Text('No history available'));
              }

              return StreamBuilder<QuerySnapshot>(
                stream:
                    _firestore
                        .collection('orders')
                        .where('userId', whereIn: assignedUsers)
                        .where('status', whereIn: ['Delivered', 'Cancelled'])
                        .orderBy('date', descending: true)
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
                      final status = orderData['status'];

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
                            color:
                                status == 'Delivered'
                                    ? Colors.green[100]
                                    : Colors.red[100],
                            child: ListTile(
                              title: Text(userData['name'] ?? 'Unknown'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Meal: ${orderData['mealType']}'),
                                  Text(
                                    'Date: ${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                                  ),
                                  Text('Status: $status'),
                                ],
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
}
