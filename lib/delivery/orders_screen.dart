import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/location_details.dart'; // Adjust path based on your project structure

class DeliveryOrdersScreen extends StatefulWidget {
  final String email;

  const DeliveryOrdersScreen({required this.email, Key? key}) : super(key: key);

  @override
  _DeliveryOrdersScreenState createState() => _DeliveryOrdersScreenState();
}

class _DeliveryOrdersScreenState extends State<DeliveryOrdersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, bool> _expandedOrders = {};
  bool _isNavigating = false;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day, 0, 0);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return Scaffold(
      appBar: AppBar(title: const Text('Delivery Orders')),
      body: Column(
        children: [
          const SizedBox(height: 40),
          const Center(
            child: Text(
              'Orders (Today)',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream:
                  _firestore
                      .collection('delivery_guys')
                      .doc(widget.email)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.data!.exists) {
                  return const Center(child: Text('No delivery profile found'));
                }

                final deliveryData =
                    snapshot.data!.data() as Map<String, dynamic>?;
                final assignedUsers =
                    deliveryData?['assignedUsers'] as List<dynamic>? ?? [];

                if (assignedUsers.isEmpty) {
                  return const Center(
                    child: Text('No users assigned to you today'),
                  );
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
                    if (orderSnapshot.hasError) {
                      return Center(
                        child: Text('Error: ${orderSnapshot.error}'),
                      );
                    }
                    if (!orderSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final orders = orderSnapshot.data!.docs;

                    if (orders.isEmpty) {
                      return const Center(
                        child: Text('No pending orders for today'),
                      );
                    }

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
                            if (userSnapshot.hasError) {
                              return ListTile(
                                title: Text('Error: ${userSnapshot.error}'),
                              );
                            }
                            if (!userSnapshot.hasData) {
                              return const ListTile(title: Text('Loading...'));
                            }
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
                            final deliveryLocation =
                                activeAddress.isNotEmpty
                                    ? LocationDetails.fromMap(activeAddress)
                                    : LocationDetails(
                                      latitude: 0,
                                      longitude: 0,
                                      address: 'No address available',
                                      street: '',
                                      city: '',
                                      country: '',
                                    );

                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 16,
                              ),
                              child: Column(
                                children: [
                                  ListTile(
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
                                    trailing: IconButton(
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
                                  ),
                                  if (isExpanded)
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Address: ${deliveryLocation.toString()}',
                                          ),
                                          if (activeAddress.isEmpty)
                                            const Text(
                                              'No active address set',
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                          Text(
                                            'Lat: ${deliveryLocation.latitude}, Lng: ${deliveryLocation.longitude}',
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            children: [
                                              ElevatedButton(
                                                onPressed:
                                                    () => _confirmDelivery(
                                                      context,
                                                      orderId,
                                                    ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.green,
                                                ),
                                                child: const Text('Delivered'),
                                              ),
                                              const SizedBox(width: 8),
                                              ElevatedButton(
                                                onPressed:
                                                    activeAddress.isNotEmpty
                                                        ? () => _openGoogleMaps(
                                                          deliveryLocation
                                                              .latitude,
                                                          deliveryLocation
                                                              .longitude,
                                                        )
                                                        : null,
                                                child:
                                                    _isNavigating
                                                        ? const CircularProgressIndicator(
                                                          color: Colors.white,
                                                        )
                                                        : const Text('Map'),
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
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelivery(BuildContext context, String orderId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delivery'),
          content: const Text(
            'Are you sure you want to mark this order as delivered?',
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Confirm'),
              onPressed: () {
                _markDelivered(context, orderId);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _markDelivered(BuildContext context, String orderId) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'status': 'Delivered',
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order marked as Delivered')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to mark as delivered: $e')),
      );
    }
  }

  Future<void> _openGoogleMaps(double latitude, double longitude) async {
    setState(() => _isNavigating = true);
    final url =
        'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude';
    try {
      if (await canLaunch(url)) {
        await launch(url);
      } else {
        throw 'Could not launch URL';
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to open Google Maps: $e')));
    } finally {
      setState(() => _isNavigating = false);
    }
  }
}

// Assuming this is your LocationDetails model (adjust as needed)
class LocationDetails {
  final double latitude;
  final double longitude;
  final String address;
  final String street;
  final String city;
  final String country;

  LocationDetails({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.street,
    required this.city,
    required this.country,
  });

  factory LocationDetails.fromMap(Map<String, dynamic> map) {
    return LocationDetails(
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      address: map['address'] as String? ?? '',
      street: map['street'] as String? ?? '',
      city: map['city'] as String? ?? '',
      country: map['country'] as String? ?? '',
    );
  }

  @override
  String toString() => address;

  @override
  bool operator ==(Object other) =>
      other is LocationDetails &&
      latitude == other.latitude &&
      longitude == other.longitude &&
      address == other.address &&
      street == other.street &&
      city == other.city &&
      country == other.country;

  @override
  int get hashCode =>
      Object.hash(latitude, longitude, address, street, city, country);
}
