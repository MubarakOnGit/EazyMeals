import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/GlassSnackBar.dart';
import 'VerificationScreen.dart';
import 'login_screen.dart';

class SignUpScreen extends StatefulWidget {
  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _agreeToTerms = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_agreeToTerms) {
      showGlassSnackBar(
        context: context,
        title: 'Action Required',
        message: 'Please agree to Privacy Policy & Terms of Use',
        type: 'error',
      );
      return;
    }

    setState(() => _isLoading = true);
    showGlassSnackBar(
      context: context,
      title: 'Creating Account',
      message: 'Please wait while we set up your account',
      type: 'loading',
    );

    try {
      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      await userCredential.user!.sendEmailVerification();

      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'createdAt': Timestamp.now(),
        'isVerified': false,
      });

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      showGlassSnackBar(
        context: context,
        title: 'Verification Sent!',
        message: 'Check your email to verify your account',
        type: 'success',
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => VerificationScreen()),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      String message = e.message ?? 'An error occurred';

      if (e.code == 'email-already-in-use') {
        message = await _handleExistingAccount(_emailController.text.trim());
      }

      showGlassSnackBar(
        context: context,
        title: 'Sign Up Failed',
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
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<String> _handleExistingAccount(String email) async {
    try {
      final methods = await _auth.fetchSignInMethodsForEmail(email);

      if (methods.contains('password')) {
        final tempUser = await _auth.signInWithEmailAndPassword(
          email: email,
          password: _passwordController.text.trim(),
        );

        if (!tempUser.user!.emailVerified) {
          await tempUser.user!.sendEmailVerification();
          await _auth.signOut();
          return 'Verification email resent. Please check your inbox.';
        }
        return 'Account already exists. Please login instead.';
      }
      return 'Account exists with different sign-in method.';
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        return 'Account exists with different credentials.';
      }
      return 'Account verification failed. Please try again.';
    } catch (e) {
      return 'Could not verify existing account.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Create Account',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 40),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildNameField(),
                    SizedBox(height: 20),
                    _buildEmailField(),
                    SizedBox(height: 20),
                    _buildPhoneField(),
                    SizedBox(height: 20),
                    _buildPasswordField(),
                    SizedBox(height: 20),
                    Row(
                      children: [
                        Checkbox(
                          value: _agreeToTerms,
                          onChanged: (value) {
                            setState(() => _agreeToTerms = value ?? false);
                          },
                          activeColor: Colors.blue[900],
                          checkColor: Colors.white,
                        ),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                              ),
                              children: [
                                TextSpan(text: 'I agree to the '),
                                TextSpan(
                                  text: 'Privacy Policy',
                                  style: TextStyle(
                                    color: Colors.blue[900],
                                    decoration: TextDecoration.underline,
                                  ),
                                  recognizer:
                                      TapGestureRecognizer()
                                        ..onTap = () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (context) =>
                                                      PrivacyPolicyScreen(),
                                            ),
                                          );
                                        },
                                ),
                                TextSpan(text: ' & '),
                                TextSpan(
                                  text: 'Terms of Use',
                                  style: TextStyle(
                                    color: Colors.blue[900],
                                    decoration: TextDecoration.underline,
                                  ),
                                  recognizer:
                                      TapGestureRecognizer()
                                        ..onTap = () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (context) =>
                                                      TermsOfUseScreen(),
                                            ),
                                          );
                                        },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 30),
                    _buildSignUpButton(),
                    SizedBox(height: 25),
                    _buildLoginPrompt(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      decoration: InputDecoration(
        labelText: 'Full Name',
        labelStyle: TextStyle(color: Colors.grey),
        prefixIcon: Icon(Icons.person, color: Colors.blue[900]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.blue[900]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey),
        ),
      ),
      style: TextStyle(color: Colors.white),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Please enter your name';
        return null;
      },
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(
        labelText: 'Email',
        labelStyle: TextStyle(color: Colors.grey),
        prefixIcon: Icon(Icons.email, color: Colors.blue[900]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.blue[900]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey),
        ),
      ),
      style: TextStyle(color: Colors.white),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Please enter your email';
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
          return 'Please enter a valid email';
        }
        return null;
      },
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      decoration: InputDecoration(
        labelText: 'Phone Number',
        labelStyle: TextStyle(color: Colors.grey),
        prefixIcon: Icon(Icons.phone, color: Colors.blue[900]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.blue[900]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey),
        ),
      ),
      style: TextStyle(color: Colors.white),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your phone number';
        }
        if (!RegExp(r'^[0-9]{9}$').hasMatch(value)) {
          return 'Please enter a valid 9-digit Georgian phone number';
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
        labelStyle: TextStyle(color: Colors.grey),
        prefixIcon: Icon(Icons.lock, color: Colors.blue[900]),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: Colors.blue[900],
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.blue[900]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey),
        ),
      ),
      style: TextStyle(color: Colors.white),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Please enter your password';
        if (value.length < 6) return 'Password must be at least 6 characters';
        return null;
      },
    );
  }

  Widget _buildSignUpButton() {
    return ElevatedButton(
      onPressed: _agreeToTerms ? (_isLoading ? null : _signUp) : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: _agreeToTerms ? Colors.blue[900] : Colors.grey,
        padding: EdgeInsets.symmetric(horizontal: 50, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
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
                'Sign Up',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
    );
  }

  Widget _buildLoginPrompt() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Already have an account? ",
          style: TextStyle(color: Colors.white),
        ),
        TextButton(
          onPressed:
              () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => LoginScreen()),
              ),
          child: Text(
            'Login',
            style: TextStyle(
              color: Colors.blue[900],
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// New Privacy Policy Screen
class PrivacyPolicyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Privacy Policy',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy Policy',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'This is a dummy Privacy Policy for demonstration purposes:\n\n'
              '1. **Data Collection**: We collect your name, email, and phone number '
              'to provide you with our services.\n\n'
              '2. **Usage**: Your data is used solely for account creation, verification, '
              'and communication purposes.\n\n'
              '3. **Security**: We implement reasonable measures to protect your '
              'personal information from unauthorized access.\n\n'
              '4. **Sharing**: We do not share your data with third parties without '
              'your consent, except as required by law.\n\n'
              '5. **Updates**: This policy may be updated periodically, and you will '
              'be notified of significant changes.',
              style: TextStyle(fontSize: 16, color: Colors.white, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// New Terms of Use Screen
class TermsOfUseScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Terms of Use',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Terms of Use',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'This is a dummy Terms of Use for demonstration purposes:\n\n'
              '1. **Acceptance**: By using our service, you agree to these terms.\n\n'
              '2. **Eligibility**: You must be at least 18 years old to use this service.\n\n'
              '3. **Account Responsibility**: You are responsible for maintaining the '
              'confidentiality of your account credentials.\n\n'
              '4. **Prohibited Actions**: You may not use our service for illegal activities '
              'or to harm others.\n\n'
              '5. **Termination**: We reserve the right to terminate your account for '
              'violating these terms.',
              style: TextStyle(fontSize: 16, color: Colors.white, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
