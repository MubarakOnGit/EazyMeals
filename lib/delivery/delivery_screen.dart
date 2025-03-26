import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'orders_screen.dart'; // DeliveryOrdersScreen
import 'history_screen.dart'; // DeliveryHistoryScreen
import 'profile_screen.dart'; // DeliveryProfileScreen
import 'dart:async';

class DeliveryScreen extends StatefulWidget {
  const DeliveryScreen({super.key}); // No email parameter

  @override
  _DeliveryScreenState createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  int _selectedIndex = 0;
  Timer? _resetTimer;

  @override
  void initState() {
    super.initState();
    print(
      'Initializing DeliveryScreen for ${_auth.currentUser?.email ?? "unknown"}',
    );
    _scheduleVerificationReset();
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    print(
      'Disposing DeliveryScreen for ${_auth.currentUser?.email ?? "unknown"}',
    );
    super.dispose();
  }

  void _scheduleVerificationReset() {
    final now = DateTime.now();
    var next12PM = DateTime(now.year, now.month, now.day, 12, 0);
    if (now.isAfter(next12PM)) {
      next12PM = next12PM.add(const Duration(days: 1));
    }
    final duration = next12PM.difference(now);

    _resetTimer?.cancel();
    _resetTimer = Timer(duration, () async {
      final email = _auth.currentUser?.email;
      if (email != null) {
        print('Resetting verification at 12 PM for $email');
        await _firestore.collection('delivery_guys').doc(email).update({
          'verified': false,
        });
        _scheduleVerificationReset();
      }
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _refreshVerification() {
    print(
      'Manually refreshing verification for ${_auth.currentUser?.email ?? "unknown"}',
    );
    setState(() {}); // Force rebuild
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('Please log in', style: TextStyle(fontSize: 18)),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream:
          _firestore.collection('delivery_guys').doc(user.email).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          print('No snapshot data yet for ${user.email}');
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
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
          print('No data found in Firestore for ${user.email}');
          return const Scaffold(
            body: Center(child: Text('No data found for this delivery guy')),
          );
        }

        final isVerified = data['verified'] as bool? ?? false;
        final lastVerified =
            data['lastVerified'] != null
                ? (data['lastVerified'] as Timestamp).toDate()
                : null;
        final now = DateTime.now();

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
            verificationExpiry = verificationExpiry.add(
              const Duration(days: 1),
            );
          }
        }

        final isValid =
            isVerified &&
            lastVerified != null &&
            now.isBefore(verificationExpiry!);

        print('Verification status for ${user.email}:');
        print('  isVerified: $isVerified');
        print('  lastVerified: $lastVerified');
        print('  verificationExpiry: $verificationExpiry');
        print('  isValid: $isValid');
        print('  Current time: $now');

        if (!isVerified || !isValid) {
          print('Showing pending verification screen for ${user.email}');
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                    ),
                    child: const Text('Pending Verification'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _refreshVerification,
                    child: const Text('Refresh'),
                  ),
                ],
              ),
            ),
          );
        }

        print('Verification passed, showing main screen for ${user.email}');
        final List<Widget> _screens = [
          const DeliveryOrdersScreen(), // No email, matches updated version
          DeliveryHistoryScreen(
            email: user.email!,
          ), // Temporary fix: pass email
          DeliveryProfileScreen(
            email: user.email!,
          ), // Temporary fix: pass email
        ];

        return Scaffold(
          body: _screens[_selectedIndex],
          bottomNavigationBar: BottomNavigationBar(
            items: const [
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
