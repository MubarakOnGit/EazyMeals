import 'package:flutter/material.dart';

class CongratulationsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900], // Fixed grey[900] background
      appBar: AppBar(
        backgroundColor: Colors.grey[900], // Match app bar to background
        elevation: 0, // Remove shadow for a flat look
        title: Text(
          'Congratulations',
          style: TextStyle(
            color: Colors.white, // White text for contrast
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white), // White back arrow
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Welcome Aboard!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white, // White text for contrast
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Your account has been successfully verified.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(
                  0.7,
                ), // White with opacity for contrast
              ),
            ),
            SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/CustomerDashboard');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[900], // Blue[900] button color
                padding: EdgeInsets.symmetric(horizontal: 50, vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30), // Rounded button
                ),
              ),
              child: Text(
                'Continue to Home',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white, // White text for contrast
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
