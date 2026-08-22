import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:family_tree/data/services/auth_service.dart';

/// Headline numbers for the landing page, derived from the real tree.
class FamilyStats {
  final int people;
  final int generations;

  const FamilyStats({required this.people, required this.generations});

  /// Shown before the real numbers arrive, and if the backend is unreachable.
  static const unknown = FamilyStats(people: 0, generations: 0);
}

/// Reads the public tree endpoint (no auth) and derives headline counts.
final familyStatsProvider = FutureProvider<FamilyStats>((ref) async {
  final http.Response response;
  try {
    response = await http
        .get(Uri.parse('${AuthService.baseUrl}/public/persons'))
        .timeout(const Duration(seconds: 6));
  } catch (_) {
    return FamilyStats.unknown;
  }

  if (response.statusCode != 200) return FamilyStats.unknown;

  final decoded = jsonDecode(response.body);
  if (decoded is! List || decoded.isEmpty) return FamilyStats.unknown;

  // Map each person to their parent so depth can be walked from the roots.
  final parentOf = <String, String?>{};
  for (final raw in decoded) {
    if (raw is! Map<String, dynamic>) continue;
    final id = raw['id'] as String?;
    if (id == null) continue;
    final parents =
        (raw['relationships']?['parents'] as List?)?.cast<String>() ?? const [];
    parentOf[id] = parents.isEmpty ? null : parents.first;
  }

  var deepest = 0;
  for (final id in parentOf.keys) {
    var depth = 0;
    var cursor = parentOf[id];
    // Guard against a malformed cycle rather than looping forever.
    while (cursor != null && depth <= parentOf.length) {
      depth++;
      cursor = parentOf[cursor];
    }
    if (depth > deepest) deepest = depth;
  }

  return FamilyStats(people: parentOf.length, generations: deepest + 1);
});
