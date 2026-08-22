import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_tree/core/theme/app_colors.dart';
import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/core/theme/elegant_theme.dart';

/// Rough perceived lightness, for contrast sanity checks.
double _luminance(Color c) => c.computeLuminance();

double _contrast(Color a, Color b) {
  final l1 = _luminance(a), l2 = _luminance(b);
  final hi = l1 > l2 ? l1 : l2, lo = l1 > l2 ? l2 : l1;
  return (hi + 0.05) / (lo + 0.05);
}

/// How warm a colour is: red channel minus blue. The old dark theme was slate
/// (blue-biased); the unified one should lean warm like the light theme.
int _warmth(Color c) =>
    ((c.r * 255).round()) - ((c.b * 255).round());

void main() {
  group('one identity across both themes', () {
    test('the brand accent is the same hue family in light and dark', () {
      // Light mode has always been terracotta. Dark mode used to be emerald,
      // which is what made the two themes look like different products.
      expect(_warmth(AppColors.light.accent), greaterThan(40),
          reason: 'light accent should be warm (terracotta)');
      expect(_warmth(AppColors.dark.accent), greaterThan(40),
          reason: 'dark accent should be the warm counterpart, not emerald');
    });

    test('both grounds are warm, not blue-grey slate', () {
      expect(_warmth(AppColors.light.ground), greaterThan(0));
      expect(_warmth(AppColors.dark.ground), greaterThan(0),
          reason: 'the dark ground was Slate-900, which is blue-biased');
    });

    test('the light palette is exactly what the screens already painted', () {
      expect(AppColors.light.ground, ElegantColors.cream);
      expect(AppColors.light.surface, ElegantColors.warmWhite);
      expect(AppColors.light.ink, ElegantColors.charcoal);
      expect(AppColors.light.accent, ElegantColors.terracotta);
      // The ThemeData now agrees with them instead of saying neutral grey.
      expect(AppTheme.backgroundLight, ElegantColors.cream);
      expect(AppTheme.textPrimaryLight, ElegantColors.charcoal);
    });
  });

  group('legibility', () {
    for (final entry in {
      'light': AppColors.light,
      'dark': AppColors.dark,
    }.entries) {
      final c = entry.value;

      test('${entry.key}: body text on the ground clears 7:1', () {
        expect(_contrast(c.ink, c.ground), greaterThan(7.0));
      });

      test('${entry.key}: body text on a surface clears 7:1', () {
        expect(_contrast(c.ink, c.surface), greaterThan(7.0));
      });

      test('${entry.key}: secondary text clears 4.5:1', () {
        expect(_contrast(c.inkSoft, c.ground), greaterThan(4.5));
      });

      test('${entry.key}: muted text clears 3:1', () {
        // Timestamps and hints — large or incidental, so 3:1 is the bar.
        expect(_contrast(c.inkMuted, c.ground), greaterThan(3.0));
      });

      test('${entry.key}: the accent is readable on the ground', () {
        expect(_contrast(c.accent, c.ground), greaterThan(3.0));
      });

      test('${entry.key}: an accent wash still takes ink on top', () {
        expect(_contrast(c.ink, c.accentSoft), greaterThan(4.5));
      });
    }
  });

  group('wiring', () {
    // One pump per test: pumping twice in a row reuses the same element tree,
    // which makes what the second build actually saw ambiguous.
    testWidgets('context.colors resolves the light palette', (tester) async {
      late AppColors seen;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(builder: (context) {
          seen = context.colors;
          return const SizedBox();
        }),
      ));
      await tester.pump();
      expect(seen.ground, AppColors.light.ground);
      expect(seen.accent, AppColors.light.accent);
    });

    testWidgets('context.colors resolves the dark palette', (tester) async {
      late AppColors seen;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: Builder(builder: (context) {
          seen = context.colors;
          return const SizedBox();
        }),
      ));
      await tester.pump();
      expect(seen.ground, AppColors.dark.ground);
      expect(seen.accent, AppColors.dark.accent);
      expect(seen.ground, isNot(AppColors.light.ground));
    });

    testWidgets('a theme with no extension still yields a palette',
        (tester) async {
      late AppColors fallback;
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: Builder(builder: (context) {
          fallback = context.colors;
          return const SizedBox();
        }),
      ));
      await tester.pump();
      expect(fallback.ground, AppColors.dark.ground);
    });
  });
}
