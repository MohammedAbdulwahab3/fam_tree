import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'elegant_theme.dart';

/// The app's colours by the job they do, resolved for the current theme.
///
/// Screens used to pick colours with `isDark ? AppTheme.x : ElegantColors.y`,
/// written out at every call site — around 130 times. That put the decision
/// about what the app looks like inside each widget, so the two themes drifted
/// into two different designs and any change meant editing thirty files.
///
/// Read these through [ThemeColors.colors] instead:
///
/// ```dart
/// color: context.colors.accent,
/// ```
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.ground,
    required this.surface,
    required this.surfaceRaised,
    required this.hairline,
    required this.ink,
    required this.inkSoft,
    required this.inkMuted,
    required this.accent,
    required this.accentDeep,
    required this.accentSoft,
    required this.secondary,
    required this.gold,
    required this.rose,
    required this.info,
    required this.brandGradient,
  });

  /// The page behind everything.
  final Color ground;

  /// A card or sheet sitting on [ground].
  final Color surface;

  /// A panel raised above [surface] — an inset, a selected row.
  final Color surfaceRaised;

  /// Borders and dividers.
  final Color hairline;

  /// Body and heading text.
  final Color ink;

  /// Secondary text: subtitles, captions that still need to be read.
  final Color inkSoft;

  /// Text you are not meant to read closely: timestamps, hints.
  final Color inkMuted;

  /// The brand colour. Terracotta, lifted on dark grounds.
  final Color accent;

  /// A deeper accent for gradients and pressed states.
  final Color accentDeep;

  /// A wash of the accent, for tinted backgrounds behind icons and chips.
  final Color accentSoft;

  /// The second brand colour. Sage.
  final Color secondary;

  /// Gold, for anything celebratory — anniversaries, admin marks.
  final Color gold;

  /// Dusty rose, used for mentions and personal notices.
  final Color rose;

  /// Informational blue, for neutral notices.
  final Color info;

  /// The brand gradient for primary buttons and marks.
  final LinearGradient brandGradient;

  /// Status colours do not change between themes: green means good in both.
  Color get success => AppTheme.success;
  Color get warning => AppTheme.warning;
  Color get danger => AppTheme.error;

  static const AppColors light = AppColors(
    ground: ElegantColors.cream,
    surface: ElegantColors.warmWhite,
    surfaceRaised: ElegantColors.parchment,
    hairline: Color(0xFFE8DFD0),
    ink: ElegantColors.charcoal,
    inkSoft: Color(0xFF6B6259),
    inkMuted: ElegantColors.warmGray,
    accent: ElegantColors.terracotta,
    accentDeep: ElegantColors.sienna,
    accentSoft: Color(0xFFF6E7E2),
    secondary: ElegantColors.sage,
    gold: ElegantColors.gold,
    rose: ElegantColors.dustyRose,
    info: ElegantColors.softBlue,
    brandGradient: ElegantColors.warmGradient,
  );

  static const AppColors dark = AppColors(
    ground: AppTheme.backgroundDark,
    surface: AppTheme.surfaceDark,
    surfaceRaised: AppTheme.cardDark,
    hairline: AppTheme.borderDark,
    ink: AppTheme.textPrimaryDark,
    inkSoft: AppTheme.textSecondaryDark,
    inkMuted: AppTheme.textMutedDark,
    accent: AppTheme.primaryLight,
    accentDeep: AppTheme.primaryDeep,
    accentSoft: Color(0xFF3A2A24),
    secondary: AppTheme.accentTeal,
    gold: AppTheme.accentGold,
    rose: AppTheme.accentRose,
    info: AppTheme.accentCyan,
    brandGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppTheme.primaryDeep, AppTheme.primaryLight],
    ),
  );

  @override
  AppColors copyWith({
    Color? ground,
    Color? surface,
    Color? surfaceRaised,
    Color? hairline,
    Color? ink,
    Color? inkSoft,
    Color? inkMuted,
    Color? accent,
    Color? accentDeep,
    Color? accentSoft,
    Color? secondary,
    Color? gold,
    Color? rose,
    Color? info,
    LinearGradient? brandGradient,
  }) {
    return AppColors(
      ground: ground ?? this.ground,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      hairline: hairline ?? this.hairline,
      ink: ink ?? this.ink,
      inkSoft: inkSoft ?? this.inkSoft,
      inkMuted: inkMuted ?? this.inkMuted,
      accent: accent ?? this.accent,
      accentDeep: accentDeep ?? this.accentDeep,
      accentSoft: accentSoft ?? this.accentSoft,
      secondary: secondary ?? this.secondary,
      gold: gold ?? this.gold,
      rose: rose ?? this.rose,
      info: info ?? this.info,
      brandGradient: brandGradient ?? this.brandGradient,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      ground: Color.lerp(ground, other.ground, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkSoft: Color.lerp(inkSoft, other.inkSoft, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentDeep: Color.lerp(accentDeep, other.accentDeep, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      rose: Color.lerp(rose, other.rose, t)!,
      info: Color.lerp(info, other.info, t)!,
      brandGradient:
          LinearGradient.lerp(brandGradient, other.brandGradient, t)!,
    );
  }
}

/// `context.colors` — the app palette for the theme in force.
extension ThemeColors on BuildContext {
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? AppColors.dark
          : AppColors.light);
}
