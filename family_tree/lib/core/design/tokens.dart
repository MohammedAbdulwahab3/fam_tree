import 'package:flutter/widgets.dart';

/// The measurements every screen shares.
///
/// The people using this app are not all confident with phones. Several of the
/// numbers here are deliberately larger than the platform default — a 56pt
/// button instead of 48, 17pt body text instead of 14 — because a control that
/// is easy to hit and text that is easy to read is most of what "intuitive"
/// means for a reader who is not sure what will happen when they tap.
class Insets {
  const Insets._();

  /// A 4pt base scale. Everything is a multiple, so vertical rhythm holds
  /// without anyone having to think about it.
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double huge = 64;

  /// The margin from the edge of the screen to content.
  static const double gutter = 20;

  /// Space between a section's heading and its content.
  static const double sectionGap = 32;
}

/// Corner radii. Moderate and consistent — nothing is a perfect circle except
/// avatars and chips, and nothing is square.
class Corners {
  const Corners._();

  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;

  static const BorderRadius small = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius medium = BorderRadius.all(Radius.circular(md));
  static const BorderRadius large = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius extraLarge = BorderRadius.all(Radius.circular(xl));

  /// Sheets are rounded at the top only.
  static const BorderRadius sheet = BorderRadius.vertical(
    top: Radius.circular(xl),
  );

  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));
}

/// Control sizes.
class Sizes {
  const Sizes._();

  /// The smallest anything tappable is allowed to be. Material says 48; this
  /// app says 56, because a missed tap is the most common way an unconfident
  /// user decides an app is broken.
  static const double minTouch = 56;

  /// A primary button, and a text field.
  static const double control = 56;

  /// A large primary action — the one thing a screen wants you to do.
  static const double controlLarge = 64;

  /// Icon buttons in a toolbar.
  static const double iconButton = 48;

  /// Icons, by role.
  static const double iconSm = 18;
  static const double iconMd = 22;
  static const double iconLg = 28;
  static const double iconXl = 40;

  /// Avatars, by role.
  static const double avatarSm = 36;
  static const double avatarMd = 48;
  static const double avatarLg = 72;
  static const double avatarXl = 112;

  /// Running text stops being comfortable past about this width.
  static const double readableWidth = 560;

  /// A form or dialog on a wide screen.
  static const double formWidth = 480;
}

/// Motion. Short and few — animation should confirm what happened, not
/// perform.
class Motion {
  const Motion._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve standard = Curves.easeInOutCubic;
}
