import 'package:flutter_test/flutter_test.dart';

import 'package:family_tree/core/design/tokens.dart';
import 'package:family_tree/core/theme/app_colors.dart';
import 'package:family_tree/core/theme/app_theme.dart';

void main() {
  // Material says 48. This app says 56, because a missed tap is the most
  // common way somebody unsure of a phone decides an app is broken.
  test('controls are bigger than the platform minimum', () {
    expect(Sizes.minTouch, greaterThanOrEqualTo(48));
    expect(Sizes.control, greaterThanOrEqualTo(Sizes.minTouch));
    expect(Sizes.controlLarge, greaterThan(Sizes.control));
  });

  test('spacing is a consistent scale', () {
    final scale = [
      Insets.xxs,
      Insets.xs,
      Insets.sm,
      Insets.md,
      Insets.lg,
      Insets.xl,
      Insets.xxl,
    ];

    for (var i = 1; i < scale.length; i++) {
      expect(scale[i], greaterThan(scale[i - 1]));
    }
    for (final step in scale) {
      expect(step % 4, 0, reason: 'every step is a multiple of the 4pt base');
    }
  });

  group('palette', () {
    // A colour defined for only one theme is how an app ends up rendering one
    // theme's text on the other theme's ground.
    test('both themes define every role', () {
      for (final palette in [AppColors.light, AppColors.dark]) {
        for (final colour in [
          palette.ground,
          palette.surface,
          palette.surfaceRaised,
          palette.hairline,
          palette.ink,
          palette.inkSoft,
          palette.inkMuted,
          palette.accent,
          palette.accentDeep,
          palette.accentSoft,
          palette.onAccent,
          palette.success,
          palette.warning,
          palette.danger,
        ]) {
          expect(colour.a, 1.0, reason: 'palette colours are opaque');
        }
      }
    });

    test('the two themes are actually different', () {
      expect(AppColors.light.ground, isNot(AppColors.dark.ground));
      expect(AppColors.light.ink, isNot(AppColors.dark.ink));
    });

    // Status colours were one shared pair on the reasoning that green means
    // good either way. It does — but the same green is either too dark to read
    // on black or too light to read on white.
    test('status colours differ between themes', () {
      expect(AppColors.light.danger, isNot(AppColors.dark.danger));
      expect(AppColors.light.success, isNot(AppColors.dark.success));
    });

    test('ink reads against its own ground', () {
      double luminance(int argb) =>
          (argb & 0xFF) * 0.0722 +
          ((argb >> 8) & 0xFF) * 0.7152 +
          ((argb >> 16) & 0xFF) * 0.2126;

      // Light theme: dark ink on a light ground, and the reverse for dark.
      expect(
        luminance(AppColors.light.ink.toARGB32()),
        lessThan(luminance(AppColors.light.ground.toARGB32())),
      );
      expect(
        luminance(AppColors.dark.ink.toARGB32()),
        greaterThan(luminance(AppColors.dark.ground.toARGB32())),
      );
    });

    test('generation colours cycle rather than running out', () {
      expect(AppTheme.generationColors, isNotEmpty);
      expect(
        AppTheme.getGenerationColor(AppTheme.generationColors.length + 2),
        AppTheme.generationColors[2],
      );
      // Negative depth is a data problem, not a crash.
      expect(() => AppTheme.getGenerationColor(-3), returnsNormally);
    });
  });

  group('themes', () {
    test('both build, and carry the palette as an extension', () {
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        expect(theme.extension<AppColors>(), isNotNull);
        expect(theme.scaffoldBackgroundColor,
            theme.extension<AppColors>()!.ground);
      }
    });

    test('buttons are at least the minimum touch size in both', () {
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        final size =
            theme.filledButtonTheme.style?.minimumSize?.resolve({})?.height;
        expect(size, greaterThanOrEqualTo(Sizes.control));
      }
    });
  });
}
