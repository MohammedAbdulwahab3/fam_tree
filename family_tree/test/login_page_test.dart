import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_tree/features/auth/login_page.dart';

// NOTE: the page runs a deliberately endless ambient background animation, so
// pumpAndSettle would never return — every step pumps a fixed duration.

Widget _harness({required Size size, Brightness brightness = Brightness.dark}) {
  return ProviderScope(
    child: MediaQuery(
      data: MediaQueryData(size: size),
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: const LoginPage(),
      ),
    ),
  );
}

void main() {
  group('Login page renders', () {
    testWidgets('wide layout shows brand panel and form', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_harness(size: const Size(1440, 900)));
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Mammedu\nFamily'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2)); // email + password
      expect(tester.takeException(), isNull);
    });

    testWidgets('narrow layout stacks without the brand column',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_harness(size: const Size(390, 844)));
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('Mammedu Family'), findsOneWidget);
      expect(find.text('Welcome back'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('light theme renders without error', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _harness(size: const Size(1440, 900), brightness: Brightness.light),
      );
      await tester.pump(const Duration(milliseconds: 800));
      expect(tester.takeException(), isNull);
    });
  });

  group('Login page behaviour', () {
    testWidgets('toggling to sign up reveals the name field', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_harness(size: const Size(1440, 900)));
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.byType(TextFormField), findsNWidgets(2));

      await tester.tap(find.text('Create one'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Create your account'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(3)); // + name
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty submit surfaces validation instead of calling the API',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_harness(size: const Size(1440, 900)));
      await tester.pump(const Duration(milliseconds: 800));

      await tester.tap(find.text('Sign in'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Enter your email'), findsOneWidget);
      expect(find.text('Enter your password'), findsOneWidget);
    });

    testWidgets('password visibility toggle flips the obscure state',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_harness(size: const Size(1440, 900)));
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });
  });
}
