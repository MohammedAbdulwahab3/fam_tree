import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Premium design system with warm gradients and glassmorphism
/// Supports both dark and light themes for an emotionally rich experience
class AppTheme {
  // ============ BRAND COLORS ============
  // Primary - Warm emerald to teal gradient
  // ============ BRAND ============
  //
  // One identity, two grounds. These used to be Tailwind emerald and teal
  // while every light-mode screen painted itself terracotta and cream from
  // ElegantColors — so `isDark ? AppTheme.primaryLight : ElegantColors.terracotta`,
  // written 31 times across the app, produced a warm earthy design in light
  // mode and a cold technical one in dark. They were not the same product with
  // the lights off; they were two designs.
  //
  // These are now the dark-ground counterparts of the ElegantColors palette:
  // the same hues, lifted for legibility on a dark surface.
  static const Color primaryDeep = Color(0xFFC1543C); // Terracotta, deepened
  static const Color primaryLight = Color(0xFFE07A5F); // Terracotta on dark
  static const Color accentTeal = Color(0xFFA3B58F); // Sage on dark
  static const Color accentCyan = Color(0xFF8FB0CC); // Soft blue on dark
  static const Color accentGold = Color(0xFFE3C05C); // Gold on dark
  static const Color accentRose = Color(0xFFE0AFAF); // Dusty rose on dark
  
  // ============ DARK MODE COLORS ============
  // Warm-dark grounds. Slate is blue-grey and fought the terracotta sitting on
  // top of it; these are the same charcoal the light theme uses for ink,
  // opened up into surfaces.
  static const Color backgroundDark = Color(0xFF1A1613);
  static const Color surfaceDark = Color(0xFF241E1A);
  static const Color cardDark = Color(0xFF2F2823);
  static const Color borderDark = Color(0xFF3E352D);
  
  // Dark mode text
  static const Color textPrimaryDark = Color(0xFFF6F1E9);
  static const Color textSecondaryDark = Color(0xFFD8CDC0);
  static const Color textMutedDark = Color(0xFFA99A8A);
  
  // ============ LIGHT MODE COLORS ============
  // These match ElegantColors exactly, which is what the screens were already
  // painting by hand. The theme said neutral grey; the app drew warm cream.
  static const Color backgroundLight = Color(0xFFFAF7F2); // cream
  static const Color surfaceLight = Color(0xFFFFFCF7); // warmWhite
  static const Color cardLight = Color(0xFFF5F0E6); // parchment
  static const Color borderLight = Color(0xFFE8DFD0);
  
  // Light mode text
  static const Color textPrimaryLight = Color(0xFF3D3833); // charcoal
  static const Color textSecondaryLight = Color(0xFF6B6259);
  static const Color textMutedLight = Color(0xFF8B8178); // warmGray
  
  // ============ GENERATION COLORS (Universal) ============
  // Generations were saturated Tailwind primaries — a rainbow that read as a
  // colour test rather than a family. These are the branch colours the
  // artboard already uses, muted to sit under the warm palette.
  static const List<Color> generationColors = [
    Color(0xFFCD5C45), // Terracotta
    Color(0xFF7D9471), // Sage
    Color(0xFFC9A227), // Ochre
    Color(0xFF6B8CAE), // Soft blue
    Color(0xFF8B7B9B), // Muted purple
    Color(0xFFB87333), // Copper
    Color(0xFF5B8C7B), // Sea green
  ];
  
  // ============ SEMANTIC COLORS ============
  static const Color success = Color(0xFF10B981); // Green-500
  static const Color warning = Color(0xFFF59E0B); // Amber-500
  static const Color error = Color(0xFFEF4444); // Red-500
  static const Color info = Color(0xFF3B82F6); // Blue-500
  
  // Legacy aliases for backwards compatibility
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
  
