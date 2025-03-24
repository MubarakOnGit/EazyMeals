import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:eazy_meals/utils/theme.dart';
import 'home_screen.dart'; // Adjust path as per your project structure
import 'menu_screen.dart'; // Adjust path as per your project structure
import 'history_screen.dart'; // Adjust path as per your project structure
import 'profile_screen.dart'; // Adjust path as per your project structure

class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({super.key});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  int _currentIndex = 0;

  static final List<Widget> _screens = [
    HomeScreen(),
    MenuScreen(),
    HistoryScreen(), // Labeled as "Plan" in the UI
    ProfileScreen(),
  ];

  // Handle back button press or predictive back gesture
  void _onPopInvokedWithResult(bool didPop, Object? result) {
    if (didPop) {
      return; // If navigation already occurred, do nothing
    }
    if (_currentIndex != 0) {
      setState(() {
        _currentIndex = 0;
      });
    } else {
      Navigator.of(context).pop(); // Exit the app if on HomeScreen
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentIndex == 0, // Allow pop only when on HomeScreen
      onPopInvokedWithResult: _onPopInvokedWithResult,
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          top: false,
          child: IndexedStack(index: _currentIndex, children: _screens),
        ),
        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: backgroundColor,
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400),
          items: const [
            BottomNavigationBarItem(icon: Icon(Iconsax.home), label: 'Home'),
            BottomNavigationBarItem(
              icon: Icon(Iconsax.book_saved),
              label: 'Menu',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.access_time_outlined),
              label: 'Plan',
            ),
            BottomNavigationBarItem(
              icon: Icon(Iconsax.profile_circle),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
