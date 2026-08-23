import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:family_tree/core/logging.dart';
import 'package:family_tree/data/models/app_user.dart';
import 'package:family_tree/data/services/api_service.dart';
import 'package:family_tree/data/services/auth_service.dart';

/// Why the app is showing the sign-in screen rather than the family.
enum SignedOutReason {
  /// Nobody has signed in on this device yet, or they signed out on purpose.
  none,

  /// The stored session was too old to use. Thirty days of not opening the
  /// app, or an admin changed the signing key.
  sessionExpired,

  /// An admin suspended this account.
  suspended,

  /// The account was deleted while signed in — by the member themselves on
  /// another device, or by an admin.
  accountGone,
}

/// Who is signed in, and what the app should do about it.
///
/// This replaced five overlapping objects that each held part of the answer —
/// an AuthService singleton with its own stream, an authStateProvider, an
/// AuthController with an AuthState, an AdminController with an AdminState,
/// and a userRoleProvider that fetched /api/me all over again. They could
/// disagree, and did: signing out left the admin controller still believing
/// the last user was an admin until something happened to rebuild it.
class Session {
  const Session({
    this.user,
    this.reason = SignedOutReason.none,
    this.busy = false,
    this.error,
  });

  /// The signed-in account, or null.
  final AppUser? user;

  /// Set when [user] is null and it is worth explaining why.
  final SignedOutReason reason;

  /// A sign-in, sign-up or sign-out is in flight.
  final bool busy;

  /// The last failure, written for a person to read.
  final String? error;

  bool get isSignedIn => user != null;
  bool get isAdmin => user?.isAdmin ?? false;

  /// True once an admin has linked this account to somebody in the tree. Until
  /// then the member can look at the family but has no record of their own.
  bool get isLinked => user?.isVerified ?? false;

  Session copyWith({
    AppUser? user,
    SignedOutReason? reason,
    bool? busy,
    String? error,
    bool clearError = false,
    bool clearUser = false,
  }) {
    return Session(
      user: clearUser ? null : (user ?? this.user),
      reason: reason ?? this.reason,
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
    );
  }

  static const empty = Session();
}

class SessionController extends StateNotifier<Session> {
  SessionController(this._auth) : super(Session(user: _auth.currentUser)) {
    // A request rejected as unauthenticated anywhere in the app lands here, so
    // an expired session is handled once rather than by each caller guessing.
    ApiService.onAuthFailure = _handleAuthFailure;
  }

  final AuthService _auth;

  @override
  void dispose() {
    ApiService.onAuthFailure = null;
    super.dispose();
  }

  /// Restore a stored session, if there is one. Called once at startup.
  Future<void> restore() async {
    final user = await _auth.init();
    if (!mounted) return;

    state = user == null ? const Session() : Session(user: user);
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final user =
          await _auth.signInWithEmail(email: email, password: password);
      if (!mounted) return false;
      state = Session(user: user);
      return true;
    } catch (error) {
      if (!mounted) return false;
      state = state.copyWith(busy: false, error: _readable(error));
      return false;
    }
  }

  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final user = await _auth.signUpWithEmail(
        email: email,
        password: password,
        name: name,
      );
      if (!mounted) return false;
      state = Session(user: user);
      return true;
    } catch (error) {
      if (!mounted) return false;
      state = state.copyWith(busy: false, error: _readable(error));
      return false;
    }
  }

  /// Set a new password with a code an admin issued, and sign in with it.
  Future<bool> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final user = await _auth.resetPasswordWithCode(
        email: email,
        code: code,
        newPassword: newPassword,
      );
      if (!mounted) return false;
      state = Session(user: user);
      return true;
    } catch (error) {
      if (!mounted) return false;
      state = state.copyWith(busy: false, error: _readable(error));
      return false;
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(busy: true);
    await _auth.signOut();
    if (!mounted) return;
    state = const Session();
  }

  /// Re-read the account from the server. Picks up a role change, a new
  /// display name, and — the one that matters most — an admin approving the
  /// member's claim, which flips [Session.isLinked].
  Future<void> refresh() async {
    if (!state.isSignedIn) return;
    try {
      final user = await _auth.reloadUser();
      if (!mounted || user == null) return;
      state = state.copyWith(user: user);
    } catch (error) {
      // A refresh that fails changes nothing; the app carries on with what it
      // already knows. A genuine expiry arrives through onAuthFailure.
      log('Could not refresh the account', error);
    }
  }

  /// Update the local copy after the member edits their own name or photo,
  /// without a round trip to read back what we just sent.
  void applyLocalChange(AppUser user) {
    if (!mounted) return;
    state = state.copyWith(user: user);
  }

  void clearError() {
    if (state.error != null) state = state.copyWith(clearError: true);
  }

  /// Called when any request comes back unauthenticated or suspended.
  Future<void> _handleAuthFailure(AuthFailure failure) async {
    if (!state.isSignedIn) return;

    await _auth.signOut();
    if (!mounted) return;

    state = Session(
      reason: switch (failure.kind) {
        AuthFailureKind.expired => SignedOutReason.sessionExpired,
        AuthFailureKind.suspended => SignedOutReason.suspended,
        AuthFailureKind.gone => SignedOutReason.accountGone,
      },
      error: failure.message,
    );
  }

  String _readable(Object error) => messageForError(error);
}

/// The service behind the session. Exposed because a couple of screens edit
/// the account directly — a display name, a photo — and then hand the result
/// back through [SessionController.applyLocalChange].
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// The one place the app asks who is signed in.
final sessionProvider =
    StateNotifierProvider<SessionController, Session>((ref) {
  return SessionController(ref.watch(authServiceProvider));
});

/// Convenience reads, so a widget that only needs one fact does not rebuild
/// when an unrelated part of the session changes.
final currentUserProvider = Provider<AppUser?>(
  (ref) => ref.watch(sessionProvider).user,
);

final isSignedInProvider = Provider<bool>(
  (ref) => ref.watch(sessionProvider.select((s) => s.isSignedIn)),
);

final isAdminProvider = Provider<bool>(
  (ref) => ref.watch(sessionProvider.select((s) => s.isAdmin)),
);

/// Whether this account has been linked to somebody in the tree.
final isLinkedProvider = Provider<bool>(
  (ref) => ref.watch(sessionProvider.select((s) => s.isLinked)),
);
