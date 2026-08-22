import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// Guards the self-authored profile fields against the live backend at :5000.
///
/// The bug these exist for: `PUT /api/persons/:id` ends in GORM's `Save`,
/// which writes every column. The handler used to bind the body into a *zero*
/// Person, so any field the request omitted came back as empty — meaning a
/// profile form that posts only a bio and an occupation silently deleted the
/// person's parents, spouses and children. It really did wipe a five-child
/// family once. The handler now decodes onto the stored record instead.
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

  late String token;
  late String personId;
  late Map<String, dynamic> original;

  setUpAll(() async {
    token = await _login('maw3c3@gmail.com', 'developer');

    // Work on somebody who actually has relatives — the whole point is that
    // they survive.
    final all = jsonDecode(
      (await http.get(Uri.parse('$base/api/persons'), headers: _auth(token)))
          .body,
    ) as List;

    final withKin = all.firstWhere(
      (p) => ((p['relationships']?['children'] as List?) ?? const []).isNotEmpty,
      orElse: () => null,
    );
    expect(withKin, isNotNull,
        reason: 'the tree needs at least one person with children');

    personId = withKin['id'] as String;
    original = Map<String, dynamic>.from(withKin as Map);
  });

  tearDownAll(() async {
    // Put the record back exactly as it was found.
    await http.put(
      Uri.parse('$base/api/persons/$personId'),
      headers: _auth(token),
      body: jsonEncode(original),
    );
  });

  Future<Map<String, dynamic>> fetch() async {
    final r = await http.get(
      Uri.parse('$base/api/persons/$personId'),
      headers: _auth(token),
    );
    expect(r.statusCode, 200);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  test('a profile-only save keeps every relationship', () async {
    final before = await fetch();
    final parentsBefore =
        ((before['relationships']?['parents'] as List?) ?? const []).length;
    final childrenBefore =
        ((before['relationships']?['children'] as List?) ?? const []).length;
    expect(childrenBefore, greaterThan(0));

    // Exactly the shape the profile editor posts: no relationships key.
    final r = await http.put(
      Uri.parse('$base/api/persons/$personId'),
      headers: _auth(token),
      body: jsonEncode({
        'firstName': before['firstName'],
        'lastName': before['lastName'],
        'bio': 'A life spent close to the land.',
        'occupation': 'Farmer',
      }),
    );
    expect(r.statusCode, 200);

    final after = await fetch();
    expect(
      ((after['relationships']?['parents'] as List?) ?? const []).length,
      parentsBefore,
      reason: 'omitting relationships must not erase parents',
    );
    expect(
      ((after['relationships']?['children'] as List?) ?? const []).length,
      childrenBefore,
      reason: 'omitting relationships must not erase children',
    );
    expect(after['bio'], 'A life spent close to the land.');
    expect(after['occupation'], 'Farmer');
  });

  test('round-trips every self-authored profile field', () async {
    final r = await http.put(
      Uri.parse('$base/api/persons/$personId'),
      headers: _auth(token),
      body: jsonEncode({
        'occupation': 'Teacher',
        'education': 'Addis Ababa University',
        'birthPlace': 'Harar',
        'currentResidence': 'Dire Dawa',
        'contactEmail': 'test@example.com',
        'contactPhone': '+251 911 123456',
        'interests': ['Coffee', 'Poetry'],
      }),
    );
    expect(r.statusCode, 200);

    final after = await fetch();
    expect(after['occupation'], 'Teacher');
    expect(after['education'], 'Addis Ababa University');
    expect(after['birthPlace'], 'Harar');
    expect(after['currentResidence'], 'Dire Dawa');
    expect(after['contactEmail'], 'test@example.com');
    expect(after['contactPhone'], '+251 911 123456');
    expect(after['interests'], ['Coffee', 'Poetry']);
  });

  test('a partial save leaves untouched fields alone', () async {
    await http.put(
      Uri.parse('$base/api/persons/$personId'),
      headers: _auth(token),
      body: jsonEncode({'occupation': 'Weaver', 'birthPlace': 'Gondar'}),
    );

    // Now send only the occupation; the birth place must survive.
    final r = await http.put(
      Uri.parse('$base/api/persons/$personId'),
      headers: _auth(token),
      body: jsonEncode({'occupation': 'Potter'}),
    );
    expect(r.statusCode, 200);

    final after = await fetch();
    expect(after['occupation'], 'Potter');
    expect(after['birthPlace'], 'Gondar');
  });

  test('round-trips marital status, spouse name and photo', () async {
    final r = await http.put(
      Uri.parse('$base/api/persons/$personId'),
      headers: _auth(token),
      body: jsonEncode({
        'maritalStatus': 'married',
        'spouseName': 'Fatuma Ahmed',
        'profilePhotoUrl': 'http://example.com/photo.jpg',
      }),
    );
    expect(r.statusCode, 200);

    final after = await fetch();
    expect(after['maritalStatus'], 'married');
    expect(after['spouseName'], 'Fatuma Ahmed');
    expect(after['profilePhotoUrl'], 'http://example.com/photo.jpg');
  });

  test('an admin can mark someone as having died, and undo it', () async {
    await http.put(
      Uri.parse('$base/api/persons/$personId'),
      headers: _auth(token),
      body: jsonEncode({'isDeceased': true}),
    );
    expect((await fetch())['isDeceased'], isTrue);

    await http.put(
      Uri.parse('$base/api/persons/$personId'),
      headers: _auth(token),
      body: jsonEncode({'isDeceased': false}),
    );
    expect((await fetch())['isDeceased'], isFalse);
  });

  test('the admin review list resolves both sides to names', () async {
    final r = await http.get(
      Uri.parse('$base/api/admin/link-requests'),
      headers: _auth(token),
    );
    expect(r.statusCode, 200);

    final requests = jsonDecode(r.body) as List;
    for (final request in requests) {
      // Whatever else is true, an admin must never be shown a bare UUID pair.
      expect(request['requester'], isNotNull,
          reason: 'every pending request must name the account');
      expect(request['person'], isNotNull,
          reason: 'every pending request must name the claimed record');
      expect(request['requester']['email'], isNotEmpty);
      expect(request['person']['fullName'], isNotEmpty);
      expect(request['person'], contains('parentNames'));
      expect(request['person'], contains('childNames'));
    }
  });
}
