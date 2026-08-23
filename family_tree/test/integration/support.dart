import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// Shared setup for the tests that talk to a running backend.
///
/// These are integration tests, not unit tests, and they used to live alongside
/// the widget tests with an admin email and password written into the source —
/// `flutter test` therefore needed a live server and real credentials to pass,
/// which meant in practice it was never run.
///
/// Everything here comes from the environment now:
///
///     flutter test test/integration \
///       --dart-define=TEST_API_URL=http://localhost:8080 \
///       --dart-define=TEST_ADMIN_EMAIL=you@example.com \
///       --dart-define=TEST_ADMIN_PASSWORD=...
///
/// With no credentials configured the tests skip rather than fail, so a
/// contributor without a local server still gets a green run.
class Backend {
  static const url = String.fromEnvironment(
    'TEST_API_URL',
    defaultValue: 'http://localhost:8080',
  );
  static const adminEmail = String.fromEnvironment('TEST_ADMIN_EMAIL');
  static const adminPassword = String.fromEnvironment('TEST_ADMIN_PASSWORD');

  /// Whether credentials were supplied at all.
  static bool get isConfigured =>
      adminEmail.isNotEmpty && adminPassword.isNotEmpty;

  /// The reason to show when skipping, or null when the suite can run.
  static String? get skipReason => isConfigured
      ? null
      : 'Set TEST_ADMIN_EMAIL and TEST_ADMIN_PASSWORD to run the integration '
          'tests against a live backend.';

  /// Call from `setUpAll` in every integration suite.
  static void prepare() {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = null;
  }

  static Map<String, String> auth(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  /// Sign in and return a token. Throws with a useful message if the server is
  /// not reachable, rather than a null-check failure three frames later.
  static Future<String> signIn([String? email, String? password]) async {
    final http.Response response;
    try {
      response = await http.post(
        Uri.parse('$url/login'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email ?? adminEmail,
          'password': password ?? adminPassword,
        }),
      );
    } catch (error) {
      throw StateError('No backend at $url — start it with `go run .`. ($error)');
    }

    if (response.statusCode != 200) {
      throw StateError(
        'Sign-in failed with ${response.statusCode}: ${response.body}',
      );
    }
    return (jsonDecode(response.body) as Map<String, dynamic>)['token'] as String;
  }

  /// Register a throwaway account and return its id and token.
  static Future<({String id, String token, String email})> register(
    String name,
  ) async {
    final email = 'test_${DateTime.now().microsecondsSinceEpoch}@example.test';
    final response = await http.post(
      Uri.parse('$url/register'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': 'test-password-123',
        'name': name,
      }),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (
      id: (body['user'] as Map<String, dynamic>)['id'] as String,
      token: body['token'] as String,
      email: email,
    );
  }
}
