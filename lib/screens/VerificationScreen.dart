import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/GlassSnackBar.dart';
import 'CongratulationsScreen.dart';

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              isDark ? Colors.grey[900]! : Colors.lightBlue[100]!,
              theme.scaffoldBackgroundColor,
            ],
          ),
        ),
        child: Center(
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
                    color: theme.colorScheme.onSurface,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 40),
                _buildGradientProgressIndicator(theme),
                SizedBox(height: 30),
                Text(
                  'We’re automatically checking your verification status...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                SizedBox(height: 20),
                TextButton(
                  onPressed: _isResending ? null : _resendVerificationEmail,
                  child:
                      _isResending
                          ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : Text(
                            'Resend Verification Email',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGradientProgressIndicator(ThemeData theme) {
    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return LinearGradient(
          colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
          stops: [0.0, 1.0],
          tileMode: TileMode.mirror,
        ).createShader(bounds);
      },
      child: SizedBox(
        width: 200,
        child: LinearProgressIndicator(
          backgroundColor: Colors.grey[300],
          minHeight: 8,
          borderRadius: BorderRadius.circular(10),
          valueColor: AlwaysStoppedAnimation<Color>(Colors.transparent),
        ),
      ),
    );
  }
}
