import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB3Y8yNosO1G5JqTi1KiOb4_OhGAtkCZBQ',
    appId: '1:593651044753:web:4ec8a0a463fa8cdeeaca30',
    messagingSenderId: '593651044753',
    projectId: 'eazymeals-86f8e',
    authDomain: 'eazymeals-86f8e.firebaseapp.com',
    storageBucket: 'eazymeals-86f8e.firebasestorage.app',
    measurementId: 'G-LPTLBL62CN',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBD1zqk5TPQ4HbpPwX1F70qJlTgfUFN6to',
    appId: '1:593651044753:android:64842a1e566e6380eaca30',
    messagingSenderId: '593651044753',
    projectId: 'eazymeals-86f8e',
    storageBucket: 'eazymeals-86f8e.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyC2VSlaRuKs3c35xPxe0juMzF_1JQKzrvI',
    appId: '1:593651044753:ios:291c23c283f552b1eaca30',
    messagingSenderId: '593651044753',
    projectId: 'eazymeals-86f8e',
    storageBucket: 'eazymeals-86f8e.firebasestorage.app',
    iosClientId: '593651044753-tf1gn040cjeam8arbn3ihtt1sg4alnfc.apps.googleusercontent.com',
    iosBundleId: 'com.example.eazyMeals',
  );

}