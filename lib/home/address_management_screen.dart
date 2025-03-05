import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddressManagementScreen extends StatefulWidget {
  @override
  _AddressManagementScreenState createState() =>
      _AddressManagementScreenState();
}

class _AddressManagementScreenState extends State<AddressManagementScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _addressController = TextEditingController();
  List<String> _addresses = ['12 Food Street, Metro City']; // Dummy address
  String _activeAddress =
      '12 Food Street, Metro City'; // Default active address
  bool _isLoading = true;

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
        if (doc.exists) {
          setState(() {
            // Safely handle the 'addresses' field; use default if it doesn't exist
            _addresses =
                doc['addresses'] != null
                    ? List<String>.from(doc['addresses'])
                    : ['12 Food Street, Metro City'];
            // Safely handle the 'activeAddress' field; use default if it doesn't exist
            _activeAddress = doc['activeAddress'] ?? _addresses[0];
            _isLoading = false;
          });
        } else {
          // If the document doesn't exist, create it with default values
          await _firestore.collection('users').doc(user.uid).set(
            {
              'addresses': ['12 Food Street, Metro City'],
              'activeAddress': '12 Food Street, Metro City',
            },
            SetOptions(merge: true),
          ); // Use merge to avoid overwriting other fields
          setState(() {
            _addresses = ['12 Food Street, Metro City'];
            _activeAddress = '12 Food Street, Metro City';
            _isLoading = false;
          });
        }
      } catch (e) {
        print('Error loading addresses: $e');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load addresses: $e')));
        // Fallback to local default values in case of error
        setState(() {
          _addresses = ['12 Food Street, Metro City'];
          _activeAddress = '12 Food Street, Metro City';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _addAddress() async {
    final newAddress = _addressController.text.trim();
    if (newAddress.isEmpty) return;

    User? user = _auth.currentUser;
    if (user != null) {
      try {
        setState(() {
          _addresses.add(newAddress);
          if (_addresses.length == 1) {
            _activeAddress = newAddress; // Set first address as active
          }
        });
        await _firestore.collection('users').doc(user.uid).update({
          'addresses': _addresses,
          'activeAddress': _activeAddress,
        });
        _addressController.clear();
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add address: $e')));
      }
    }
  }

  Future<void> _deleteAddress(int index) async {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        setState(() {
          String removedAddress = _addresses.removeAt(index);
          if (_activeAddress == removedAddress) {
            _activeAddress =
                _addresses.isNotEmpty
                    ? _addresses[0]
                    : ''; // Set new active address or empty if no addresses left
          }
        });
        await _firestore.collection('users').doc(user.uid).update({
          'addresses': _addresses,
          'activeAddress': _activeAddress,
        });
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete address: $e')));
      }
    }
  }

  Future<void> _setActiveAddress(String address) async {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        setState(() => _activeAddress = address);
        await _firestore.collection('users').doc(user.uid).update({
          'activeAddress': _activeAddress,
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to set active address: $e')),
        );
      }
    }
  }

  Future<void> _editAddress(int index, String newAddress) async {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        setState(() {
          _addresses[index] = newAddress;
          if (_activeAddress == _addresses[index]) {
            _activeAddress = newAddress; // Update active address if edited
          }
        });
        await _firestore.collection('users').doc(user.uid).update({
          'addresses': _addresses,
          'activeAddress': _activeAddress,
        });
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to edit address: $e')));
      }
    }
  }

  void _showEditDialog(int index) {
    final TextEditingController editController = TextEditingController(
      text: _addresses[index],
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Edit Address'),
            content: TextField(
              controller: editController,
              decoration: InputDecoration(hintText: 'Enter new address'),
            ),
            actions: [
              TextButton(
                child: Text('Cancel'),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton(
                child: Text('Save'),
                onPressed: () {
                  if (editController.text.trim().isNotEmpty) {
                    _editAddress(index, editController.text.trim());
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
    );
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
                    Expanded(
                      child: ListView.builder(
                        itemCount: _addresses.length,
                        itemBuilder: (context, index) {
                          final address = _addresses[index];
                          return Card(
                            elevation: 2,
                            margin: EdgeInsets.only(
                              bottom: 10,
                            ), // Fixed to 'bottom'
                            child: ListTile(
                              title: Text(address),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () => _showEditDialog(index),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteAddress(index),
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
