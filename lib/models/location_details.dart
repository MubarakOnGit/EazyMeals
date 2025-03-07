import 'package:geocoding/geocoding.dart';

class LocationDetails {
  final double latitude;
  final double longitude;
  final String? address;
  final String? street;
  final String? city;
  final String? country;

  LocationDetails({
    required this.latitude,
    required this.longitude,
    this.address,
    this.street,
    this.city,
    this.country,
  });

  factory LocationDetails.fromMap(Map<String, dynamic> map) {
    return LocationDetails(
      latitude: map['latitude'] ?? 0.0,
      longitude: map['longitude'] ?? 0.0,
      address: map['address'],
      street: map['street'],
      city: map['city'],
      country: map['country'],
    );
  }

  static Future<LocationDetails> fromLatLng(
    double latitude,
    double longitude,
  ) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );
      Placemark place = placemarks.first;
      return LocationDetails(
        latitude: latitude,
        longitude: longitude,
        address:
            place.street != null && place.locality != null
                ? '${place.street}, ${place.locality}, ${place.country}'
                : null,
        street: place.street,
        city: place.locality,
        country: place.country,
      );
    } catch (e) {
      print('Reverse geocoding failed: $e');
      return LocationDetails(latitude: latitude, longitude: longitude);
    }
  }

  @override
  String toString() {
    return address ?? 'Lat: $latitude, Lng: $longitude';
  }
}
