import 'package:eazy_meals/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'utils/theme.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      routes: {'/login': (context) => LoginScreen()},
      title: 'Food App',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode:
          ThemeMode.system, // Automatically switch between light and dark mode
      home: SplashScreen(),
    );
  }
}
