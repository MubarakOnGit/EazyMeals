import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../delivery/delivery_screen.dart';

class EmployeeLoginScreen extends StatefulWidget {
  @override
  _EmployeeLoginScreenState createState() => _EmployeeLoginScreenState();
}

class _EmployeeLoginScreenState extends State<EmployeeLoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context); // Navigate back if possible
            } else {}
          },
        ),
        title: Text(
          'Delivery Guy Login',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Your Email',
                hintText: 'Enter your registered email',
                labelStyle: TextStyle(color: Colors.grey[400]),
                hintStyle: TextStyle(color: Colors.grey[600]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.blue.shade600),
                ),
                prefixIcon: Icon(Icons.email, color: Colors.blue.shade900),
              ),
              style: TextStyle(color: Colors.white),
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 32),
            _isLoading
                ? CircularProgressIndicator(color: Colors.blue.shade900)
                : ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade900,
                    padding: EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  child: Text(
                    'Login',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  void _login() async {
    final email = _emailController.text.trim();
    final user = _auth.currentUser;

    if (email.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please enter your email')));
      return;
    }

    if (user == null || email != user.email) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please use your logged-in email')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      DocumentSnapshot deliveryDoc =
          await _firestore.collection('delivery_guys').doc(email).get();
      if (!deliveryDoc.exists) {
        await _firestore.collection('delivery_guys').doc(email).set({
          'email': email,
          'name': 'Delivery Guy',
          'verified': false,
          'lastVerified': null,
          'isOnline': false,
        }, SetOptions(merge: true));
        print('Created new delivery guy entry for $email');
      }

      final data = deliveryDoc.data() as Map<String, dynamic>? ?? {};
      final isVerified = data['verified'] as bool? ?? false;

      if (!isVerified) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => WaitingForVerificationScreen(email: email),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => DeliveryScreen(email: email)),
        );
      }
    } catch (e) {
      print('Login error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Login failed: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }
}

class WaitingForVerificationScreen extends StatelessWidget {
  final String email;

  const WaitingForVerificationScreen({required this.email});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context); // Navigate back if possible
            } else {}
          },
        ),
        title: Text(
          'Verification Pending',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_empty, size: 80, color: Colors.blue.shade600),
            SizedBox(height: 32),
            Text(
              'Waiting for Verification',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Text(
              'Your account ($email) is under review. Please wait for admin approval.',
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade900,
                padding: EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              child: Text(
                'Back',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
