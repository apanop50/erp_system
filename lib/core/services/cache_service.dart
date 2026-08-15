// Cache Service
//
// Clears all local caches (Hive, SQLite, and Firestore offline persistence)
// so that the app does not display stale/old locally-cached data and instead
// shows fresh data coming from Firestore.
//
// Preferences (theme/locale/company settings) and the authentication session
// are intentionally preserved.
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../constants/app_constants.dart';

/// Central helper to clean local caches on app startup.
class CacheService {
  CacheService._();

  /// Clears the local data caches:
  /// 1. Firestore offline persistence cache
  /// 2. Hive `cache` box (cached app/listing data)
  /// 3. Local SQLite database file
  ///
  /// All steps are best-effort and never throw.
  static Future<void> clearLocalData() async {
    await _clearFirestoreCache();
    await _clearHiveCache();
    await _clearSqlite();
  }

  /// Clears the local Firestore persistence cache so previously cached
  /// (old) documents are not served from disk. Requires temporarily
  /// disabling the network with no active listeners (true at startup).
  static Future<void> _clearFirestoreCache() async {
    try {
      await FirebaseFirestore.instance.disableNetwork();
      await FirebaseFirestore.instance.clearPersistence();
      await FirebaseFirestore.instance.enableNetwork();
    } catch (e) {
      // Best-effort. A failure here should never crash the app.
    }
  }

  /// Clears the Hive `cache` box. The `settings` box (preferences) and the
  /// `auth` box (session) are left untouched.
  static Future<void> _clearHiveCache() async {
    try {
      if (Hive.isBoxOpen(AppConstants.cacheBox)) {
        await Hive.box<dynamic>(AppConstants.cacheBox).clear();
      }
    } catch (e) {
      // Best-effort.
    }
  }

  /// Deletes the local SQLite database file so it is recreated from scratch
  /// on next use. Called before the database is opened to avoid lock issues.
  static Future<void> _clearSqlite() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final dbPath = p.join(dir.path, AppConstants.databaseName);
      final file = File(dbPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Best-effort.
    }
  }
}
