import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/GlassSnackBar.dart';

class ForgotPasswordScreen extends StatefulWidget {
  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  Future<void> _sendPasswordResetEmail() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      showGlassSnackBar(
        context: context,
        title: 'Error',
        message: 'Please enter your email',
        type: 'error',
      );
      return;
    }

    setState(() => _isLoading = true);
    showGlassSnackBar(
      context: context,
      title: 'Sending Email',
      message: 'Please wait while we send reset instructions',
      type: 'loading',
    );

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      showGlassSnackBar(
        context: context,
        title: 'Email Sent',
        message: 'Check your inbox for password reset instructions',
        type: 'success',
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      String message;

      switch (e.code) {
        case 'user-not-found':
          message = 'No account found with this email';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email address';
          break;
        case 'auth/invalid-email':
          message = 'The email address is invalid';
          break;
        case 'auth/user-disabled':
          message = 'This account has been disabled';
          break;
        default:
          message = 'Failed to send reset email: ${e.message}';
      }

      showGlassSnackBar(
        context: context,
        title: 'Error',
        message: message,
        type: 'error',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      showGlassSnackBar(
        context: context,
        title: 'Error',
        message: 'An unexpected error occurred',
        type: 'error',
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900], // Fixed grey[900] background
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Forgot Password',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white, // White text for contrast
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Enter your email to reset your password',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(
                    0.7,
                  ), // White with opacity for contrast
                ),
              ),
              SizedBox(height: 40),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(
                    color: Colors.grey,
                  ), // Grey label for contrast
                  prefixIcon: Icon(
                    Icons.email,
                    color: Colors.blue[900], // Blue[900] icon
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(
                      color: Colors.blue[900]!,
                    ), // Blue[900] focus border
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                ),
                style: TextStyle(color: Colors.white), // White text input
              ),
              SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isLoading ? null : _sendPasswordResetEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[900], // Blue[900] button color
                  padding: EdgeInsets.symmetric(horizontal: 50, vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child:
                    _isLoading
                        ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : Text(
                          'Reset Password',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
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
}
