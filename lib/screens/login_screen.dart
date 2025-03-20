import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/GlassSnackBar.dart';
import 'VerificationScreen.dart';
import 'forgot_password_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _signInWithEmailAndPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    showGlassSnackBar(
      context: context,
      title: 'Signing In',
      message: 'Authenticating your credentials',
      type: 'loading',
    );

    try {
      final UserCredential userCredential = await _auth
          .signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      if (!userCredential.user!.emailVerified) {
        await _handleUnverifiedUser(userCredential.user!);
        return;
      }

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      showGlassSnackBar(
        context: context,
        title: 'Welcome Back!',
        message: 'Successfully logged in',
        type: 'success',
      );

      Navigator.pushReplacementNamed(context, '/CustomerDashboard');
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      String message = e.message ?? 'Invalid email or password';

      if (e.code == 'user-not-found') {
        message = 'No account found for this email';
      } else if (e.code == 'wrong-password') {
        message = 'Incorrect password';
      }

      showGlassSnackBar(
        context: context,
        title: 'Login Failed',
        message: message,
        type: 'error',
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleUnverifiedUser(User user) async {
    try {
      await user.reload();
      final updatedUser = _auth.currentUser;

      if (updatedUser != null && !updatedUser.emailVerified) {
        await updatedUser.sendEmailVerification();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => VerificationScreen()),
        );
      }
    } catch (e) {
      showGlassSnackBar(
        context: context,
        title: 'Verification Error',
        message: 'Failed to resend verification email',
        type: 'error',
      );
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
                'Welcome Back!',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white, // White text for contrast
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 40),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildEmailField(),
                    SizedBox(height: 20),
                    _buildPasswordField(),
                    SizedBox(height: 15),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ForgotPasswordScreen(),
                            ),
                          );
                        },
                        child: Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: Colors.blue[900],
                          ), // Blue[900] for text button
                        ),
                      ),
                    ),
                    SizedBox(height: 30),
                    _buildLoginButton(),
                    SizedBox(height: 25),
                    _buildSignupPrompt(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(
        labelText: 'Email',
        labelStyle: TextStyle(color: Colors.grey), // Grey label for contrast
        prefixIcon: Icon(
          Icons.email,
          color: Colors.blue[900],
        ), // Blue[900] icon
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
      validator: (value) {
        if (value == null || value.isEmpty) return 'Please enter your email';
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
          return 'Please enter a valid email';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: 'Password',
        labelStyle: TextStyle(color: Colors.grey), // Grey label for contrast
        prefixIcon: Icon(Icons.lock, color: Colors.blue[900]), // Blue[900] icon
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: Colors.blue[900], // Blue[900] icon
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
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
      validator: (value) {
        if (value == null || value.isEmpty) return 'Please enter your password';
        if (value.length < 6) return 'Password must be at least 6 characters';
        return null;
      },
    );
  }

  Widget _buildLoginButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _signInWithEmailAndPassword,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue[900], // Blue[900] button color
        padding: EdgeInsets.symmetric(horizontal: 50, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      child: Text(
        'Login',
        style: TextStyle(
          fontSize: 18,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSignupPrompt() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account? ",
          style: TextStyle(color: Colors.white), // White text for contrast
        ),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => SignUpScreen()),
            );
          },
          child: Text(
            'Sign Up',
            style: TextStyle(
              color: Colors.blue[900], // Blue[900] for sign-up text
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
