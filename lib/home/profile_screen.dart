import 'dart:io';
import 'package:eazy_meals/utils/theme.dart';
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
import 'employee_login_screen.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  String activeAddress = 'Add Your Address and Set Active';
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
            _isVerified =
                data.containsKey('studentDetails')
                    ? (data['studentDetails']['isVerified'] ?? false)
                    : false;
            activeAddress = data['activeAddress'] ?? 'Manage your addresses';
          });
        }
      } catch (e) {
        print('Error loading user data: $e');
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
    const String phone = '+995500900095';
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
    const String email = 'eazy.24@yandex.com';
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
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: Colors.white,
            title: Text(
              'Confirm Logout',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade900,
              ),
            ),
            content: Text(
              'Are you sure you want to logout?',
              style: TextStyle(color: Colors.grey[800]),
            ),
            actions: [
              TextButton(
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.blue.shade900),
                ),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade900,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('Logout', style: TextStyle(color: Colors.white)),
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    await _auth.signOut();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => LoginScreen()),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to logout: $e')),
                    );
                  }
                },
              ),
            ],
          ),
    );
  }

  void _showEditProfileDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: Colors.white,
            title: Text(
              'Edit Profile',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade900,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: Icon(Icons.person, color: Colors.blue.shade900),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: Icon(Icons.phone, color: Colors.blue.shade900),
                  ),
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
            actions: [
              TextButton(
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.blue.shade900),
                ),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton(
                child: Text('Save', style: TextStyle(color: Colors.white)),
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
      backgroundColor: backgroundColor,
      body:
          _isLoading
              ? Center(
                child: CircularProgressIndicator(color: Colors.blue.shade900),
              )
              : Stack(
                children: [
                  // Background gradient
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.blue.shade900.withOpacity(0.05),
                          backgroundColor,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  CustomScrollView(
                    physics: BouncingScrollPhysics(),
                    slivers: [
                      SliverAppBar(
                        expandedHeight: 280,
                        floating: false,
                        pinned: true,
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        flexibleSpace: FlexibleSpaceBar(
                          background: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.shade900,
                                  Colors.blue.shade700,
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.vertical(
                                bottom: Radius.circular(30),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                GestureDetector(
                                  onTap: _pickProfileImage,
                                  child: AnimatedContainer(
                                    duration: Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 3,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 10,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                      image: DecorationImage(
                                        image:
                                            _profileImage != null
                                                ? FileImage(_profileImage!)
                                                : AssetImage(
                                                      'assets/profile_pic.jpg',
                                                    )
                                                    as ImageProvider,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    child: Align(
                                      alignment: Alignment.bottomRight,
                                      child: Container(
                                        padding: EdgeInsets.all(6),
                                        margin: EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade900,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 1,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.camera_alt,
                                          color: Colors.white,
                                          size: 18,
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
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  _auth.currentUser?.email ?? '',
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
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 24,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Account Settings',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: headTextColor,
                                ),
                              ),
                              SizedBox(height: 16),
                              ProfileCard(
                                icon: Icons.person,
                                title: 'Edit Profile',
                                subtitle: 'Update your name and phone number',
                                onTap: _showEditProfileDialog,
                              ),
                              ProfileCard(
                                icon: Icons.restaurant_menu,
                                title: 'Meal Plan',
                                subtitle: 'Premium Weekly Subscription',
                                onTap: _navigateToMealPreferences,
                              ),
                              ProfileCard(
                                icon: Icons.location_on,
                                title: 'Address',
                                subtitle: activeAddress,
                                onTap:
                                    () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) =>
                                                AddressManagementScreen(),
                                      ),
                                    ).then((_) => _loadUserData()),
                              ),
                              ProfileCard(
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
                                    _isVerified
                                        ? null
                                        : _showVerificationSurvey,
                                trailing:
                                    _isVerified
                                        ? Icon(
                                          Icons.check_circle,
                                          color: Colors.green,
                                        )
                                        : null,
                              ),
                              SizedBox(height: 24),
                              Text(
                                'Support & More',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: headTextColor,
                                ),
                              ),
                              SizedBox(height: 16),
                              ProfileCard(
                                icon: Icons.support_agent,
                                title: 'Support',
                                subtitle: 'Chat with us on WhatsApp',
                                onTap: _launchWhatsApp,
                              ),
                              ProfileCard(
                                icon: Icons.feedback,
                                title: 'Feedback',
                                subtitle: 'Send us your thoughts',
                                onTap: _launchEmail,
                              ),
                              ProfileCard(
                                icon: Icons.admin_panel_settings,
                                title: 'Employee Login',
                                subtitle: 'Access admin features',
                                onTap: _navigateToEmployeeLogin,
                              ),
                              ProfileCard(
                                icon: Icons.logout,
                                title: 'Logout',
                                subtitle: 'Sign out of your account',
                                onTap: _logout,
                                color: Colors.redAccent,
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

class ProfileCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color? color;
  final Widget? trailing;

  const ProfileCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.color,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              onTap != null
                  ? [Colors.blue.shade900, Colors.blue.shade700]
                  : [Colors.grey.shade700, Colors.grey.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color ?? Colors.white, size: 28),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 14, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                trailing ??
                    (onTap != null
                        ? Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white70,
                          size: 16,
                        )
                        : SizedBox()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
