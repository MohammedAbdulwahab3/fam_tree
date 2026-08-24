import 'package:flutter/material.dart';

import 'app_theme.dart';

/// The old light-mode palette, kept as names pointing at the current one.
///
/// These were a separate warm scheme — cream, parchment, terracotta — painted
/// directly by around 120 call sites that never went through the theme. That is
/// why the app had two designs: screens reading `context.colors` got one
/// palette and screens reading `ElegantColors` got another, and a change to
/// either only fixed half the app.
///
/// Every name here now resolves to the single palette in [AppTheme], so those
/// call sites render correctly without each one having to be found first.
///
/// Do not use these in new code. Read `context.colors` instead, which resolves
/// for the theme in force rather than assuming a light one.
@Deprecated('Use context.colors — see AppColors')
class ElegantColors {
  const ElegantColors._();

  // Grounds.
  static const cream = AppTheme.backgroundLight;
  static const warmWhite = AppTheme.surfaceLight;
  static const parchment = AppTheme.cardLight;
  static const offWhite = AppTheme.surfaceLight;

  // What used to be the terracotta family is now the accent.
  static const terracotta = AppTheme.primary;
  static const sienna = AppTheme.primaryDeep;
  static const rust = AppTheme.error;
  static const copper = AppTheme.accentGold;

  // Supporting tones.
  static const sage = AppTheme.accentTeal;
  static const dustyRose = AppTheme.accentRose;
  static const warmGray = AppTheme.textMutedLight;
  static const charcoal = AppTheme.textPrimaryLight;

  static const gold = AppTheme.accentGold;
  static const champagne = Color(0xFFF3EBD4);

  static const softTeal = AppTheme.accentTeal;
  static const softBlue = AppTheme.info;
  static const softPurple = Color(0xFF7A6A9E);

  /// One colour per family line. The old set was twelve saturated primaries,
  /// which read as a colour test rather than a family; these are the
  /// generation colours, which are all the same weight as each other.
  static const List<Color> branchColors = AppTheme.generationColors;

  static const LinearGradient warmGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppTheme.primary, AppTheme.primaryDeep],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppTheme.accentGold, Color(0xFFDCBB58)],
  );

  static const LinearGradient sageGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppTheme.accentTeal, Color(0xFF6BA39C)],
  );
}
