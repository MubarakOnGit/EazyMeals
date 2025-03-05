import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../screens/login_screen.dart';
import 'address_management_screen.dart';
import 'student_verification_survey.dart';
import 'feedback_dialog.dart';
import 'meal_preferences_screen.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final List<String> profilePics = [
    'assets/images/on1.png',
    'assets/images/on3.png',
    'assets/images/on1.png',
    'assets/images/on2.png',
    'assets/images/on1.png',
  ];
  int selectedPicIndex = 0;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController nameController = TextEditingController();
  String activeAddress = '12 Food Street, Metro City'; // Dummy address
  String userName = '';
  final PageController _pageController = PageController();
  bool _isLoading = true;
  bool _isVerified = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
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
            selectedPicIndex = doc['profilePicIndex'] ?? 0;
            _isVerified = doc['studentDetails']?['isVerified'] ?? false;
            activeAddress =
                doc['activeAddress'] ?? '12 Food Street, Metro City';
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_pageController.hasClients) {
              _pageController.jumpToPage(selectedPicIndex);
            }
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

  Future<void> _updateProfilePic(int index) async {
    setState(() => selectedPicIndex = index);
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).update({
          'profilePicIndex': index,
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile picture: $e')),
        );
      }
    }
  }

  void _navigateToMealPreferences() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MealPreferencesScreen()),
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
                  backgroundColor: Colors.purple,
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
                  // Header Section
                  Container(
                    height: 320,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.deepPurple, Colors.purpleAccent],
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
                        SizedBox(
                          height: 130,
                          width: MediaQuery.of(context).size.width,
                          child: GestureDetector(
                            onHorizontalDragUpdate: (details) {
                              if (details.delta.dx > 0 &&
                                  selectedPicIndex > 0) {
                                _pageController.previousPage(
                                  duration: Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              } else if (details.delta.dx < 0 &&
                                  selectedPicIndex < profilePics.length - 1) {
                                _pageController.nextPage(
                                  duration: Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              }
                            },
                            child: PageView.builder(
                              controller: _pageController,
                              itemCount: profilePics.length,
                              onPageChanged:
                                  (index) => _updateProfilePic(index),
                              itemBuilder: (context, index) {
                                return Center(
                                  child: CircleAvatar(
                                    radius: 60,
                                    backgroundImage: AssetImage(
                                      profilePics[index],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(profilePics.length, (index) {
                            return Container(
                              width: 8,
                              height: 8,
                              margin: EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color:
                                    selectedPicIndex == index
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.4),
                              ),
                            );
                          }),
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
                            subtitle:
                                activeAddress, // Display the active address
                            trailing: Icon(Icons.edit, color: Colors.purple),
                            onTap: () {
                              // Navigate to AddressManagementScreen
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => AddressManagementScreen(),
                                ),
                              ).then((_) {
                                // Refresh the profile screen when returning from AddressManagementScreen
                                _loadUserData();
                              });
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
                    color: Colors.purple,
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
        color: Colors.purple.withOpacity(0.1),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.purple),
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
                  backgroundColor: Colors.purple,
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
      margin: EdgeInsets.only(
        bottom: 10,
      ), // Fixed typo: 'bottom' instead of 'custom'
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.purple),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[600])),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}
