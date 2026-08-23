import 'package:flutter/material.dart';

import 'package:family_tree/core/design/tokens.dart';
import 'package:family_tree/core/design/typography.dart';
import 'package:family_tree/core/theme/app_colors.dart';

/// The standard page: a plain app bar, content in a readable column, and an
/// optional action pinned to the bottom where a thumb reaches.
///
/// Putting the primary action at the bottom rather than in the app bar matters
/// on a large phone: the top of the screen is the hardest place to reach
/// one-handed, and it is where the least important controls should live.
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions,
    this.bottomAction,
    this.leading,
    this.scrollable = true,
    this.padding = const EdgeInsets.all(Insets.gutter),
    this.constrainWidth = true,
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget>? actions;

  /// Pinned above the bottom edge, clear of the keyboard.
  final Widget? bottomAction;

  final Widget? leading;
  final bool scrollable;
  final EdgeInsetsGeometry padding;

  /// Keeps content within a readable column on a tablet or the web.
  final bool constrainWidth;

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    Widget body = Padding(padding: padding, child: child);

    if (constrainWidth) {
      body = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Sizes.readableWidth),
          child: body,
        ),
      );
    }

    if (scrollable) {
      body = SingleChildScrollView(
        // Space for the pinned action, so the last field is never trapped
        // behind it.
        padding: EdgeInsets.only(bottom: bottomAction == null ? 0 : 96),
        child: body,
      );
    }

    return Scaffold(
      backgroundColor: c.ground,
      appBar: AppBar(
        leading: leading ??
            (Navigator.of(context).canPop()
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: onBack ?? () => Navigator.of(context).pop(),
                    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  )
                : null),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title),
            if (subtitle != null)
              Text(
                subtitle!,
                style: AppType.caption.copyWith(color: c.inkSoft),
              ),
          ],
        ),
        actions: actions,
      ),
      body: SafeArea(child: body),
      bottomNavigationBar: bottomAction == null
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(
                  Insets.gutter,
                  Insets.sm,
                  Insets.gutter,
                  Insets.md,
                ),
                decoration: BoxDecoration(
                  color: c.ground,
                  border: Border(top: BorderSide(color: c.hairline)),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxWidth: Sizes.readableWidth),
                    child: bottomAction,
                  ),
                ),
              ),
            ),
    );
  }
}

/// A bottom sheet with a title and a scrollable body.
///
/// Opens at a size that shows its content rather than at an arbitrary
/// fraction, and drags to full height. A sheet that opens half-covering its
/// own first field is one of the more common ways a form feels broken.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required String title,
  required Widget Function(BuildContext context, ScrollController scroll) body,
  String? subtitle,
  Widget? bottomAction,
  double initialSize = 0.72,
  bool dismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: dismissible,
    enableDrag: dismissible,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      final c = context.colors;

      return DraggableScrollableSheet(
        initialChildSize: initialSize,
        minChildSize: 0.4,
        maxChildSize: 0.96,
        expand: false,
        builder: (context, scroll) => Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: Corners.sheet,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              const SizedBox(height: Insets.sm),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: c.hairline,
                  borderRadius: Corners.pill,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.gutter,
                  Insets.md,
                  Insets.xs,
                  Insets.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: AppType.heading.copyWith(color: c.ink),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style:
                                  AppType.bodySmall.copyWith(color: c.inkSoft),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: c.hairline),
              Expanded(child: body(context, scroll)),
              if (bottomAction != null)
                Container(
                  padding: const EdgeInsets.fromLTRB(
                    Insets.gutter,
                    Insets.sm,
                    Insets.gutter,
                    Insets.md,
                  ),
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: Border(top: BorderSide(color: c.hairline)),
                  ),
                  child: SafeArea(top: false, child: bottomAction),
                ),
            ],
          ),
        ),
      );
    },
  );
}
