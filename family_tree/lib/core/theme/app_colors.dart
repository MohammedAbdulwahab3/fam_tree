import 'package:flutter/material.dart';

import 'app_theme.dart';

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
    required this.onAccent,
    required this.success,
    required this.warning,
    required this.danger,
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

  /// The brand colour. An evergreen, lifted on dark grounds.
  final Color accent;

  /// A deeper accent for gradients and pressed states.
  final Color accentDeep;

  /// A wash of the accent, for tinted backgrounds behind icons and chips.
  final Color accentSoft;

  /// A supporting hue, desaturated so the accent stays the only voice
  /// raised above a murmur.
  final Color secondary;

  /// Gold, for anything celebratory — anniversaries, admin marks.
  final Color gold;

  /// A muted rose, used for mentions and personal notices.
  final Color rose;

  /// Informational blue, for neutral notices.
  final Color info;

  /// Text and icons drawn on top of [accent].
  final Color onAccent;

  /// Something worked.
  final Color success;

  /// Something needs attention but is not broken.
  final Color warning;

  /// Something failed, or is about to be destroyed.
  ///
  /// These three used to be one pair of constants shared by both themes, on
  /// the reasoning that green means good either way. It does — but the same
  /// green is either too dark to read on black or too light to read on white,
  /// so each theme now carries its own.
  final Color danger;

  /// The brand gradient for primary buttons and marks.
  final LinearGradient brandGradient;

  static const AppColors light = AppColors(
    ground: AppTheme.backgroundLight,
    surface: AppTheme.surfaceLight,
    surfaceRaised: AppTheme.cardLight,
    hairline: AppTheme.borderLight,
    ink: AppTheme.textPrimaryLight,
    inkSoft: AppTheme.textSecondaryLight,
    inkMuted: AppTheme.textMutedLight,
    accent: AppTheme.primary,
    accentDeep: AppTheme.primaryDeep,
    accentSoft: Color(0xFFE3F1EB),
    secondary: AppTheme.accentTeal,
    gold: AppTheme.accentGold,
    rose: AppTheme.accentRose,
    info: AppTheme.info,
    onAccent: Color(0xFFFFFFFF),
    success: AppTheme.success,
    warning: AppTheme.warning,
    danger: AppTheme.error,
    brandGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppTheme.primary, AppTheme.primaryDeep],
    ),
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
    accentDeep: AppTheme.primary,
    accentSoft: Color(0xFF12291F),
    secondary: AppTheme.accentTeal,
    gold: AppTheme.accentGoldDark,
    rose: AppTheme.accentRose,
    info: AppTheme.accentCyan,
    onAccent: Color(0xFF04231A),
    success: AppTheme.successDark,
    warning: AppTheme.warningDark,
    danger: AppTheme.errorDark,
    brandGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppTheme.primaryLight, AppTheme.primary],
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
    Color? onAccent,
    Color? success,
    Color? warning,
    Color? danger,
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
      onAccent: onAccent ?? this.onAccent,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
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
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
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
