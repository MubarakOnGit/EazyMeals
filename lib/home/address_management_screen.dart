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
  State<AddressManagementScreen> createState() =>
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
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (mounted) {
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
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Failed to load addresses: $e');
      }
    }
  }

  Future<void> _updateAddressesInFirestore() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'addresses': _addresses.map((addr) => addr.toMap()).toList(),
        if (_activeAddress != null) 'activeAddress': _activeAddress!.toMap(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (mounted) _showErrorSnackBar('Failed to update addresses: $e');
    }
  }

  Future<void> _updateActiveAddressInFirestore() async {
    final user = _auth.currentUser;
    if (user == null || _activeAddress == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'activeAddress': _activeAddress!.toMap(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (mounted) _showErrorSnackBar('Failed to update active address: $e');
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

    final result = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: Colors.white,
            title: Text(
              'Add New Address',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.blue[900],
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
                  style: TextStyle(color: Colors.blue[900]),
                ),
                onPressed: () => Navigator.pop(context, false),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[900],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Add', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
    );

    if (result == true && mounted) {
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
      } catch (e) {
        _showErrorSnackBar('Failed to add address: $e');
      }
    }
  }

  Future<void> _addAddressFromGoogleMaps() async {
    final coordsController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: Colors.white,
            title: Text(
              'Add from Google Maps',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.blue[900],
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Follow these steps:',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '1. Open Google Maps',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  Text(
                    '2. Pin your location',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  Text(
                    '3. Copy coordinates (e.g., 11.201561, 76.336183)',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  Text(
                    '4. Paste below',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
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
                  style: TextStyle(color: Colors.blue[900]),
                ),
              ),
              TextButton(
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.blue[900]),
                ),
                onPressed: () => Navigator.pop(context, false),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[900],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Add', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
    );

    if (result == true && mounted) {
      final coords = coordsController.text.trim();
      if (coords.isEmpty) {
        _showErrorSnackBar('Please enter coordinates');
        return;
      }

      try {
        final latLng = coords.split(',');
        if (latLng.length != 2) throw Exception('Invalid coordinate format');

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
      } catch (e) {
        _showErrorSnackBar('Failed to process coordinates: $e');
      }
    }
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
      if (mounted) _showErrorSnackBar('Failed to delete address: $e');
    }
  }

  Future<void> _setActiveAddress(LocationDetails address) async {
    try {
      setState(() => _activeAddress = address);
      await _updateActiveAddressInFirestore();
    } catch (e) {
      if (mounted) _showErrorSnackBar('Failed to set active address: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted)
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
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(color: Colors.grey[700]),
          hintStyle: TextStyle(color: Colors.grey[500]),
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 16,
          ),
        ),
        style: TextStyle(color: Colors.blue[900]),
        keyboardType: keyboardType ?? TextInputType.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue[900]!.withAlpha(13),
                  Colors.grey[100]!,
                ], // 0.05 -> 13
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          RefreshIndicator(
            onRefresh: _loadAddresses,
            color: Colors.blue[900],
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildSliverAppBar(),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildAddAddressSection(),
                        const SizedBox(height: 24),
                        Text(
                          'Your Addresses',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.blue[900],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                _isLoading
                    ? SliverToBoxAdapter(
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Colors.blue[900],
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

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[900]!, Colors.blue[700]!],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(30),
            ),
          ),
          child: const Center(
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

  Widget _buildAddAddressSection() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add New Address',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.blue[900],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _addAddress,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue[900],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 8,
                    shadowColor: Colors.blue.withAlpha(77), // 0.3 -> 77
                  ),
                  child: const Row(
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
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _addAddressFromGoogleMaps,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue[900],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 8,
                    shadowColor: Colors.blue.withAlpha(77), // 0.3 -> 77
                  ),
                  child: const Row(
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

  Widget _buildAddressCard(LocationDetails address, int index) {
    final isActive = _activeAddress == address;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              isActive
                  ? [Colors.blue[900]!, Colors.blue[700]!]
                  : [Colors.white, Colors.grey[50]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(51),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ], // 0.2 -> 51
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color:
                  isActive
                      ? Colors.white.withAlpha(26)
                      : Colors.blue[900]!.withAlpha(26), // 0.1 -> 26
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.location_on,
              color: isActive ? Colors.white : Colors.blue[900],
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  address.address,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isActive ? Colors.white : Colors.blue[900],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Street: ${address.street}\nCity: ${address.city}\nLat: ${address.latitude}, Lng: ${address.longitude}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isActive ? Colors.white70 : Colors.grey[600],
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
                  color: isActive ? Colors.redAccent : Colors.red[400],
                ),
                onPressed: () => _deleteAddress(index),
              ),
              IconButton(
                icon: Icon(
                  isActive ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: isActive ? Colors.greenAccent : Colors.grey[600],
                ),
                onPressed: () => _setActiveAddress(address),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No addresses added yet',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Add one to get started!',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
