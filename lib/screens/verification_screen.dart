import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/theme.dart';
import '../widgets/GlassSnackBar.dart';
import 'congratulations_screen.dart';

class VerificationScreen extends StatefulWidget {
  @override
  _VerificationScreenState createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  Timer? _verificationTimer;
  bool _isVerified = false;
  bool _isResending = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showInitialSnackbar();
    });
    _startVerificationCheck();
  }

  void _showInitialSnackbar() {
    showGlassSnackBar(
      context: context,
      title: 'Verification Required',
      message: 'Please check your email to verify your account',
      type: 'info',
    );
  }

  @override
  void dispose() {
    _verificationTimer?.cancel();
    super.dispose();
  }

  void _startVerificationCheck() {
    _verificationTimer = Timer.periodic(Duration(seconds: 3), (timer) async {
      await _checkEmailVerification();
    });
  }

  Future<void> _checkEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (mounted) Navigator.pop(context);
        return;
      }

      await user.reload();
      final updatedUser = _auth.currentUser;
      final isVerified = updatedUser?.emailVerified ?? false;

      if (isVerified && !_isVerified) {
        _verificationTimer?.cancel();
        if (mounted) {
          setState(() => _isVerified = true);
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => CongratulationsScreen()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        showGlassSnackBar(
          context: context,
          title: 'Verification Check Failed',
          message:
              e.code == 'network-request-failed'
                  ? 'Internet connection required'
                  : 'Please try again later',
          type: 'error',
        );
      }
    } catch (e) {
      if (mounted) {
        showGlassSnackBar(
          context: context,
          title: 'Error',
          message: 'Failed to check verification status',
          type: 'error',
        );
      }
    }
  }

  Future<void> _resendVerificationEmail() async {
    try {
      setState(() => _isResending = true);
      final user = _auth.currentUser;
      if (user != null) {
        await user.sendEmailVerification();
        showGlassSnackBar(
          context: context,
          title: 'Email Resent',
          message: 'Check your inbox again',
          type: 'info',
        );
      }
    } on FirebaseAuthException catch (e) {
      showGlassSnackBar(
        context: context,
        title: 'Resend Failed',
        message: e.message ?? 'Could not resend verification email',
        type: 'error',
      );
    } catch (e) {
      showGlassSnackBar(
        context: context,
        title: 'Error',
        message: 'An unexpected error occurred',
        type: 'error',
      );
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Email Verification',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: headTextColor, // White text for contrast
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 40),
              _buildProgressIndicator(),
              SizedBox(height: 30),
              Text(
                'check your email to complete the verification, ',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: subHeadTextColor,
                ), // White with opacity for contrast
              ),
              SizedBox(height: 20),
              TextButton(
                onPressed: _isResending ? null : _resendVerificationEmail,
                child:
                    _isResending
                        ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.blue[900], // Blue[900] for progress
                            strokeWidth: 2,
                          ),
                        )
                        : Text(
                          'Resend Verification Email',
                          style: TextStyle(
                            color: Colors.blue[900], // Blue[900] for text
                            fontWeight: FontWeight.w600,
                          ),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return SizedBox(
      width: 200,
      child: LinearProgressIndicator(
        backgroundColor: Colors.blue.shade50,
        minHeight: 8,
        borderRadius: BorderRadius.circular(10),
        valueColor: AlwaysStoppedAnimation<Color>(
          Colors.blue[900]!,
        ), // Blue[900] for progress
      ),
    );
  }
}
