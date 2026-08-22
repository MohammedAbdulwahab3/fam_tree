import 'package:flutter/material.dart';

/// Where the layout changes shape.
///
/// The app had grown five different answers to "is this a phone" — 600, 720,
/// 768, 800 and 940 — scattered across screens, so a window 700 pixels wide got
/// the phone layout on one screen and the desktop layout on the next.
enum Breakpoint {
  /// Phones. One column, full-width controls, labels hidden on icon buttons.
  compact,

  /// Large phones in landscape and small tablets. One column, but there is
  /// room for labels and side padding.
  medium,

  /// Tablets and desktop. Side-by-side layouts become worthwhile here.
  expanded;

  static const double mediumMin = 600;
  static const double expandedMin = 960;

  static Breakpoint of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);

  static Breakpoint fromWidth(double width) {
    if (width < mediumMin) return Breakpoint.compact;
    if (width < expandedMin) return Breakpoint.medium;
    return Breakpoint.expanded;
  }

  bool get isCompact => this == Breakpoint.compact;
  bool get isExpanded => this == Breakpoint.expanded;

  /// True on anything narrower than a tablet — the common "stack it" test.
  bool get isNarrow => this != Breakpoint.expanded;

  /// Pick a value per size without a chain of ternaries at the call site.
  T pick<T>({required T compact, T? medium, required T expanded}) {
    switch (this) {
      case Breakpoint.compact:
        return compact;
      case Breakpoint.medium:
        return medium ?? expanded;
      case Breakpoint.expanded:
        return expanded;
    }
  }
}

/// Layout helpers that read from the current [BuildContext].
extension ResponsiveContext on BuildContext {
  Breakpoint get breakpoint => Breakpoint.of(this);
  bool get isCompact => breakpoint.isCompact;
  bool get isExpanded => breakpoint.isExpanded;

  /// Comfortable page gutters for the current width.
  double get gutter => breakpoint.pick(compact: 16, medium: 24, expanded: 32);

  /// How wide a dialog or sheet should be here.
  ///
  /// Dialogs used to hardcode `width: 400`, which overflows a 360-pixel phone
  /// by the better part of a hundred pixels once dialog insets are taken off.
  double dialogWidth({double max = 440}) {
    final available = MediaQuery.sizeOf(this).width - 48;
    return available < max ? available : max;
  }

  /// The user's text scale, clamped so a very large system font enlarges type
  /// without bursting fixed-height chrome.
  TextScaler clampedTextScaler({double max = 1.4}) =>
      MediaQuery.textScalerOf(this).clamp(maxScaleFactor: max);
}
