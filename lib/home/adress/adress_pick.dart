import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/location_details.dart';

class MapAddressPickerScreen extends StatefulWidget {
  @override
  _MapAddressPickerScreenState createState() => _MapAddressPickerScreenState();
}

class _MapAddressPickerScreenState extends State<MapAddressPickerScreen> {
  LatLng? _selectedLocation;
  LatLng? _initialLocation;
  final MapController _mapController = MapController();
  bool _isLoading = true;
  bool _isSatelliteView = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services are disabled.');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _initialLocation = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _initialLocation = LatLng(51.509364, -0.128928); // Default: London
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to get location: $e')));
    }
  }

  Future<LocationDetails> _getLocationDetails(LatLng latLng) async {
    return await LocationDetails.fromLatLng(latLng.latitude, latLng.longitude);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('en', 'US'),
      supportedLocales: [const Locale('en', 'US')],
      home: Scaffold(
        appBar: AppBar(
          title: Text('Select Address'),
          actions: [
            IconButton(
              icon: Icon(_isSatelliteView ? Icons.map : Icons.satellite),
              onPressed: () {
                setState(() => _isSatelliteView = !_isSatelliteView);
              },
              tooltip: 'Toggle Map View',
            ),
            if (_selectedLocation != null)
              IconButton(
                icon: Icon(Icons.check),
                onPressed: () async {
                  LocationDetails details = await _getLocationDetails(
                    _selectedLocation!,
                  );
                  Navigator.pop(context, details);
                },
              ),
          ],
        ),
        body:
            _isLoading
                ? Center(child: CircularProgressIndicator())
                : FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter:
                        _initialLocation ?? LatLng(51.509364, -0.128928),
                    initialZoom: 15.0,
                    minZoom: 3.0,
                    maxZoom: 18.0,
                    onTap: (tapPosition, latLng) {
                      setState(() => _selectedLocation = latLng);
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
                    if (_selectedLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _selectedLocation!,
                            child: Icon(
                              Icons.location_pin,
                              color: Colors.red,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                    if (_initialLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _initialLocation!,
                            child: Icon(
                              Icons.my_location,
                              color: Colors.blue,
                              size: 30,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            if (_initialLocation != null) {
              _mapController.move(_initialLocation!, 15.0);
            }
          },
          child: Icon(Icons.my_location),
          tooltip: 'Go to my location',
        ),
      ),
    );
  }
}
