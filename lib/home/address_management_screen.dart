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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: Colors.white,
            title: Text(
              'Add New Address',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.blue.shade900,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDialogTextField(
                    _addressController,
                    'Address',
                    'Full address description',
                  ),
                  _buildDialogTextField(
                    streetController,
                    'Street',
                    'Street name',
                  ),
                  _buildDialogTextField(cityController, 'City', 'City name'),
                  _buildDialogTextField(
                    latController,
                    'Latitude',
                    'e.g., 11.201561',
                    keyboardType: TextInputType.number,
                  ),
                  _buildDialogTextField(
                    lngController,
                    'Longitude',
                    'e.g., 76.336183',
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.blue.shade900),
                ),
                onPressed: () => Navigator.pop(context),
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: Colors.white,
            title: Text(
              'Add from Google Maps',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.blue.shade900,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Follow these steps:',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '1. Open Google Maps',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  Text(
                    '2. Pin your location',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  Text(
                    '3. Copy coordinates (e.g., 11.201561, 76.336183)',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  Text(
                    '4. Paste below',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  SizedBox(height: 16),
                  _buildDialogTextField(
                    coordsController,
                    'Coordinates (lat,lng)',
                    'e.g., 11.201561, 76.336183',
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
                  style: TextStyle(color: Colors.blue.shade900),
                ),
              ),
              TextButton(
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.blue.shade900),
                ),
                onPressed: () => Navigator.pop(context),
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

  Widget _buildDialogTextField(
    TextEditingController controller,
    String label,
    String hint, {
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(color: Colors.grey.shade700),
          hintStyle: TextStyle(color: Colors.grey.shade500),
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
        style: TextStyle(color: Colors.blue.shade900),
        keyboardType: keyboardType ?? TextInputType.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Stack(
        children: [
          // Background gradient for subtle depth
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.shade900.withOpacity(0.05),
                  Colors.grey.shade100,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          RefreshIndicator(
            onRefresh: _loadAddresses,
            color: Colors.blue.shade900,
            child: CustomScrollView(
              physics: BouncingScrollPhysics(),
              slivers: [
                _buildSliverAppBar(),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildAddAddressSection(),
                        SizedBox(height: 24),
                        Text(
                          'Your Addresses',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.blue.shade900,
                          ),
                        ),
                        SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                _isLoading
                    ? SliverToBoxAdapter(
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Colors.blue.shade900,
                        ),
                      ),
                    )
                    : _addresses.isEmpty
                    ? SliverToBoxAdapter(child: _buildEmptyState())
                    : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) =>
                            _buildAddressCard(_addresses[index], index),
                        childCount: _addresses.length,
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // SliverAppBar with gradient and modern styling
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade900, Colors.blue.shade700],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Manage Addresses',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Set your delivery locations',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Add address section with buttons
  Widget _buildAddAddressSection() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add New Address',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.blue.shade900,
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _addAddress,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue.shade900,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 8,
                    shadowColor: Colors.blue.withOpacity(0.3),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_location, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Manual Entry',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _addAddressFromGoogleMaps,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue.shade900,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 8,
                    shadowColor: Colors.blue.withOpacity(0.3),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.map, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'From Google Maps',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Address card with actions
  Widget _buildAddressCard(LocationDetails address, int index) {
    final isActive = _activeAddress == address;
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              isActive
                  ? [Colors.blue.shade900, Colors.blue.shade700]
                  : [Colors.white, Colors.grey.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color:
                  isActive
                      ? Colors.white.withOpacity(0.1)
                      : Colors.blue.shade900.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.location_on,
              color: isActive ? Colors.white : Colors.blue.shade900,
              size: 20,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  address.address,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isActive ? Colors.white : Colors.blue.shade900,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Street: ${address.street}\nCity: ${address.city}\nLat: ${address.latitude}, Lng: ${address.longitude}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isActive ? Colors.white70 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  Icons.delete,
                  color: isActive ? Colors.redAccent : Colors.red.shade400,
                ),
                onPressed: () => _deleteAddress(index),
              ),
              IconButton(
                icon: Icon(
                  isActive ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: isActive ? Colors.greenAccent : Colors.grey.shade600,
                ),
                onPressed: () => _setActiveAddress(address),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Empty state widget
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off, size: 60, color: Colors.grey.shade400),
          SizedBox(height: 16),
          Text(
            'No addresses added yet',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          SizedBox(height: 8),
          Text(
            'Add one to get started!',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
