import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:family_tree/data/models/auth_state.dart';
import 'package:family_tree/data/services/auth_service.dart';

/// Provider for AuthService
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Provider for auth state stream
final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
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
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  /// Sign up with email and password
  Future<void> signUpWithEmail(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    
    try {
      await _authService.signUpWithEmail(email: email, password: password);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  /// Sign in with Google
  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true);
    
    try {
      await _authService.signInWithGoogle();
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  /// Start phone verification
  Future<void> verifyPhoneNumber(String phoneNumber) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _authService.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        onCodeSent: (verificationId) {
          state = state.copyWith(
            isLoading: false,
            verificationId: verificationId,
            phoneNumber: phoneNumber,
          );
        },
        onError: (error) {
          state = state.copyWith(
            isLoading: false,
            error: error,
          );
        },
        onAutoVerified: (credential) async {
          // Handle auto-verification (Android only)
          state = state.copyWith(isLoading: false);
        },
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Verify SMS code
  Future<void> verifySMSCode(String smsCode) async {
    if (state.verificationId == null) {
      state = state.copyWith(error: 'No verification in progress');
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _authService.verifySMSCode(
        verificationId: state.verificationId!,
        smsCode: smsCode,
      );
      
      state = state.copyWith(
        isLoading: false,
        clearVerificationId: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
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

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    state = state.copyWith(isLoading: true, clearError: true);
    
    try {
      await _authService.sendPasswordResetEmail(email: email);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  /// Send email verification
  Future<void> sendEmailVerification() async {
    state = state.copyWith(isLoading: true, clearError: true);
    
    try {
      await _authService.sendEmailVerification();
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  /// Check if email is verified
  bool get isEmailVerified => _authService.isEmailVerified;

  /// Reload user to get latest verification status
  Future<void> reloadUser() async {
    await _authService.reloadUser();
  }

  /// Sign in with Apple
  Future<void> signInWithApple() async {
    state = state.copyWith(isLoading: true, clearError: true);
    
    try {
      await _authService.signInWithApple();
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }
}

/// Provider for AuthController
final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthController(authService);
});
