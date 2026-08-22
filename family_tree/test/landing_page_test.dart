import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_tree/features/auth/landing_page.dart';
import 'package:family_tree/providers/family_stats_provider.dart';

// The page runs endless ambient animations, so pumpAndSettle would never
// return — every step pumps a fixed duration instead.
Widget _harness({
  required Size size,
  Brightness brightness = Brightness.dark,
  FamilyStats? stats,
}) {
  return ProviderScope(
    overrides: [
      familyStatsProvider.overrideWith(
        (ref) async => stats ?? const FamilyStats(people: 205, generations: 6),
      ),
    ],
    child: MediaQuery(
      data: MediaQueryData(size: size),
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: const LandingPage(),
      ),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 900));
  await tester.pump(const Duration(milliseconds: 1400)); // count-up finishes
}

void main() {
  for (final entry in {
    'desktop': const Size(1440, 900),
    'tablet': const Size(900, 1000),
    'mobile': const Size(390, 844),
  }.entries) {
    testWidgets('renders on ${entry.key} without overflow', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_harness(size: entry.value));
      await _settle(tester);

      // Appears twice by design: the navbar wordmark and the hero title.
      expect(find.text('Mammedu Family'), findsNWidgets(2));
      expect(find.text('Our Roots, Our Legacy, Our Story'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('light theme renders cleanly', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _harness(size: const Size(1440, 900), brightness: Brightness.light),
    );
    await _settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the real family counts, not the old placeholders',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(size: const Size(1440, 900)));
    await _settle(tester);

    expect(find.text('205'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    expect(find.text('Relatives'), findsOneWidget);
    expect(find.text('Generations'), findsOneWidget);
    // The hardcoded values this replaced must be gone.
    expect(find.text('50+'), findsNothing);
    expect(find.text('5+'), findsNothing);
  });

  testWidgets('falls back to a dash when the backend is unreachable',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _harness(size: const Size(1440, 900), stats: FamilyStats.unknown),
    );
    await _settle(tester);

    // Never invent a number: 0 renders as an em dash.
    expect(find.text('—'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
