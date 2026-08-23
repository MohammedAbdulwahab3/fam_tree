import 'package:flutter/material.dart';

/// One typeface, doing every job.
///
/// The app used three Latin families — Inter for most things, Playfair Display
/// and Cormorant Garamond for headings — and none of them can draw Ethiopic.
/// So every Amharic screen silently fell back to whatever sans the device
/// happened to have, and the two languages did not look like the same product.
///
/// Manrope carries the Latin text and Noto Sans Ethiopic is registered as its
/// fallback, so a heading in አማርኛ has the same weight and colour as the same
/// heading in English. Hierarchy comes from size and weight rather than from
/// switching faces, which is both the more minimal choice and the more legible
/// one for a reader who is not looking closely.
///
/// Both families are bundled under `assets/fonts` and declared in the pubspec.
/// They used to be fetched at runtime by `google_fonts`, which meant a first
/// launch on a slow connection showed system type — and Amharic in particular
/// fell back to whatever the device had, which is the exact problem this class
/// exists to solve.
class AppType {
  const AppType._();

  /// The bundled Latin family. Every style in the app is set in it.
  static const String family = 'Manrope';

  /// Ethiopic is a fallback rather than a separate style, so mixed text — a
  /// name in Amharic inside an English sentence — sets on one baseline.
  static const List<String> fallback = ['Noto Sans Ethiopic'];

  static TextStyle _face({
    required double size,
    required double height,
    required FontWeight weight,
    double tracking = 0,
  }) {
    return TextStyle(
      fontFamily: family,
      fontFamilyFallback: fallback,
      fontSize: size,
      height: height / size,
      fontWeight: weight,
      letterSpacing: tracking,
    );
  }

  /// A screen's one big statement. Used once per screen at most.
  static TextStyle get display =>
      _face(size: 34, height: 40, weight: FontWeight.w800, tracking: -0.8);

  /// A page or sheet title.
  static TextStyle get title =>
      _face(size: 26, height: 32, weight: FontWeight.w700, tracking: -0.5);

  /// A section heading.
  static TextStyle get heading =>
      _face(size: 21, height: 28, weight: FontWeight.w700, tracking: -0.3);

  /// A card heading, or a person's name in a list.
  static TextStyle get subheading =>
      _face(size: 18, height: 24, weight: FontWeight.w600, tracking: -0.2);

  /// Running text. 17pt rather than the usual 14 — this app is read by people
  /// who hold the phone at arm's length.
  static TextStyle get body =>
      _face(size: 17, height: 26, weight: FontWeight.w400);

  /// Running text that needs to stand out from the sentence around it.
  static TextStyle get bodyStrong =>
      _face(size: 17, height: 26, weight: FontWeight.w600);

  /// Secondary text under a heading, and helper text under a field.
  static TextStyle get bodySmall =>
      _face(size: 15, height: 22, weight: FontWeight.w400);

  /// A button, a tab, a field label.
  static TextStyle get label =>
      _face(size: 15, height: 20, weight: FontWeight.w600, tracking: 0.1);

  /// Timestamps, counts, hints — the things not meant to be read closely.
  static TextStyle get caption =>
      _face(size: 13, height: 18, weight: FontWeight.w500, tracking: 0.2);

  /// A small uppercase marker over a section. Used sparingly.
  static TextStyle get overline =>
      _face(size: 11, height: 14, weight: FontWeight.w700, tracking: 1.2);

  /// Numbers that line up in a column.
  static TextStyle get tabular => body.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// A drop-in for a direct `GoogleFonts.x(...)` call.
  ///
  /// The app had 224 of those across fifteen screens, in three different Latin
  /// families, none of which can draw Ethiopic — so every one of them rendered
  /// Amharic in whatever the device happened to have. This takes the same
  /// arguments and returns the same size, weight and colour in the one family,
  /// with the Ethiopic fallback attached.
  ///
  /// Prefer the named styles above in new code. This exists so that fixing the
  /// script problem did not require re-deciding the type on every screen at
  /// the same time.
  static TextStyle sans({
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    Color? color,
    Color? backgroundColor,
    double? letterSpacing,
    double? wordSpacing,
    double? height,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
    List<Shadow>? shadows,
    List<FontFeature>? fontFeatures,
    TextBaseline? textBaseline,
    Paint? foreground,
    Paint? background,
  }) {
    return TextStyle(
      fontFamily: family,
      fontFamilyFallback: fallback,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      color: color,
      backgroundColor: backgroundColor,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      height: height,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
      shadows: shadows,
      fontFeatures: fontFeatures,
      textBaseline: textBaseline,
      foreground: foreground,
      background: background,
    );
  }

  /// The Material text theme, so anything that has not been given an explicit
  /// style still lands inside the system.
  static TextTheme textTheme(Color ink, Color inkSoft) {
    return TextTheme(
      displayLarge: display.copyWith(color: ink),
      displayMedium: title.copyWith(color: ink),
      displaySmall: heading.copyWith(color: ink),
      headlineLarge: title.copyWith(color: ink),
      headlineMedium: heading.copyWith(color: ink),
      headlineSmall: subheading.copyWith(color: ink),
      titleLarge: subheading.copyWith(color: ink),
      titleMedium: bodyStrong.copyWith(color: ink),
      titleSmall: label.copyWith(color: ink),
      bodyLarge: body.copyWith(color: ink),
      bodyMedium: body.copyWith(color: ink),
      bodySmall: bodySmall.copyWith(color: inkSoft),
      labelLarge: label.copyWith(color: ink),
      labelMedium: label.copyWith(color: inkSoft),
      labelSmall: caption.copyWith(color: inkSoft),
    );
  }
}
