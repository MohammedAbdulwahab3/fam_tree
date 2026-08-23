import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_tree/core/design/typography.dart';

/// The app used three Latin faces — Inter, Playfair Display, Cormorant
/// Garamond — and not one of them can draw Ethiopic. Every Amharic screen
/// therefore fell back to whatever sans the device happened to have, so the
/// two languages did not look like the same product.
void main() {
  test('every named style carries an Ethiopic fallback', () {
    final styles = <String, TextStyle>{
      'display': AppType.display,
      'title': AppType.title,
      'heading': AppType.heading,
      'subheading': AppType.subheading,
      'body': AppType.body,
      'bodyStrong': AppType.bodyStrong,
      'bodySmall': AppType.bodySmall,
      'label': AppType.label,
      'caption': AppType.caption,
      'overline': AppType.overline,
      'tabular': AppType.tabular,
      'sans': AppType.sans(fontSize: 14),
    };

    styles.forEach((name, style) {
      expect(
        style.fontFamilyFallback,
        isNotEmpty,
        reason: '$name would render Amharic in a system font',
      );
      expect(
        style.fontFamilyFallback!.any((f) => f.contains('Ethiopic')),
        isTrue,
        reason: '$name has no Ethiopic fallback',
      );
    });
  });

  test('every named style comes from the same family', () {
    final families = {
      AppType.display.fontFamily,
      AppType.body.fontFamily,
      AppType.caption.fontFamily,
      AppType.sans().fontFamily,
    };

    expect(families, hasLength(1), reason: 'one face does every job');
    expect(families.single, AppType.family);
  });

  // The drop-in exists so that fixing the script problem did not require
  // re-deciding the type on 225 call sites at the same time — which means it
  // has to preserve exactly what those call sites asked for.
  test('sans preserves the size, weight and colour it was given', () {
    final style = AppType.sans(
      fontSize: 13.5,
      fontWeight: FontWeight.w700,
      color: const Color(0xFF123456),
      letterSpacing: 0.4,
      height: 1.4,
    );

    expect(style.fontSize, 13.5);
    expect(style.fontWeight, FontWeight.w700);
    expect(style.color, const Color(0xFF123456));
    expect(style.letterSpacing, 0.4);
    expect(style.height, 1.4);
  });

  test('body text is large enough to read at arm\'s length', () {
    // 17pt rather than Material's 14. The people using this app are not all
    // confident with phones, and several are reading at a distance.
    expect(AppType.body.fontSize, greaterThanOrEqualTo(16));
  });

  test('the text theme fills every Material slot', () {
    final theme = AppType.textTheme(
      const Color(0xFF000000),
      const Color(0xFF666666),
    );

    for (final style in [
      theme.displayLarge,
      theme.headlineMedium,
      theme.titleLarge,
      theme.bodyLarge,
      theme.bodyMedium,
      theme.bodySmall,
      theme.labelLarge,
      theme.labelSmall,
    ]) {
      expect(style, isNotNull);
      expect(style!.fontFamilyFallback, isNotEmpty);
    }
  });
}
