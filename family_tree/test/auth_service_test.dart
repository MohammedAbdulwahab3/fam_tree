import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:family_tree/data/services/auth_service.dart';

/// Exercises the real Go backend on :5000. Skipped automatically if it is down.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The test binding stubs every HTTP call to 400; clear it so these tests
  // exercise the real backend on :5000.
  setUpAll(() => HttpOverrides.global = null);

  final unique = DateTime.now().microsecondsSinceEpoch;
  final email = 'test_$unique@example.com';
  const password = 'testpass123';

  setUp(() => SharedPreferences.setMockInitialValues({}));

  tearDown(() async => AuthService().signOut());

  // Each run registers a real account on the dev backend; remove it afterwards
  // so the users table does not accumulate test rows.
  tearDownAll(() async {
    try {
      final login = await http.post(
        Uri.parse('${AuthService.baseUrl}/login'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'email': 'maw3c3@gmail.com', 'password': 'developer'}),
      );
      if (login.statusCode != 200) return;
      final adminToken = jsonDecode(login.body)['token'] as String;

      final users = await http.get(
        Uri.parse('${AuthService.baseUrl}/api/admin/users'),
        headers: {'Authorization': 'Bearer $adminToken'},
      );
      if (users.statusCode != 200) return;

      for (final u in jsonDecode(users.body) as List) {
        if (u['email'] == email) {
          await http.delete(
            Uri.parse('${AuthService.baseUrl}/api/admin/users/${u['id']}'),
            headers: {'Authorization': 'Bearer $adminToken'},
          );
        }
      }
    } catch (_) {
      // Cleanup is best-effort; never fail the suite over it.
    }
  });

  test('register issues a token and signs the user in', () async {
    final user = await AuthService().signUpWithEmail(
      email: email,
      password: password,
      name: 'Test User',
    );
    expect(user.email, email);
    expect(user.name, 'Test User');
    expect(user.role, 'member');
    expect(AuthService().token, isNotNull);
    expect(AuthService().isSignedIn, isTrue);
  });

  test('login with correct credentials succeeds', () async {
    final user = await AuthService()
        .signInWithEmail(email: email, password: password);
    expect(user.email, email);
    expect(AuthService().token, isNotNull);
  });

  test('login with a wrong password is rejected', () async {
    expect(
      () => AuthService().signInWithEmail(email: email, password: 'nope'),
      throwsA(isA<AuthException>()),
    );
  });

  test('duplicate registration is rejected', () async {
    expect(
      () => AuthService().signUpWithEmail(
        email: email,
        password: password,
        name: 'Dup',
      ),
      throwsA(isA<AuthException>()),
    );
  });

  test('signOut clears the token and stored session', () async {
    await AuthService().signInWithEmail(email: email, password: password);
    expect(AuthService().isSignedIn, isTrue);

    await AuthService().signOut();
    expect(AuthService().token, isNull);
    expect(AuthService().currentUser, isNull);
    expect(AuthService().isSignedIn, isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('auth_token'), isNull);
  });

  test('updateProfile renames without clearing the photo', () async {
    await AuthService().signInWithEmail(email: email, password: password);
    await AuthService().updatePhotoUrl('http://example.com/p.png');
    final renamed = await AuthService().updateDisplayName('Renamed User');
    expect(renamed.name, 'Renamed User');
    expect(renamed.photoUrl, 'http://example.com/p.png');
  });

  test('a restored session survives init()', () async {
    await AuthService().signInWithEmail(email: email, password: password);
    final token = AuthService().token!;

    // Simulate a fresh app launch with the token already on disk.
    SharedPreferences.setMockInitialValues({'auth_token': token});
    final restored = await AuthService().init();
    expect(restored, isNotNull);
    expect(restored!.email, email);
  });

  test('init() with a junk token signs the user out', () async {
    SharedPreferences.setMockInitialValues({'auth_token': 'not-a-real-token'});
    final restored = await AuthService().init();
    expect(restored, isNull);
    expect(AuthService().isSignedIn, isFalse);
  });
}
