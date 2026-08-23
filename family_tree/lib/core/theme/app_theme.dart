import 'package:flutter/material.dart';

import 'package:family_tree/core/design/tokens.dart';
import 'package:family_tree/core/design/typography.dart';

import 'app_colors.dart';

/// The app's colours, and the two ThemeData objects built from them.
///
/// Read colours through `context.colors` rather than from here — see
/// [AppColors]. These constants remain because the palette itself has to live
/// somewhere, and because a good deal of the app still names them directly.
class AppTheme {
  // ============ BRAND ============
  //
  // One identity, one accent, two grounds.
  //
  // There used to be two palettes fighting: Tailwind emerald and teal for
  // dark, terracotta and cream for light, chosen per call site as
  // `isDark ? AppTheme.x : ElegantColors.y` about 130 times. That put the
  // decision about what the app looks like inside each widget, and the two
  // themes drifted into two different products.
  //
  // The accent is an evergreen — the same green as the launcher icon, which
  // was already the app's identity everywhere except the app itself. Deep
  // enough to read as considered rather than default, and it holds its meaning
  // on both a near-white and a near-black ground.
  static const Color primaryDeep = Color(0xFF0A5B43);
  static const Color primary = Color(0xFF0F7A5A);
  static const Color primaryLight = Color(0xFF3FBF92); // the accent on dark

  /// Celebratory only — a birthday, an anniversary, an admin mark. Gold means
  /// something here, so it is never used as decoration.
  static const Color accentGold = Color(0xFFC9A227);
  static const Color accentGoldDark = Color(0xFFE0BE4E);

  /// Supporting hues, kept desaturated so the accent stays the only voice
  /// raised above a murmur.
  static const Color accentTeal = Color(0xFF4E8C86);
  static const Color accentCyan = Color(0xFF5E87A8);
  static const Color accentRose = Color(0xFFBE7F7F);

  // ============ DARK GROUNDS ============
  // Near-black with a faint green cast, so the accent sits on it as a relative
  // rather than a stranger. Slate is blue-grey and fought everything on top.
  static const Color backgroundDark = Color(0xFF0D100F);
  static const Color surfaceDark = Color(0xFF151917);
  static const Color cardDark = Color(0xFF1E2321);
  static const Color borderDark = Color(0xFF2B322E);

  static const Color textPrimaryDark = Color(0xFFEDF0EE);
  static const Color textSecondaryDark = Color(0xFFA9B2AC);
  static const Color textMutedDark = Color(0xFF7B857E);

