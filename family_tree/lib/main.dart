import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:family_tree/app_router.dart';
import 'package:family_tree/core/config.dart';
import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/features/auth/session.dart';
import 'package:family_tree/l10n/app_localizations.dart';
import 'package:family_tree/providers/locale_provider.dart';
import 'package:family_tree/providers/theme_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // A release build talking to a plain-HTTP server sends the session token in
  // clear text on every request. Fail loudly in debug rather than shipping it.
  assert(
    !AppConfig.isInsecureTransport || kDebugMode,
    'API_BASE_URL is ${AppConfig.apiBaseUrl}, which is not HTTPS. Build with '
    '--dart-define=API_BASE_URL=https://your-server for release.',
  );

  runApp(const ProviderScope(child: FamilyTreeApp()));
}

class FamilyTreeApp extends ConsumerStatefulWidget {
  const FamilyTreeApp({super.key});

  @override
  ConsumerState<FamilyTreeApp> createState() => _FamilyTreeAppState();
}

class _FamilyTreeAppState extends ConsumerState<FamilyTreeApp> {
  /// Restoring the stored session before the first frame is what stops the app
  /// flashing the signed-out tree at somebody who is already signed in.
  ///
  /// This used to happen in `main()`, before ProviderScope existed, which
  /// meant the session lived in a singleton the providers then had to be
  /// seeded from. Doing it here lets the router simply wait.
  late final Future<void> _restored =
      ref.read(sessionProvider.notifier).restore();

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(appLocaleProvider);

    return FutureBuilder<void>(
      future: _restored,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _SplashScreen(themeMode: themeMode);
        }

        return MaterialApp.router(
          title: 'Family Tree',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          locale: locale,
          supportedLocales: AppLocaleNotifier.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: ref.watch(routerProvider),
        );
      },
    );
  }
}

/// Held for the fraction of a second it takes to read the stored session off
/// the keystore. Deliberately plain: a spinner here would flash and look like
/// a stutter.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen({required this.themeMode});

  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) {
    final dark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
      home: Scaffold(
        backgroundColor:
            dark ? AppTheme.backgroundDark : AppTheme.backgroundLight,
        body: const SizedBox.expand(),
      ),
    );
  }
}
