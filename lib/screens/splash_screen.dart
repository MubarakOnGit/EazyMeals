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
  @override
  _SplashScreenState createState() => _SplashScreenState();
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
      duration: Duration(seconds: 3),
      vsync: this,
    );
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _controller.forward().whenComplete(() => _checkAuthAndMenu());
  }

  Future<String> _getLocalFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/menu.json';
  }

  Future<void> _downloadMenuFile() async {
    try {
      Reference ref = _storage.ref().child('menus/menu.json');
      String downloadUrl = await ref.getDownloadURL();
      final response = await http.get(Uri.parse(downloadUrl));
      if (response.statusCode == 200) {
        final filePath = await _getLocalFilePath();
        final file = File(filePath);
        await file.writeAsString(response.body);
      } else {}
    } catch (e) {}
  }

  Future<Map<String, dynamic>> _loadLocalMenu() async {
    try {
      final filePath = await _getLocalFilePath();
      final file = File(filePath);
      if (await file.exists()) {
        String jsonString = await file.readAsString();
        return jsonDecode(jsonString);
      }
      return {'version': '0.00', 'menus': []};
    } catch (e) {
      print('Error loading local menu: $e');
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

    // Otherwise, check once daily after 12 AM
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day, 0, 0);
    final lastCheck = DateTime.fromMillisecondsSinceEpoch(lastCheckTimestamp);

    if (lastCheck.isBefore(todayMidnight) && now.isAfter(todayMidnight)) {
      await prefs.setInt('last_menu_check', now.millisecondsSinceEpoch);
      return true;
    }
    return false;
  }

  Future<void> _checkMenuFile() async {
    if (!await _shouldCheckForUpdate()) {
      return;
    }

    final filePath = await _getLocalFilePath();
    final file = File(filePath);

    // Load local version
    Map<String, dynamic> localData = await _loadLocalMenu();
    String localVersion = localData['version'] ?? '0.00';

    // Check remote version via metadata
    try {
      Reference ref = _storage.ref().child('menus/menu.json');
      FullMetadata metadata = await ref.getMetadata();
      String remoteVersion = metadata.customMetadata?['version'] ?? '0.00';

      // Compare versions and update if needed
      if (!await file.exists() || localVersion != remoteVersion) {
        print(
          'Local version ($localVersion) differs from remote ($remoteVersion), downloading update...',
        );
        if (await file.exists()) await file.delete();
        await _downloadMenuFile();
      } else {
        print('Menu is up-to-date (version $localVersion)');
      }
    } catch (e) {
      print('Error checking menu file version: $e');
      // Proceed with local file if offline or error occurs
    }
  }

  Future<void> _checkAuthAndMenu() async {
    await _checkMenuFile();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await user.reload();
      if (user.emailVerified) {
        Navigator.pushReplacementNamed(context, '/CustomerDashboard');
      } else {
        Navigator.pushReplacementNamed(context, '/verification');
      }
    } else {
      Navigator.pushReplacementNamed(context, '/onboarding');
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
      body: Stack(
        children: [
          Center(
            child: Image.asset(
              'assets/images/logo.png',
              width: 300,
              height: 300,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 20,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: AnimatedBuilder(
                animation: _progressAnimation,
                builder: (context, child) {
                  return LinearProgressIndicator(
                    value: _progressAnimation.value,
                    backgroundColor: Colors.white24,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(10),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
