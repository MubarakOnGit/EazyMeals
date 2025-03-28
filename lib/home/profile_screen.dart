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
import 'base_state.dart';
import 'package:get/get.dart';
import 'package:eazy_meals/controllers/profile_controller.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends BaseState<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final ProfileController profileController = Get.find<ProfileController>();
  String _activeAddress = 'Add Your Address and Set Active';
  String _userName = '';
  String _phoneNumber = '';
  bool _isLoading = true;
  bool _isVerified = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    profileController.loadProfileImage();
  }

  Future<void> _loadUserData() async {
    final user = currentUser;
    if (user != null) {
      try {
        final doc = await firestore.collection('users').doc(user.uid).get();
        if (doc.exists && mounted) {
          final data = doc.data() ?? {};
          setState(() {
            _userName = data['name'] ?? 'User';
            _phoneNumber = data['phoneNumber'] ?? '';
            _nameController.text = _userName;
            _phoneController.text = _phoneNumber;
            _isVerified =
                data['studentDetails']?['isVerified'] as bool? ?? false;
            _activeAddress = data['activeAddress'] ?? 'Manage your addresses';
          });
        }
      } catch (e) {
        debugPrint('Error loading user data: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
      );
      if (pickedFile != null) {
        await profileController.updateProfileImage(File(pickedFile.path));
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  Future<void> _launchWhatsApp() async {
    const phone = '+995500900095';
    final url = Uri.parse('https://wa.me/$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch WhatsApp')),
      );
    }
  }

  Future<void> _launchEmail() async {
    const email = 'eazy.24@yandex.com';
    final url = Uri.parse('mailto:$email?subject=Feedback');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not launch email')));
    }
  }

  Future<void> _showVerificationSurvey() async {
    final currentContext = context;
    final result = await Navigator.push(
      currentContext,
      MaterialPageRoute(builder: (_) => StudentVerificationSurvey()),
    );

    if (result == null || !mounted) return;

    final user = currentUser;
    if (user == null) return;

    try {
      await firestore.collection('users').doc(user.uid).update({
        'studentDetails': result,
      });

      if (!mounted) return;
      setState(() => _isVerified = result['isVerified'] ?? false);

      if (!currentContext.mounted) return;
      ScaffoldMessenger.of(currentContext).showSnackBar(
        const SnackBar(content: Text('Student verification submitted!')),
      );
    } catch (e) {
      if (!currentContext.mounted) return;
      ScaffoldMessenger.of(currentContext).showSnackBar(
        SnackBar(content: Text('Failed to submit verification: $e')),
      );
    }
  }

  Future<void> _logout() async {
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: Colors.white,
            title: Text(
              'Confirm Logout',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue[900],
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
                  style: TextStyle(color: Colors.blue[900]),
                ),
                onPressed: () => Navigator.pop(context, false),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[900],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Logout'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      await logout();
      if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
    }
  }

  Future<void> _showEditProfileDialog() async {
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: Colors.white,
            title: Text(
              'Edit Profile',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue[900],
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: Icon(Icons.person, color: Colors.blue[900]),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: Icon(Icons.phone, color: Colors.blue[900]),
                  ),
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
            actions: [
              TextButton(
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.blue[900]),
                ),
                onPressed: () => Navigator.pop(context, false),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[900],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(color: Colors.white),
                ),
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
    );

    if (confirm == true && mounted) {
      if (_nameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Name cannot be empty')));
        return;
      }
      try {
        await firestore.collection('users').doc(currentUser!.uid).update({
              'name': _nameController.text.trim(),
              'phoneNumber': _phoneController.text.trim(),
            });
        if (mounted) {
          setState(() {
            _userName = _nameController.text.trim();
            _phoneNumber = _phoneController.text.trim();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update profile: $e')),
          );
        }
      }
    }
  }

  void _navigateToMealPreferences(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SubscriptionScreen()),
    );
  }

  void _navigateToAddressManagement(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddressManagementScreen()),
    ).then((_) => _loadUserData());
  }

  void _navigateToStudentVerification(BuildContext context) {
    if (_isVerified) return;
    _showVerificationSurvey();
  }

  Future<void> _launchHelpSupport() async {
    const phone = '+995500900095';
    final url = Uri.parse('https://wa.me/$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch WhatsApp')),
      );
    }
  }

  void _navigateToEmployeeLogin(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EmployeeLoginScreen()),
    );
  }

  @override
  void onOrderUpdate(QuerySnapshot snapshot) {
    if (mounted) {
      setState(() {
        // Update UI based on order changes
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body:
          _isLoading
              ? Center(
                child: CircularProgressIndicator(color: Colors.blue[900]),
              )
              : Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.blue[900]!.withAlpha(13),
                          backgroundColor,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  CustomScrollView(
                    physics: const BouncingScrollPhysics(),
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
                                colors: [Colors.blue[900]!, Colors.blue[700]!],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(30),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                GestureDetector(
                                  onTap: _pickProfileImage,
                                  child: GetX<ProfileController>(
                                    builder:
                                        (controller) => AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
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
                                                color: Colors.black.withAlpha(
                                                  51,
                                                ),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                            ],
                                      image: DecorationImage(
                                        image:
                                                  controller
                                                              .profileImage
                                                              .value !=
                                                          null
                                                      ? FileImage(
                                                        controller
                                                            .profileImage
                                                            .value!,
                                                      )
                                                : const AssetImage(
                                                      'assets/profile_pic.jpg',
                                                    )
                                                    as ImageProvider,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    child: Align(
                                      alignment: Alignment.bottomRight,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        margin: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.blue[900],
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 1,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.camera_alt,
                                          color: Colors.white,
                                          size: 18,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _userName,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  currentUser?.email ?? '',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white.withAlpha(179),
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
                          padding: const EdgeInsets.symmetric(
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
                              const SizedBox(height: 16),
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
                                onTap:
                                    () => _navigateToMealPreferences(context),
                              ),
                              ProfileCard(
                                icon: Icons.location_on,
                                title: 'Address',
                                subtitle: _activeAddress,
                                onTap:
                                    () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) =>
                                                const AddressManagementScreen(),
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
                                        ? const Icon(
                                          Icons.check_circle,
                                          color: Colors.green,
                                        )
                                        : null,
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Support & More',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: headTextColor,
                                ),
                              ),
                              const SizedBox(height: 16),
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
                                onTap: () => _navigateToEmployeeLogin(context),
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
    super.key,
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
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              onTap != null
                  ? [Colors.blue[900]!, Colors.blue[700]!]
                  : [Colors.blue[900]!, Colors.blue[700]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ], // 0.1 -> 26
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                  ), // 0.1 -> 26
                  child: Icon(icon, color: color ?? Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withAlpha(179),
                        ), // 0.7 -> 179
                      ),
                    ],
                  ),
                ),
                trailing ??
                    (onTap != null
                        ? Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white.withAlpha(179),
                          size: 16,
                        )
                        : const SizedBox()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
