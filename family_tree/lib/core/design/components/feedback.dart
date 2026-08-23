import 'package:flutter/material.dart';

import 'package:family_tree/core/design/components/buttons.dart';
import 'package:family_tree/core/design/tokens.dart';
import 'package:family_tree/core/design/typography.dart';
import 'package:family_tree/core/theme/app_colors.dart';

/// Telling the user what just happened.
///
/// Every screen used to build its own SnackBar, so the same outcome looked
/// different depending on where you were standing, and several of them showed
/// the raw exception.
class Toast {
  const Toast._();

  static void show(
    BuildContext context,
    String message, {
    ToastTone tone = ToastTone.neutral,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    if (!context.mounted) return;
    final c = context.colors;

    final icon = switch (tone) {
      ToastTone.success => Icons.check_circle_rounded,
      ToastTone.danger => Icons.error_rounded,
      ToastTone.neutral => null,
    };
    final iconColor = switch (tone) {
      ToastTone.success => c.success,
      ToastTone.danger => c.danger,
      ToastTone.neutral => null,
    };

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: Sizes.iconMd, color: iconColor),
                const SizedBox(width: Insets.sm),
              ],
              Expanded(child: Text(message)),
            ],
          ),
          // Long enough to read a full sentence without hurrying.
          duration: Duration(
            milliseconds: tone == ToastTone.danger ? 6000 : 3500,
          ),
          action: actionLabel != null && onAction != null
              ? SnackBarAction(label: actionLabel, onPressed: onAction)
              : null,
        ),
      );
  }

  static void success(BuildContext context, String message) =>
      show(context, message, tone: ToastTone.success);

  static void error(BuildContext context, String message) =>
      show(context, message, tone: ToastTone.danger);
}

enum ToastTone { neutral, success, danger }

/// Asks before doing something that cannot be undone.
///
/// Returns true only if the user confirmed. The confirm button says what will
/// happen — "Delete Kulsum", not "OK" — because "OK" on a dialog you did not
/// read is how people delete their grandmother.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
  IconData? icon,
  Widget? detail,
}) async {
  final c = context.colors;

  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: icon == null
          ? null
          : Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: (destructive ? c.danger : c.accent)
                    .withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: Sizes.iconLg,
                color: destructive ? c.danger : c.accent,
              ),
            ),
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: AppType.body.copyWith(color: c.inkSoft)),
          if (detail != null) ...[
            const SizedBox(height: Insets.md),
            detail,
          ],
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        Insets.md,
        0,
        Insets.md,
        Insets.md,
      ),
      actions: [
        // Stacked, not side by side: two buttons in a row are easy to mis-tap,
        // and the destructive one should never be the one under your thumb.
        Column(
          children: [
            PrimaryButton(
              label: confirmLabel,
              tone: destructive ? ButtonTone.danger : ButtonTone.accent,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: Insets.xs),
            SecondaryButton(
              label: cancelLabel,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ],
    ),
  );

  return result ?? false;
}

/// A full-screen "working on it" for something that blocks.
///
/// Used sparingly — most waits belong on the button that started them, where
/// the user is already looking.
Future<T> withBlockingProgress<T>(
  BuildContext context,
  String message,
  Future<T> Function() work,
) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PopScope(
      canPop: false,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(Insets.lg),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: Corners.large,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: Insets.md),
              Text(message, style: AppType.body),
            ],
          ),
        ),
      ),
    ),
  );

  try {
    return await work();
  } finally {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }
}

/// A loading state that does not look like a broken screen.
class AppLoading extends StatelessWidget {
  const AppLoading({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: Insets.md),
            Text(
              message!,
              style: AppType.body.copyWith(color: c.inkSoft),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// What a screen shows when loading failed. Always offers the retry.
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.title = 'Something went wrong',
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Insets.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Sizes.formWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: c.danger.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud_off_rounded,
                  size: Sizes.iconLg,
                  color: c.danger,
                ),
              ),
              const SizedBox(height: Insets.md),
              Text(
                title,
                style: AppType.heading.copyWith(color: c.ink),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Insets.xs),
              Text(
                message,
                style: AppType.body.copyWith(color: c.inkSoft),
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: Insets.lg),
                SecondaryButton(
                  label: 'Try again',
                  icon: Icons.refresh_rounded,
                  expand: false,
                  onPressed: onRetry,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
