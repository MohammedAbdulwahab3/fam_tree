import 'package:flutter/material.dart';

import 'package:family_tree/core/design/tokens.dart';
import 'package:family_tree/core/design/typography.dart';
import 'package:family_tree/core/theme/app_colors.dart';

/// The one thing a screen wants you to do.
///
/// Full width, 56pt tall, and it says what will happen rather than "OK" or
/// "Submit". While it is working it says so and stops accepting taps, because
/// the commonest way an unsure user creates a duplicate is tapping again when
/// nothing appeared to happen.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.busyLabel,
    this.expand = true,
    this.tone = ButtonTone.accent,
  });

  final String label;

  /// Null disables the button. A disabled primary action should be rare — it
  /// is usually better to let the tap happen and explain what is missing.
  final VoidCallback? onPressed;

  final IconData? icon;
  final bool busy;

  /// What to say while working. Defaults to [label], but a verb in progress
  /// ("Saving…") reassures where a repeated label does not.
  final String? busyLabel;

  final bool expand;
  final ButtonTone tone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final destructive = tone == ButtonTone.danger;

    final button = FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: destructive ? c.danger : c.accent,
        foregroundColor: destructive ? Colors.white : c.onAccent,
        disabledBackgroundColor: busy
            ? (destructive ? c.danger : c.accent)
            : c.hairline,
        disabledForegroundColor: busy
            ? (destructive ? Colors.white : c.onAccent)
            : c.inkMuted,
        minimumSize: const Size(0, Sizes.controlLarge),
        shape: const RoundedRectangleBorder(borderRadius: Corners.medium),
        textStyle: AppType.label.copyWith(fontSize: 17),
      ),
      child: _Content(
        label: busy ? (busyLabel ?? label) : label,
        icon: icon,
        busy: busy,
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// A second action beside a [PrimaryButton] — "Cancel", "Not now", "Skip".
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final button = OutlinedButton(
      onPressed: busy ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: c.ink,
        side: BorderSide(color: c.hairline, width: 1.5),
        minimumSize: const Size(0, Sizes.controlLarge),
        shape: const RoundedRectangleBorder(borderRadius: Corners.medium),
        textStyle: AppType.label.copyWith(fontSize: 17),
      ),
      child: _Content(label: label, icon: icon, busy: busy),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// A low-emphasis action — a link in a sentence, a "Change" beside a value.
class QuietButton extends StatelessWidget {
  const QuietButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.tone = ButtonTone.accent,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ButtonTone tone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = switch (tone) {
      ButtonTone.accent => c.accent,
      ButtonTone.danger => c.danger,
      ButtonTone.neutral => c.inkSoft,
    };

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        minimumSize: const Size(0, Sizes.minTouch),
        padding: const EdgeInsets.symmetric(horizontal: Insets.md),
        textStyle: AppType.label.copyWith(fontSize: 16),
      ),
      child: _Content(label: label, icon: icon, busy: false),
    );
  }
}

enum ButtonTone { accent, danger, neutral }

class _Content extends StatelessWidget {
  const _Content({required this.label, required this.icon, required this.busy});

  final String label;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation(
                DefaultTextStyle.of(context).style.color ?? Colors.white,
              ),
            ),
          ),
          const SizedBox(width: Insets.sm),
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      );
    }

    if (icon == null) {
      return Text(label, textAlign: TextAlign.center);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: Sizes.iconMd),
        const SizedBox(width: Insets.xs),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
