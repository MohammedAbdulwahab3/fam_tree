import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_tree/features/admin/admin_family_artboard.dart';

// Ambient aurora animates forever, so pumpAndSettle never returns.
Widget _harness({required Size size, Brightness brightness = Brightness.dark}) {
  return ProviderScope(
    child: MediaQuery(
      data: MediaQueryData(size: size),
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: const AdminFamilyArtboard(),
      ),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 900));
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  for (final entry in {
    'desktop': const Size(1280, 900),
    'mobile': const Size(390, 844),
  }.entries) {
    testWidgets('renders on ${entry.key} without overflow', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_harness(size: entry.value));
      await _settle(tester);

      expect(find.text('Family Artboard'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('light theme renders cleanly', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _harness(size: const Size(1280, 900), brightness: Brightness.light),
    );
    await _settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the header carries no create buttons at any width',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(size: const Size(1280, 900)));
    await _settle(tester);

    // Creating a member or a post lives in the tools menu now, so the header
    // stays a place to navigate and search rather than a call to action.
    expect(find.text('Add member'), findsNothing);
    expect(find.text('Add post'), findsNothing);
  });

  testWidgets('tools menu offers members, posts and the admin utilities',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(size: const Size(1280, 900)));
    await _settle(tester);

    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Members'), findsOneWidget);
    expect(find.text('Posts'), findsOneWidget);
    expect(find.text('Send announcement'), findsOneWidget);
    expect(find.text('Link requests'), findsOneWidget);
    expect(find.text('Export tree'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow layout folds the add actions into the menu',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(size: const Size(390, 844)));
    await _settle(tester);

    // Not shown inline at this width…
    expect(find.text('Add member'), findsNothing);

    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // …but still reachable.
    expect(find.text('Add member'), findsOneWidget);
    expect(find.text('Add post'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
