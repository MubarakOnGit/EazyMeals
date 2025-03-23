import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../utils/theme.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    // Set up animation controller for 3 seconds
    _controller = AnimationController(
      duration: Duration(seconds: 3),
      vsync: this,
    );
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    // Start the animation and check auth state
    _controller.forward().whenComplete(() => _checkAuthState());

    // Ensure animation completes before navigation
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _checkAuthState();
      }
    });
  }

  Future<void> _checkAuthState() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      await user.reload(); // Ensure the latest user state
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
              width: 300, // Adjust size as needed
              height: 300,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 20, // Place at the bottom
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: AnimatedBuilder(
                animation: _progressAnimation,
                builder: (context, child) {
                  return LinearProgressIndicator(
                    value: _progressAnimation.value, // Progress from 0 to 1
                    backgroundColor: Colors.white24, // Darker grey for contrast
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.blue,
                    ), // Blue[900] progress
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
