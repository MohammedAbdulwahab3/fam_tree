import 'package:flutter/widgets.dart';
import 'package:family_tree/l10n/app_localizations.dart';

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;

  String get localeTag => Localizations.localeOf(this).toLanguageTag();
}
