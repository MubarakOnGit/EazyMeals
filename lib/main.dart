// Updated main.dart (unchanged)
import 'package:eazy_meals/screens/splash_screen.dart';
import 'package:eazy_meals/screens/verification_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:eazy_meals/screens/onboarding_screen.dart';
import 'package:eazy_meals/screens/login_screen.dart';
import 'package:eazy_meals/home/customer_dashboard.dart';
import 'package:eazy_meals/home/menu_screen.dart';
import 'package:eazy_meals/home/view_all_screen.dart';
import 'package:get/get.dart';
import 'package:eazy_meals/controllers/order_status_controller.dart';
import 'package:eazy_meals/controllers/pause_play_controller.dart';
import 'package:eazy_meals/controllers/profile_controller.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

import 'home/address_management_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    print('Firebase initialization error: $e');
  }

  await FirebaseAppCheck.instance.activate(
    webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'),
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.appAttest,
  );

  Get.put(OrderController(), permanent: true);
  Get.put(PausePlayController(), permanent: true);
  Get.put(ProfileController());

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
      routes: {
        '/onboarding': (context) => const OnboardingScreen(),
        '/login': (context) => const LoginScreen(),
        '/CustomerDashboard': (context) => const CustomerDashboard(),
        '/verification': (context) =>  VerificationScreen(),
        '/menu': (context) => const MenuScreen(),
        '/viewAll': (context) => const ViewAllScreen(),
        '/addressManagement': (context) => const AddressManagementScreen(),
      },
      builder: (context, child) {
        final mediaQueryData = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQueryData.copyWith(
            textScaler: const TextScaler.linear(1.0).clamp(minScaleFactor: 1.0, maxScaleFactor: 1.2),
          ),
          child: child!,
        );
      },
    );
  }
}