import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/location_details.dart'; // Adjust path to your model file

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
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Today’s Deliveries',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream:
            _firestore
                .collection('delivery_guys')
                .doc(widget.email)
                .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.data!.exists) {
            return const Center(child: Text('No delivery profile found'));
          }

          final deliveryData = snapshot.data!.data() as Map<String, dynamic>?;
          final assignedOrders = List<String>.from(
            deliveryData?['assignedOrders'] ?? [],
          );

          if (assignedOrders.isEmpty) {
            return const Center(child: Text('No orders assigned to you today'));
          }

          return StreamBuilder<QuerySnapshot>(
            stream:
                _firestore
                    .collection('orders')
                    .where(FieldPath.documentId, whereIn: assignedOrders)
                    .where('status', isEqualTo: 'Pending Delivery')
                    .where(
                      'date',
                      isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
                    )
                    .where(
                      'date',
                      isLessThanOrEqualTo: Timestamp.fromDate(endOfDay),
                    )
                    .orderBy('date')
                    .snapshots(),
            builder: (context, orderSnapshot) {
              if (!orderSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final orders = orderSnapshot.data!.docs;

              if (orders.isEmpty) {
                return const Center(
                  child: Text('No pending deliveries for today'),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];
                  final orderData = order.data() as Map<String, dynamic>;
                  final orderId = order.id;
                  final isExpanded = _expandedOrders[orderId] ?? false;

                  return FutureBuilder<DocumentSnapshot>(
                    future:
                        _firestore
                            .collection('users')
                            .doc(orderData['userId'])
                            .get(),
                    builder: (context, userSnapshot) {
                      if (!userSnapshot.hasData) {
                        return const SizedBox(
                          height: 80,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final userData =
                          userSnapshot.data!.data() as Map<String, dynamic>? ??
                          {};
                      final customerName =
                          userData['name'] ?? 'Unknown Customer';
                      final phone = userData['phone'] ?? 'N/A';
                      final activeAddress =
                          userData['activeAddress'] as Map<String, dynamic>? ??
                          {};
                      final enhancedLocation =
                          activeAddress.isNotEmpty
                              ? EnhancedLocationDetails.fromMap(activeAddress)
                              : EnhancedLocationDetails(
                                location: LocationDetails(
                                  latitude: 0,
                                  longitude: 0,
                                  address: 'No address available',
                                  street: '',
                                  city: '',
                                  country: '',
                                ),
                                addressType: 'N/A',
                                buildingName: '',
                                floorNumber: '',
                                doorNumber: '',
                                phoneNumber: phone,
                                entranceLatitude: 0,
                                entranceLongitude: 0,
                              );

                      return _buildOrderCard(
                        orderId: orderId,
                        mealType: orderData['mealType'] ?? 'Unknown Meal',
                        customerName: customerName,
                        date: (orderData['date'] as Timestamp).toDate(),
                        enhancedLocation: enhancedLocation,
                        isExpanded: isExpanded,
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildOrderCard({
    required String orderId,
    required String mealType,
    required String customerName,
    required DateTime date,
    required EnhancedLocationDetails enhancedLocation,
    required bool isExpanded,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$mealType Order',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Customer: $customerName',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _expandedOrders[orderId] = !isExpanded;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Time: ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
            if (isExpanded) ...[
              const SizedBox(height: 12),
              Text(
                'Phone: ${enhancedLocation.phoneNumber}',
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
              Text(
                'Address: ${enhancedLocation.location.address}',
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
              Text(
                'Type: ${enhancedLocation.addressType}',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              Text(
                'Building: ${enhancedLocation.buildingName.isNotEmpty ? enhancedLocation.buildingName : 'N/A'}',
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
              Text(
                'Floor: ${enhancedLocation.floorNumber.isNotEmpty ? enhancedLocation.floorNumber : 'N/A'}',
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
              Text(
                'Door: ${enhancedLocation.doorNumber.isNotEmpty ? enhancedLocation.doorNumber : 'N/A'}',
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
              if (enhancedLocation.additionalInfo != null &&
                  enhancedLocation.additionalInfo!.isNotEmpty)
                Text(
                  'Additional Info: ${enhancedLocation.additionalInfo}',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              if (enhancedLocation.location.address == 'No address available')
                const Text(
                  'No active address set',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: () => _confirmDelivery(context, orderId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Mark Delivered',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  ElevatedButton(
                    onPressed:
                        enhancedLocation.location.address !=
                                'No address available'
                            ? () => _openGoogleMaps(
                              enhancedLocation.entranceLatitude,
                              enhancedLocation.entranceLongitude,
                            )
                            : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child:
                        _isNavigating
                            ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                            : const Text(
                              'Open Map',
                              style: TextStyle(color: Colors.white),
                            ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmDelivery(BuildContext context, String orderId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Confirm Delivery'),
          content: const Text(
            'Are you sure you want to mark this order as delivered?',
          ),
          actions: [
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              onPressed: () {
                _markDelivered(context, orderId);
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Confirm',
                style: TextStyle(color: Colors.white),
              ),
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
        'deliveredAt': Timestamp.fromDate(DateTime.now()),
      });
      await _firestore.collection('delivery_guys').doc(widget.email).update({
        'assignedOrders': FieldValue.arrayRemove([orderId]),
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order marked as Delivered')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark as delivered: $e')),
        );
      }
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open Google Maps: $e')),
        );
      }
    } finally {
      setState(() => _isNavigating = false);
    }
  }
}

// EnhancedLocationDetails and LocationDetails classes (unchanged from previous)
class EnhancedLocationDetails {
  final LocationDetails location;
  final String addressType;
  final String buildingName;
  final String floorNumber;
  final String doorNumber;
  final String phoneNumber;
  final String? additionalInfo;
  final double entranceLatitude;
  final double entranceLongitude;

  EnhancedLocationDetails({
    required this.location,
    required this.addressType,
    required this.buildingName,
    required this.floorNumber,
    required this.doorNumber,
    required this.phoneNumber,
    this.additionalInfo,
    required this.entranceLatitude,
    required this.entranceLongitude,
  });

  Map<String, dynamic> toMap() => {
    'location': location.toMap(),
    'addressType': addressType,
    'buildingName': buildingName,
    'floorNumber': floorNumber,
    'doorNumber': doorNumber,
    'phoneNumber': phoneNumber,
    'additionalInfo': additionalInfo,
    'entranceLatitude': entranceLatitude,
    'entranceLongitude': entranceLongitude,
  };

  factory EnhancedLocationDetails.fromMap(Map<String, dynamic> map) {
    return EnhancedLocationDetails(
      location: LocationDetails.fromMap(
        map['location'] as Map<String, dynamic>,
      ),
      addressType: map['addressType'] as String,
      buildingName: map['buildingName'] ?? '',
      floorNumber: map['floorNumber'] ?? '',
      doorNumber: map['doorNumber'] ?? '',
      phoneNumber: map['phoneNumber'] as String,
      additionalInfo: map['additionalInfo'] as String?,
      entranceLatitude: map['entranceLatitude'] as double,
      entranceLongitude: map['entranceLongitude'] as double,
    );
  }
}

class LocationDetails {
  final double latitude;
  final double longitude;
  final String address;
  final String street;
  final String city;
  final String country;

  const LocationDetails({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.street,
    required this.city,
    required this.country,
  });

  Map<String, dynamic> toMap() => {
    'latitude': latitude,
    'longitude': longitude,
    'address': address,
    'street': street,
    'city': city,
    'country': country,
  };

  factory LocationDetails.fromMap(Map<String, dynamic> map) => LocationDetails(
    latitude: map['latitude'] as double,
    longitude: map['longitude'] as double,
    address: map['address'] as String,
    street: map['street'] ?? '',
    city: map['city'] ?? '',
    country: map['country'] ?? '',
  );
}
