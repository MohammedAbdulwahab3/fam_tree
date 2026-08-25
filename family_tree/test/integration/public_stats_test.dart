import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support.dart';

/// The public stats endpoint, which reports the tree's size without
/// exposing anybody in it.
///
/// This used to fetch `/public/persons` — every person's full record, contact
/// details included, without authentication — and count the generations here,
/// then assert the answer was exactly six. That endpoint is gone, and the
/// assertion was pinned to one particular seeded database.
void main() {
  Backend.prepare();
  final skip = Backend.skipReason;

  test('public stats reports a plausible tree', skip: skip, () async {
    final response = await http.get(Uri.parse('${Backend.url}/public/stats'));
    expect(response.statusCode, 200);

    final stats = jsonDecode(response.body) as Map<String, dynamic>;
    expect(stats['people'], isA<int>());
    expect(stats['generations'], isA<int>());

    // A tree with people in it has at least one generation, and cannot have
    // more generations than people.
    final people = stats['people'] as int;
    final generations = stats['generations'] as int;
    if (people > 0) {
      expect(generations, greaterThanOrEqualTo(1));
      expect(generations, lessThanOrEqualTo(people));
    }
  });

  test('public stats leaks nothing about individuals', skip: skip, () async {
    final response = await http.get(Uri.parse('${Backend.url}/public/stats'));
    final body = response.body.toLowerCase();

    for (final leaked in ['email', 'phone', 'birthdate', 'bio', 'firstname']) {
      expect(
        body.contains(leaked),
        isFalse,
        reason: 'the public endpoint must expose counts only, not people',
      );
    }
  });

  test('the tree itself needs authentication', skip: skip, () async {
    final response = await http.get(Uri.parse('${Backend.url}/api/persons'));
    expect(response.statusCode, 401);
  });
}
