import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:family_tree/core/config.dart';
import 'package:family_tree/features/admin/admin_family_artboard.dart';
import 'package:family_tree/features/auth/landing_page.dart';
import 'package:family_tree/features/auth/reset_password_page.dart';
import 'package:family_tree/features/auth/session.dart';
import 'package:family_tree/features/auth/sign_in_page.dart';
import 'package:family_tree/features/auth/welcome_page.dart';
import 'package:family_tree/features/feed/feed_page.dart';
import 'package:family_tree/features/settings/account_page.dart';
import 'package:family_tree/features/tree_view/tree_screen.dart';

/// Where the app can be, and who is allowed to be there.
///
/// The router used to have no redirects at all: every route was reachable
/// whether or not anybody was signed in, and each screen decided for itself
/// what to do about that. So signing out left you looking at a family tree
/// that would not refresh, and a deep link into the admin screen showed an
/// admin screen with nothing in it.
final routerProvider = Provider<GoRouter>((ref) {
  // Rebuilding the router on every session change would drop the navigation
  // stack. Listening to it instead lets go_router re-run its redirect.
  final refresh = _SessionRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final path = state.matchedLocation;

      const openToEveryone = {'/', '/signin', '/signup', '/reset-password'};
      final isOpen = openToEveryone.contains(path);

      // Signed out and heading somewhere private: go and sign in.
      if (!session.isSignedIn) return isOpen ? null : '/signin';

      // Signed in and looking at the sign-in screen: there is nothing here for
      // them. New members go to the step that matters — finding themselves in
      // the tree — and everybody else to the family.
      if (isOpen && path != '/') {
        return session.isLinked ? '/tree' : '/welcome';
      }

      // The admin screens are not merely hidden from members; the routes
      // refuse them, so a shared link cannot get anybody in.
      if (path.startsWith('/admin') && !session.isAdmin) return '/tree';

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const LandingPage(),
      ),
      GoRoute(
        path: '/signin',
        builder: (context, state) => const SignInPage(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignInPage(startOnSignUp: true),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => const ResetPasswordPage(),
      ),
      GoRoute(
        // Where a new member lands: an explanation of what this app is for,
        // and the one thing they should do next.
        path: '/welcome',
        builder: (context, state) => const WelcomePage(),
      ),
      GoRoute(
        path: '/tree',
        builder: (context, state) => TreeScreen(
          familyTreeId: AppConfig.familyTreeId,
          promptToLink: state.uri.queryParameters['findme'] == '1',
        ),
      ),
      GoRoute(
        path: '/feed',
        builder: (context, state) => const FeedPage(),
      ),
      GoRoute(
        path: '/account',
        builder: (context, state) => const AccountPage(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminFamilyArtboard(),
      ),
      // Kept so notification deep links and anything bookmarked still resolve.
      GoRoute(path: '/login', redirect: (_, __) => '/signin'),
      GoRoute(path: '/group', redirect: (_, __) => '/feed'),
      GoRoute(path: '/admin/artboard', redirect: (_, __) => '/admin'),
    ],
  );
});

/// Notifies go_router when the session changes, without rebuilding the router
/// itself and losing the navigation stack.
class _SessionRefresh extends ChangeNotifier {
  _SessionRefresh(Ref ref) {
    _subscription = ref.listen<Session>(
      sessionProvider,
      (previous, next) {
        // Only the facts the redirect actually reads.
        if (previous?.isSignedIn != next.isSignedIn ||
            previous?.isAdmin != next.isAdmin ||
            previous?.isLinked != next.isLinked) {
          notifyListeners();
        }
      },
    );
  }

  late final ProviderSubscription<Session> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}
