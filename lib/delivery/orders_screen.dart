// lib/delivery/orders_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class DeliveryOrdersScreen extends StatelessWidget {
  final String email;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DeliveryOrdersScreen({required this.email});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day, 0, 0);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                stream:
                    _firestore
                        .collection('delivery_guys')
                        .doc(email)
                        .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }
                  final deliveryData =
                      snapshot.data!.data() as Map<String, dynamic>;
                  final assignedUsers = deliveryData['assignedUsers'] ?? [];

                  if (assignedUsers.isEmpty) {
                    return Center(
                      child: Text(
                        'No orders assigned for today',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    );
                  }

                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Pending Deliveries'),
                        _buildOrdersList(
                          context,
                          assignedUsers,
                          'Pending Delivery',
                          startOfDay,
                          endOfDay,
                        ),
                        _buildSectionTitle('Delivered Today'),
                        _buildOrdersList(
                          context,
                          assignedUsers,
                          'Delivered',
                          startOfDay,
                          endOfDay,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[900]!, Colors.blue[700]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Center(
        child: Text(
          'Today\'s Orders',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.blue[900],
        ),
      ),
    );
  }

  Widget _buildOrdersList(
    BuildContext context,
    List<dynamic> assignedUsers,
    String status,
    DateTime startOfDay,
    DateTime endOfDay,
  ) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          _firestore
              .collection('orders')
              .where('userId', whereIn: assignedUsers)
              .where('status', isEqualTo: status)
              .where(
                'date',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
              )
              .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
              .orderBy('date')
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }
        final orders = snapshot.data!.docs;

        if (orders.isEmpty) {
          return Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'No $status orders',
              style: TextStyle(color: Colors.grey[600]),
            ),
          );
        }

        return Column(
          children:
              orders.map((order) => _buildOrderCard(context, order)).toList(),
        );
      },
    );
  }

  Widget _buildOrderCard(BuildContext context, QueryDocumentSnapshot order) {
    final orderData = order.data() as Map<String, dynamic>;
    final date = (orderData['date'] as Timestamp).toDate();

    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('users').doc(orderData['userId']).get(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return _buildLoadingCard();
        }

        final userData = userSnapshot.data!.data() as Map<String, dynamic>;

        return FutureBuilder<QuerySnapshot>(
          future:
              _firestore
                  .collection('users')
                  .doc(orderData['userId'])
                  .collection('addresses')
                  .where('isActive', isEqualTo: true)
                  .limit(1)
                  .get(),
          builder: (context, addressSnapshot) {
            if (!addressSnapshot.hasData) {
              return _buildLoadingCard();
            }

            if (addressSnapshot.data!.docs.isEmpty) {
              return _buildErrorCard('No active address');
            }

            final addressData =
                addressSnapshot.data!.docs.first.data() as Map<String, dynamic>;

            return Card(
              elevation: 4,
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ExpansionTile(
                leading: Icon(
                  orderData['status'] == 'Delivered'
                      ? Icons.check_circle
                      : Icons.delivery_dining,
                  color:
                      orderData['status'] == 'Delivered'
                          ? Colors.green
                          : Colors.blue[900],
                ),
                title: Text(
                  userData['name'] ?? 'Unknown',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
                subtitle: Text(
                  'Time: ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                children: [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(
                          Icons.fastfood,
                          'Meal',
                          orderData['mealType'],
                        ),
                        _buildInfoRow(
                          Icons.category,
                          'Category',
                          orderData['category'] ?? 'N/A',
                        ),
                        _buildInfoRow(
                          Icons.location_on,
                          'Address',
                          addressData['location']['address'],
                        ),
                        _buildInfoRow(
                          Icons.phone,
                          'Phone',
                          addressData['phoneNumber'],
                        ),
                        _buildInfoRow(
                          Icons.apartment,
                          'Building',
                          addressData['buildingName'],
                        ),
                        _buildInfoRow(
                          Icons.door_sliding,
                          'Door',
                          addressData['doorNumber'],
                        ),
                        _buildInfoRow(
                          Icons.stairs,
                          'Floor',
                          addressData['floorNumber'],
                        ),
                        if (addressData['additionalInfo'] != null)
                          _buildInfoRow(
                            Icons.info,
                            'Additional',
                            addressData['additionalInfo'],
                          ),
                        SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _openGoogleMaps(addressData),
                              icon: Icon(Icons.map),
                              label: Text('Route to Entrance'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[700],
                                foregroundColor: Colors.white,
                              ),
                            ),
                            if (orderData['status'] != 'Delivered')
                              ElevatedButton.icon(
                                onPressed:
                                    () => _confirmDelivery(context, order.id),
                                icon: Icon(Icons.check),
                                label: Text('Mark Delivered'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                          ],
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
  }

  Widget _buildLoadingCard() {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(message, style: TextStyle(color: Colors.red)),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue[900]),
          SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.grey[800])),
          ),
        ],
      ),
    );
  }

  void _confirmDelivery(BuildContext context, String orderId) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Confirm Delivery'),
            content: Text(
              'Are you sure you want to mark this order as delivered?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  _markDelivered(context, orderId);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: Text('Confirm'),
              ),
            ],
          ),
    );
  }

  void _markDelivered(BuildContext context, String orderId) async {
    await _firestore.collection('orders').doc(orderId).update({
      'status': 'Delivered',
      'deliveredTime': Timestamp.now(),
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Order marked as Delivered'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _openGoogleMaps(Map<String, dynamic> addressData) async {
    final entranceLat = addressData['entranceLatitude'] as double;
    final entranceLng = addressData['entranceLongitude'] as double;

    final url =
        'https://www.google.com/maps/dir/?api=1&destination=$entranceLat,$entranceLng';

    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch Google Maps';
    }
  }
}
