import 'package:flutter/material.dart';

import 'package:family_tree/core/design/tokens.dart';
import 'package:family_tree/core/design/typography.dart';
import 'package:family_tree/core/theme/app_colors.dart';

/// A bordered panel. Flat, with a hairline instead of a shadow.
///
/// Shadows imply a stack of floating planes; on a phone screen held by someone
/// who is not looking for depth cues, they mostly just add noise. A line is
/// enough to say "this is one thing".
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Insets.md),
    this.onTap,
    this.selected = false,
    this.tone,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool selected;

  /// Tints the card — for a warning, a success, an admin-only panel. Left
  /// unset the card is neutral, which is what almost every card should be.
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final border = selected
        ? c.accent
        : tone?.withValues(alpha: 0.35) ?? c.hairline;

    final content = AnimatedContainer(
      duration: Motion.fast,
      padding: padding,
      decoration: BoxDecoration(
        color: tone?.withValues(alpha: 0.06) ?? c.surface,
        borderRadius: Corners.large,
        border: Border.all(color: border, width: selected ? 2 : 1),
      ),
      child: child,
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: Corners.large,
        child: content,
      ),
    );
  }
}

/// A titled group of related fields or rows.
class AppSection extends StatelessWidget {
  const AppSection({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.icon,
    this.action,
    this.gap = Insets.md,
  });

  final String title;

  /// A sentence saying what this group is for. Worth writing for anything an
  /// unsure reader might otherwise skip past.
  final String? subtitle;

  final IconData? icon;

  /// A single action for the section — "Add", "Edit".
  final Widget? action;

  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon, size: Sizes.iconMd, color: c.accent),
              const SizedBox(width: Insets.xs),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppType.heading.copyWith(color: c.ink)),
                  if (subtitle != null) ...[
                    const SizedBox(height: Insets.xxs),
                    Text(
                      subtitle!,
                      style: AppType.bodySmall.copyWith(color: c.inkSoft),
                    ),
                  ],
                ],
              ),
            ),
            if (action != null) action!,
          ],
        ),
        SizedBox(height: gap),
        ...children,
      ],
    );
  }
}

/// What a screen shows when there is nothing on it yet.
///
/// Always names the reason and offers the way out. An empty screen with only
/// an illustration leaves a reader wondering whether the app is broken or they
/// are.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Insets.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Sizes.formWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: c.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: Sizes.iconXl, color: c.accent),
              ),
              const SizedBox(height: Insets.lg),
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
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: Insets.lg),
                FilledButton(
                  onPressed: onAction,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, Sizes.controlLarge),
                    padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
                  ),
                  child: Text(actionLabel!),
                ),
              ],
              if (secondaryLabel != null && onSecondary != null) ...[
                const SizedBox(height: Insets.xs),
                TextButton(
                  onPressed: onSecondary,
                  child: Text(secondaryLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A short notice inside a screen — an explanation, a warning, a confirmation
/// of state. Not a snackbar: this one stays put and can be read twice.
class AppNotice extends StatelessWidget {
  const AppNotice({
    super.key,
    required this.message,
    this.title,
    this.tone = NoticeTone.info,
    this.icon,
    this.action,
  });

  final String message;
  final String? title;
  final NoticeTone tone;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final (color, defaultIcon) = switch (tone) {
      NoticeTone.info => (c.info, Icons.info_outline_rounded),
      NoticeTone.success => (c.success, Icons.check_circle_outline_rounded),
      NoticeTone.warning => (c.warning, Icons.warning_amber_rounded),
      NoticeTone.danger => (c.danger, Icons.error_outline_rounded),
      NoticeTone.pending => (c.accent, Icons.hourglass_top_rounded),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: Corners.medium,
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? defaultIcon, size: Sizes.iconMd, color: color),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: AppType.bodyStrong.copyWith(color: c.ink),
                  ),
                  const SizedBox(height: Insets.xxs),
                ],
                Text(
                  message,
                  style: AppType.bodySmall.copyWith(color: c.inkSoft),
                ),
                if (action != null) ...[
                  const SizedBox(height: Insets.xs),
                  action!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum NoticeTone { info, success, warning, danger, pending }

/// A full-width row that behaves like a button — the building block of
/// settings and menus.
class AppRow extends StatelessWidget {
  const AppRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.leading,
    this.trailing,
    this.onTap,
    this.tone,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Colours the icon and title — for a destructive row, or an admin one.
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final titleColor = tone ?? c.ink;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: Corners.medium,
        child: Container(
          constraints: const BoxConstraints(minHeight: Sizes.minTouch),
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.md,
            vertical: Insets.sm,
          ),
          child: Row(
            children: [
              if (leading != null)
                leading!
              else if (icon != null)
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: (tone ?? c.accent).withValues(alpha: 0.1),
                    borderRadius: Corners.small,
                  ),
                  child: Icon(
                    icon,
                    size: Sizes.iconMd,
                    color: tone ?? c.accent,
                  ),
                ),
              if (leading != null || icon != null)
                const SizedBox(width: Insets.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: AppType.bodyStrong.copyWith(color: titleColor),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: AppType.bodySmall.copyWith(color: c.inkSoft),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  size: Sizes.iconMd,
                  color: c.inkMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
