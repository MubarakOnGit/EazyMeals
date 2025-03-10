import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:url_launcher/url_launcher.dart';
import '../screens/login_screen.dart';
import '../screens/subscription_screen.dart';
import 'address_management_screen.dart';
import 'student_verification_survey.dart';
import 'feedback_dialog.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController nameController = TextEditingController();
  String activeAddress = '12 Food Street, Metro City'; // Dummy address
  String userName = '';
  bool _isLoading = true;
  bool _isVerified = false;
  File? _profileImage; // Store the local image file

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadLocalProfileImage(); // Load the image from local storage on init
  }

  Future<void> _loadUserData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot doc =
            await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          setState(() {
            userName = doc['name'] ?? 'User';
            nameController.text = userName;
            _isVerified = doc['studentDetails']?['isVerified'] ?? false;
            activeAddress =
                doc['activeAddress'] ?? '12 Food Street, Metro City';
          });
        }
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load user data: $e')));
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  // Load the profile image from local storage
  Future<void> _loadLocalProfileImage() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final imagePath = '${directory.path}/profile_image.jpg';
      final file = File(imagePath);
      if (await file.exists()) {
        setState(() {
          _profileImage = file;
        });
      }
    } catch (e) {
      print('Error loading local image: $e');
    }
  }

  // Pick an image from the gallery and save it locally
  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final directory = await getApplicationDocumentsDirectory();
        final imagePath = '${directory.path}/profile_image.jpg';
        final file = File(pickedFile.path);
        await file.copy(imagePath);
        setState(() {
          _profileImage = File(imagePath);
        });
      } else {
        print('No image selected');
      }
    } on PlatformException catch (e) {
      print('PlatformException picking image: ${e.message}, code: ${e.code}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: ${e.message}')),
      );
    } catch (e) {
      print('Unexpected error picking image: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unexpected error: $e')));
    }
  }

  void _navigateToMealPreferences() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SubscriptionScreen()),
    );
  }

  Future<void> _showVerificationSurvey() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => StudentVerificationSurvey()),
    );
    if (result != null) {
      User? user = _auth.currentUser;
      if (user != null) {
        try {
          await _firestore.collection('users').doc(user.uid).update({
            'studentDetails': result,
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Student verification submitted!')),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to submit verification: $e')),
          );
        }
      }
    }
  }

  void _showFeedbackDialog() {
    showDialog(context: context, builder: (context) => FeedbackDialog());
  }

  Future<void> _logout() async {
    try {
      await _auth.signOut();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to logout: $e')));
    }
  }

  void _showAddressEditDialog() {
    final TextEditingController addressController = TextEditingController(
      text: activeAddress,
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Edit Address'),
            content: TextField(
              controller: addressController,
              decoration: InputDecoration(
                hintText: 'Enter your address',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            actions: [
              TextButton(
                child: Text('Cancel'),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton(
                child: Text('Save'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      Colors.blue.shade900, // Updated to blue shade 900
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  if (addressController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Address cannot be empty')),
                    );
                    return;
                  }
                  try {
                    await _firestore
                        .collection('users')
                        .doc(_auth.currentUser!.uid)
                        .update({'activeAddress': addressController.text});
                    setState(() => activeAddress = addressController.text);
                    Navigator.pop(context);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to update address: $e')),
                    );
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
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  // Header Section with updated gradient
                  Container(
                    height: 320,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.blue.shade900,
                          Colors.blue.shade700,
                        ], // Updated gradient
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(30),
                        bottomRight: Radius.circular(30),
                      ),
                    ),
                    padding: EdgeInsets.only(top: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: _pickProfileImage, // Tap to pick a new image
                          child: CircleAvatar(
                            radius: 60,
                            backgroundImage:
                                _profileImage != null
                                    ? FileImage(_profileImage!)
                                    : AssetImage('assets/images/on1.png')
                                        as ImageProvider, // Default image
                            child: Align(
                              alignment: Alignment.bottomRight,
                              child: Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              userName,
                              style: TextStyle(
                                fontSize: 26,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.white),
                              onPressed: () => _showNameEditDialog(),
                            ),
                          ],
                        ),
                        Text(
                          _auth.currentUser?.email ?? '',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        children: [
                          ProfileSectionCard(
                            icon: Icons.restaurant_menu,
                            title: 'Meal Plan',
                            subtitle: 'Premium Weekly Subscription',
                            onTap: _navigateToMealPreferences,
                          ),
                          ProfileSectionCard(
                            icon: Icons.location_on,
                            title: 'Address',
                            subtitle: activeAddress,
                            trailing: Icon(
                              Icons.edit,
                              color: Colors.blue.shade900,
                            ), // Updated icon color
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => AddressManagementScreen(),
                                ),
                              ).then((_) => _loadUserData());
                            },
                          ),
                          ProfileSectionCard(
                            icon: Icons.school,
                            title:
                                _isVerified
                                    ? 'Verified Student Discount Activated'
                                    : 'Student Discount',
                            subtitle:
                                _isVerified
                                    ? 'You are eligible for a 10% discount!'
                                    : 'Verify to get 10% off',
                            onTap: _isVerified ? null : _showVerificationSurvey,
                          ),
                          ProfileSectionCard(
                            icon: Icons.support_agent,
                            title: 'Support',
                            subtitle: 'Contact us for help',
                            onTap: () => _showSupportOptions(),
                          ),
                          ProfileSectionCard(
                            icon: Icons.feedback,
                            title: 'Feedback',
                            subtitle: 'Share your thoughts',
                            onTap: _showFeedbackDialog,
                          ),
                          ProfileSectionCard(
                            icon: Icons.logout,
                            title: 'Logout',
                            subtitle: 'Sign out of your account',
                            onTap: _logout,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
    );
  }

  void _showSupportOptions() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Support Options',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900, // Updated text color
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildSupportIcon(Icons.phone, 'tel:+1234567890'),
                    _buildSupportIcon(
                      Icons.message,
                      'https://wa.me/+1234567890',
                    ),
                    _buildSupportIcon(
                      Icons.email,
                      'mailto:support@foodapp.com',
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildSupportIcon(IconData icon, String url) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.blue.shade900.withOpacity(
          0.1,
        ), // Updated background color
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.blue.shade900), // Updated icon color
        onPressed: () async {
          try {
            await launchUrl(Uri.parse(url));
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not launch $url: $e')),
            );
          }
        },
      ),
    );
  }

  void _showNameEditDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Edit Name'),
            content: TextField(
              controller: nameController,
              decoration: InputDecoration(
                hintText: 'Enter your name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            actions: [
              TextButton(
                child: Text('Cancel'),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton(
                child: Text('Save'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      Colors.blue.shade900, // Updated to blue shade 900
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  if (nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Name cannot be empty')),
                    );
                    return;
                  }
                  try {
                    await _firestore
                        .collection('users')
                        .doc(_auth.currentUser!.uid)
                        .update({'name': nameController.text});
                    setState(() => userName = nameController.text);
                    Navigator.pop(context);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to update name: $e')),
                    );
                  }
                },
              ),
            ],
          ),
    );
  }
}

class ProfileSectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const ProfileSectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: 10), // Note: 'custom' should be 'bottom'
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade900.withOpacity(
              0.1,
            ), // Updated background color
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.blue.shade900), // Updated icon color
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[600])),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}
