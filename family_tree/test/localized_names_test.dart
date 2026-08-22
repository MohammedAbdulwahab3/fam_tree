import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:family_tree/data/models/person.dart';

void main() {
  group('Person localized names (real backend payload)', () {
    late List<Person> persons;

    setUpAll(() {
      final raw = File('test/_live_sample.json').readAsStringSync();
      persons = (jsonDecode(raw) as List)
          .map((e) => Person.fromJson(e as Map<String, dynamic>))
          .toList();
    });

    test('parses localizedNames from the API payload', () {
      final root = persons.firstWhere((p) => p.firstName == 'Mammaduu');
      expect(root.localizedNames.containsKey('am'), isTrue);
      expect(root.localizedNames['am']!.firstName, 'ማማዱ');
      expect(root.localizedNames['am']!.lastName, 'ቤተሰብ');
    });

    test('renders Amharic for the am locale', () {
      final root = persons.firstWhere((p) => p.firstName == 'Mammaduu');
      expect(root.fullNameForLocaleTag('am'), 'ማማዱ ቤተሰብ');
      expect(root.shortNameForLocaleTag('am'), 'ማማዱ');
    });

    test('resolves region tags like am-ET down to the am entry', () {
      final issa = persons.firstWhere((p) => p.firstName == 'Issa');
      expect(issa.fullNameForLocaleTag('am-ET'), 'ኢሳ ማማዱ');
    });

    test('falls back to English for en and for unknown locales', () {
      final root = persons.firstWhere((p) => p.firstName == 'Mammaduu');
      expect(root.fullNameForLocaleTag('en'), 'Mammaduu Family');
      expect(root.fullNameForLocaleTag('fr'), 'Mammaduu Family');
      expect(root.fullNameForLocaleTag(null), 'Mammaduu Family');
    });

    test('keeps Latin text for names with no Amharic mapping', () {
      final makkah = persons.firstWhere((p) => p.firstName == 'Makkah');
      // Makkah has no entry in the source _amharicNameMap, so it stays Latin
      // while the surname still localizes.
      expect(makkah.fullNameForLocaleTag('am'), 'Makkah ኢሳ');
    });

    test('search matches across both scripts', () {
      final root = persons.firstWhere((p) => p.firstName == 'Mammaduu');
      expect(root.matchesNameQuery('ማማዱ'), isTrue);
      expect(root.matchesNameQuery('mammaduu'), isTrue);
      expect(root.matchesNameQuery('zzzz'), isFalse);
    });
  });
}
