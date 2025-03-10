import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Add the missing Google Sign-In method
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    showGlassSnackBar(
      context: context,
      title: 'Signing In',
      message: 'Connecting with Google...',
      type: 'loading',
    );

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      if (userCredential.user != null) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        showGlassSnackBar(
          context: context,
          title: 'Welcome!',
          message: 'Google Sign-In successful',
          type: 'success',
        );
        Navigator.pushReplacementNamed(context, '/CustomerDashboard');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      showGlassSnackBar(
        context: context,
        title: 'Google Sign-In Failed',
        message: 'Error connecting to Google',
        type: 'error',
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Update the _signInWithEmailAndPassword method
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

      // Check if email is verified
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

  // Add this new method
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
                    color: theme.colorScheme.onSurface,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 40),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildEmailField(theme),
                      SizedBox(height: 20),
                      _buildPasswordField(theme),
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
                            style: TextStyle(color: theme.colorScheme.primary),
                          ),
                        ),
                      ),
                      SizedBox(height: 30),
                      _buildLoginButton(theme),
                      SizedBox(height: 25),
                      _buildGoogleSignInButton(theme, isDark),
                      SizedBox(height: 25),
                      _buildSignupPrompt(theme),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailField(ThemeData theme) {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(
        labelText: 'Email',
        prefixIcon: Icon(Icons.email, color: theme.colorScheme.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: theme.colorScheme.primary),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Please enter your email';
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
          return 'Please enter a valid email';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField(ThemeData theme) {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: 'Password',
        prefixIcon: Icon(Icons.lock, color: theme.colorScheme.primary),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: theme.colorScheme.primary,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Please enter your password';
        if (value.length < 6) return 'Password must be at least 6 characters';
        return null;
      },
    );
  }

  Widget _buildLoginButton(ThemeData theme) {
    return ElevatedButton(
      onPressed: _isLoading ? null : _signInWithEmailAndPassword,
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.primary,
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

  Widget _buildGoogleSignInButton(ThemeData theme, bool isDark) {
    return OutlinedButton(
      onPressed: _isLoading ? null : _signInWithGoogle,
      style: OutlinedButton.styleFrom(
        backgroundColor: isDark ? Colors.grey[800] : Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        side: BorderSide(color: theme.colorScheme.primary),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/images/google.png', height: 24),
          SizedBox(width: 10),
          Text(
            'Sign in with Google',
            style: TextStyle(
              fontSize: 16,
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignupPrompt(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account? ",
          style: TextStyle(color: theme.colorScheme.onSurface),
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
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
