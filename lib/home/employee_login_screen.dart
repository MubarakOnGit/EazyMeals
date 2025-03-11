import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../delivery/delivery_screen.dart';

class EmployeeLoginScreen extends StatefulWidget {
  @override
  _EmployeeLoginScreenState createState() => _EmployeeLoginScreenState();
}

class _EmployeeLoginScreenState extends State<EmployeeLoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Delivery Guy Login')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 20),
            _isLoading
                ? CircularProgressIndicator()
                : ElevatedButton(onPressed: _login, child: Text('Login')),
          ],
        ),
      ),
    );
  }

  void _login() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please enter your email')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Check if delivery guy exists, create if not
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
      } else {
        print('Delivery guy $email already exists: ${deliveryDoc.data()}');
      }

      // Navigate to DeliveryScreen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => DeliveryScreen(email: email)),
      );
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
