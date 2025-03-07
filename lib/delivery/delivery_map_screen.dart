import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models/location_details.dart';

class DeliveryMapScreen extends StatefulWidget {
  final LocationDetails deliveryLocation;
  final String customerName;

  DeliveryMapScreen({
    required this.deliveryLocation,
    required this.customerName,
  });

  @override
  _DeliveryMapScreenState createState() => _DeliveryMapScreenState();
}

class _DeliveryMapScreenState extends State<DeliveryMapScreen> {
  LatLng? _currentLocation;
  late LatLng _customerLocation;
  final MapController _mapController = MapController();
  bool _isLoading = true;
  bool _isSatelliteView = false;
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    print('InitState: Setting customer location and fetching current location');
    _customerLocation = LatLng(
      widget.deliveryLocation.latitude != 0.0
          ? widget.deliveryLocation.latitude
          : 51.509364,
      widget.deliveryLocation.longitude != 0.0
          ? widget.deliveryLocation.longitude
          : -0.128928,
    );
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      print('Fetching current location...');
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services disabled, prompting user...');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enable location services')),
        );
        await Geolocator.openLocationSettings();
        if (!await Geolocator.isLocationServiceEnabled()) {
          throw Exception('Location services are still disabled.');
        }
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        print('Requesting location permission...');
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
        if (permission == LocationPermission.deniedForever) {
          print('Permission permanently denied, opening settings...');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please allow location permission in settings'),
            ),
          );
          await Geolocator.openAppSettings();
          throw Exception('Location permissions permanently denied');
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _isLoading = false;
        print('Current location fetched: $_currentLocation');
        if (_isMapReady) _fitBounds(); // Only fit bounds if map is ready
      });
    } catch (e) {
      print('Error fetching location: $e');
      setState(() {
        _currentLocation = LatLng(51.509364, -0.128928); // Fallback: London
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to get location: $e')));
      if (_isMapReady && !_isLoading) _fitBounds();
    }
  }

  void _fitBounds() {
    if (_currentLocation == null) {
      print('FitBounds: Current location not ready, centering on customer');
      _mapController.move(_customerLocation, 15.0);
      return;
    }
    print('Fitting bounds between $_currentLocation and $_customerLocation');
    final bounds = LatLngBounds(_currentLocation!, _customerLocation);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
    );
  }

  void _centerOnCurrentLocation() async {
    print('FAB clicked: Centering on current location');
    setState(() {
      _isLoading = true; // Show loading indicator while fetching
    });

    await _getCurrentLocation(); // Always re-fetch to get the latest position

    setState(() {
      _isLoading = false;
    });

    if (_currentLocation != null && _isMapReady) {
      print('Moving map to $_currentLocation');
      _mapController.move(_currentLocation!, 16.0);
    } else {
      print('Failed to center: Current location null or map not ready');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to center on current location')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Map to ${widget.customerName}'),
        backgroundColor: Colors.blue,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_isSatelliteView ? Icons.map : Icons.satellite),
            onPressed: () {
              setState(() {
                _isSatelliteView = !_isSatelliteView;
                print(
                  'Map view toggled to: ${_isSatelliteView ? 'Satellite' : 'Normal'}',
                );
              });
            },
            tooltip: 'Toggle Map View',
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation ?? _customerLocation,
              initialZoom: 15.0,
              minZoom: 3.0,
              maxZoom: 18.0,
              onMapReady: () {
                print('Map ready');
                setState(() {
                  _isMapReady = true;
                });
                _fitBounds(); // Fit bounds once map is ready
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    _isSatelliteView
                        ? 'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}'
                        : 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: _isSatelliteView ? [] : ['a', 'b', 'c'],
                tileProvider: NetworkTileProvider(),
                maxZoom: 18.0,
              ),
              MarkerLayer(
                markers: [
                  if (_currentLocation != null)
                    Marker(
                      point: _currentLocation!,
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.blue,
                        size: 30,
                      ),
                    ),
                  Marker(
                    point: _customerLocation,
                    child: const Icon(
                      Icons.location_pin,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _centerOnCurrentLocation,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.my_location),
        tooltip: 'Go to My Location',
      ),
    );
  }
}