  // Typography
  static TextTheme get textTheme => TextTheme(
    // Display - Playfair Display for elegant names
    displayLarge: GoogleFonts.playfairDisplay(
      fontSize: 57,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.25,
      color: textPrimary,
    ),
    displayMedium: GoogleFonts.playfairDisplay(
      fontSize: 45,
      fontWeight: FontWeight.w400,
      color: textPrimary,
    ),
    displaySmall: GoogleFonts.playfairDisplay(
      fontSize: 36,
      fontWeight: FontWeight.w400,
      color: textPrimary,
    ),
    
    // Headings - Inter for UI
    headlineLarge: GoogleFonts.inter(
      fontSize: 32,
      fontWeight: FontWeight.w600,
      color: textPrimary,
    ),
    headlineMedium: GoogleFonts.inter(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      color: textPrimary,
    ),
    headlineSmall: GoogleFonts.inter(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: textPrimary,
    ),
    
    // Titles
    titleLarge: GoogleFonts.inter(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: textPrimary,
    ),
    titleMedium: GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: textPrimary,
    ),
    titleSmall: GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: textPrimary,
    ),
    
    // Body
    bodyLarge: GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: textPrimary,
    ),
    bodyMedium: GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: textPrimary,
    ),
    bodySmall: GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: textSecondary,
    ),
    
    // Labels
    labelLarge: GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: textPrimary,
    ),
    labelMedium: GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: textSecondary,
    ),
    labelSmall: GoogleFonts.inter(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: textMuted,
    ),
  );
  
  // ============ THEME DATA ============
  
  /// Dark Theme - Premium slate with emerald accents
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: primaryLight,
      secondary: accentTeal,
      tertiary: accentCyan,
      surface: surfaceDark,
      error: error,
    ),
    scaffoldBackgroundColor: backgroundDark,
    textTheme: _buildTextTheme(isDark: true),
    extensions: const [AppColors.dark],
    
    // Card theme
    cardTheme: CardThemeData(
      color: cardDark,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLg),
      ),
    ),
    
    // App bar theme
    appBarTheme: AppBarTheme(
      backgroundColor: surfaceDark.withValues(alpha: 0.8),
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimaryDark,
      ),
    ),
    
    // Button themes
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryLight,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(
          horizontal: spaceLg,
          vertical: spaceMd,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        elevation: 0,
      ),
    ),
    
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryLight,
        side: const BorderSide(color: primaryLight),
        padding: const EdgeInsets.symmetric(
          horizontal: spaceLg,
          vertical: spaceMd,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
    ),
    
    // Input decoration
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardDark,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: spaceMd,
        vertical: spaceMd,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: primaryLight, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: error, width: 1),
      ),
    ),
    
    // Dialog theme
    dialogTheme: DialogThemeData(
      backgroundColor: surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLg),
      ),
    ),
    
    // Bottom sheet theme
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
  );

  /// Light Theme - Clean and warm with soft shadows
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: primaryDeep,
      secondary: accentTeal,
      tertiary: accentCyan,
      surface: surfaceLight,
      error: error,
    ),
    scaffoldBackgroundColor: backgroundLight,
    textTheme: _buildTextTheme(isDark: false),
    extensions: const [AppColors.light],
    
    // Card theme
    cardTheme: CardThemeData(
      color: cardLight,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLg),
      ),
    ),
    
    // App bar theme
    appBarTheme: AppBarTheme(
      backgroundColor: surfaceLight.withValues(alpha: 0.9),
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimaryLight,
      ),
      iconTheme: const IconThemeData(color: textPrimaryLight),
    ),
    
    // Button themes
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryDeep,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(
          horizontal: spaceLg,
          vertical: spaceMd,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        elevation: 2,
        shadowColor: primaryDeep.withValues(alpha: 0.3),
      ),
    ),
    
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryDeep,
        side: const BorderSide(color: primaryDeep),
        padding: const EdgeInsets.symmetric(
          horizontal: spaceLg,
          vertical: spaceMd,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
    ),
    
    // Input decoration
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardLight,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: spaceMd,
        vertical: spaceMd,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: BorderSide(color: borderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: BorderSide(color: borderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: primaryDeep, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: error, width: 1),
      ),
    ),
    
    // Dialog theme
    dialogTheme: DialogThemeData(
      backgroundColor: surfaceLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLg),
      ),
    ),
    
    // Bottom sheet theme
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: surfaceLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
  );
  
  /// Build text theme based on brightness
  static TextTheme _buildTextTheme({required bool isDark}) {
    final textPrimary = isDark ? textPrimaryDark : textPrimaryLight;
    final textSecondary = isDark ? textSecondaryDark : textSecondaryLight;
    final textMuted = isDark ? textMutedDark : textMutedLight;
    
    return TextTheme(
      // Display - Playfair Display for elegant names
      displayLarge: GoogleFonts.playfairDisplay(
        fontSize: 57,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.25,
        color: textPrimary,
      ),
      displayMedium: GoogleFonts.playfairDisplay(
        fontSize: 45,
        fontWeight: FontWeight.w400,
        color: textPrimary,
      ),
      displaySmall: GoogleFonts.playfairDisplay(
        fontSize: 36,
        fontWeight: FontWeight.w400,
        color: textPrimary,
      ),
      
      // Headings - Inter for UI
      headlineLarge: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      
      // Titles
      titleLarge: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      
      // Body
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: textPrimary,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textPrimary,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: textSecondary,
      ),
      
      // Labels
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textPrimary,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: textSecondary,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: textMuted,
      ),
    );
  }
  
  // Helper to get generation color
  static Color getGenerationColor(int generation) {
    return generationColors[generation % generationColors.length];
  }
  
  // Glassmorphism decoration
  static BoxDecoration glassDecoration({
    Color? color,
    double borderRadius = radiusLg,
  }) {
    return BoxDecoration(
      color: (color ?? cardDark).withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.1),
        width: 1,
      ),
      boxShadow: shadowMd,
    );
  }
  
  // Gradient backgrounds
  static LinearGradient get primaryGradient => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDeep, primaryLight, accentTeal],
  );
  
  static LinearGradient get surfaceGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      surfaceDark.withValues(alpha: 0.8),
      cardDark.withValues(alpha: 0.6),
    ],
  );
}
