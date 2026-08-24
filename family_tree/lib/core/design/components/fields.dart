import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:family_tree/core/design/tokens.dart';
import 'package:family_tree/core/design/typography.dart';
import 'package:family_tree/core/theme/app_colors.dart';

/// A labelled text field.
///
/// The label sits above the field rather than floating inside it. A floating
/// label disappears the moment you start typing, which means a reader who
/// looks away mid-form comes back to a box of text with nothing saying what it
/// is. Above the field it stays put.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.helper,
    this.errorText,
    this.icon,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.sentences,
    this.obscureText = false,
    this.enabled = true,
    this.autofocus = false,
    this.maxLines = 1,
    this.maxLength,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.focusNode,
    this.optional = false,
  });

  final String label;
  final TextEditingController? controller;

  /// An example of what goes here, not a repeat of the label.
  final String? hint;

  /// A sentence under the field explaining why it is being asked for, or what
  /// happens to the answer.
  final String? helper;

  final String? errorText;
  final IconData? icon;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool obscureText;
  final bool enabled;
  final bool autofocus;
  final int maxLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? Function(String?)? validator;
  final FocusNode? focusNode;

  /// Marks the field as one that can be left blank.
  ///
  /// Optional is marked rather than required, which is the way round that
  /// suits a long profile form: almost everything here is optional, and
  /// starring the two fields that are not is quieter than starring the
  /// fifteen that are.
  final bool optional;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: AppType.label.copyWith(color: c.ink)),
            if (optional) ...[
              const SizedBox(width: Insets.xs),
              Text(
                'optional',
                style: AppType.caption.copyWith(color: c.inkMuted),
              ),
            ],
          ],
        ),
        const SizedBox(height: Insets.xs),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          autofocus: autofocus,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          maxLines: obscureText ? 1 : maxLines,
          maxLength: maxLength,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          validator: validator,
          style: AppType.body.copyWith(color: c.ink),
          cursorColor: c.accent,
          decoration: InputDecoration(
            hintText: hint,
            helperText: helper,
            helperMaxLines: 3,
            errorText: errorText,
            errorMaxLines: 3,
            counterText: '',
            prefixIcon: icon == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(
                      left: Insets.md,
                      right: Insets.sm,
                    ),
                    child: Icon(icon, size: Sizes.iconMd),
                  ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0),
            suffixIcon: suffix,
            // A taller box than the default. Multi-line fields grow from here.
            contentPadding: EdgeInsets.symmetric(
              horizontal: icon == null ? Insets.md : Insets.xs,
              vertical: maxLines > 1 ? Insets.md : Insets.md + 2,
            ),
          ),
        ),
      ],
    );
  }
}

/// A field that opens a picker rather than a keyboard — a date, a choice.
///
/// Looks exactly like [AppTextField] so a form does not visibly change
/// character halfway down, but the whole row is one large tap target.
class AppPickerField extends StatelessWidget {
  const AppPickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.placeholder = 'Choose',
    this.icon,
    this.helper,
    this.onClear,
    this.optional = false,
  });

  final String label;

  /// The current value, or null when nothing is chosen yet.
  final String? value;

  final VoidCallback onTap;
  final String placeholder;
  final IconData? icon;
  final String? helper;

  /// Shows a clear button when set and a value is present.
  final VoidCallback? onClear;

  final bool optional;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasValue = value != null && value!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: AppType.label.copyWith(color: c.ink)),
            if (optional) ...[
              const SizedBox(width: Insets.xs),
              Text(
                'optional',
                style: AppType.caption.copyWith(color: c.inkMuted),
              ),
            ],
          ],
        ),
        const SizedBox(height: Insets.xs),
        Material(
          color: c.surfaceRaised,
          borderRadius: Corners.medium,
          child: InkWell(
            onTap: onTap,
            borderRadius: Corners.medium,
            child: Container(
              height: Sizes.control,
              padding: const EdgeInsets.symmetric(horizontal: Insets.md),
              decoration: BoxDecoration(
                borderRadius: Corners.medium,
                border: Border.all(color: c.hairline),
              ),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: Sizes.iconMd, color: c.inkSoft),
                    const SizedBox(width: Insets.sm),
                  ],
                  Expanded(
                    child: Text(
                      hasValue ? value! : placeholder,
                      style: AppType.body.copyWith(
                        color: hasValue ? c.ink : c.inkMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hasValue && onClear != null)
                    IconButton(
                      onPressed: onClear,
                      icon: const Icon(Icons.close_rounded),
                      iconSize: Sizes.iconSm,
                      color: c.inkMuted,
                      tooltip: 'Clear',
                    )
                  else
                    Icon(
                      Icons.expand_more_rounded,
                      size: Sizes.iconMd,
                      color: c.inkMuted,
                    ),
                ],
              ),
            ),
          ),
        ),
        if (helper != null) ...[
          const SizedBox(height: Insets.xxs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.xxs),
            child: Text(
              helper!,
              style: AppType.bodySmall.copyWith(color: c.inkSoft),
            ),
          ),
        ],
      ],
    );
  }
}

/// A row of mutually exclusive choices, shown in full rather than hidden
/// behind a dropdown.
///
/// A dropdown hides every option but one, so choosing means tapping to find
/// out what the choices even are. With three or four short options there is
/// no reason not to show them all.
class AppChoiceField<T> extends StatelessWidget {
  const AppChoiceField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.helper,
    this.optional = false,
  });

  final String label;
  final T? value;
  final List<AppChoice<T>> options;
  final ValueChanged<T> onChanged;
  final String? helper;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: AppType.label.copyWith(color: c.ink)),
            if (optional) ...[
              const SizedBox(width: Insets.xs),
              Text(
                'optional',
                style: AppType.caption.copyWith(color: c.inkMuted),
              ),
            ],
          ],
        ),
        const SizedBox(height: Insets.xs),
        Wrap(
          spacing: Insets.xs,
          runSpacing: Insets.xs,
          children: [
            for (final option in options)
              _ChoiceChip<T>(
                option: option,
                selected: option.value == value,
                onTap: () => onChanged(option.value),
              ),
          ],
        ),
        if (helper != null) ...[
          const SizedBox(height: Insets.xs),
          Text(
            helper!,
            style: AppType.bodySmall.copyWith(color: c.inkSoft),
          ),
        ],
      ],
    );
  }
}

class AppChoice<T> {
  const AppChoice({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

class _ChoiceChip<T> extends StatelessWidget {
  const _ChoiceChip({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final AppChoice<T> option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Material(
      color: selected ? c.accentSoft : c.surfaceRaised,
      borderRadius: Corners.medium,
      child: InkWell(
        onTap: onTap,
        borderRadius: Corners.medium,
        child: AnimatedContainer(
          duration: Motion.fast,
          constraints: const BoxConstraints(minHeight: Sizes.minTouch - 8),
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.md,
            vertical: Insets.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: Corners.medium,
            border: Border.all(
              color: selected ? c.accent : c.hairline,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (option.icon != null) ...[
                Icon(
                  option.icon,
                  size: Sizes.iconSm,
                  color: selected ? c.accent : c.inkSoft,
                ),
                const SizedBox(width: Insets.xs),
              ],
              Text(
                option.label,
                style: AppType.label.copyWith(
                  color: selected ? c.accentDeep : c.ink,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
