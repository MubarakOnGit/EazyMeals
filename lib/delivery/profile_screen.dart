import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class DeliveryProfileScreen extends StatefulWidget {
  final String email;

  const DeliveryProfileScreen({required this.email, Key? key})
    : super(key: key);

  @override
  _DeliveryProfileScreenState createState() => _DeliveryProfileScreenState();
}

class _DeliveryProfileScreenState extends State<DeliveryProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  bool _isOnline = true;
  bool _isEditing = false;
  final String _countryCode = '+995';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('delivery_guys').doc(widget.email).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _nameController.text = data['name'] ?? 'Delivery Guy';
          String whatsapp = data['whatsappNumber'] ?? '';
          // Remove country code if it exists before displaying
          if (whatsapp.startsWith(_countryCode)) {
            _whatsappController.text = whatsapp.substring(_countryCode.length);
          } else {
            _whatsappController.text = whatsapp;
          }
          _isOnline = data['isOnline'] ?? true;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
    }
  }

  bool _validatePhoneNumber(String number) {
    // Check if the number is exactly 9 digits
    final RegExp georgianNumberPattern = RegExp(r'^\d{9}$');
    return georgianNumberPattern.hasMatch(number);
  }

  Future<void> _updateProfile() async {
    String phoneNumber = _whatsappController.text.trim();

    if (!_validatePhoneNumber(phoneNumber)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 9-digit Georgian number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      String fullNumber = _countryCode + phoneNumber;
      await _firestore.collection('delivery_guys').doc(widget.email).update({
        'name': _nameController.text,
        'whatsappNumber': fullNumber,
      });
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating profile: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              const Text(
                'Profile',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 30),
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.blue[900],
                backgroundImage: const AssetImage('assets/profile_pic.jpg'),
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue[900]!, Colors.blue[700]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          enabled: _isEditing,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Name',
                            labelStyle: TextStyle(color: Colors.grey[400]),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.blue[900]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[400]!),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 18,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[400]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _countryCode,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _whatsappController,
                                enabled: _isEditing,
                                style: const TextStyle(color: Colors.white),
                                keyboardType: TextInputType.phone,
                                maxLength: 9, // Restrict to 9 digits
                                decoration: InputDecoration(
                                  labelText: 'WhatsApp Number',
                                  labelStyle: TextStyle(
                                    color: Colors.grey[400],
                                  ),
                                  prefixIcon: Icon(
                                    Icons.phone,
                                    color: Colors.grey[400],
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: Colors.blue[900]!,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: Colors.grey[400]!,
                                    ),
                                  ),
                                  counterText: '', // Hide character counter
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            if (_isEditing) {
                              _updateProfile();
                            } else {
                              setState(() => _isEditing = true);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[900],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 12,
                            ),
                          ),
                          child: Text(
                            _isEditing ? 'Save Profile' : 'Edit Profile',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Rest of the code remains the same...
              const SizedBox(height: 20),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue[900]!, Colors.blue[700]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: Text(
                          _isOnline ? 'Online' : 'Offline',
                          style: const TextStyle(color: Colors.white),
                        ),
                        secondary: Icon(
                          Icons.power_settings_new,
                          color: Colors.grey[400],
                        ),
                        value: _isOnline,
                        activeColor: Colors.green,
                        onChanged: (value) async {
                          setState(() => _isOnline = value);
                          try {
                            await _firestore
                                .collection('delivery_guys')
                                .doc(widget.email)
                                .update({'isOnline': value});
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error updating status: $e'),
                              ),
                            );
                          }
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.support, color: Colors.grey[400]),
                        title: const Text(
                          'Contact Support',
                          style: TextStyle(color: Colors.white),
                        ),
                        onTap: () async {
                          String phoneNumber = "+995599699618";
                          String url = "https://wa.me/$phoneNumber";

                          if (await canLaunchUrl(Uri.parse(url))) {
                            await launchUrl(
                              Uri.parse(url),
                              mode: LaunchMode.externalApplication,
                            );
                          } else {
                            throw "Could not launch $url";
                          }
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.logout, color: Colors.grey[400]),
                        title: const Text(
                          'Logout',
                          style: TextStyle(color: Colors.white),
                        ),
                        onTap: () {
                          Navigator.popUntil(context, (route) => route.isFirst);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }
}
