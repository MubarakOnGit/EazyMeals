import 'package:flutter/material.dart';

class ManagerProfileScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 40),
        Center(
          child: Text(
            'Profile',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(height: 20),
        CircleAvatar(
          radius: 50,
          backgroundImage: AssetImage(
            'assets/manager_profile.png',
          ), // Placeholder
        ),
        SizedBox(height: 20),
        Text(
          'Manager Name', // Replace with actual data if available
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text('manager@example.com'),
        SizedBox(height: 20),
        ListTile(
          leading: Icon(Icons.support),
          title: Text('Contact Support'),
          onTap: () {
            // Implement support logic
          },
        ),
        ListTile(
          leading: Icon(Icons.logout),
          title: Text('Logout'),
          onTap: () {
            Navigator.popUntil(context, (route) => route.isFirst);
          },
        ),
      ],
    );
  }
}
