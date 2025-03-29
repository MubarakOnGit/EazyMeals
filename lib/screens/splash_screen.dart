import 'package:eazy_meals/utils/theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key}); // Add const constructor

  @override
  State<SplashScreen> createState() => _SplashScreenState(); // Fix: Use State<SplashScreen>
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _controller.forward().whenComplete(_checkAuthAndMenu);
  }

  Future<String> _getLocalFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/menu.json';
  }

  Future<void> _downloadMenuFile() async {
    try {
      final ref = _storage.ref().child('menus/menu.json');
      final downloadUrl = await ref.getDownloadURL();
      final response = await http.get(Uri.parse(downloadUrl));
      if (response.statusCode == 200) {
        final filePath = await _getLocalFilePath();
        final file = File(filePath);
        await file.writeAsString(response.body);
      }
    } catch (_) {
      // Silently handle errors; app proceeds with local file if available
    }
  }

  Future<Map<String, dynamic>> _loadLocalMenu() async {
    try {
      final filePath = await _getLocalFilePath();
      final file = File(filePath);
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        return jsonDecode(jsonString) as Map<String, dynamic>;
      }
      return {'version': '0.00', 'menus': []};
    } catch (_) {
      return {'version': '0.00', 'menus': []};
    }
  }

  Future<bool> _shouldCheckForUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheckTimestamp = prefs.getInt('last_menu_check') ?? 0;
    final filePath = await _getLocalFilePath();
    final file = File(filePath);

    // Force check if no local file exists (new user)
    if (!await file.exists()) {
      await prefs.setInt(
        'last_menu_check',
        DateTime.now().millisecondsSinceEpoch,
      );
      return true;
    }

    // Check once daily after 12 AM
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final lastCheck = DateTime.fromMillisecondsSinceEpoch(lastCheckTimestamp);

    if (lastCheck.isBefore(todayMidnight) && now.isAfter(todayMidnight)) {
      await prefs.setInt('last_menu_check', now.millisecondsSinceEpoch);
      return true;
    }
    return false;
  }

  Future<void> _checkMenuFile() async {
    if (!await _shouldCheckForUpdate()) return;

    final filePath = await _getLocalFilePath();
    final file = File(filePath);
    final localData = await _loadLocalMenu();
    final localVersion = localData['version'] ?? '0.00';

    try {
      final ref = _storage.ref().child('menus/menu.json');
      final metadata = await ref.getMetadata();
      final remoteVersion = metadata.customMetadata?['version'] ?? '0.00';

      if (!await file.exists() || localVersion != remoteVersion) {
        if (await file.exists()) await file.delete();
        await _downloadMenuFile();
      }
    } catch (_) {
      // Proceed with local file if network fails
    }
  }

  Future<void> _checkAuthAndMenu() async {
    await _checkMenuFile();

    final user = FirebaseAuth.instance.currentUser;
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;

    if (user != null) {
      await user.reload();
      if (user.emailVerified) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/CustomerDashboard');
        }
      } else {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/verification');
        }
      }
    } else {
      if (mounted) {
        if (!hasSeenOnboarding) {
          Navigator.pushReplacementNamed(context, '/onboarding');
        } else {
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: FractionallySizedBox(
                widthFactor: 0.6, // Responsive width (60% of screen)
                heightFactor: 0.6, // Responsive height (60% of screen)
                child: Image.asset(
                  'assets/images/logo_transparent.png',
                  fit: BoxFit.contain, // Ensure logo scales properly
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom:
                  MediaQuery.of(context).size.height *
                  0.05, // Responsive bottom padding
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal:
                      MediaQuery.of(context).size.width *
                      0.1, // Responsive padding
                ),
                child: AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (context, child) {
                    return LinearProgressIndicator(
                      value: _progressAnimation.value,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.blue,
                      ),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(10),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