  // ============ LIGHT GROUNDS ============
  // Near-white, barely off-neutral. Cream and parchment read as a scrapbook;
  // this is a record the family keeps, and the photographs in it should be the
  // warmest thing on the screen.
  static const Color backgroundLight = Color(0xFFFCFCFB);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFF4F5F3);
  static const Color borderLight = Color(0xFFE3E6E2);

  static const Color textPrimaryLight = Color(0xFF141917);
  static const Color textSecondaryLight = Color(0xFF4E5651);
  static const Color textMutedLight = Color(0xFF7C857F);

  // ============ GENERATIONS ============
  // One family of colours rather than a rainbow. Each is the same weight and
  // saturation, so a generation reads as "a different branch" and not as a
  // warning, a success, or a colour test.
  static const List<Color> generationColors = [
    Color(0xFF0F7A5A), // evergreen — the trunk
    Color(0xFF4E7CA1), // slate blue
    Color(0xFFB07C3F), // amber-brown
    Color(0xFF7A6A9E), // muted violet
    Color(0xFF4E8C86), // teal
    Color(0xFFA9636B), // muted red
    Color(0xFF6E8B4A), // olive
  ];

  // ============ SEMANTIC ============
  // Separate from the accent, and only ever used for what they mean.
  static const Color success = Color(0xFF1E8A5F);
  static const Color warning = Color(0xFFB4791A);
  static const Color error = Color(0xFFB4423A);
  static const Color info = Color(0xFF4E7CA1);

  // On a dark ground the same meanings need lifting to stay legible.
  static const Color successDark = Color(0xFF4FBF8B);
  static const Color warningDark = Color(0xFFE0A93F);
  static const Color errorDark = Color(0xFFE07A70);

  /// The one gradient in the app, from the deep green through the accent.
  ///
  /// Six call sites — the landing page, the tree's primary action, a post's
  /// author chip — draw it, so it is defined once rather than rebuilt inline
  /// with slightly different stops each time.
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDeep, primary, primaryLight],
  );

  // Legacy aliases, kept so older call sites still resolve.
  static const Color textPrimary = textPrimaryDark;
  static const Color textSecondary = textSecondaryDark;
  static const Color textMuted = textMutedDark;

  // Spacing system (8px grid)
  static const double spaceXs = 4.0;
  static const double spaceSm = 8.0;
  static const double spaceMd = 16.0;
  static const double spaceLg = 24.0;
  static const double spaceXl = 32.0;
  static const double space2xl = 48.0;

  // Border radius
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;
  static const double radiusFull = 9999.0;

  // Elevation & Shadows
  static List<BoxShadow> get shadowSm => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get shadowMd => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.15),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get shadowLg => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.2),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get shadowGlow => [
        BoxShadow(
          color: primaryLight.withValues(alpha: 0.3),
          blurRadius: 20,
          offset: const Offset(0, 0),
        ),
      ];

  /// The legacy TextTheme getter, now sourced from [AppType] so anything still
  /// reading it lands inside the type system rather than beside it.
  static TextTheme get textTheme =>
      AppType.textTheme(textPrimaryDark, textSecondaryDark);

  /// The colour for a generation band, wrapping so an unusually deep family
  /// keeps cycling through the same restrained set.
  static Color getGenerationColor(int generation) =>
      generationColors[generation.abs() % generationColors.length];

  // ============ THEME DATA ============

  static ThemeData get lightTheme => _theme(AppColors.light, Brightness.light);
  static ThemeData get darkTheme => _theme(AppColors.dark, Brightness.dark);

  /// One builder for both themes.
  ///
  /// The two used to be written out separately, about a hundred lines each,
  /// and had drifted: different radii, different button padding, a filled
  /// input on one and an outlined one on the other. Anything that should
  /// genuinely differ between them is already a token in [AppColors].
  static ThemeData _theme(AppColors c, Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: isDark ? const Color(0xFF04231A) : Colors.white,
      primaryContainer: c.accentSoft,
      onPrimaryContainer: c.accentDeep,
      secondary: c.secondary,
      onSecondary: Colors.white,
      tertiary: c.gold,
      onTertiary: const Color(0xFF241B00),
      surface: c.surface,
      onSurface: c.ink,
      surfaceContainerHighest: c.surfaceRaised,
      onSurfaceVariant: c.inkSoft,
      outline: c.hairline,
      outlineVariant: c.hairline,
      error: c.danger,
      onError: Colors.white,
    );

    final text = AppType.textTheme(c.ink, c.inkSoft);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.ground,
      canvasColor: c.ground,
      textTheme: text,
      extensions: [c],
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: c.ground,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppType.heading.copyWith(color: c.ink),
        iconTheme: IconThemeData(color: c.ink, size: Sizes.iconMd),
      ),

      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: Corners.large,
          side: BorderSide(color: c.hairline),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: c.hairline,
        thickness: 1,
        space: 1,
      ),

      // Every button is at least 56pt tall. The default 48 is the smallest a
      // confident user needs; it is not the smallest an unsure one can hit.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: c.hairline,
          disabledForegroundColor: c.inkMuted,
          minimumSize: const Size(0, Sizes.control),
          padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
          shape: const RoundedRectangleBorder(borderRadius: Corners.medium),
          textStyle: AppType.label.copyWith(fontSize: 16),
          elevation: 0,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(0, Sizes.control),
          padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
          shape: const RoundedRectangleBorder(borderRadius: Corners.medium),
          textStyle: AppType.label.copyWith(fontSize: 16),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.ink,
          side: BorderSide(color: c.hairline, width: 1.5),
          minimumSize: const Size(0, Sizes.control),
          padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
          shape: const RoundedRectangleBorder(borderRadius: Corners.medium),
          textStyle: AppType.label.copyWith(fontSize: 16),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.accent,
          minimumSize: const Size(0, Sizes.minTouch),
          padding: const EdgeInsets.symmetric(horizontal: Insets.md),
          shape: const RoundedRectangleBorder(borderRadius: Corners.medium),
          textStyle: AppType.label.copyWith(fontSize: 16),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: c.ink,
          minimumSize: const Size(Sizes.iconButton, Sizes.iconButton),
          shape: const RoundedRectangleBorder(borderRadius: Corners.medium),
        ),
      ),

      // A filled field with no border until it is focused. An outlined box on
      // a white ground reads as decoration; a filled one reads as somewhere to
      // type, which is what an unsure user is looking for.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceRaised,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.md,
        ),
        hintStyle: AppType.body.copyWith(color: c.inkMuted),
        labelStyle: AppType.body.copyWith(color: c.inkSoft),
        floatingLabelStyle: AppType.label.copyWith(color: c.accent),
        helperStyle: AppType.bodySmall.copyWith(color: c.inkSoft),
        errorStyle: AppType.bodySmall.copyWith(color: c.danger),
        prefixIconColor: c.inkSoft,
        suffixIconColor: c.inkSoft,
        border: const OutlineInputBorder(
          borderRadius: Corners.medium,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: Corners.medium,
          borderSide: BorderSide(color: c.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Corners.medium,
          borderSide: BorderSide(color: c.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: Corners.medium,
          borderSide: BorderSide(color: c.danger, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: Corners.medium,
          borderSide: BorderSide(color: c.danger, width: 2),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceRaised,
        selectedColor: c.accentSoft,
        side: BorderSide(color: c.hairline),
        labelStyle: AppType.label.copyWith(color: c.ink),
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.sm,
          vertical: Insets.xs,
        ),
        shape: const RoundedRectangleBorder(borderRadius: Corners.pill),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: c.surface,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: Corners.sheet),
        showDragHandle: true,
        dragHandleColor: c.hairline,
        dragHandleSize: const Size(44, 5),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: Corners.large),
        titleTextStyle: AppType.heading.copyWith(color: c.ink),
        contentTextStyle: AppType.body.copyWith(color: c.inkSoft),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? c.surfaceRaised : const Color(0xFF1E2321),
        contentTextStyle: AppType.body.copyWith(
          color: isDark ? c.ink : Colors.white,
        ),
        actionTextColor: c.accent,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: Corners.medium),
        insetPadding: const EdgeInsets.all(Insets.md),
        elevation: 0,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? Colors.white : c.inkMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? c.accent
              : c.surfaceRaised,
        ),
        trackOutlineColor: WidgetStateProperty.all(c.hairline),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.accent,
        linearTrackColor: c.surfaceRaised,
        circularTrackColor: c.surfaceRaised,
      ),

      listTileTheme: ListTileThemeData(
        iconColor: c.inkSoft,
        titleTextStyle: AppType.bodyStrong.copyWith(color: c.ink),
        subtitleTextStyle: AppType.bodySmall.copyWith(color: c.inkSoft),
        minVerticalPadding: Insets.sm,
        shape: const RoundedRectangleBorder(borderRadius: Corners.medium),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? c.surfaceRaised : const Color(0xFF1E2321),
          borderRadius: Corners.small,
        ),
        textStyle: AppType.caption.copyWith(
          color: isDark ? c.ink : Colors.white,
        ),
      ),
    );
  }
}
