import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLocaleNotifier extends StateNotifier<Locale> {
  static const String _localeKey = 'app_locale';
  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('am'),
  ];

  AppLocaleNotifier() : super(const Locale('en')) {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLanguageCode = prefs.getString(_localeKey);
    if (savedLanguageCode != null) {
      state = _resolveLocale(savedLanguageCode);
      return;
    }

    state = _resolveLocale(PlatformDispatcher.instance.locale.languageCode);
  }

  Future<void> setLocale(Locale locale) async {
    state = _resolveLocale(locale.languageCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, state.languageCode);
  }

  Locale _resolveLocale(String languageCode) {
    for (final locale in supportedLocales) {
      if (locale.languageCode == languageCode) {
        return locale;
      }
    }
    return supportedLocales.first;
  }
}

final appLocaleProvider =
    StateNotifierProvider<AppLocaleNotifier, Locale>(
  (ref) => AppLocaleNotifier(),
);
