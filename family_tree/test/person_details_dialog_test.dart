import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_tree/data/models/person.dart';
import 'package:family_tree/features/auth/providers/auth_provider.dart';
import 'package:family_tree/features/tree_view/widgets/person_details_dialog.dart';

Person _person(String id, String first, {String last = 'Bekele'}) => Person(
      id: id,
      familyTreeId: 'test-tree',
      firstName: first,
      lastName: last,
      birthDate: DateTime(1958, 3, 14),
      bio: 'A long biography that needs to wrap across several lines without '
          'pushing the card out past the edges of a narrow phone screen.',
      occupation: 'Teacher',
      birthPlace: 'Addis Ababa',
      currentResidence: 'Dire Dawa',
      relationships: Relationships(),
      createdAt: DateTime(2020, 1, 1),
      updatedAt: DateTime(2020, 1, 1),
    );

Widget _harness({required Size size, Brightness brightness = Brightness.dark}) {
  return ProviderScope(
    overrides: [
      // The dialog asks who is signed in; nobody is, which is the read-only
      // path and keeps the test off the network.
      authStateProvider.overrideWith((ref) => Stream.value(null)),
    ],
    child: MediaQuery(
      data: MediaQueryData(size: size),
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: Scaffold(
          body: PersonDetailsDialog(
            person: _person('p1', 'Mamaduu'),
            spouses: [_person('p2', 'Aster')],
            children: [_person('p3', 'Yonas'), _person('p4', 'Meron')],
            onPersonTapped: (_) {},
          ),
        ),
      ),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  // 320 is the narrowest phone still in circulation; the card used to be a
  // hard 400 wide with 24 of margin either side, so it ran off both edges.
  final sizes = {
    'small phone': const Size(320, 640),
    'phone': const Size(360, 780),
    'large phone': const Size(414, 896),
    'tablet': const Size(834, 1112),
    'desktop': const Size(1440, 900),
  };

  for (final entry in sizes.entries) {
    for (final brightness in Brightness.values) {
      testWidgets('fits a ${entry.key} in ${brightness.name}', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _harness(size: entry.value, brightness: brightness),
        );
        await _settle(tester);

        expect(find.textContaining('Mamaduu'), findsWidgets);
        // takeException catches the "RenderFlex overflowed" assertion that a
        // fixed-width card raises on a narrow screen.
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('never draws wider than the screen allows', (tester) async {
    const size = Size(320, 640);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(size: size));
    await _settle(tester);

    for (final element in find.byType(Container).evaluate()) {
      final box = element.renderObject;
      if (box is RenderBox && box.hasSize) {
        expect(
          box.size.width,
          lessThanOrEqualTo(size.width),
          reason: 'a box wider than the screen means the card overflows',
        );
      }
    }
  });

  testWidgets('survives a large system text size', (tester) async {
    const size = Size(360, 780);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(1.5),
          ),
          child: MaterialApp(
            home: Scaffold(body: SizedBox.shrink()),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
