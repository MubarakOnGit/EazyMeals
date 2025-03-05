// lib/employee_login_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../delivery/delivery_screen.dart';
import '../manager/manager_screen.dart';

class EmployeeLoginScreen extends StatefulWidget {
  @override
  _EmployeeLoginScreenState createState() => _EmployeeLoginScreenState();
}

class _EmployeeLoginScreenState extends State<EmployeeLoginScreen> {
  String _selectedRole = 'Manager';
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  final List<String> _roles = ['Manager', 'Delivery Guy', 'Other Employee'];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Employee Login')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _selectedRole,
              decoration: InputDecoration(labelText: 'Select Role'),
              items:
                  _roles
                      .map(
                        (role) =>
                            DropdownMenuItem(value: role, child: Text(role)),
                      )
                      .toList(),
              onChanged: (value) {
                setState(() => _selectedRole = value!);
              },
            ),
            SizedBox(height: 20),
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            if (_selectedRole == 'Manager') ...[
              SizedBox(height: 20),
              TextFormField(
                controller: _codeController,
                decoration: InputDecoration(labelText: 'Secret Code'),
                obscureText: true,
              ),
            ],
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
      if (_selectedRole == 'Manager') {
        final code = _codeController.text.trim();
        if (code.isEmpty) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Please enter the secret code')),
          );
          return;
        }

        DocumentSnapshot codeDoc =
            await _firestore.collection('admin').doc('secret_code').get();
        if (!codeDoc.exists) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Secret code not found in database')),
          );
          return;
        }

        String secretCode = codeDoc['code'] ?? 'default_code';
        if (code != secretCode) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Invalid secret code')));
          return;
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ManagerScreen()),
        );
      } else if (_selectedRole == 'Delivery Guy') {
        // Only set initial data if the delivery guy doesn't exist
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
        }
        // No overwrite of 'verified' or 'lastVerified', rely on existing data
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => DeliveryScreen(email: email)),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Role not supported yet')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Login failed: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
