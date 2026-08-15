/// Firebase Service
///
/// Centralized Firebase initialization and service locator.
/// Initializes all Firebase services: Auth, Firestore, Storage, FCM,
/// Crashlytics, Analytics, Remote Config, and App Check.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

/// Centralized Firebase service that initializes and provides access
/// to all Firebase services.
class FirebaseService {
  static bool _initialized = false;

  /// Initializes all Firebase services.
  static Future<void> initialize() async {
    if (_initialized) return;

    // Initialize Firebase Core
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      debugPrint('Error initializing Firebase Core: $e');
      rethrow;
    }

    // Initialize App Check - platform-specific providers
    // Note: App Check on web requires a valid reCAPTCHA site key.
    // Skip on web for now to avoid ArgumentError in _flutterfire_internals.
    if (!kIsWeb) {
      try {
        await FirebaseAppCheck.instance.activate(
          androidProvider: AndroidProvider.playIntegrity,
          appleProvider: AppleProvider.appAttest,
        );
      } catch (e) {
        debugPrint('Warning: Failed to activate App Check: $e');
      }
    }

    // Initialize Crashlytics - only on non-web platforms (not available on web)
    if (!kIsWeb) {
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    } else {
      // On web, use default Flutter error handling
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        debugPrint('Flutter error: ${details.exceptionAsString()}');
      };
    }

    // Initialize Analytics
    try {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
    } catch (e) {
      debugPrint('Warning: Failed to initialize Analytics: $e');
    }

    // Initialize Remote Config
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ));
      await remoteConfig.setDefaults(const {
        'tax_percentage': 14.0,
        'currency': 'EGP',
        'low_stock_threshold': 10,
      });
      await remoteConfig.fetchAndActivate();
    } catch (e) {
      debugPrint('Warning: Failed to initialize Remote Config: $e');
    }

    // Enable Firestore persistence for offline support
    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (e) {
      debugPrint('Warning: Failed to configure Firestore: $e');
    }

    _initialized = true;
  }

  /// Provides FirebaseAuth instance.
  static FirebaseAuth get auth => FirebaseAuth.instance;

  /// Provides FirebaseFirestore instance.
  static FirebaseFirestore get firestore => FirebaseFirestore.instance;

  /// Provides FirebaseStorage instance.
  static FirebaseStorage get storage => FirebaseStorage.instance;

  /// Provides FirebaseMessaging instance.
  static FirebaseMessaging get messaging => FirebaseMessaging.instance;

  /// Provides FirebaseCrashlytics instance (null on web).
  static FirebaseCrashlytics? get crashlytics =>
      kIsWeb ? null : FirebaseCrashlytics.instance;

  /// Provides FirebaseAnalytics instance.
  static FirebaseAnalytics get analytics => FirebaseAnalytics.instance;

  /// Provides FirebaseRemoteConfig instance.
  static FirebaseRemoteConfig get remoteConfig => FirebaseRemoteConfig.instance;
}