import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:family_tree/data/models/app_user.dart';
import 'package:family_tree/data/models/auth_state.dart';
import 'package:family_tree/data/services/auth_service.dart';

/// Provider for AuthService
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// The signed-in user, or null. Emits on every sign-in / sign-out.
///
/// Seeded with the service's current user so widgets built before the first
/// stream event still see an already-restored session.
final authStateProvider = StreamProvider<AppUser?>((ref) async* {
  final authService = ref.watch(authServiceProvider);
  // AuthService.init() runs before ProviderScope exists, and its broadcast
  // stream drops events that have no listener yet — so emit the already
  // restored session first, then follow the stream.
  yield authService.currentUser;
  yield* authService.authStateChanges;
});

/// Controller for authentication
class AuthController extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthController(this._authService) : super(AuthState.initial);

  /// Sign in with email and password
  Future<void> signInWithEmail(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _authService.signInWithEmail(email: email, password: password);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _message(e));
    }
  }

  /// Register a new account. The backend requires a display name.
  Future<void> signUpWithEmail(
    String email,
    String password, {
    String? name,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final resolvedName = (name == null || name.trim().isEmpty)
          ? email.split('@').first
          : name.trim();
      await _authService.signUpWithEmail(
        email: email,
        password: password,
        name: resolvedName,
      );
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _message(e));
    }
  }

  /// Sign out
  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    await _authService.signOut();
    state = AuthState.initial;
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Re-read the current user from the backend (picks up role changes).
  Future<void> reloadUser() async {
    await _authService.reloadUser();
  }

  String _message(Object e) =>
      e.toString().replaceAll('Exception: ', '').replaceAll('AuthException: ', '');
}

/// Provider for AuthController
final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthController(authService);
});
