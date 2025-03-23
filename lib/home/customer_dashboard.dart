import 'package:eazy_meals/utils/theme.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'home_screen.dart'; // Adjust path as per your project structure
import 'menu_screen.dart'; // Adjust path as per your project structure
import 'history_screen.dart'; // Adjust path as per your project structure
import 'profile_screen.dart'; // Adjust path as per your project structure

class CustomerDashboard extends StatefulWidget {
  @override
  _CustomerDashboardState createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    HomeScreen(),
    MenuScreen(),
    HistoryScreen(), // Assuming this is your "Plan" screen based on the label
    ProfileScreen(),
  ];

  // Handle back button press
  Future<bool> _onWillPop() async {
    if (_currentIndex != 0) {
      // If not on HomeScreen, switch to HomeScreen
      setState(() {
        _currentIndex = 0;
      });
      return false; // Prevent exiting the app
    }
    // If on HomeScreen, allow exit
    return true; // Exit the app
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop, // Intercept back button press
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: _screens[_currentIndex],
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
          items: [
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
