/// Firebase Configuration Options
///
/// This file contains the Firebase configuration for all platforms.
/// Replace the placeholder values with your actual Firebase project configuration.
/// You can generate this file automatically by running:
///   dart pub global activate flutterfire_cli
///   flutterfire configure
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default Firebase configuration for the Marivio ERP application.
///
/// Replace these placeholder values with your actual Firebase project credentials
/// from the Firebase Console (Project Settings > General > Your apps).
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
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.macOS:
        return macos;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform. '
          'Run flutterfire configure to generate the configuration.',
        );
    }
  }

  // ---------------------------------------------------------------------------
  // Project: marivio-inventory-sales (project number 948968642932)
  // ---------------------------------------------------------------------------

  /// Web configuration.

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAVsOevQ4yUN8I5IuDyfo6QM9r-u5DGGJ0',
    appId: '1:475808793328:web:e7935a8b56ff4817fc3835',
    messagingSenderId: '475808793328',
    projectId: 'marivioerp',
    authDomain: 'marivioerp.firebaseapp.com',
    storageBucket: 'marivioerp.firebasestorage.app',
    measurementId: 'G-E4WZ565ZKN',
  );
  /// Android configuration (from android/app/google-services.json).
  /// Matches the registered Firebase Android app in project "marivioerp"
  /// (package com.example.erp_system), which is the applicationId used in
  /// android/app/build.gradle.kts.

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD2ET9_9M1M4tuGe2JWnKZz1Ekxl1c1dmk',
    appId: '1:475808793328:android:1aa05d7d201859cafc3835',
    messagingSenderId: '475808793328',
    projectId: 'marivioerp',
    storageBucket: 'marivioerp.firebasestorage.app',
  );
  /// iOS configuration.
  /// TODO: Replace apiKey/appId with the correct iOS app config for this project.

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD40JZKc_XzR8rpmHgADNMDWGZ6Scj4wDA',
    appId: '1:475808793328:ios:3a24e2da7c9caedafc3835',
    messagingSenderId: '475808793328',
    projectId: 'marivioerp',
    storageBucket: 'marivioerp.firebasestorage.app',
    iosBundleId: 'com.example.erpSystem',
  );
  /// macOS configuration.
  /// TODO: Replace apiKey/appId with the correct macOS app config for this project.

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyD40JZKc_XzR8rpmHgADNMDWGZ6Scj4wDA',
    appId: '1:475808793328:ios:3a24e2da7c9caedafc3835',
    messagingSenderId: '475808793328',
    projectId: 'marivioerp',
    storageBucket: 'marivioerp.firebasestorage.app',
    iosBundleId: 'com.example.erpSystem',
  );
  /// Windows configuration (Firebase Core for Windows uses the web config).
  /// TODO: Replace apiKey/appId with the correct Windows app config for this project.

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAVsOevQ4yUN8I5IuDyfo6QM9r-u5DGGJ0',
    appId: '1:475808793328:web:8c6b339804663d97fc3835',
    messagingSenderId: '475808793328',
    projectId: 'marivioerp',
    authDomain: 'marivioerp.firebaseapp.com',
    storageBucket: 'marivioerp.firebasestorage.app',
    measurementId: 'G-VBX7840NFK',
  );
}
