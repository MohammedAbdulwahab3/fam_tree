import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:family_tree/core/design/design.dart';
import 'package:family_tree/core/widgets/locale_menu_button.dart';
import 'package:family_tree/data/services/auth_service.dart';
import 'package:family_tree/features/auth/session.dart';
import 'package:family_tree/features/linking/link_status.dart';
import 'package:family_tree/features/settings/change_password_sheet.dart';
import 'package:family_tree/features/settings/delete_account_sheet.dart';
import 'package:family_tree/providers/theme_provider.dart';

/// Everything a member can do about their own account, in one place.
///
/// These controls used to be scattered — the password change inside a profile
/// editor, the language switch in a tree toolbar, sign-out behind a long-press
/// on an avatar — so a member who wanted one of them had to already know where
/// it lived.
class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final user = ref.watch(currentUserProvider);
    final link = ref.watch(linkStatusProvider);
    final themeMode = ref.watch(themeModeProvider);

    if (user == null) {
      return const AppPage(title: 'Your account', child: AppLoading());
    }

    return AppPage(
      title: 'Your account',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Who you are.
          AppCard(
            padding: const EdgeInsets.all(Insets.md),
            child: Row(
              children: [
                Container(
                  width: Sizes.avatarLg,
                  height: Sizes.avatarLg,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.accentSoft,
                    shape: BoxShape.circle,
                    image: user.photoURL == null
                        ? null
                        : DecorationImage(
                            image: NetworkImage(user.photoURL!),
                            fit: BoxFit.cover,
                          ),
                  ),
                  child: user.photoURL != null
                      ? null
                      : Text(
                          user.initials,
                          style: AppType.heading.copyWith(color: c.accent),
                        ),
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: AppType.subheading.copyWith(color: c.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.email,
                        style: AppType.bodySmall.copyWith(color: c.inkSoft),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: Insets.xs),
                      Wrap(
                        spacing: Insets.xs,
                        runSpacing: Insets.xxs,
                        children: [
                          if (user.isAdmin)
                            _Tag(
                              label: 'Admin',
                              color: c.gold,
                              icon: Icons.shield_outlined,
                            ),
                          link.maybeWhen(
                            data: (status) => switch (status.state) {
                              LinkState.verified => _Tag(
                                  label: 'In the tree',
                                  color: c.success,
                                  icon: Icons.check_circle_outline_rounded,
                                ),
                              LinkState.pending => _Tag(
                                  label: 'Waiting to be linked',
                                  color: c.accent,
                                  icon: Icons.hourglass_top_rounded,
                                ),
                              _ => _Tag(
                                  label: 'Not linked yet',
                                  color: c.inkMuted,
                                  icon: Icons.person_outline_rounded,
                                ),
                            },
                            orElse: () => const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Not linked: the one thing worth doing, offered rather than hidden.
          link.maybeWhen(
            data: (status) => status.state == LinkState.verified
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: Insets.md),
                    child: AppNotice(
                      tone: status.state == LinkState.pending
                          ? NoticeTone.pending
                          : NoticeTone.info,
                      title: status.state == LinkState.pending
                          ? 'An admin is checking your claim'
                          : 'You are not in the tree yet',
                      message: status.state == LinkState.pending
                          ? 'Nothing more to do — we will tell you when it is '
                              'confirmed.'
                          : 'Point at which person in the tree is you, and an '
                              'admin will confirm it.',
                      action: status.state == LinkState.pending
                          ? null
                          : QuietButton(
                              label: 'Find myself',
                              onPressed: () => context.go('/tree?findme=1'),
                            ),
                    ),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),

          const SizedBox(height: Insets.sectionGap),

          AppSection(
            title: 'How the app looks',
            gap: Insets.xs,
            children: [
              AppRow(
                icon: Icons.language_rounded,
                title: 'Language',
                subtitle: 'English or አማርኛ',
                trailing: const LocaleMenuButton(),
              ),
              AppRow(
                icon: themeMode == ThemeMode.dark
                    ? Icons.dark_mode_outlined
                    : Icons.light_mode_outlined,
                title: 'Dark mode',
                subtitle: 'Easier on the eyes at night',
                trailing: Switch(
                  value: themeMode == ThemeMode.dark,
                  onChanged: (on) => ref
                      .read(themeModeProvider.notifier)
                      .setMode(on ? ThemeMode.dark : ThemeMode.light),
                ),
              ),
            ],
          ),

          const SizedBox(height: Insets.sectionGap),

          AppSection(
            title: 'Signing in',
            gap: Insets.xs,
            children: [
              AppRow(
                icon: Icons.password_rounded,
                title: 'Change your password',
                subtitle: 'You will need your current one',
                onTap: () => showChangePasswordSheet(context),
              ),
              AppRow(
                icon: Icons.logout_rounded,
                title: 'Sign out',
                subtitle: 'On this device only',
                onTap: () => _signOut(context, ref),
              ),
            ],
          ),

          const SizedBox(height: Insets.sectionGap),

          AppSection(
            title: 'Leaving',
            subtitle: 'Your place in the family tree stays either way — it '
                'belongs to the family, not to the login.',
            gap: Insets.xs,
            children: [
              AppRow(
                icon: Icons.delete_outline_rounded,
                tone: c.danger,
                title: 'Delete my account',
                subtitle: 'This cannot be undone',
                onTap: () => showDeleteAccountSheet(context, ref),
              ),
            ],
          ),

          const SizedBox(height: Insets.xl),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirm(
      context,
      title: 'Sign out?',
      message: 'You will need your email and password to get back in.',
      confirmLabel: 'Sign out',
      icon: Icons.logout_rounded,
    );
    if (!confirmed || !context.mounted) return;

    await ref.read(sessionProvider.notifier).signOut();
    if (context.mounted) context.go('/signin');
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color, required this.icon});

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.xs,
        vertical: Insets.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: Corners.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: AppType.caption.copyWith(color: color)),
        ],
      ),
    );
  }
}

/// Kept out of the widget tree above so both sheets can reuse it.
AuthService get authService => AuthService();
