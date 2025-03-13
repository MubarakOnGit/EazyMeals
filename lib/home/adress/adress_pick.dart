import 'package:flutter/material.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/location_details.dart';

class MapAddressPickerScreen extends StatefulWidget {
  @override
  _MapAddressPickerScreenState createState() => _MapAddressPickerScreenState();
}

class _MapAddressPickerScreenState extends State<MapAddressPickerScreen> {
  Point? _selectedLocation;
  Point? _initialLocation;
  YandexMapController? _mapController;
  bool _isLoading = true;
  bool _isSatelliteView = false;
  String? _statusMessage;
  final List<MapObject> _mapObjects = [];

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
        _initialLocation = Point(
          latitude: position.latitude,
          longitude: position.longitude,
        );
        _isLoading = false;
        _statusMessage =
            'Location: ${position.latitude}, ${position.longitude}';
      });
    } catch (e) {
      setState(() {
        _initialLocation = Point(
          latitude: 51.509364,
          longitude: -0.128928,
        ); // London fallback
        _isLoading = false;
        _statusMessage = 'Location error: $e';
      });
    }
  }

  Future<LocationDetails> _getLocationDetails(Point point) async {
    return await LocationDetails.fromLatLng(point.latitude, point.longitude);
  }

  void _updateMapObjects() {
    _mapObjects.clear();
    if (_initialLocation != null) {
      _mapObjects.add(
        PlacemarkMapObject(
          mapId: MapObjectId('initial_location'),
          point: _initialLocation!,
          icon: PlacemarkIcon.single(
            PlacemarkIconStyle(
              image: BitmapDescriptor.fromAssetImage('assets/my_location.png'),
              scale: 1.0,
            ),
          ),
        ),
      );
    }
    if (_selectedLocation != null) {
      _mapObjects.add(
        PlacemarkMapObject(
          mapId: MapObjectId('selected_location'),
          point: _selectedLocation!,
          icon: PlacemarkIcon.single(
            PlacemarkIconStyle(
              image: BitmapDescriptor.fromAssetImage('assets/location_pin.png'),
              scale: 1.0,
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Address'),
        actions: [
          IconButton(
            icon: Icon(_isSatelliteView ? Icons.map : Icons.satellite),
            onPressed: () {
              setState(() {
                _isSatelliteView = !_isSatelliteView;
                _statusMessage =
                    'View: ${_isSatelliteView ? "Satellite" : "Vector"}';
              });
            },
          ),
          if (_selectedLocation != null)
            IconButton(
              icon: Icon(Icons.check),
              onPressed: () async {
                if (_selectedLocation != null) {
                  LocationDetails details = await _getLocationDetails(
                    _selectedLocation!,
                  );
                  Navigator.pop(context, details);
                }
              },
            ),
        ],
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : Stack(
                children: [
                  YandexMap(
                    mapType:
                        _isSatelliteView ? MapType.satellite : MapType.vector,
                    onMapCreated: (controller) async {
                      _mapController = controller;
                      try {
                        if (_initialLocation != null) {
                          await _mapController!.moveCamera(
                            CameraUpdate.newCameraPosition(
                              CameraPosition(
                                target: _initialLocation!,
                                zoom: 15.0,
                              ),
                            ),
                          );
                          setState(() {
                            _statusMessage =
                                'Map loaded at ${_initialLocation!.latitude}, ${_initialLocation!.longitude}';
                          });
                        }
                        _updateMapObjects();
                      } catch (e) {
                        setState(() {
                          _statusMessage = 'Map init error: $e';
                        });
                      }
                    },
                    mapObjects: _mapObjects,
                    onMapTap: (point) {
                      setState(() {
                        _selectedLocation = point;
                        _updateMapObjects();
                        _statusMessage =
                            'Tapped: ${point.latitude}, ${point.longitude}';
                      });
                    },
                  ),
                  if (_statusMessage != null)
                    Positioned(
                      top: 10,
                      left: 10,
                      right: 10,
                      child: Container(
                        padding: EdgeInsets.all(8),
                        color: Colors.black54,
                        child: Text(
                          _statusMessage!,
                          style: TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (_initialLocation != null && _mapController != null) {
            await _mapController!.moveCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(target: _initialLocation!, zoom: 15.0),
              ),
            );
            setState(() {
              _statusMessage = 'Moved to initial location';
            });
          }
        },
        child: Icon(Icons.my_location),
      ),
    );
  }
}
