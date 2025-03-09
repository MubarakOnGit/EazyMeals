import 'package:flutter/material.dart';
import 'home_screen.dart'; // Import the HomeScreen
import 'menu_screen.dart';
import 'profile_screen.dart';
import 'package:iconsax/iconsax.dart';
import 'history_screen.dart';

class CustomerDashboard extends StatefulWidget {
  @override
  _CustomerDashboardState createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    HomeScreen(), // HomeScreen is the first screen
    MenuScreen(),
    HistoryScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _screens[_currentIndex], // Display the selected screen
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white, // Background color of the bar
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.white,
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.shifting,
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
