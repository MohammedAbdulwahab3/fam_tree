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

/// Hue in degrees, for checking two colours belong to the same family.
double _hue(Color c) => HSLColor.fromColor(c).hue;

/// How blue a colour is: blue channel minus red. The old dark theme was
/// Slate-900, which is strongly blue-biased (+27) and read as a different
/// product from the light theme.
int _blueBias(Color c) => ((c.b * 255).round()) - ((c.r * 255).round());

void main() {
  group('one identity across both themes', () {
    test('the brand accent is the same hue family in light and dark', () {
      // The app had three identities: context.colors said one thing, ~120
      // direct ElegantColors call sites said another, and dark mode was a
      // third. There is one evergreen accent now — the same green as the
      // launcher icon, which was already the identity everywhere except
      // inside the app. Dark mode lifts it rather than changing it.
      final light = _hue(AppColors.light.accent);
      final dark = _hue(AppColors.dark.accent);

      expect(light, inInclusiveRange(140, 180),
          reason: 'the light accent should be the evergreen, not terracotta');
      expect(dark, inInclusiveRange(140, 180),
          reason: 'the dark accent should be the same green, not emerald');
      expect((light - dark).abs(), lessThan(15),
          reason: 'one hue in both themes, differing only in lightness');
    });

    test('neither ground is blue-grey slate', () {
      // Slate-900 sits at +27 on this measure and reads cold next to the
      // light theme. Both grounds here are within a couple of points of
      // neutral, which is what lets the accent carry the whole identity.
      expect(_blueBias(AppColors.light.ground), lessThan(10));
      expect(_blueBias(AppColors.dark.ground), lessThan(10),
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
