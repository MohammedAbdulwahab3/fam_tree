import 'package:firebase_auth/firebase_auth.dart';

/// Authentication state for the application
class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;
  final String? verificationId;
  final String? phoneNumber;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.verificationId,
    this.phoneNumber,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    User? user,
    bool? isLoading,
    String? error,
    String? verificationId,
    String? phoneNumber,
    bool clearError = false,
    bool clearVerificationId = false,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      verificationId: clearVerificationId ? null : (verificationId ?? this.verificationId),
      phoneNumber: phoneNumber ?? this.phoneNumber,
    );
  }

  static const initial = AuthState();
}
