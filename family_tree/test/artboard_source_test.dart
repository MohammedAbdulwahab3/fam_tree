import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards a regression that is easiest to check by reading the source.
///
/// The artboard once rendered a hardcoded five-entry generation filter, which
/// silently hid the sixth generation of a family that had one. Deriving the
/// list from the loaded tree is the fix, and this makes sure it stays derived.
///
/// It was previously bundled with tests that needed a live backend, so it never
/// ran; it needs nothing but the file.
void main() {
  final artboard =
      File('lib/features/admin/admin_family_artboard.dart').readAsStringSync();

  test('the generation filter is derived from the tree', () {
    expect(
      artboard.contains("'Gen 1', 'Gen 2', 'Gen 3', 'Gen 4', 'Gen 5'"),
      isFalse,
      reason: 'a fixed list hides any generation past the last one listed',
    );
    expect(
      artboard.contains('for (var i = 1; i <= _generationCount; i++)'),
      isTrue,
      reason: 'the filter should be built from the loaded tree',
    );
  });
}
