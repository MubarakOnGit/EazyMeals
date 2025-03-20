import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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

  @override
  String toString() => address;

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

class AddressManagementScreen extends StatefulWidget {
  const AddressManagementScreen({super.key});

  @override
  _AddressManagementScreenState createState() =>
      _AddressManagementScreenState();
}

class _AddressManagementScreenState extends State<AddressManagementScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _addressController = TextEditingController();
  List<LocationDetails> _addresses = [];
  LocationDetails? _activeAddress;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadAddresses() async {
    final User? user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      setState(() {
        _isLoading = false;
        if (doc.exists && doc['addresses'] != null) {
          _addresses =
              (doc['addresses'] as List)
                  .map((addr) => LocationDetails.fromMap(addr))
                  .toList();
          if (doc['activeAddress'] != null) {
            final active = LocationDetails.fromMap(doc['activeAddress']);
            if (_activeAddress == null || _activeAddress != active) {
              _activeAddress = active;
            }
          } else if (_activeAddress == null && _addresses.isNotEmpty) {
            _activeAddress = _addresses.first;
            _updateActiveAddressInFirestore();
          }
        } else {
          _addresses = [];
          _activeAddress = null;
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load addresses: $e');
    }
  }

  Future<void> _updateAddressesInFirestore() async {
    final User? user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'addresses': _addresses.map((addr) => addr.toMap()).toList(),
        if (_activeAddress != null) 'activeAddress': _activeAddress!.toMap(),
      }, SetOptions(merge: true));
    } catch (e) {
      _showErrorSnackBar('Failed to update addresses: $e');
    }
  }

  Future<void> _updateActiveAddressInFirestore() async {
    final User? user = _auth.currentUser;
    if (user == null || _activeAddress == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'activeAddress': _activeAddress!.toMap(),
      }, SetOptions(merge: true));
    } catch (e) {
      _showErrorSnackBar('Failed to update active address: $e');
    }
  }

  Future<LocationDetails> _getAddressFromCoordinates(
    double lat,
    double lng,
  ) async {
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      throw Exception('Invalid coordinates');
    }

    const url =
        'https://nominatim.openstreetmap.org/reverse?format=json&zoom=18&addressdetails=1';
    try {
      final response = await http
          .get(
            Uri.parse('$url&lat=$lat&lon=$lng'),
            headers: {'User-Agent': 'AddressManager/1.0'},
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'];
        return LocationDetails(
          latitude: lat,
          longitude: lng,
          address: data['display_name'] ?? '$lat, $lng',
          street: address['road'] ?? address['street'] ?? '',
          city: address['city'] ?? address['town'] ?? address['village'] ?? '',
          country: address['country'] ?? '',
        );
      }
      throw Exception('Failed to fetch address details');
    } catch (e) {
      return LocationDetails(
        latitude: lat,
        longitude: lng,
        address: '$lat, $lng',
        street: '',
        city: '',
        country: '',
      );
    }
  }

  Future<void> _addAddress() async {
    final streetController = TextEditingController();
    final cityController = TextEditingController();
    final latController = TextEditingController();
    final lngController = TextEditingController();

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.grey[850],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: Text(
              'Add New Address',
              style: TextStyle(color: Colors.white),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTextField(_addressController, 'Address'),
                  _buildTextField(streetController, 'Street'),
                  _buildTextField(cityController, 'City'),
                  _buildTextField(
                    latController,
                    'Latitude',
                    keyboardType: TextInputType.number,
                  ),
                  _buildTextField(
                    lngController,
                    'Longitude',
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (_addressController.text.trim().isEmpty ||
                      streetController.text.trim().isEmpty ||
                      cityController.text.trim().isEmpty ||
                      latController.text.trim().isEmpty ||
                      lngController.text.trim().isEmpty) {
                    _showErrorSnackBar('Please fill all fields');
                    return;
                  }

                  try {
                    final lat = double.parse(latController.text);
                    final lng = double.parse(lngController.text);
                    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
                      _showErrorSnackBar('Invalid coordinates');
                      return;
                    }

                    final newLocation = LocationDetails(
                      latitude: lat,
                      longitude: lng,
                      address: _addressController.text.trim(),
                      street: streetController.text.trim(),
                      city: cityController.text.trim(),
                      country: '',
                    );

                    setState(() {
                      _addresses.add(newLocation);
                      _activeAddress ??= newLocation;
                    });
                    await _updateAddressesInFirestore();
                    _addressController.clear();
                    Navigator.pop(context);
                  } catch (e) {
                    _showErrorSnackBar('Failed to add address: $e');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade900,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('Add', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
    );
  }

  Future<void> _addAddressFromGoogleMaps() async {
    final coordsController = TextEditingController();
    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.grey[850],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: Text(
              'Add from Google Maps',
              style: TextStyle(color: Colors.white),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '1. Open Google Maps',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  Text(
                    '2. Pin your location',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  Text(
                    '3. Copy coordinates (e.g., 11.201561, 76.336183)',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  Text(
                    '4. Paste below',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  SizedBox(height: 10),
                  _buildTextField(
                    coordsController,
                    'Coordinates (lat,lng)',
                    hint: 'e.g., 11.201561, 76.336183',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed:
                    () async => await launchUrl(
                      Uri.parse('https://www.google.com/maps'),
                    ),
                child: Text(
                  'Open Maps',
                  style: TextStyle(color: Colors.blue.shade600),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  final coords = coordsController.text.trim();
                  if (coords.isEmpty) {
                    _showErrorSnackBar('Please enter coordinates');
                    return;
                  }

                  try {
                    final latLng = coords.split(',');
                    if (latLng.length != 2)
                      throw Exception('Invalid coordinate format');

                    final latitude = double.parse(latLng[0].trim());
                    final longitude = double.parse(latLng[1].trim());
                    final newLocation = await _getAddressFromCoordinates(
                      latitude,
                      longitude,
                    );

                    setState(() {
                      _addresses.add(newLocation);
                      _activeAddress ??= newLocation;
                    });
                    await _updateAddressesInFirestore();
                    Navigator.pop(context);
                  } catch (e) {
                    _showErrorSnackBar('Failed to process coordinates: $e');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade900,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('Add', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteAddress(int index) async {
    try {
      setState(() {
        final wasActive = _activeAddress == _addresses[index];
        _addresses.removeAt(index);
        if (wasActive) {
          _activeAddress = _addresses.isNotEmpty ? _addresses.first : null;
        }
      });
      await _updateAddressesInFirestore();
    } catch (e) {
      _showErrorSnackBar('Failed to delete address: $e');
    }
  }

  Future<void> _setActiveAddress(LocationDetails address) async {
    try {
      setState(() => _activeAddress = address);
      await _updateActiveAddressInFirestore();
    } catch (e) {
      _showErrorSnackBar('Failed to set active address: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    String? hint,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(color: Colors.grey[400]),
          hintStyle: TextStyle(color: Colors.grey[600]),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blue.shade600),
          ),
        ),
        style: TextStyle(color: Colors.white),
        keyboardType: keyboardType ?? TextInputType.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context); // Navigate back if possible
            } else {}
          },
        ),
        title: Text(
          'Manage Addresses',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadAddresses,
        color: Colors.blue.shade600,
        child:
            _isLoading
                ? Center(
                  child: CircularProgressIndicator(color: Colors.blue.shade900),
                )
                : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    _addressController,
                                    'Add New Address',
                                  ),
                                ),
                                SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: _addAddress,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade900,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Icon(Icons.add, color: Colors.white),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _addAddressFromGoogleMaps,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade900,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.map, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text(
                                    'Add from Google Maps',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final address = _addresses[index];
                        final isActive = _activeAddress == address;
                        return Card(
                          elevation: 4,
                          margin: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          color: Colors.grey[850],
                          child: ListTile(
                            contentPadding: EdgeInsets.all(16),
                            title: Text(
                              address.toString(),
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                'Street: ${address.street}\nCity: ${address.city}\nLat: ${address.latitude}, Lng: ${address.longitude}',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.delete,
                                    color: Colors.red.shade400,
                                  ),
                                  onPressed: () => _deleteAddress(index),
                                ),
                                IconButton(
                                  icon: Icon(
                                    isActive
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    color:
                                        isActive
                                            ? Colors.green.shade400
                                            : Colors.grey[600],
                                  ),
                                  onPressed: () => _setActiveAddress(address),
                                ),
                              ],
                            ),
                          ),
                        );
                      }, childCount: _addresses.length),
                    ),
                    if (_addresses.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: Text(
                              'No addresses added yet',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
      ),
    );
  }
}
