import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'delivery_map_screen.dart';
import '../models/location_details.dart';

class DeliveryOrdersScreen extends StatefulWidget {
  final String email;

  DeliveryOrdersScreen({required this.email});

  @override
  _DeliveryOrdersScreenState createState() => _DeliveryOrdersScreenState();
}

class _DeliveryOrdersScreenState extends State<DeliveryOrdersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, bool> _expandedOrders = {};

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
                _firestore
                    .collection('delivery_guys')
                    .doc(widget.email)
                    .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return Center(child: CircularProgressIndicator());
              if (!snapshot.data!.exists)
                return Center(child: Text('No delivery profile found'));

              final deliveryData =
                  snapshot.data!.data() as Map<String, dynamic>?;
              final assignedUsers =
                  deliveryData?['assignedUsers'] as List<dynamic>? ?? [];

              if (assignedUsers.isEmpty)
                return Center(child: Text('No users assigned to you today'));

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
                    return Center(child: CircularProgressIndicator());
                  final orders = orderSnapshot.data!.docs;

                  if (orders.isEmpty)
                    return Center(child: Text('No pending orders for today'));

                  return ListView.builder(
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      final orderData = order.data() as Map<String, dynamic>;
                      final date = (orderData['date'] as Timestamp).toDate();
                      final orderId = order.id;
                      final isExpanded = _expandedOrders[orderId] ?? false;

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
                              userSnapshot.data!.data()
                                  as Map<String, dynamic>? ??
                              {};
                          final name = userData['name'] ?? 'Unknown';
                          final phone = userData['phone'] ?? 'N/A';
                          final activeAddress =
                              userData['activeAddress']
                                  as Map<String, dynamic>? ??
                              {};

                          LocationDetails deliveryLocation =
                              LocationDetails.fromMap(activeAddress);

                          return Card(
                            child: Column(
                              children: [
                                ListTile(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => DeliveryMapScreen(
                                              deliveryLocation:
                                                  deliveryLocation,
                                              customerName: name,
                                            ),
                                      ),
                                    );
                                  },
                                  title: Text(name),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Phone: $phone'),
                                      Text(
                                        'Category: ${orderData['category'] ?? 'N/A'}',
                                      ),
                                      Text('Meal: ${orderData['mealType']}'),
                                      Text(
                                        'Time: ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                                      ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          isExpanded
                                              ? Icons.arrow_drop_up
                                              : Icons.arrow_drop_down,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _expandedOrders[orderId] =
                                                !isExpanded;
                                          });
                                        },
                                      ),
                                      ElevatedButton(
                                        onPressed:
                                            () => _markDelivered(
                                              context,
                                              orderId,
                                            ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                        ),
                                        child: Text('Delivered'),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isExpanded)
                                  Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Address: ${deliveryLocation.toString()}',
                                        ),
                                        Text(
                                          'Lat: ${deliveryLocation.latitude}, Lng: ${deliveryLocation.longitude}',
                                        ),
                                        ElevatedButton(
                                          onPressed: () {
                                            final addressText =
                                                'Address: ${deliveryLocation.toString()}\nLat: ${deliveryLocation.latitude}, Lng: ${deliveryLocation.longitude}';
                                            Clipboard.setData(
                                              ClipboardData(text: addressText),
                                            );
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Address details copied',
                                                ),
                                              ),
                                            );
                                          },
                                          child: Text('Copy Address'),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
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
