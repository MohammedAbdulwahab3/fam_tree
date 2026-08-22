import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Service for handling Firebase Authentication
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Initialize GoogleSignIn with OAuth client ID
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
    clientId: '216305526466-4anm45ujfhvuirp0gvtsc6bjk7ktr552.apps.googleusercontent.com',
  );

  /// Get current user
  User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with Email and Password
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw Exception('No user found with this email');
      } else if (e.code == 'wrong-password') {
        throw Exception('Incorrect password');
      } else if (e.code == 'invalid-email') {
        throw Exception('Invalid email address');
      }
      throw Exception(e.message ?? 'Failed to sign in');
    }
  }

  /// Sign up with Email and Password
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        throw Exception('Password is too weak');
      } else if (e.code == 'email-already-in-use') {
        throw Exception('An account already exists with this email');
      } else if (e.code == 'invalid-email') {
        throw Exception('Invalid email address');
      }
      throw Exception(e.message ?? 'Failed to create account');
    }
  }

  /// Sign in with Google
  Future<UserCredential> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        throw Exception('Google sign-in was cancelled');
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      throw Exception('Failed to sign in with Google: ${e.toString()}');
    }
  }

  /// Verify phone number and send SMS code
  Future<String> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(String error) onError,
    void Function(PhoneAuthCredential credential)? onAutoVerified,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-verification on Android
        if (onAutoVerified != null) {
          onAutoVerified(credential);
        } else {
          await _auth.signInWithCredential(credential);
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        String errorMessage = 'Verification failed';
        if (e.code == 'invalid-phone-number') {
          errorMessage = 'Invalid phone number format';
        } else if (e.code == 'too-many-requests') {
          errorMessage = 'Too many requests. Please try again later.';
        } else if (e.message != null) {
          errorMessage = e.message!;
        }
        onError(errorMessage);
      },
      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        // Timeout for auto-retrieval
      },
    );

    return phoneNumber;
  }

  /// Verify SMS code and sign in
  Future<UserCredential> verifySMSCode({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-verification-code') {
        throw Exception('Invalid verification code. Please try again.');
      } else if (e.code == 'session-expired') {
        throw Exception('Verification code expired. Please request a new code.');
      }
      throw Exception(e.message ?? 'Failed to verify code');
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw Exception('No user found with this email');
      } else if (e.code == 'invalid-email') {
        throw Exception('Invalid email address');
      }
      throw Exception(e.message ?? 'Failed to send reset email');
    }
  }

  /// Send email verification to current user
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No user is signed in');
    }
    if (user.emailVerified) {
      throw Exception('Email is already verified');
    }
    try {
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Failed to send verification email');
    }
  }

  /// Check if current user's email is verified
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  /// Reload current user to get latest data
  Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
  }

  /// Sign in with Apple
  Future<UserCredential> signInWithApple() async {
    try {
      // Create and configure an OAuthProvider for Sign In With Apple
      final appleProvider = OAuthProvider('apple.com')
        ..addScope('email')
        ..addScope('name');

      // Sign in with popup on web, or native on mobile
      return await _auth.signInWithProvider(appleProvider);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        throw Exception('An account already exists with a different sign-in method');
      }
      throw Exception(e.message ?? 'Failed to sign in with Apple');
    } catch (e) {
      throw Exception('Apple Sign In failed: ${e.toString()}');
    }
  }
}
