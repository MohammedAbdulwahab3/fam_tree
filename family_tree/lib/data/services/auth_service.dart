import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:family_tree/core/config.dart';
import 'package:family_tree/data/models/app_user.dart';
import 'package:family_tree/data/services/session_store.dart';

/// Thrown for any auth failure so the UI can show the backend's message.
class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

/// Email + password authentication against the Go backend.
///
/// The backend issues a JWT from `/login` and `/register`; that token is the
/// only credential the app stores, and every authenticated request carries it
/// as `Authorization: Bearer <token>`.
class AuthService {
  static const String baseUrl = AppConfig.apiBaseUrl;

  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final StreamController<AppUser?> _authStateController =
      StreamController<AppUser?>.broadcast();

  AppUser? _currentUser;
  String? _token;

  AppUser? get currentUser => _currentUser;
  String? get token => _token;
  bool get isSignedIn => _token != null && _currentUser != null;

  /// Emits the signed-in user, or null when signed out.
  Stream<AppUser?> get authStateChanges => _authStateController.stream;

  /// Restore a previous session from disk. Safe to call more than once.
  Future<AppUser?> init() async {
    _token = await SessionStore.readToken();

    if (_token == null) {
      _emit(null);
      return null;
    }

    final cached = await SessionStore.readUser();
    if (cached != null) {
      try {
        _currentUser = AppUser.fromJson(
          jsonDecode(cached) as Map<String, dynamic>,
        );
      } catch (_) {
        // Corrupt cache — the server response below is authoritative anyway.
      }
    }

    // Confirm the stored token is still valid and refresh the role.
    final refreshed = await _fetchMe();
    if (refreshed == null) {
      await signOut();
      return null;
    }

    _currentUser = refreshed;
    await _persistUser(refreshed);
    _emit(refreshed);
    return refreshed;
  }

  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _authenticate('/login', {
      'email': email.trim(),
      'password': password,
    });
  }

  Future<AppUser> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) {
    return _authenticate('/register', {
      'email': email.trim(),
      'password': password,
      'name': name.trim(),
    });
  }

  /// Sign out and forget everything stored about this member, including the
  /// cached family tree — which used to survive sign-out, so the next person to
  /// sign in on the same device saw the previous account's family.
  Future<void> signOut() async {
    _token = null;
    _currentUser = null;
    await SessionStore.clear();
    _emit(null);
  }

  /// Re-read the current user from the backend (picks up role changes).
  Future<AppUser?> reloadUser() async {
    if (_token == null) return null;
    final user = await _fetchMe();
    if (user != null) {
      _currentUser = user;
      await _persistUser(user);
      _emit(user);
    }
    return user;
  }

  /// Update the signed-in user's display name.
  Future<AppUser> updateDisplayName(String name) => updateProfile(name: name);

  /// Update the signed-in user's profile photo.
  Future<AppUser> updatePhotoUrl(String photoUrl) =>
      updateProfile(photoUrl: photoUrl);

  /// Update the signed-in user's profile. Omitted fields are left unchanged.
  Future<AppUser> updateProfile({String? name, String? photoUrl}) async {
    if (_token == null) {
      throw AuthException('You must be signed in to update your profile.');
    }
    final response = await http.put(
      Uri.parse('$baseUrl/api/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      },
      body: jsonEncode({
        if (name != null) 'name': name.trim(),
        if (photoUrl != null) 'profilePhotoUrl': photoUrl,
      }),
    );

    final decoded = _decode(response.body);
    if (response.statusCode != 200 || decoded == null) {
      throw AuthException(_errorMessage(decoded, response.statusCode));
    }

    _currentUser = AppUser.fromJson(decoded);
    await _persistUser(_currentUser!);
    _emit(_currentUser);
    return _currentUser!;
  }

  /// Set a new password using a code an admin issued, and sign in with it.
  ///
  /// There is no mail server, so the code reaches the member however the admin
  /// normally reaches them — a phone call, a message. It is the admin
  /// recognising a relative that stands in for a verification email.
  Future<AppUser> resetPasswordWithCode({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    late final http.Response response;
    try {
      response = await http.post(
        Uri.parse('$baseUrl/reset-password'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim(),
          'code': code.trim(),
          'newPassword': newPassword,
        }),
      );
    } catch (_) {
      throw AuthException(
        'Could not reach the server. Check that the backend is running.',
      );
    }

    final decoded = _decode(response.body);
    if (response.statusCode != 200 || decoded == null) {
      throw AuthException(_errorMessage(decoded, response.statusCode));
    }

    final token = decoded['token'] as String?;
    final userJson = decoded['user'] as Map<String, dynamic>?;
    if (token == null || userJson == null) {
      // The password did change; only the auto sign-in did not happen.
      throw AuthException(
        'Password changed. Sign in with your new password.',
      );
    }

    _token = token;
    _currentUser = AppUser.fromJson(userJson);

    await SessionStore.writeToken(token);
    await _persistUser(_currentUser!);

    _emit(_currentUser);
    return _currentUser!;
  }

  /// Change the password of the signed-in user.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_token == null) {
      throw AuthException('You must be signed in to change your password.');
    }

    final response = await http.put(
      Uri.parse('$baseUrl/api/me/password'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      },
      body: jsonEncode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
    );

    if (response.statusCode != 200) {
      throw AuthException(
        _errorMessage(_decode(response.body), response.statusCode),
      );
    }
  }

  /// Permanently delete the signed-in user's account, then sign out.
  ///
  /// Their person record stays in the tree and becomes unclaimed — it belongs
  /// to the family's history, not to the login.
  Future<void> deleteAccount({required String password}) async {
    if (_token == null) {
      throw AuthException('You must be signed in to delete your account.');
    }

    final response = await http.delete(
      Uri.parse('$baseUrl/api/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      },
      body: jsonEncode({'password': password}),
    );

    if (response.statusCode != 200) {
      throw AuthException(
        _errorMessage(_decode(response.body), response.statusCode),
      );
    }

    await signOut();
  }

  Future<AppUser> _authenticate(
    String endpoint,
    Map<String, String> body,
  ) async {
    late final http.Response response;
    try {
      response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
    } catch (_) {
      throw AuthException(
        'Could not reach the server. Check that the backend is running.',
      );
    }

    final decoded = _decode(response.body);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw AuthException(_errorMessage(decoded, response.statusCode));
    }

    final token = decoded?['token'] as String?;
    final userJson = decoded?['user'] as Map<String, dynamic>?;
    if (token == null || userJson == null) {
      throw AuthException('Unexpected response from server.');
    }

    _token = token;
    _currentUser = AppUser.fromJson(userJson);

    await SessionStore.writeToken(token);
    await _persistUser(_currentUser!);

    _emit(_currentUser);
    return _currentUser!;
  }

  Future<AppUser?> _fetchMe() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/me'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (response.statusCode != 200) return null;
      final decoded = _decode(response.body);
      if (decoded == null) return null;
      return AppUser.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistUser(AppUser user) =>
      SessionStore.writeUser(jsonEncode(user.toJson()));

  Map<String, dynamic>? _decode(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  String _errorMessage(Map<String, dynamic>? decoded, int statusCode) {
    final error = decoded?['error'];
    if (error is String && error.isNotEmpty) {
      // Surface the friendly version of the binding-validation messages.
      if (error.contains('min') && error.contains('Password')) {
        return 'Password must be at least 6 characters.';
      }
      if (error.contains('email') && error.contains('required')) {
        return 'Please enter a valid email address.';
      }
      return error;
    }
    switch (statusCode) {
      case 401:
        return 'Incorrect email or password.';
      case 409:
        return 'That email is already registered.';
      default:
        return 'Something went wrong (HTTP $statusCode).';
    }
  }

  void _emit(AppUser? user) {
    if (!_authStateController.isClosed) {
      _authStateController.add(user);
    }
  }
}
