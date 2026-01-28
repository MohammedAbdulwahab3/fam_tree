import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/data/services/firebase_service.dart';
import 'package:family_tree/features/tree_view/tree_screen.dart';
import 'package:family_tree/features/auth/landing_page.dart';
import 'package:family_tree/features/auth/login_page.dart';
import 'package:family_tree/features/admin/admin_dashboard_page.dart';
import 'package:family_tree/features/admin/admin_family_artboard.dart';
import 'package:family_tree/features/group/group_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await FirebaseService.initialize();
  
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
      path: '/tree',
      builder: (context, state) => const TreeScreen(
        familyTreeId: 'main-family-tree',
      ),
    ),
    GoRoute(
      path: '/tree/:id',
      builder: (context, state) => TreeScreen(
        familyTreeId: state.pathParameters['id'] ?? 'main-family-tree',
      ),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminDashboardPage(),
    ),
    GoRoute(
      path: '/admin/artboard',
      builder: (context, state) => const AdminFamilyArtboard(),
    ),
    GoRoute(
      path: '/group',
      builder: (context, state) => const GroupPage(),
    ),
  ],
);

class FamilyTreeApp extends ConsumerWidget {
  const FamilyTreeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Family Tree',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: _router,
    );
  }
}
