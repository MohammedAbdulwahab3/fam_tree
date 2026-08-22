import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// Exercises the admin API on the live backend at :5000.
const base = 'http://localhost:5000';

Future<String> _login(String email, String password) async {
  final r = await http.post(
    Uri.parse('$base/login'),
    headers: const {'Content-Type': 'application/json'},
    body: jsonEncode({'email': email, 'password': password}),
  );
  return jsonDecode(r.body)['token'] as String;
}

Map<String, String> _auth(String token) => {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => HttpOverrides.global = null);

  late String adminToken;
  late String adminId;
  late String victimId;
  late String victimToken;
  final victimEmail = 'victim_${DateTime.now().microsecondsSinceEpoch}@example.com';

  setUpAll(() async {
    adminToken = await _login('maw3c3@gmail.com', 'developer');
    adminId = jsonDecode(
      (await http.get(Uri.parse('$base/api/me'), headers: _auth(adminToken)))
          .body,
    )['id'] as String;

    final reg = await http.post(
      Uri.parse('$base/register'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': victimEmail,
        'password': 'victim123',
        'name': 'Victim',
      }),
    );
    final body = jsonDecode(reg.body);
    victimId = body['user']['id'] as String;
    victimToken = body['token'] as String;
  });

  tearDownAll(() async {
    // Never leave test accounts behind in the dev database.
    await http.delete(Uri.parse('$base/api/admin/users/$victimId'),
        headers: _auth(adminToken));
  });

  test('admin can list users', () async {
    final r = await http.get(Uri.parse('$base/api/admin/users'),
        headers: _auth(adminToken));
    expect(r.statusCode, 200);
    expect(jsonDecode(r.body), isA<List>());
  });

  test('a suspension revokes an already-issued token', () async {
    expect(
      (await http.get(Uri.parse('$base/api/persons'), headers: _auth(victimToken)))
          .statusCode,
      200,
    );

    final ban = await http.put(
      Uri.parse('$base/api/admin/users/$victimId/ban'),
      headers: _auth(adminToken),
      body: jsonEncode({'banned': true, 'reason': 'testing'}),
    );
    expect(ban.statusCode, 200);

    // The token was minted before the ban and must stop working anyway.
    expect(
      (await http.get(Uri.parse('$base/api/persons'), headers: _auth(victimToken)))
          .statusCode,
      403,
    );
  });

  test('a suspended account cannot log back in', () async {
    final r = await http.post(
      Uri.parse('$base/login'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'email': victimEmail, 'password': 'victim123'}),
    );
    expect(r.statusCode, 403);
  });

  test('restoring access works', () async {
    final r = await http.put(
      Uri.parse('$base/api/admin/users/$victimId/ban'),
      headers: _auth(adminToken),
      body: jsonEncode({'banned': false}),
    );
    expect(r.statusCode, 200);
    expect(
      (await http.get(Uri.parse('$base/api/persons'), headers: _auth(victimToken)))
          .statusCode,
      200,
    );
  });

  group('guards', () {
    test('admin cannot ban themselves', () async {
      final r = await http.put(
        Uri.parse('$base/api/admin/users/$adminId/ban'),
        headers: _auth(adminToken),
        body: jsonEncode({'banned': true}),
      );
      expect(r.statusCode, 409);
    });

    test('admin cannot delete themselves', () async {
      final r = await http.delete(Uri.parse('$base/api/admin/users/$adminId'),
          headers: _auth(adminToken));
      expect(r.statusCode, 409);
    });

    // The guard is "the *last* admin cannot be demoted", so it only returns
    // 409 when this account really is the only one. With a seeded second admin
    // the demotion is legitimate — and it used to actually go through, turning
    // the token into a member's and failing every later test in this file with
    // 403. There is no way to undo it either: the demoted account can no
    // longer reach the role endpoint. So the attempt is only made when it is
    // safe, and skipped loudly otherwise.
    test('the last admin cannot be demoted', () async {
      final users = jsonDecode(
        (await http.get(Uri.parse('$base/api/admin/users'),
                headers: _auth(adminToken)))
            .body,
      ) as List;
      final admins =
          users.where((u) => u['role'] == 'admin').map((u) => u['email']);

      if (admins.length > 1) {
        markTestSkipped(
          'needs a single-admin database; found ${admins.length}: '
          '${admins.join(', ')}',
        );
        return;
      }

      final r = await http.put(
        Uri.parse('$base/api/admin/users/$adminId/role'),
        headers: _auth(adminToken),
        body: jsonEncode({'role': 'member'}),
      );
      expect(r.statusCode, 409);
    });

    test('an unknown role is rejected', () async {
      final r = await http.put(
        Uri.parse('$base/api/admin/users/$victimId/role'),
        headers: _auth(adminToken),
        body: jsonEncode({'role': 'superuser'}),
      );
      expect(r.statusCode, 400);
    });

    test('a member cannot reach admin routes', () async {
      final r = await http.get(Uri.parse('$base/api/admin/users'),
          headers: _auth(victimToken));
      expect(r.statusCode, 403);
    });
  });

  test('announcement reaches every user as a notification', () async {
    final r = await http.post(
      Uri.parse('$base/api/admin/announcements'),
      headers: _auth(adminToken),
      body: jsonEncode({'title': 'Test notice', 'message': 'Body text'}),
    );
    expect(r.statusCode, 201);
    expect(jsonDecode(r.body)['recipients'], greaterThan(0));

    final inbox = await http.get(Uri.parse('$base/api/notifications'),
        headers: _auth(victimToken));
    final items = jsonDecode(inbox.body) as List;
    expect(items.any((n) => n['title'] == 'Test notice'), isTrue);
  });

  test('announcement rejects empty fields', () async {
    final r = await http.post(
      Uri.parse('$base/api/admin/announcements'),
      headers: _auth(adminToken),
      body: jsonEncode({'title': '  ', 'message': ''}),
    );
    expect(r.statusCode, 400);
  });

  test('export returns the full tree', () async {
    final r = await http.get(
        Uri.parse('$base/api/admin/export/main-family-tree'),
        headers: _auth(adminToken));
    expect(r.statusCode, 200);
    final body = jsonDecode(r.body);
    expect(body['counts']['people'], 205);
    expect((body['people'] as List).length, 205);
  });
}
