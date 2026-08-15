/// Authentication Service
///
/// Centralized Firebase Authentication (Auth + Firestore user profile)
/// for the ERP system.
///
/// Handles email/password login, registration, role management,
/// password reset, email verification, session persistence, and the
/// mapping of Firebase errors to user-friendly Arabic messages.
import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';

import '../constants/app_constants.dart';
import 'firebase_service.dart';

/// Thrown by [AuthService] when an authentication operation fails.
///
/// Carries a user-friendly [message] (Arabic by default) so that
/// presentation layers can display it directly instead of raw
/// `FirebaseAuthException` codes.
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}

/// User model for authentication.
class AppUser {
  final String uid;
  final String name;
  final String email;
  final String? phone;
  final String? photoUrl;
  final UserRole role;
  final bool isActive;
  final DateTime? lastLogin;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    this.phone,
    this.photoUrl,
    required this.role,
    this.isActive = true,
    this.lastLogin,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a copy of this user with the given fields replaced.
  AppUser copyWith({
    String? name,
    String? email,
    String? phone,
    String? photoUrl,
    UserRole? role,
    bool? isActive,
    DateTime? lastLogin,
  }) {
    return AppUser(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      lastLogin: lastLogin ?? this.lastLogin,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    final roleName = map['role'] as String? ?? '';
    return AppUser(
      uid: map['uid'] as String? ?? '',
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String?,
      photoUrl: map['photoUrl'] as String?,
      role: UserRole.values.firstWhere(
        (r) => r.name == roleName,
        orElse: () => UserRole.salesRepresentative,
      ),
      isActive: map['isActive'] as bool? ?? true,
      lastLogin: (map['lastLogin'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'photoUrl': photoUrl,
      'role': role.name,
      'isActive': isActive,
      'lastLogin': lastLogin != null ? Timestamp.fromDate(lastLogin!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

/// Authentication service using Firebase Auth and Firestore.
class AuthService {
  final FirebaseAuth _auth = FirebaseService.auth;
  final FirebaseFirestore _db = FirebaseService.firestore;

  /// Prevents re-applying persistence on every instantiation.
  static bool _persistenceApplied = false;

  /// Stream of raw authentication state changes.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Stream of authenticated user profiles derived from auth state.
  Stream<AppUser?> get userChanges =>
      authStateChanges.asyncMap((User? user) {
        return user == null ? null : getUser(user.uid);
      });

  /// Gets the current authenticated Firebase user.
  User? get currentUser => _auth.currentUser;

  /// Whether the current user has verified their email.
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  /// Applies session persistence once so signed-in users remain logged in
  /// across app restarts on supported platforms.
  Future<void> _applyPersistence() async {
    if (_persistenceApplied) return;
    try {
      await _auth.setPersistence(Persistence.LOCAL);
      _persistenceApplied = true;
    } catch (_) {
      // Ignore: not all platforms support the setting.
    }
  }

  /// Signs in with email and password.
  Future<AppUser?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      await _applyPersistence();
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (credential.user == null) return null;

      // Try to load the Firestore profile. If unavailable (missing doc, rules,
      // offline), build an AppUser from the Auth user itself so sign-in always
      // completes.
      AppUser? appUser;
      try {
        appUser = await _fetchAppUser(credential.user!.uid);
      } catch (_) {
        appUser = null;
      }
      appUser ??= _appUserFromAuthUser(credential.user!, email.trim());

      // Block sign-in for deactivated accounts.
      if (!appUser.isActive) {
        await _auth.signOut();
        throw const AuthException(
          'تم تعطيل هذا الحساب. يرجى التواصل مع الإدارة.',
        );
      }

      // Save credentials locally for offline sign-in.
      await _saveLocalCredentials(email.trim(), password, appUser);
      return appUser;
    } on FirebaseAuthException catch (e) {
      // Attempt local sign-in for connectivity/authorization errors (network,
      // App Check, rules, operation-not-allowed...). Clear input errors are
      // surfaced instead.
      if (_isLocalFallbackError(e.code)) {
        final localUser = await _signInLocal(email.trim(), password);
        if (localUser != null) return localUser;
      }
      throw _mapAuthError(e);
    } catch (e) {
      // Generic error (e.g. Firebase init failed on web). Try local sign-in.
      final localUser = await _signInLocal(email.trim(), password);
      if (localUser != null) return localUser;
      rethrow;
    }
  }

  /// Attempts to sign in using locally stored credentials (offline).
  Future<AppUser?> _signInLocal(String email, String password) async {
    try {
      final box = _offlineBox();

      // Search locally registered users.
      final localUsers = _getLocalUsers(box);
      for (final u in localUsers) {
        if (u['email'] == email.trim() && u['password'] == password) {
          final appUser = AppUser.fromMap(u);
          if (appUser.uid.isNotEmpty) {
            // Refresh the cached credentials for subsequent offline launches.
            await _saveLocalCredentials(email.trim(), password, appUser);
            return appUser;
          }
        }
      }

      // Fall back to the last saved login session.
      final raw = box.get('offline_credentials');
      if (raw == null) return null;
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      if (data['email'] == email && data['password'] == password) {
        final appUser = AppUser.fromMap(
          jsonDecode(box.get('offline_user') as String) as Map<String, dynamic>,
        );
        if (appUser.uid.isNotEmpty) return appUser;
      }
    } catch (_) {
      // Best-effort.
    }
    return null;
  }

  /// Saves the last successful login credentials locally so the user can sign
  /// in offline on subsequent launches.
  Future<void> _saveLocalCredentials(
    String email,
    String password,
    AppUser user,
  ) async {
    try {
      final box = _offlineBox();
      await box.put('offline_credentials', jsonEncode({
        'email': email,
        'password': password,
      }));
      await box.put('offline_user', jsonEncode(user.toMap()));
    } catch (_) {
      // Best-effort; local storage is a convenience, not a requirement.
    }
  }

  Box _offlineBox() {
    if (Hive.isBoxOpen('auth')) return Hive.box('auth');
    return Hive.box('auth');
  }

  /// Returns the locally cached [AppUser] if one exists (offline fallback).
  AppUser? getLocalUser() {
    try {
      final box = _offlineBox();
      final raw = box.get('offline_user');
      if (raw == null) return null;
      return AppUser.fromMap(
        jsonDecode(raw as String) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  /// Registers a new user with email and password.
  /// If Firebase is unreachable (offline), creates a local account instead so
  /// registration still works and the app can be used locally.
  Future<AppUser?> registerWithEmailAndPassword({
    required String name,
    required String email,
    required String password,
    String? phone,
    UserRole role = UserRole.salesRepresentative,
  }) async {
    final trimmedPhone = phone?.trim();
    try {
      await _applyPersistence();
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (credential.user == null) return null;

      final now = DateTime.now();
      final appUser = AppUser(
        uid: credential.user!.uid,
        name: name.trim(),
        email: email.trim(),
        phone: (trimmedPhone == null || trimmedPhone.isEmpty)
            ? null
            : trimmedPhone,
        role: role,
        isActive: true,
        lastLogin: now,
        createdAt: now,
        updatedAt: now,
      );

      await _db.collection('users').doc(appUser.uid).set(appUser.toMap());
      // Persist locally for offline sign-in on later launches.
      await _saveLocalCredentials(email.trim(), password, appUser);
      return appUser;
    } on FirebaseAuthException catch (e) {
      // Fall back to a local account for connectivity/authorization errors
      // (offline, App Check, rules, operation-not-allowed, etc.) so that
      // registration still works. Clear input errors are surfaced instead.
      if (_isLocalFallbackError(e.code)) {
        final local = await _registerLocal(
          name: name,
          email: email,
          password: password,
          phone: trimmedPhone,
          role: role,
        );
        if (local != null) return local;
      }
      throw _mapAuthError(e);
    } catch (e) {
      // On web a failed/wrong Firebase init can throw a generic FirebaseException
      // (not a FirebaseAuthException). Fall back to a local account so that
      // registration always succeeds locally.
      final local = await _registerLocal(
        name: name,
        email: email,
        password: password,
        phone: trimmedPhone,
        role: role,
      );
      if (local != null) return local;
      rethrow;
    }
  }

  /// Returns true for errors where falling back to a local account is safe and
  /// desirable (network, App Check, permissions, disabled operation...).
  static bool _isLocalFallbackError(String code) {
    const inputErrors = {
      'email-already-in-use',
      'weak-password',
      'invalid-email',
      'invalid-credential',
      'wrong-password',
      'user-not-found',
      'user-disabled',
    };
    return !inputErrors.contains(code);
  }

  /// Registers a local (offline) account and stores it in the `auth` box.
  Future<AppUser?> _registerLocal({
    required String name,
    required String email,
    required String password,
    String? phone,
    UserRole role = UserRole.salesRepresentative,
  }) async {
    try {
      final box = _offlineBox();
      final localUsers = _getLocalUsers(box);

      // Prevent duplicate local registrations with the same email.
      if (localUsers.any((u) => u['email'] == email.trim())) {
        throw const AuthException(
          'هذا البريد الإلكتروني مستخدم بالفعل.',
        );
      }

      final now = DateTime.now();
      final uid = 'local_${now.millisecondsSinceEpoch}';
      final appUser = AppUser(
        uid: uid,
        name: name.trim(),
        email: email.trim(),
        phone: (phone == null || phone.isEmpty) ? null : phone,
        role: role,
        isActive: true,
        lastLogin: now,
        createdAt: now,
        updatedAt: now,
      );

      final userMap = appUser.toMap();
      userMap['password'] = password;
      localUsers.add(userMap);
      await box.put('local_users', jsonEncode(localUsers));
      await _saveLocalCredentials(email.trim(), password, appUser);
      return appUser;
    } catch (_) {
      // Fall through; the caller will throw the original auth error.
      return null;
    }
  }

  /// Reads the locally registered users list.
  List<Map<String, dynamic>> _getLocalUsers(Box box) {
    try {
      final raw = box.get('local_users');
      if (raw == null) return [];
      return (jsonDecode(raw as String) as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Signs out the current user and clears locally stored credentials.
  Future<void> signOut() async {
    try {
      final box = _offlineBox();
      await box.delete('offline_credentials');
      await box.delete('offline_user');
    } catch (_) {
      // Best-effort.
    }
    await _auth.signOut();
  }

  /// Sends a password reset email.
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  /// Sends a verification email to the current user.
  Future<void> sendEmailVerification() async {
    _requireSignedIn();
    try {
      await _auth.currentUser!.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  /// Reloads the current user from Firebase (refreshes `emailVerified`, etc.).
  Future<void> reload() async {
    await _auth.currentUser?.reload();
  }

  /// Updates the current user's email address.
  ///
  /// Uses [verifyBeforeUpdateEmail] (the recommended replacement for the
  /// deprecated `updateEmail`), which sends a confirmation email to the new
  /// address before applying the change.
  Future<void> updateEmail(String email) async {
    _requireSignedIn();
    try {
      await _auth.currentUser!.verifyBeforeUpdateEmail(email.trim());
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  /// Updates the current user's password.
  Future<void> updatePassword(String newPassword) async {
    _requireSignedIn();
    try {
      await _auth.currentUser!.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  /// Deletes the current user's account together with its Firestore profile.
  Future<void> deleteAccount() async {
    _requireSignedIn();
    final uid = _auth.currentUser!.uid;
    try {
      await _auth.currentUser!.delete();
      await _db.collection('users').doc(uid).delete();
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  /// Ensures there is a signed-in user before a guarded operation.
  void _requireSignedIn() {
    if (_auth.currentUser == null) {
      throw const AuthException('لا يوجد مستخدم مسجل حالياً.');
    }
  }

  /// Fetches the AppUser data from Firestore and updates last login.
  Future<AppUser?> _fetchAppUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;

    // Update last login timestamp.
    await _db.collection('users').doc(uid).update({
      'lastLogin': Timestamp.fromDate(DateTime.now()),
    });

    return AppUser.fromMap({...doc.data()!, 'uid': doc.id});
  }

  /// Builds an [AppUser] directly from the Firebase Auth user. Used when the
  /// Firestore profile cannot be loaded so that sign-in always completes.
  AppUser _appUserFromAuthUser(User user, String email) {
    final now = DateTime.now();
    return AppUser(
      uid: user.uid,
      name: user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : (email.split('@').first),
      email: email,
      phone: user.phoneNumber,
      photoUrl: user.photoURL,
      role: UserRole.salesRepresentative,
      isActive: true,
      lastLogin: now,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Gets the AppUser data for a specific UID without writing.
  Future<AppUser?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromMap({...doc.data()!, 'uid': doc.id});
  }

  /// Updates user profile data in Firestore.
  ///
  /// Only non-null optional fields are written so existing values (e.g.
  /// phone / photo) are not accidentally wiped during partial updates.
  Future<void> updateUserProfile(AppUser user) async {
    final update = <String, dynamic>{
      'name': user.name,
      'email': user.email,
      'role': user.role.name,
      'isActive': user.isActive,
      'lastLogin': user.lastLogin != null
          ? Timestamp.fromDate(user.lastLogin!)
          : null,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
      if (user.phone != null) 'phone': user.phone,
      if (user.photoUrl != null) 'photoUrl': user.photoUrl,
    };
    await _db.collection('users').doc(user.uid).update(update);
  }

  /// Checks if the current authenticated user has a specific role.
  Future<bool> hasRole(UserRole role) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    final appUser = await getUser(uid);
    return appUser?.role == role;
  }

  /// Maps a [FirebaseAuthException] to a user-friendly [AuthException] with
  /// an Arabic message for known error codes.
  AuthException _mapAuthError(FirebaseAuthException e) {
    const messages = <String, String>{
      'invalid-email': 'البريد الإلكتروني غير صالح.',
      'user-disabled': 'تم تعطيل هذا الحساب. يرجى التواصل مع الإدارة.',
      'user-not-found': 'لا يوجد حساب مسجل بهذا البريد الإلكتروني.',
      'wrong-password': 'كلمة المرور غير صحيحة.',
      'invalid-credential': 'بيانات الدخول غير صحيحة.',
      'email-already-in-use': 'هذا البريد الإلكتروني مستخدم بالفعل.',
      'weak-password': 'كلمة المرور ضعيفة جداً، استخدم 6 أحرف على الأقل.',
      'operation-not-allowed': 'العملية غير مسموح بها حالياً.',
      'too-many-requests': 'محاولات دخول كثيرة، يرجى المحاولة لاحقاً.',
      'network-request-failed': 'خطأ في الاتصال بالشبكة، تحقق من الاتصال.',
      'requires-recent-login': 'يرجى تسجيل الدخول مرة أخرى لإتمام هذه العملية.',
      'credential-already-in-use': 'بيانات الدخول مستخدمة من حساب آخر.',
      'invalid-verification-code': 'رمز التحقق غير صحيح.',
      'configuration-not-found':
          'تعذر تفعيل المصادقة (Firebase Authentication غير مُعدّ للمشروع أو مفاتيح الإعداد غير صحيحة).',
      'invalid-api-key': 'مفتاح Firebase API غير صالح في الإعدادات.',
      'api-key-not-valid':
          'مفتاح Firebase API غير صالح، تحقق من إعدادات المشروع.',
      'app-not-authorized': 'هذا التطبيق غير مصرّح باستخدام Firebase Authentication.',
      'unsupported-api-variant': 'إصدار API غير مدعوم لخدمة المصادقة.',
    };
    final message = messages[e.code];
    if (message != null) return AuthException(message);
    // Fall back to a generic message including the code for debugging.
    return AuthException('حدث خطأ أثناء العملية (${e.code}).');
  }
}