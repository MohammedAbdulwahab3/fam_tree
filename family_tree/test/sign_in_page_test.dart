import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/features/auth/sign_in_page.dart';

Widget _harness({
  Size size = const Size(390, 844),
  Brightness brightness = Brightness.light,
  bool startOnSignUp = false,
}) {
  return ProviderScope(
    child: MediaQuery(
      data: MediaQueryData(size: size),
      child: MaterialApp(
        theme: brightness == Brightness.dark
            ? AppTheme.darkTheme
            : AppTheme.lightTheme,
        home: SignInPage(startOnSignUp: startOnSignUp),
      ),
    ),
  );
}

void main() {
  Future<void> pumpPage(WidgetTester tester, Widget widget) async {
    await tester.pumpWidget(widget);
    await tester.pump(const Duration(milliseconds: 400));
  }

  // The default test surface is 800x600 and the form scrolls, so in sign-up
  // mode — which carries a third field — the button below it starts off
  // screen. Tapping without scrolling first silently misses.
  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('renders', () {
    for (final entry in {
      'phone': const Size(390, 844),
      'tablet': const Size(1024, 768),
    }.entries) {
      testWidgets('on ${entry.key} without overflowing', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await pumpPage(tester, _harness(size: entry.value));

        expect(find.text('Welcome back'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('in dark theme', (tester) async {
      await pumpPage(tester, _harness(brightness: Brightness.dark));
      expect(tester.takeException(), isNull);
    });

    testWidgets('signing in asks for two things', (tester) async {
      await pumpPage(tester, _harness());
      expect(find.byType(TextFormField), findsNWidgets(2));
    });

    testWidgets('creating an account also asks for a name', (tester) async {
      await pumpPage(tester, _harness(startOnSignUp: true));

      expect(find.text('Create your account'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(3));
    });
  });

  group('behaviour', () {
    testWidgets('switching to sign up reveals the name field', (tester) async {
      await pumpPage(tester, _harness());
      expect(find.byType(TextFormField), findsNWidgets(2));

      await tapAndSettle(tester, find.text('Create an account'));

      expect(find.text('Create your account'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(3));
    });

    // Validation happens before anything reaches the network, so an empty form
    // never produces a request that fails for a reason nobody can read.
    testWidgets('an empty form explains what is missing', (tester) async {
      await pumpPage(tester, _harness());

      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Please enter your email address.'), findsOneWidget);
      expect(find.text('Please enter your password.'), findsOneWidget);
    });

    testWidgets('a short password is refused when creating an account',
        (tester) async {
      await pumpPage(tester, _harness(startOnSignUp: true));

      await tester.enterText(find.byType(TextFormField).at(1), 'a@b.com');
      await tester.enterText(find.byType(TextFormField).at(2), '123');
      await tapAndSettle(
          tester, find.widgetWithText(FilledButton, 'Create account'));

      expect(find.text('Please use at least 6 characters.'), findsOneWidget);
    });

    testWidgets('the password can be shown', (tester) async {
      await pumpPage(tester, _harness());

      expect(find.byIcon(Icons.visibility_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.visibility_rounded));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(Icons.visibility_off_rounded), findsOneWidget);
    });
  });
}
