import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/location_details.dart';
import 'adress/adress_pick.dart'; // Ensure this import points to the updated MapAddressPickerScreen

class AddressManagementScreen extends StatefulWidget {
  @override
  _AddressManagementScreenState createState() =>
      _AddressManagementScreenState();
}

class _AddressManagementScreenState extends State<AddressManagementScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _addressController = TextEditingController();
  List<LocationDetails> _addresses = [];
  late LocationDetails _activeAddress;
  bool _isLoading = true;

  // Define the dummy address as a constant
  static final LocationDetails _dummyAddress = LocationDetails(
    latitude: 1234,
    longitude: 5678,
    address: '123 Dummy Address',
    street: '123 Dummy Address',
    city: 'City',
    country: 'Country',
  );

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot doc =
            await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists && doc['addresses'] != null) {
          setState(() {
            _addresses =
                (doc['addresses'] as List)
                    .map(
                      (addr) => LocationDetails(
                        latitude: addr['latitude'],
                        longitude: addr['longitude'],
                        address: addr['address'],
                        street: addr['street'],
                        city: addr['city'],
                        country: addr['country'],
                      ),
                    )
                    .toList();
            var active = doc['activeAddress'];
            _activeAddress = LocationDetails(
              latitude: active['latitude'],
              longitude: active['longitude'],
              address: active['address'],
              street: active['street'],
              city: active['city'],
              country: active['country'],
            );
            // Ensure dummy address is included if not already present
            if (!_addresses.any((addr) => _isDummyAddress(addr))) {
              _addresses.add(_dummyAddress);
            }
            // If active address is invalid or missing, set to dummy
            if (!_addresses.contains(_activeAddress)) {
              _activeAddress = _dummyAddress;
            }
            _isLoading = false;
          });
        } else {
          // Initialize with dummy address if no data exists
          setState(() {
            _addresses = [_dummyAddress];
            _activeAddress = _dummyAddress;
            _isLoading = false;
          });
          await _firestore.collection('users').doc(user.uid).set({
            'addresses': [
              {
                'latitude': _dummyAddress.latitude,
                'longitude': _dummyAddress.longitude,
                'address': _dummyAddress.address,
                'street': _dummyAddress.street,
                'city': _dummyAddress.city,
                'country': _dummyAddress.country,
              },
            ],
            'activeAddress': {
              'latitude': _dummyAddress.latitude,
              'longitude': _dummyAddress.longitude,
              'address': _dummyAddress.address,
              'street': _dummyAddress.street,
              'city': _dummyAddress.city,
              'country': _dummyAddress.country,
            },
          }, SetOptions(merge: true));
        }
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load addresses: $e')));
      }
    }
  }

  bool _isDummyAddress(LocationDetails address) {
    return address.latitude == _dummyAddress.latitude &&
        address.longitude == _dummyAddress.longitude &&
        address.address == _dummyAddress.address;
  }

  Future<void> _addAddress() async {
    final newAddress = _addressController.text.trim();
    if (newAddress.isEmpty) return;

    User? user = _auth.currentUser;
    if (user != null) {
      try {
        LocationDetails newLocation = LocationDetails(
          latitude: 0, // Default for manual entry
          longitude: 0,
          address: newAddress,
        );
        setState(() {
          _addresses.add(newLocation);
          // Don’t change active address automatically
        });
        await _firestore.collection('users').doc(user.uid).update({
          'addresses':
              _addresses
                  .map(
                    (addr) => {
                      'latitude': addr.latitude,
                      'longitude': addr.longitude,
                      'address': addr.address,
                      'street': addr.street,
                      'city': addr.city,
                      'country': addr.country,
                    },
                  )
                  .toList(),
          'activeAddress': {
            'latitude': _activeAddress.latitude,
            'longitude': _activeAddress.longitude,
            'address': _activeAddress.address,
            'street': _activeAddress.street,
            'city': _activeAddress.city,
            'country': _activeAddress.country,
          },
        });
        _addressController.clear();
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add address: $e')));
      }
    }
  }

  Future<void> _addAddressFromMap() async {
    final LocationDetails? selectedLocation = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MapAddressPickerScreen()),
    );

    if (selectedLocation != null) {
      User? user = _auth.currentUser;
      if (user != null) {
        try {
          setState(() {
            _addresses.add(selectedLocation);
            // Don’t change active address automatically
          });
          await _firestore.collection('users').doc(user.uid).update({
            'addresses':
                _addresses
                    .map(
                      (addr) => {
                        'latitude': addr.latitude,
                        'longitude': addr.longitude,
                        'address': addr.address,
                        'street': addr.street,
                        'city': addr.city,
                        'country': addr.country,
                      },
                    )
                    .toList(),
            'activeAddress': {
              'latitude': _activeAddress.latitude,
              'longitude': _activeAddress.longitude,
              'address': _activeAddress.address,
              'street': _activeAddress.street,
              'city': _activeAddress.city,
              'country': _activeAddress.country,
            },
          });
        } catch (e) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to add address: $e')));
        }
      }
    }
  }

  void _showEditDialog(int index) {
    if (_isDummyAddress(_addresses[index]))
      return; // Prevent editing dummy address

    final editController = TextEditingController(
      text: _addresses[index].address,
    );
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Edit Address'),
            content: TextField(controller: editController),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  User? user = _auth.currentUser;
                  if (user != null) {
                    setState(() {
                      if (_activeAddress == _addresses[index]) {
                        _activeAddress = LocationDetails(
                          latitude: _activeAddress.latitude,
                          longitude: _activeAddress.longitude,
                          address: editController.text,
                          street: _activeAddress.street,
                          city: _activeAddress.city,
                          country: _activeAddress.country,
                        );
                      }
                      _addresses[index] = LocationDetails(
                        latitude: _addresses[index].latitude,
                        longitude: _addresses[index].longitude,
                        address: editController.text,
                        street: _addresses[index].street,
                        city: _addresses[index].city,
                        country: _addresses[index].country,
                      );
                    });
                    await _firestore.collection('users').doc(user.uid).update({
                      'addresses':
                          _addresses
                              .map(
                                (addr) => {
                                  'latitude': addr.latitude,
                                  'longitude': addr.longitude,
                                  'address': addr.address,
                                  'street': addr.street,
                                  'city': addr.city,
                                  'country': addr.country,
                                },
                              )
                              .toList(),
                      'activeAddress': {
                        'latitude': _activeAddress.latitude,
                        'longitude': _activeAddress.longitude,
                        'address': _activeAddress.address,
                        'street': _activeAddress.street,
                        'city': _activeAddress.city,
                        'country': _activeAddress.country,
                      },
                    });
                    Navigator.pop(context);
                  }
                },
                child: Text('Save'),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteAddress(int index) async {
    if (_isDummyAddress(_addresses[index]))
      return; // Prevent deleting dummy address

    User? user = _auth.currentUser;
    if (user != null) {
      try {
        setState(() {
          bool wasActive = _activeAddress == _addresses[index];
          _addresses.removeAt(index);
          if (wasActive) {
            // Check for other non-dummy addresses
            final nonDummyAddresses =
                _addresses.where((addr) => !_isDummyAddress(addr)).toList();
            if (nonDummyAddresses.isNotEmpty) {
              // Set the first non-dummy address as active
              _activeAddress = nonDummyAddresses.first;
            } else {
              // If no non-dummy addresses, set to dummy
              _activeAddress = _dummyAddress;
            }
          }
          // Ensure dummy address is always present
          if (!_addresses.any((addr) => _isDummyAddress(addr))) {
            _addresses.add(_dummyAddress);
          }
        });
        await _firestore.collection('users').doc(user.uid).update({
          'addresses':
              _addresses
                  .map(
                    (addr) => {
                      'latitude': addr.latitude,
                      'longitude': addr.longitude,
                      'address': addr.address,
                      'street': addr.street,
                      'city': addr.city,
                      'country': addr.country,
                    },
                  )
                  .toList(),
          'activeAddress': {
            'latitude': _activeAddress.latitude,
            'longitude': _activeAddress.longitude,
            'address': _activeAddress.address,
            'street': _activeAddress.street,
            'city': _activeAddress.city,
            'country': _activeAddress.country,
          },
        });
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete address: $e')));
      }
    }
  }

  Future<void> _setActiveAddress(LocationDetails address) async {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        setState(() => _activeAddress = address);
        await _firestore.collection('users').doc(user.uid).update({
          'activeAddress': {
            'latitude': _activeAddress.latitude,
            'longitude': _activeAddress.longitude,
            'address': _activeAddress.address,
            'street': _activeAddress.street,
            'city': _activeAddress.city,
            'country': _activeAddress.country,
          },
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to set active address: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Manage Addresses')),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _addressController,
                      decoration: InputDecoration(
                        labelText: 'Add New Address',
                        suffixIcon: IconButton(
                          icon: Icon(Icons.add),
                          onPressed: _addAddress,
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _addAddressFromMap,
                      child: Text('Add Address from Map'),
                    ),
                    SizedBox(height: 20),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _addresses.length,
                        itemBuilder: (context, index) {
                          final address = _addresses[index];
                          final isDummy = _isDummyAddress(address);
                          return Card(
                            elevation: 2,
                            margin: EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              title: Text(address.toString()),
                              subtitle: Text(
                                'Lat: ${address.latitude}, Lng: ${address.longitude}${address.city != null ? ', ${address.city}' : ''}${address.country != null ? ', ${address.country}' : ''}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.edit,
                                      color:
                                          isDummy ? Colors.grey : Colors.blue,
                                    ),
                                    onPressed:
                                        isDummy
                                            ? null
                                            : () => _showEditDialog(index),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete,
                                      color: isDummy ? Colors.grey : Colors.red,
                                    ),
                                    onPressed:
                                        isDummy
                                            ? null
                                            : () => _deleteAddress(index),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      _activeAddress == address
                                          ? Icons.check_circle
                                          : Icons.radio_button_unchecked,
                                      color: Colors.green,
                                    ),
                                    onPressed: () => _setActiveAddress(address),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
