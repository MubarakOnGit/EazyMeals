import 'package:flutter/material.dart';

import 'manager_screen.dart';
// We'll create this next

class EmployeeLoginScreen extends StatefulWidget {
  @override
  _EmployeeLoginScreenState createState() => _EmployeeLoginScreenState();
}

class _EmployeeLoginScreenState extends State<EmployeeLoginScreen> {
  String _selectedRole = 'Manager'; // Default role
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;

  final List<String> _roles = ['Manager', 'Delivery Guy', 'Other Employee'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Employee Login')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Role Selection
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

            // Email Input
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 20),

            // Login Button
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

    // Simulate admin verification (you can replace this with Firebase logic)
    await Future.delayed(Duration(seconds: 2));

    setState(() => _isLoading = false);

    if (_selectedRole == 'Manager') {
      // Navigate to Manager Screen
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ManagerScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Only managers can access this feature')),
      );
    }
  }
}
