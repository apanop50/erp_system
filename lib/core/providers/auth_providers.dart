/// Auth Providers
///
/// Riverpod providers for authentication state management.
/// Handles login, logout, registration, and current user state,
/// and exposes a helper provider for the latest auth error message.
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';

/// Provider for AuthService instance.
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// State notifier for authentication state.
class AuthStateNotifier extends StateNotifier<AsyncValue<AppUser?>> {
  final AuthService _authService;
  StreamSubscription<User?>? _authSubscription;

  AuthStateNotifier(this._authService) : super(const AsyncValue.loading()) {
    _init();
  }

  /// Initializes auth state by listening to auth state changes.
  void _init() {
    try {
      _authSubscription = _authService.authStateChanges.listen(
        (User? user) async {
          if (user == null) {
            // No Firebase session. Fall back to a locally cached user so the
            // app can be used offline.
            state = AsyncValue.data(_authService.getLocalUser());
          } else {
            try {
              final appUser = await _authService.getUser(user.uid);
              state = AsyncValue.data(appUser);
            } catch (e, st) {
              // Reading the profile from Firestore failed (e.g. offline).
              // Use the locally cached user if available.
              final localUser = _authService.getLocalUser();
              if (localUser != null) {
                state = AsyncValue.data(localUser);
              } else {
                state = AsyncValue.error(e, st);
              }
            }
          }
        },
        onError: (Object e, StackTrace st) {
          state = AsyncValue.data(_authService.getLocalUser());
        },
      );
    } catch (e, st) {
      // Firebase might not be initialized. Fall back to the local user.
      state = AsyncValue.data(_authService.getLocalUser());
    }
  }

  /// Signs in with email and password.
  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final appUser = await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      state = AsyncValue.data(appUser);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Registers a new user.
  Future<void> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    state = const AsyncValue.loading();
    try {
      final appUser = await _authService.registerWithEmailAndPassword(
        name: name,
        email: email,
        password: password,
        phone: phone,
      );
      state = AsyncValue.data(appUser);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Signs out the current user.
  Future<void> signOut() async {
    try {
      await _authService.signOut();
    } finally {
      state = const AsyncValue.data(null);
    }
  }

  /// Sends a password reset email.
  Future<void> resetPassword(String email) async {
    try {
      await _authService.sendPasswordResetEmail(email);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Sends a verification email to the current user.
  Future<void> sendEmailVerification() async {
    await _authService.sendEmailVerification();
  }

  /// Reloads the current user profile.
  Future<void> reload() async {
    await _authService.reload();
  }

  /// Deletes the current user's account.
  Future<void> deleteAccount() async {
    await _authService.deleteAccount();
    state = const AsyncValue.data(null);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

/// Provider for authentication state.
final authStateProvider =
    StateNotifierProvider<AuthStateNotifier, AsyncValue<AppUser?>>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthStateNotifier(authService);
});

/// Provider that returns true if the user is authenticated.
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.maybeWhen(
    data: (user) => user != null,
    orElse: () => false,
  );
});

/// Provider for the current AppUser.
final currentUserProvider = Provider<AppUser?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.maybeWhen(
    data: (user) => user,
    orElse: () => null,
  );
});

/// Provider that exposes the latest authentication error message (if any).
final authErrorMessageProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.maybeWhen(
    error: (e, _) => e.toString(),
    orElse: () => null,
  );
});
