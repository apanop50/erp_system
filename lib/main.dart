import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'app/app.dart';
import 'core/constants/app_constants.dart';
import 'core/database/database_helper.dart';
import 'core/services/cache_service.dart';
import 'core/services/firebase_service.dart';
import 'core/services/local_store.dart';
import 'core/services/notifications_service.dart';
import 'core/services/storage_fcm_service.dart';

/// Main function - initializes all services and runs the app.
///
/// Performs the following initialization steps:
/// 1. Ensures Flutter widgets binding is initialized
/// 2. Initializes Firebase (Auth, Firestore, Storage, FCM, Crashlytics, Analytics)
/// 3. Initializes Hive for local caching
/// 4. Initializes SQLite database (with FFI for desktop support)
/// 5. Initializes local notifications and FCM
/// 6. Runs the app with Riverpod ProviderScope
Future<void> main() async {
  // Ensure Flutter bindings are initialized before using platform channels
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (Auth, Firestore, Storage, FCM, Crashlytics, Analytics, Remote Config, App Check)
  try {
    await FirebaseService.initialize();
  } catch (e) {
    debugPrint('Warning: Failed to initialize Firebase: $e');
  }

  // Initialize Hive for caching
  await Hive.initFlutter();
  await Hive.openBox('settings');
  await Hive.openBox('cache');
  await Hive.openBox('auth');

  // Initialize the local persistence store (offline backup for saving data).
  await LocalStore.init();

  // NOTE: CacheService.clearLocalData() is intentionally NOT run at startup.
  // On web platforms clearPersistence() is unsupported and disableNetwork()
  // can leave Firestore offline, which silently prevents data from reaching
  // the cloud and clears cached data on every launch.

  // Initialize SQLite - platform-specific approach
  // sqflite_common_ffi is only for desktop platforms (Windows, macOS, Linux)
  // On web, SQLite is not directly available; on mobile, use the regular sqflite
  if (!kIsWeb) {
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux) {
      // Desktop platforms - use FFI
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    // On mobile (Android, iOS), the regular sqflite package is used automatically

    // Get the application documents directory for database storage
    try {
      final appDocumentDir = await getApplicationDocumentsDirectory();
      final dbPath = p.join(appDocumentDir.path, AppConstants.databaseName);

      // Initialize the database
      await DatabaseHelper.instance.initDatabase(dbPath);
    } catch (e) {
      debugPrint('Warning: Failed to initialize SQLite database: $e');
    }
  }

  // Initialize notifications service (limited support on web)
  if (!kIsWeb) {
    try {
      await NotificationsService.instance.initialize();
    } catch (e) {
      debugPrint('Warning: Failed to initialize notifications: $e');
    }
  }

  // Initialize FCM (Firebase Cloud Messaging) - works on web and mobile
  try {
    await FCMService().initialize();
  } catch (e) {
    debugPrint('Warning: Failed to initialize FCM: $e');
  }

  // Run the application with ProviderScope for Riverpod
  runApp(
    const ProviderScope(
      child: MarivioERPApp(),
    ),
  );
}