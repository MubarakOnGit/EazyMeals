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
import 'employee_login_screen.dart'; // Import EmployeeLoginScreen

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  String activeAddress = '12 Food Street, Metro City';
  String userName = '';
  String phoneNumber = '';
  bool _isLoading = true;
  bool _isVerified = false;
  File? _profileImage;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadLocalProfileImage();
  }

  Future<void> _loadUserData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot doc =
            await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          setState(() {
            userName = data['name'] ?? 'User';
            phoneNumber = data['phoneNumber'] ?? '';
            nameController.text = userName;
            phoneController.text = phoneNumber;
            // Safely handle studentDetails
            _isVerified =
                data.containsKey('studentDetails')
                    ? (data['studentDetails']['isVerified'] ?? false)
                    : false;
            activeAddress =
                data['activeAddress'] ?? '12 Food Street, Metro City';
          });
        }
      } catch (e) {
        print('Error loading user data: $e'); // Log silently, no SnackBar
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadLocalProfileImage() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final imagePath = '${directory.path}/profile_image.jpg';
      final file = File(imagePath);
      if (await file.exists()) {
        setState(() => _profileImage = file);
      }
    } catch (e) {
      print('Error loading local image: $e');
    }
  }

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final directory = await getApplicationDocumentsDirectory();
        final imagePath = '${directory.path}/profile_image.jpg';
        final file = File(pickedFile.path);
        await file.copy(imagePath);
        setState(() => _profileImage = File(imagePath));
      }
    } on PlatformException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: ${e.message}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unexpected error: $e')));
    }
  }

  Future<void> _launchWhatsApp() async {
    const String phone = '+1234567890'; // Replace with your WhatsApp number
    final Uri url = Uri.parse('https://wa.me/$phone');
    try {
      await launchUrl(url);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not launch WhatsApp: $e')));
    }
  }

  Future<void> _launchEmail() async {
    const String email =
        'support@foodapp.com'; // Replace with your support email
    final Uri url = Uri.parse('mailto:$email?subject=Feedback');
    try {
      await launchUrl(url);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not launch email: $e')));
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
          setState(() => _isVerified = result['isVerified'] ?? false);
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

  void _showEditProfileDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Edit Profile'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
            actions: [
              TextButton(
                child: Text('Cancel'),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton(
                child: Text('Save'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade900,
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
                        .update({
                          'name': nameController.text.trim(),
                          'phoneNumber': phoneController.text.trim(),
                        });
                    setState(() {
                      userName = nameController.text.trim();
                      phoneNumber = phoneController.text.trim();
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Profile updated successfully')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to update profile: $e')),
                    );
                  }
                },
              ),
            ],
          ),
    );
  }

  void _navigateToEmployeeLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EmployeeLoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: 250,
                    floating: false,
                    pinned: true,
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade900,
                              Colors.blue.shade600,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: _pickProfileImage,
                              child: CircleAvatar(
                                radius: 60,
                                backgroundImage:
                                    _profileImage != null
                                        ? FileImage(_profileImage!)
                                        : AssetImage('assets/images/on1.png')
                                            as ImageProvider,
                                child: Align(
                                  alignment: Alignment.bottomRight,
                                  child: Container(
                                    padding: EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade900,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.camera_alt,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              userName,
                              style: TextStyle(
                                fontSize: 28,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    color: Colors.black45,
                                    blurRadius: 4,
                                    offset: Offset(2, 2),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              _auth.currentUser?.email ?? '',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildListDelegate([
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          children: [
                            ProfileSectionCard(
                              icon: Icons.person,
                              title: 'Edit Profile',
                              subtitle: 'Update your name and phone number',
                              onTap: _showEditProfileDialog,
                            ),
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
                                      ? 'Verified Student Discount'
                                      : 'Student Discount',
                              subtitle:
                                  _isVerified
                                      ? '10% discount activated'
                                      : 'Verify for 10% off',
                              onTap:
                                  _isVerified ? null : _showVerificationSurvey,
                            ),
                            ProfileSectionCard(
                              icon: Icons.support_agent,
                              title: 'Support',
                              subtitle: 'Chat with us on WhatsApp',
                              onTap: _launchWhatsApp,
                            ),
                            ProfileSectionCard(
                              icon: Icons.feedback,
                              title: 'Feedback',
                              subtitle: 'Send us your thoughts',
                              onTap: _launchEmail,
                            ),
                            ProfileSectionCard(
                              icon: Icons.admin_panel_settings,
                              title: 'Employee Login',
                              subtitle: 'Access admin features',
                              onTap: _navigateToEmployeeLogin,
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
                    ]),
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
  final VoidCallback? onTap;

  const ProfileSectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: Colors.grey[850],
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue.shade900.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.blue.shade900, size: 28),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.grey[400], fontSize: 14),
        ),
        onTap: onTap,
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: Colors.grey[600],
          size: 16,
        ),
      ),
    );
  }
}
