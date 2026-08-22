import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_tree/main.dart';

void main() {
  testWidgets('Family tree app smoke test', (WidgetTester tester) async {
    // FamilyTreeApp is a ConsumerWidget, so it needs a ProviderScope ancestor
    // exactly like main() gives it.
    await tester.pumpWidget(const ProviderScope(child: FamilyTreeApp()));
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
