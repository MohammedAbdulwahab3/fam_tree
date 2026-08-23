import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:family_tree/core/config.dart';
import 'package:family_tree/core/logging.dart';

/// Headline numbers for the landing page, derived from the real tree.
class FamilyStats {
  const FamilyStats({required this.people, required this.generations});

  final int people;
  final int generations;

  /// Shown before the real numbers arrive, and if the backend is unreachable.
  static const unknown = FamilyStats(people: 0, generations: 0);
}

/// Reads the two headline counts from the backend, without authentication.
///
/// This used to fetch the entire tree from a public endpoint and count it here
/// — every person's contact email, phone number, birth date and biography
/// downloaded by anyone who loaded the landing page, in order to render two
/// numbers. The server now does the counting and returns only the answer.
final familyStatsProvider = FutureProvider<FamilyStats>((ref) async {
  final http.Response response;
  try {
    response = await http
        .get(Uri.parse('${AppConfig.apiBaseUrl}/public/stats'))
        .timeout(const Duration(seconds: 6));
  } catch (error) {
    log('Could not load the family stats', error);
    return FamilyStats.unknown;
  }

  if (response.statusCode != 200) return FamilyStats.unknown;

  try {
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return FamilyStats(
      people: decoded['people'] as int? ?? 0,
      generations: decoded['generations'] as int? ?? 0,
    );
  } catch (error) {
    log('Could not read the family stats', error);
    return FamilyStats.unknown;
  }
});
