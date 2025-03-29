import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

// Basic Location Details
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

// Enhanced Location Details with isActive
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
  final bool isActive;

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
    this.isActive = false,
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
    'isActive': isActive,
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
      isActive: map['isActive'] as bool? ?? false,
    );
  }
}

// Custom Map Screen
class CustomMapScreen extends StatefulWidget {
  const CustomMapScreen({super.key});

  @override
  _CustomMapScreenState createState() => _CustomMapScreenState();
}

class _CustomMapScreenState extends State<CustomMapScreen> {
  GoogleMapController? _mapController;
  LatLng? _pinnedLocation;
  LatLng? _currentLocation;
  LocationDetails? _currentAddressDetails;
  bool _isLoading = true;
  static const String _placesApiKey =
      'YOUR_GOOGLE_PLACES_API_KEY'; // Taken from your code
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _searchController.addListener(
      () => _onSearchChanged(_searchController.text),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
      _pinnedLocation = _currentLocation;
      _isLoading = false;
    });
    _updateAddressDetails(_currentLocation!);
    _mapController?.animateCamera(CameraUpdate.newLatLng(_currentLocation!));
  }

  void _onSearchChanged(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty) {
        _searchPlaces(query);
      } else {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) return;

    setState(() => _isSearching = true);

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.low,
    );
    String countryCode = await _getCountryCode(
      position.latitude,
      position.longitude,
    );

    final url =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=$query'
        '&key=$_placesApiKey'
        '&components=country:$countryCode';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          setState(() {
            _searchResults = List<Map<String, dynamic>>.from(
              data['predictions'],
            );
            _isSearching = false;
          });
        } else {
          setState(() {
            _searchResults = [];
            _isSearching = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Search failed: $e')));
    }
  }

  Future<String> _getCountryCode(double lat, double lng) async {
    final url =
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&addressdetails=1';
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'AddressManager/1.0'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['address']['country_code']?.toLowerCase() ?? 'us';
      }
    } catch (e) {
      print('Error fetching country code: $e');
    }
    return 'us';
  }

  Future<void> _selectPlace(Map<String, dynamic> place) async {
    final placeId = place['place_id'];
    final detailsUrl =
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=$placeId'
        '&fields=geometry,name,formatted_address'
        '&key=$_placesApiKey';

    try {
      final response = await http.get(Uri.parse(detailsUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final result = data['result'];
          final location = result['geometry']['location'];
          final lat = location['lat'];
          final lng = location['lng'];
          final address = result['formatted_address'];

          final newLocation = LatLng(lat, lng);

          setState(() {
            _pinnedLocation = newLocation;
            _currentAddressDetails = LocationDetails(
              latitude: lat,
              longitude: lng,
              address: address,
              street: '',
              city: '',
              country: '',
            );
            _searchResults = [];
            _searchController.text = address;
          });

          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(newLocation, 15),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to get place details: $e')),
      );
    }
  }

  Future<void> _updateAddressDetails(LatLng position) async {
    final details = await _getAddressFromCoordinates(
      position.latitude,
      position.longitude,
    );
    setState(() => _currentAddressDetails = details);
  }

  Future<LocationDetails> _getAddressFromCoordinates(
    double lat,
    double lng,
  ) async {
    const url =
        'https://nominatim.openstreetmap.org/reverse?format=json&zoom=18&addressdetails=1&accept-language=en';
    try {
      final response = await http.get(
            Uri.parse('$url&lat=$lat&lon=$lng'),
            headers: {'User-Agent': 'AddressManager/1.0'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'];
        return LocationDetails(
          latitude: lat,
          longitude: lng,
          address: data['display_name'] ?? '$lat, $lng',
          street: address['road'] ?? '',
          city: address['city'] ?? address['town'] ?? address['village'] ?? '',
          country: address['country'] ?? '',
        );
      }
      throw Exception('Failed to fetch address');
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

  void _onMapTapped(LatLng position) {
    setState(() => _pinnedLocation = position);
    _updateAddressDetails(position);
  }

  void _proceedToDetails() async {
    if (_pinnedLocation == null || _currentAddressDetails == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a location first.')),
      );
      return;
    }

    final result = await Navigator.push(
        context,
      MaterialPageRoute(
        builder:
            (context) =>
                AddressDetailsScreen(location: _currentAddressDetails!),
      ),
    );
    if (result != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'lastPinnedLocation': {
            'latitude': _pinnedLocation!.latitude,
            'longitude': _pinnedLocation!.longitude,
          },
        }, SetOptions(merge: true));
      }
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[900]!.withAlpha(25), Colors.grey[100]!],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 40, 16, 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue[900]!.withAlpha(230),
                      Colors.blue[700]!.withAlpha(179),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(51),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
          IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'Pin Your Location',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
        children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search places...',
                        prefixIcon: Icon(Icons.search, color: Colors.blue[900]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.blue[900]!.withAlpha(77),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.blue[900]!,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    if (_isSearching)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(),
                      ),
                    if (_searchResults.isNotEmpty)
                      Container(
                        height: 150,
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(26),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final place = _searchResults[index];
                            return ListTile(
                              leading: const Icon(Icons.location_on),
                              title: Text(
                                place['description'],
                                style: TextStyle(color: Colors.blue[900]),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => _selectPlace(place),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child:
          _isLoading
                        ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.blue,
                            ),
                          ),
                        )
              : GoogleMap(
                          onMapCreated:
                              (controller) => _mapController = controller,
                initialCameraPosition: CameraPosition(
                  target: _currentLocation ?? const LatLng(0, 0),
                  zoom: 15,
                ),
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                onTap: _onMapTapped,
                markers:
                    _pinnedLocation != null
                        ? {
                          Marker(
                            markerId: const MarkerId('pinned'),
                            position: _pinnedLocation!,
                                      icon:
                                          BitmapDescriptor.defaultMarkerWithHue(
                                            BitmapDescriptor.hueBlue,
                                          ),
                                      infoWindow:
                                          _currentAddressDetails != null
                                              ? InfoWindow(
                                                title:
                                                    _currentAddressDetails!
                                                        .address,
                                              )
                                              : const InfoWindow(),
                          ),
                        }
                        : {},
                          circles:
                              _pinnedLocation != null
                                  ? {
                                    Circle(
                                      circleId: const CircleId('pinnedCircle'),
                                      center: _pinnedLocation!,
                                      radius: 50,
                                      fillColor: Colors.blue[200]!.withAlpha(
                                        50,
                                      ),
                                      strokeColor: Colors.blue[400]!.withAlpha(
                                        100,
                                      ),
                                      strokeWidth: 2,
                                    ),
                                  }
                                  : {},
                        ),
              ),
              if (_currentAddressDetails != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    _currentAddressDetails!.address,
                    style: TextStyle(color: Colors.blue[900], fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: ElevatedButton(
                  onPressed: _proceedToDetails,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 32,
                    ),
                    backgroundColor: Colors.blue[900],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 6,
                    shadowColor: Colors.blue.withAlpha(102),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.arrow_forward, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Next',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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
}

// Address Details Screen
class AddressDetailsScreen extends StatefulWidget {
  final LocationDetails location;
  const AddressDetailsScreen({super.key, required this.location});

  @override
  State<AddressDetailsScreen> createState() => _AddressDetailsScreenState();
}

class _AddressDetailsScreenState extends State<AddressDetailsScreen> {
  String _selectedType = 'house';
  final _customTypeController = TextEditingController();
  final _buildingController = TextEditingController();
  final _floorController = TextEditingController();
  final _doorController = TextEditingController();
  final _phoneController = TextEditingController();
  final _additionalController = TextEditingController();
  LatLng? _entranceLocation;
  bool _isSaveEnabled = false;

  @override
  void initState() {
    super.initState();
    _entranceLocation = LatLng(
      widget.location.latitude,
      widget.location.longitude,
    );
    _buildingController.addListener(_checkFields);
    _floorController.addListener(_checkFields);
    _doorController.addListener(_checkFields);
    _phoneController.addListener(_checkFields);
    _additionalController.addListener(_checkFields);
    _customTypeController.addListener(_checkFields);
  }

  void _checkFields() {
        setState(() {
      _isSaveEnabled =
          _buildingController.text.trim().isNotEmpty &&
          _floorController.text.trim().isNotEmpty &&
          _doorController.text.trim().isNotEmpty &&
          _phoneController.text.trim().isNotEmpty &&
          (_selectedType != 'other' ||
              _customTypeController.text.trim().isNotEmpty);
    });
  }

  void _saveAddress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final enhancedLocation = EnhancedLocationDetails(
      location: widget.location,
      addressType:
          _selectedType == 'other'
              ? _customTypeController.text.trim()
              : _selectedType,
      buildingName: _buildingController.text.trim(),
      floorNumber: _floorController.text.trim(),
      doorNumber: _doorController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      additionalInfo:
          _additionalController.text.trim().isEmpty
              ? null
              : _additionalController.text.trim(),
      entranceLatitude: _entranceLocation!.latitude,
      entranceLongitude: _entranceLocation!.longitude,
      isActive: true,
    );

    try {
      final addressesRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('addresses');

      // Deactivate existing active address
      final activeAddresses =
          await addressesRef.where('isActive', isEqualTo: true).get();
      for (var doc in activeAddresses.docs) {
        await doc.reference.update({'isActive': false});
      }

      // Add new address
      await addressesRef.add(enhancedLocation.toMap());
      Navigator.pop(context, enhancedLocation);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[900]!, Colors.blue[700]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(51),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
              'Add New Address',
              style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withAlpha(51),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selected Location',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                color: Colors.blue[900],
              ),
            ),
                      const SizedBox(height: 8),
                      Text(
                        widget.location.address,
                        style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Text(
                      'Address Type',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[900],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildTypeOption('House', Icons.house),
                          _buildTypeOption('Apartment', Icons.apartment),
                          _buildTypeOption('Office', Icons.work),
                          _buildTypeOption('Other', Icons.label),
                        ],
                      ),
                  ),
                ],
              ),
            ),
              if (_selectedType == 'other')
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: _buildTextField(
                    _customTypeController,
                    'Custom Type',
                    Icons.label,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  children: [
                    _buildTextField(
                      _buildingController,
                      'Building Name',
                      Icons.apartment,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      _floorController,
                      'Floor Number',
                      Icons.stairs,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      _doorController,
                      'Door Number',
                      Icons.door_sliding_outlined,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      _phoneController,
                      'Phone Number',
                      Icons.phone,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      _additionalController,
                      'Additional Info (Optional)',
                      Icons.info,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Entrance Location',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[900],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withAlpha(51),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: _entranceLocation!,
                            zoom: 18,
                          ),
                          markers: {
                            Marker(
                              markerId: const MarkerId('entrance'),
                              position: _entranceLocation!,
                              draggable: true,
                              icon: BitmapDescriptor.defaultMarkerWithHue(
                                BitmapDescriptor.hueGreen,
                              ),
                              onDragEnd:
                                  (newPosition) => setState(
                                    () => _entranceLocation = newPosition,
                                  ),
                            ),
                          },
                          circles: {
                            Circle(
                              circleId: const CircleId('entranceCircle'),
                              center: _entranceLocation!,
                              radius: 20,
                              fillColor: Colors.blue[200]!.withAlpha(50),
                              strokeColor: Colors.blue[400]!.withAlpha(100),
                              strokeWidth: 2,
                            ),
                          },
                          onTap:
                              (position) =>
                                  setState(() => _entranceLocation = position),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: _isSaveEnabled ? _saveAddress : null,
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue[900],
                    disabledBackgroundColor: Colors.grey[400],
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 6,
                    shadowColor: Colors.blue.withAlpha(102),
                  ),
                  child: Container(
                    width: double.infinity,
                    alignment: Alignment.center,
                    child: const Text(
                      'Save Address',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeOption(String type, IconData icon) {
    final isSelected = _selectedType.toLowerCase() == type.toLowerCase();
    return GestureDetector(
      onTap:
          () => setState(() {
            _selectedType = type.toLowerCase();
            if (_selectedType != 'other') _customTypeController.clear();
            _checkFields();
          }),
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient:
                isSelected
                    ? LinearGradient(
                      colors: [Colors.blue[900]!, Colors.blue[700]!],
                    )
                    : LinearGradient(
                      colors: [Colors.grey[200]!, Colors.grey[300]!],
                    ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withAlpha(51),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.blue[900],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                type,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.blue[900],
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.blue[900], size: 24),
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.grey[600],
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          floatingLabelStyle: TextStyle(
            color: Colors.blue[900],
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.blue[900]!, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
        ),
        style: TextStyle(
          color: Colors.blue[900],
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// Address Management Screen
class AddressManagementScreen extends StatefulWidget {
  const AddressManagementScreen({super.key});

  @override
  State<AddressManagementScreen> createState() =>
      _AddressManagementScreenState();
}

class _AddressManagementScreenState extends State<AddressManagementScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<EnhancedLocationDetails> _addresses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      setState(() => _isLoading = true);
      final snapshot =
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('addresses')
              .get();

        setState(() {
        _addresses =
            snapshot.docs
                .map((doc) => EnhancedLocationDetails.fromMap(doc.data()))
                .toList();
        _isLoading = false;
      });
      } catch (e) {
      print('Error loading addresses: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load addresses: $e')));
    }
  }

  Future<void> _addAddressFromMap() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CustomMapScreen()),
    );
    if (result != null && result is EnhancedLocationDetails && mounted) {
      setState(() => _addresses.add(result));
      await _loadAddresses(); // Reload to ensure consistency
    }
  }

  Future<void> _deleteAddress(int index) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final addressToDelete = _addresses[index];
      final snapshot =
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('addresses')
              .where('phoneNumber', isEqualTo: addressToDelete.phoneNumber)
              .get();

      if (snapshot.docs.isNotEmpty) {
        await snapshot.docs.first.reference.delete();
      }

      setState(() {
        _addresses.removeAt(index);
        if (addressToDelete.isActive && _addresses.isNotEmpty) {
          _setActiveAddress(_addresses.first);
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete address: $e')));
    }
  }

  Future<void> _setActiveAddress(EnhancedLocationDetails address) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final addressesRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('addresses');

      // Deactivate all addresses
      final activeAddresses =
          await addressesRef.where('isActive', isEqualTo: true).get();
      for (var doc in activeAddresses.docs) {
        await doc.reference.update({'isActive': false});
      }

      // Set the selected address as active
      final snapshot =
          await addressesRef
              .where('phoneNumber', isEqualTo: address.phoneNumber)
              .get();
      if (snapshot.docs.isNotEmpty) {
        await snapshot.docs.first.reference.update({'isActive': true});
      }

      setState(() {
        _addresses =
            _addresses
                .map(
                  (addr) => EnhancedLocationDetails(
                    location: addr.location,
                    addressType: addr.addressType,
                    buildingName: addr.buildingName,
                    floorNumber: addr.floorNumber,
                    doorNumber: addr.doorNumber,
                    phoneNumber: addr.phoneNumber,
                    additionalInfo: addr.additionalInfo,
                    entranceLatitude: addr.entranceLatitude,
                    entranceLongitude: addr.entranceLongitude,
                    isActive: addr.phoneNumber == address.phoneNumber,
                  ),
                )
                .toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to set active address: $e')),
      );
    }
  }

  void _showFullAddress(BuildContext context, EnhancedLocationDetails address) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white.withAlpha(230),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                  'Type: ${address.addressType}',
                          style: TextStyle(
                    fontSize: 16,
                            color: Colors.blue[900],
                    height: 1.5,
                  ),
                ),
                Text(
                  'Address: ${address.location.address}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.blue[900],
                    height: 1.5,
                  ),
                ),
                Text(
                  'Building: ${address.buildingName}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.blue[900],
                    height: 1.5,
                  ),
                ),
                Text(
                  'Floor: ${address.floorNumber}',
                  style: TextStyle(
                    fontSize: 16,
                          color: Colors.blue[900],
                    height: 1.5,
                  ),
                ),
                Text(
                  'Door: ${address.doorNumber}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.blue[900],
                    height: 1.5,
                  ),
                ),
                Text(
                  'Phone: ${address.phoneNumber}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.blue[900],
                    height: 1.5,
                  ),
                ),
                if (address.additionalInfo != null)
                  Text(
                    'Additional Info: ${address.additionalInfo}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.blue[900],
                      height: 1.5,
            ),
          ),
        ],
            ),
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
                colors: [Colors.blue[900]!.withAlpha(25), Colors.grey[100]!],
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
                SliverAppBar(
                  expandedHeight: 200,
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
                          colors: [
                            Colors.blue[900]!.withAlpha(230),
                            Colors.blue[700]!.withAlpha(179),
                          ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(30),
            ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(51),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Manage Addresses',
                  style: TextStyle(
                    fontSize: 28,
                                fontWeight: FontWeight.bold,
                    color: Colors.white,
                                letterSpacing: 1,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                              'Your delivery locations',
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
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add New Address',
            style: TextStyle(
              fontSize: 22,
                            fontWeight: FontWeight.bold,
              color: Colors.blue[900],
            ),
          ),
          const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _addAddressFromMap,
                  style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 32,
                            ),
                    backgroundColor: Colors.blue[900],
                    shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                    ),
                            elevation: 6,
                            shadowColor: Colors.blue.withAlpha(102),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                              Icon(
                                Icons.add_location,
                                color: Colors.white,
                                size: 20,
                              ),
                      SizedBox(width: 8),
                      Text(
                                'Add Address',
                        style: TextStyle(
                          fontSize: 16,
                                  fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                        const SizedBox(height: 24),
                        Text(
                          'Your Addresses',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
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
                    ? SliverToBoxAdapter(
                      child: Center(
                        child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                            Icon(
                              Icons.location_off,
                              size: 60,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                      Text(
                              'No addresses yet',
                        style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add one to start!',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                    )
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

  Widget _buildAddressCard(EnhancedLocationDetails address, int index) {
    final isActive = address.isActive;
    IconData typeIcon =
        address.addressType == 'house'
            ? Icons.house
            : address.addressType == 'apartment'
            ? Icons.apartment
            : address.addressType == 'office'
            ? Icons.work
            : Icons.label;

    return GestureDetector(
      onTap: () => _showFullAddress(context, address),
      child: AnimatedContainer(
      duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              isActive
                  ? [Colors.blue[900]!, Colors.blue[700]!]
                    : [Colors.white, Colors.grey[100]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color:
                  isActive
                      ? Colors.blue.withOpacity(0.3)
                      : Colors.grey.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
              padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:
                  isActive
                        ? Colors.white.withOpacity(0.2)
                        : Colors.blue[900]!.withOpacity(0.1),
              shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
            ),
            child: Icon(
                typeIcon,
              color: isActive ? Colors.white : Colors.blue[900],
                size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                    address.addressType,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    color: isActive ? Colors.white : Colors.blue[900],
                      height: 1.4,
                  ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                ),
                  const SizedBox(height: 6),
                Text(
                    '${address.buildingName} • Floor ${address.floorNumber} • Door ${address.doorNumber}',
                  style: TextStyle(
                      fontSize: 14,
                      color:
                          isActive
                              ? Colors.white.withOpacity(0.9)
                              : Colors.grey[700],
                      height: 1.4,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address.phoneNumber,
                    style: TextStyle(
                      fontSize: 14,
                      color:
                          isActive
                              ? Colors.white.withOpacity(0.9)
                              : Colors.grey[700],
                      height: 1.4,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
                    size: 24,
                ),
                onPressed: () => _deleteAddress(index),
                  padding: const EdgeInsets.all(8),
              ),
              IconButton(
                icon: Icon(
                    isActive
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                  color: isActive ? Colors.greenAccent : Colors.grey[600],
                    size: 24,
                ),
                onPressed: () => _setActiveAddress(address),
                  padding: const EdgeInsets.all(8),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }
}
