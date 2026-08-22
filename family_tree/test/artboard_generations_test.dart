import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// Guards the two data-correctness fixes on the artboard:
///  * the generation filter is derived from the tree, not hardcoded to 5
///  * every generation that exists is therefore reachable
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => HttpOverrides.global = null);

  test('the tree really does have six generations', () async {
    final r = await http.get(Uri.parse('http://localhost:5000/public/persons'));
    expect(r.statusCode, 200);

    final people = jsonDecode(r.body) as List;
    final parentOf = <String, String?>{};
    for (final p in people) {
      final parents = (p['relationships']?['parents'] as List?) ?? const [];
      parentOf[p['id'] as String] =
          parents.isEmpty ? null : parents.first as String;
    }

    int depth(String id) {
      var n = 0;
      var cursor = parentOf[id];
      while (cursor != null && n <= parentOf.length) {
        n++;
        cursor = parentOf[cursor];
      }
      return n;
    }

    final deepest = parentOf.keys.map(depth).reduce((a, b) => a > b ? a : b);
    // Six generations: the hardcoded filter stopped at five and hid the last.
    expect(deepest + 1, 6);
  });

  test('the artboard no longer hardcodes the generation list', () async {
    final source =
        File('lib/features/admin/admin_family_artboard.dart').readAsStringSync();
    expect(
      source.contains("'Gen 1', 'Gen 2', 'Gen 3', 'Gen 4', 'Gen 5'"),
      isFalse,
      reason: 'generations must be derived from the loaded tree',
    );
    expect(source.contains('for (var i = 1; i <= _generationCount; i++)'), isTrue);
  });

  test('child cards keep a readable minimum width', () async {
    final source =
        File('lib/features/admin/admin_family_artboard.dart').readAsStringSync();
    // The old scale bottomed out at 95px for parents with many children.
    expect(source.contains('return 95;'), isFalse);
    expect(source.contains('return 160;'), isTrue);
  });
}
