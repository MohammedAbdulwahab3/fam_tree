import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_tree/core/design/design.dart';

void main() {
  testWidgets('a bottom action leaves the body its room', (tester) async {
    tester.view.physicalSize = const Size(1400, 950);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: AppPage(
        title: 'Forgotten password',
        bottomAction: PrimaryButton(label: 'Set new password', onPressed: () {}),
        child: const Text('the form'),
      ),
    ));
    await tester.pump();

    // The bar used to be given the whole window, which pushed the body out of
    // existence and painted over the app bar. Everything below is what that
    // looked like from the outside.
    final bar = tester.getRect(find.byType(BottomAppBar).evaluate().isEmpty
        ? find.widgetWithText(SafeArea, 'Set new password')
        : find.byType(BottomAppBar));
    expect(bar.height, lessThan(200),
        reason: 'the bottom bar swallowed the page');

    final body = tester.getRect(find.text('the form'));
    expect(body.height, greaterThan(0));
    expect(body.top, lessThan(bar.top),
        reason: 'the body must sit above the bottom bar');

    // The title has to actually be on screen, not underneath the bar.
    expect(find.text('Forgotten password'), findsOneWidget);
    final title = tester.getRect(find.text('Forgotten password'));
    expect(title.top, lessThan(100));
  });
}
