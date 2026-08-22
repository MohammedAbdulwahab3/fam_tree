import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:family_tree/core/localization/app_localizations_x.dart';
import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/providers/locale_provider.dart';

class LocaleMenuButton extends ConsumerWidget {
  const LocaleMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(appLocaleProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopupMenuButton<Locale>(
      tooltip: context.l10n.languageMenuTooltip,
      onSelected: (locale) {
        ref.read(appLocaleProvider.notifier).setLocale(locale);
      },
      itemBuilder: (context) {
        return AppLocaleNotifier.supportedLocales.map((localeOption) {
          return PopupMenuItem<Locale>(
            value: localeOption,
            child: Text(_labelForLocale(context, localeOption)),
          );
        }).toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.translate_rounded,
              size: 18,
              color: isDark
                  ? AppTheme.textSecondaryDark
                  : AppTheme.textSecondaryLight,
            ),
            const SizedBox(width: 6),
            Text(
              locale.languageCode.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppTheme.textSecondaryDark
                    : AppTheme.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _labelForLocale(BuildContext context, Locale locale) {
    final l10n = context.l10n;
    switch (locale.languageCode) {
      case 'am':
        return l10n.localeAmharic;
      case 'en':
      default:
        return l10n.localeEnglish;
    }
  }
}
