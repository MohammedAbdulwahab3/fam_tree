import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/data/services/auth_service.dart';
import 'package:family_tree/features/tree_view/tree_screen.dart';
import 'package:family_tree/features/auth/landing_page.dart';
import 'package:family_tree/features/auth/login_page.dart';
import 'package:family_tree/features/admin/admin_family_artboard.dart';
import 'package:family_tree/features/feed/feed_page.dart';
import 'package:family_tree/providers/theme_provider.dart';
import 'package:family_tree/providers/locale_provider.dart';
import 'package:family_tree/l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Restore any stored session before the first frame so the router sees the
  // signed-in user immediately instead of flashing the landing page.
  await AuthService().init();

  runApp(
    const ProviderScope(
      child: FamilyTreeApp(),
    ),
  );
}

// GoRouter configuration
final GoRouter _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const LandingPage(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/reset-password',
      builder: (context, state) => const ResetPasswordPage(),
    ),
    GoRoute(
      // `?welcome=1` marks the first arrival after signing up, which is the one
      // moment worth interrupting to ask a new member to find themselves in
      // the tree.
      path: '/tree',
      builder: (context, state) => TreeScreen(
        familyTreeId: 'main-family-tree',
        promptToLink: state.uri.queryParameters['welcome'] == '1',
      ),
    ),
    GoRoute(
      path: '/tree/:id',
      builder: (context, state) => TreeScreen(
        familyTreeId: state.pathParameters['id'] ?? 'main-family-tree',
      ),
    ),
    GoRoute(
      // The artboard IS the admin surface now; the separate dashboard with its
      // duplicate People list was removed.
      path: '/admin',
      builder: (context, state) => const AdminFamilyArtboard(),
    ),
    GoRoute(
      path: '/admin/artboard',
      builder: (context, state) => const AdminFamilyArtboard(),
    ),
    GoRoute(
      // The tabbed group page was removed; '/group' is kept so existing links
      // and notification deep-links still resolve.
      path: '/group',
      builder: (context, state) => const FeedPage(),
    ),
  ],
);

class FamilyTreeApp extends ConsumerWidget {
  const FamilyTreeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the theme mode provider to rebuild when theme changes
    final themeMode = ref.watch(themeModeProvider);
    // Watch the locale provider so the tree re-renders in the chosen language
    final locale = ref.watch(appLocaleProvider);
    
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
      routerConfig: _router,
    );
  }
}
