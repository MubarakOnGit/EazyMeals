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
    HistoryScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(color: Colors.black),
        child: BottomNavigationBar(
          backgroundColor: Colors.grey.shade900,
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
