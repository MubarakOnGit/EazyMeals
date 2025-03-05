// lib/delivery/delivery_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'orders_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'dart:async';

class DeliveryScreen extends StatefulWidget {
  final String email;

  DeliveryScreen({required this.email});

  @override
  _DeliveryScreenState createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int _selectedIndex = 0;
  Timer? _resetTimer;

  @override
  void initState() {
    super.initState();
    print('Initializing DeliveryScreen for ${widget.email}');
    _scheduleVerificationReset();
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    print('Disposing DeliveryScreen for ${widget.email}');
    super.dispose();
  }

  void _scheduleVerificationReset() {
    final now = DateTime.now();
    var next12PM = DateTime(now.year, now.month, now.day, 12, 0);
    if (now.isAfter(next12PM)) {
      next12PM = next12PM.add(Duration(days: 1));
    }
    final duration = next12PM.difference(now);

    _resetTimer?.cancel();
    _resetTimer = Timer(duration, () async {
      print('Resetting verification at 12 PM for ${widget.email}');
      await _firestore.collection('delivery_guys').doc(widget.email).update({
        'verified': false,
      });
      _scheduleVerificationReset();
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _refreshVerification() {
    print('Manually refreshing verification for ${widget.email}');
    setState(() {}); // Force rebuild
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream:
          _firestore.collection('delivery_guys').doc(widget.email).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          print('No snapshot data yet for ${widget.email}');
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text('Loading...'),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          print('Error in StreamBuilder: ${snapshot.error}');
          return Scaffold(
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null) {
          print('No data found in Firestore for ${widget.email}');
          return Scaffold(
            body: Center(child: Text('No data found for this delivery guy')),
          );
        }

        final isVerified = data['verified'] ?? false;
        final lastVerified =
            data['lastVerified'] != null
                ? (data['lastVerified'] as Timestamp).toDate()
                : null;
        final now = DateTime.now();

        // Calculate the next 12 PM after lastVerified
        DateTime? verificationExpiry;
        if (lastVerified != null) {
          verificationExpiry = DateTime(
            lastVerified.year,
            lastVerified.month,
            lastVerified.day,
            12,
            0,
          );
          if (lastVerified.isBefore(verificationExpiry)) {
            // If verified before 12 PM, expiry is that day's 12 PM
          } else {
            // If verified after 12 PM, expiry is next day's 12 PM
            verificationExpiry = verificationExpiry.add(Duration(days: 1));
          }
        }

        final isValid =
            isVerified &&
            lastVerified != null &&
            now.isBefore(verificationExpiry!);

        print('Verification status for ${widget.email}:');
        print('  isVerified: $isVerified');
        print('  lastVerified: $lastVerified');
        print('  verificationExpiry: $verificationExpiry');
        print('  isValid: $isValid');
        print('  Current time: $now');

        if (!isVerified || !isValid) {
          print('Showing pending verification screen for ${widget.email}');
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                    ),
                    child: Text('Pending Verification'),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _refreshVerification,
                    child: Text('Refresh'),
                  ),
                ],
              ),
            ),
          );
        }

        print('Verification passed, showing main screen for ${widget.email}');
        final List<Widget> _screens = [
          DeliveryOrdersScreen(email: widget.email),
          DeliveryHistoryScreen(email: widget.email),
          DeliveryProfileScreen(email: widget.email),
        ];

        return Scaffold(
          body: _screens[_selectedIndex],
          bottomNavigationBar: BottomNavigationBar(
            items: [
              BottomNavigationBarItem(
                icon: Icon(Icons.delivery_dining),
                label: 'Orders',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.history),
                label: 'History',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
            currentIndex: _selectedIndex,
            selectedItemColor: Colors.blue,
            unselectedItemColor: Colors.grey,
            onTap: _onItemTapped,
          ),
        );
      },
    );
  }
}
