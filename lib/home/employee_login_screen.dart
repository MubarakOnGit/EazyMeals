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
      backgroundColor: Colors.grey.shade100,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.shade900.withOpacity(0.05),
                  Colors.grey.shade100,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          CustomScrollView(
            physics: BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(context),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildEmailCard(),
                      SizedBox(height: 32),
                      _buildLoginButton(context), // Pass context here
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade900, Colors.blue.shade700],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delivery_dining, size: 60, color: Colors.white),
                SizedBox(height: 16),
                Text(
                  'Delivery Guy Login',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Sign in to start delivering',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailCard() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade900.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.email, color: Colors.blue.shade900, size: 20),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Email',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade900,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Enter your registered email',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 12),
          TextField(
            controller: _emailController,
            decoration: InputDecoration(
              hintText: 'e.g., delivery@example.com',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(
                vertical: 14,
                horizontal: 16,
              ),
              prefixIcon: Icon(Icons.email, color: Colors.blue.shade900),
            ),
            style: TextStyle(color: Colors.blue.shade900),
            keyboardType: TextInputType.emailAddress,
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton(BuildContext context) {
    // Add context parameter
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      width: double.infinity,
      child:
          _isLoading
              ? Center(
                child: CircularProgressIndicator(color: Colors.blue.shade900),
              )
              : ElevatedButton(
                onPressed: () => _login(context), // Pass context to _login
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  backgroundColor: Colors.blue.shade900,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 8,
                  shadowColor: Colors.blue.withOpacity(0.3),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.login, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  void _login(BuildContext context) async {
    // Add context parameter
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
      backgroundColor: Colors.grey.shade100,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.shade900.withOpacity(0.05),
                  Colors.grey.shade100,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          CustomScrollView(
            physics: BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(context),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildVerificationCard(),
                      SizedBox(height: 32),
                      _buildBackButton(context), // Pass context here
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade900, Colors.blue.shade700],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.hourglass_empty, size: 60, color: Colors.white),
                SizedBox(height: 16),
                Text(
                  'Verification Pending',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Awaiting admin approval',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationCard() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.hourglass_empty, size: 80, color: Colors.blue.shade900),
          SizedBox(height: 24),
          Text(
            'Waiting for Verification',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.blue.shade900,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          Text(
            'Your account ($email) is under review. Please wait for admin approval.',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    // Add context parameter
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => Navigator.pop(context),
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: 18),
          backgroundColor: Colors.blue.shade900,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 8,
          shadowColor: Colors.blue.withOpacity(0.3),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.arrow_back, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'Back',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
