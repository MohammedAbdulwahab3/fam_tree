import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/core/theme/app_colors.dart';
import 'package:family_tree/core/theme/elegant_theme.dart';
import 'package:family_tree/data/models/app_user.dart';
import 'package:family_tree/data/models/person.dart';
import 'package:family_tree/features/auth/session.dart';
import 'package:family_tree/data/services/api_service.dart';
import 'package:family_tree/data/services/auth_service.dart';
import 'package:family_tree/data/services/link_service.dart';
import 'package:family_tree/features/notifications/notifications_screen.dart';
import 'package:family_tree/features/linking/find_myself_sheet.dart';
import 'package:family_tree/features/linking/link_status.dart';
import 'package:family_tree/providers/locale_provider.dart';
import 'package:family_tree/providers/theme_provider.dart';
import 'package:family_tree/core/design/typography.dart';

/// The profile side panel opened from the tree screen's avatar button.
///
/// Everything it shows is derived from data the tree screen already holds, so
/// opening the drawer costs no extra round-trip: the account, the person record
/// the account is linked to, and the loaded family. The one thing it fetches is
/// the unread-notification count, which is cheap and refreshed on every open.
class ProfileDrawer extends ConsumerStatefulWidget {
  const ProfileDrawer({
    super.key,
    required this.familyMembers,
    required this.linkedPerson,
    required this.onChangePhoto,
    required this.onEditLinkedProfile,
  });

  /// Everyone in the tree — the pool the family stats are computed from, and
  /// the pool the link flow lets an unlinked account claim from.
  final List<Person> familyMembers;

  /// The person record this account owns, when the account has been linked.
  final Person? linkedPerson;

  final VoidCallback onChangePhoto;
  final VoidCallback onEditLinkedProfile;

  @override
  ConsumerState<ProfileDrawer> createState() => _ProfileDrawerState();
}

class _ProfileDrawerState extends ConsumerState<ProfileDrawer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  final ScrollController _scroll = ScrollController();

  /// Drives the hairline under the header once the content scrolls beneath it.
  bool _scrolledUnderHeader = false;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    final scrolled = _scroll.hasClients && _scroll.offset > 4;
    if (scrolled != _scrolledUnderHeader) {
      setState(() => _scrolledUnderHeader = scrolled);
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authUser = ref.watch(currentUserProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final linked = widget.linkedPerson;

    final stats = _FamilyStats.from(widget.familyMembers, linked);

    // Narrow phones get an almost-full-width panel; anything roomier keeps the
    // fixed 348 so the two-column action grid stays on its intended rhythm.
    final screenWidth = MediaQuery.of(context).size.width;
    final width = math.min(348.0, screenWidth * 0.92);

    return Drawer(
      width: width,
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          bottomLeft: Radius.circular(28),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        AppTheme.backgroundDark.withValues(alpha: 0.96),
                        const Color(0xFF0D1F2D).withValues(alpha: 0.96),
                        AppTheme.primaryDeep.withValues(alpha: 0.28),
                      ]
                    : [
                        ElegantColors.warmWhite.withValues(alpha: 0.96),
                        ElegantColors.cream.withValues(alpha: 0.96),
                        ElegantColors.champagne.withValues(alpha: 0.55),
                      ],
              ),
              border: Border(
                left: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : ElegantColors.champagne,
                ),
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _buildHeader(isDark),
                  Expanded(
                    child: ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
                      children: [
                        _reveal(
                            0,
                            _IdentityCard(
                              user: authUser,
                              linkState: linked != null
                                  ? _LinkState.verified
                                  : ref.watch(linkStatusProvider).maybeWhen(
                                        data: _LinkState.fromStatus,
                                        orElse: () => _LinkState.unknown,
                                      ),
                              isAdmin: isAdmin,
                              isDark: isDark,
                              onChangePhoto: () {
                                Navigator.pop(context);
                                widget.onChangePhoto();
                              },
                            )),
                        const SizedBox(height: 18),
                        _reveal(1, _StatsRow(stats: stats, isDark: isDark)),
                        if (linked != null) ...[
                          const SizedBox(height: 18),
                          _reveal(
                              2,
                              _LineageCard(
                                person: linked,
                                stats: stats,
                                isDark: isDark,
                              )),
                        ],
                        const SizedBox(height: 22),
                        _reveal(
                            3, _SectionLabel('Quick actions', isDark: isDark)),
                        const SizedBox(height: 12),
                        _reveal(4, _buildQuickGrid(isDark, isAdmin)),
                        const SizedBox(height: 22),
                        _reveal(5, _SectionLabel('Account', isDark: isDark)),
                        const SizedBox(height: 12),
                        _reveal(6, _buildAccountActions(isDark, linked)),
                        const SizedBox(height: 22),
                        _reveal(
                            7, _SectionLabel('Preferences', isDark: isDark)),
                        const SizedBox(height: 12),
                        _reveal(8, _PreferencesCard(isDark: isDark)),
                        const SizedBox(height: 24),
                        _reveal(9, _buildSignOut(isDark)),
                        const SizedBox(height: 18),
                        _reveal(9, _Footer(isDark: isDark)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Fades + lifts a section into place, staggered by its position in the list.
  Widget _reveal(int index, Widget child) {
    final start = (index * 0.06).clamp(0.0, 0.6);
    final animation = CurvedAnimation(
      parent: _entrance,
      curve: Interval(start, (start + 0.4).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Opacity(
        opacity: animation.value,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - animation.value)),
          child: child,
        ),
      ),
      child: child,
    );
  }

  Widget _buildHeader(bool isDark) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: _scrolledUnderHeader
                ? (isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : ElegantColors.champagne)
                : Colors.transparent,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [AppTheme.primaryLight, AppTheme.accentTeal]
                    : [ElegantColors.terracotta, ElegantColors.copper],
              ),
              borderRadius: BorderRadius.circular(11),
            ),
            child:
                const Icon(Icons.park_rounded, color: Colors.white, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile',
                  style: AppType.sans(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    color: context.colors.ink,
                  ),
                ),
                Text(
                  'Your place in the family',
                  style: AppType.sans(
                    fontSize: 13,
                    color: context.colors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.close_rounded,
              color: context.colors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickGrid(bool isDark, bool isAdmin) {
    final unread = ref.watch(unreadCountProvider).value ?? 0;

    final tiles = <Widget>[
      _QuickTile(
        icon: Icons.forum_rounded,
        label: 'Family Feed',
        caption: 'Posts & chat',
        color: ElegantColors.sage,
        isDark: isDark,
        onTap: () {
          Navigator.pop(context);
          context.go('/group');
        },
      ),
      _QuickTile(
        icon: Icons.notifications_rounded,
        label: 'Notifications',
        caption: unread > 0 ? '$unread unread' : 'All caught up',
        color: context.colors.gold,
        badge: unread > 0 ? (unread > 99 ? '99+' : '$unread') : null,
        isDark: isDark,
        onTap: () {
          // Grab the navigator before closing the drawer — popping tears this
          // subtree down, so its context is no longer usable to push with.
          final navigator = Navigator.of(context);
          navigator.pop();
          navigator.push(
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          );
        },
      ),
      _linkTile(isDark),
      if (isAdmin)
        _QuickTile(
          icon: Icons.admin_panel_settings_rounded,
          label: 'Admin Panel',
          caption: 'Manage tree',
          color: ElegantColors.gold,
          isDark: isDark,
          onTap: () {
            Navigator.pop(context);
            context.go('/admin');
          },
        ),
    ];

    return _TileGrid(tiles: tiles);
  }

  /// The link tile reads the account's real status rather than assuming: an
  /// unlinked account may still have a request sitting in the admin queue, and
  /// offering "request link" again there would only 409.
  Widget _linkTile(bool isDark) {
    final statusAsync = ref.watch(linkStatusProvider);
    final linked = widget.linkedPerson != null;

    // Treat the person record as the source of truth — if this account already
    // owns one, it is linked regardless of what the status endpoint is doing.
    final state = linked
        ? _LinkState.verified
        : statusAsync.maybeWhen(
            data: (status) => _LinkState.fromStatus(status),
            orElse: () => _LinkState.unknown,
          );

    return _QuickTile(
      icon: state.icon,
      label: state.label,
      caption: state.caption,
      color: state.color(context),
      isDark: isDark,
      // Nothing to do once you are linked; the tile just reports the fact.
      onTap: state == _LinkState.verified
          ? null
          : () {
              Navigator.pop(context);
              showFindMyselfSheet(
                context,
                people: widget.familyMembers,
              );
            },
    );
  }

  /// Editing is gated on the link: until an admin has tied this account to a
  /// person there is nothing personal to edit, so the section offers the way
  /// to get linked instead of controls that would go nowhere.
  Widget _buildAccountActions(bool isDark, Person? linked) {
    if (linked == null) {
      final status = ref.watch(linkStatusProvider).valueOrNull;
      final state = status == null
          ? _LinkState.unknown
          : _LinkState.fromStatus(status);

      return _LinkCallToAction(
        state: state,
        status: status,
        isDark: isDark,
        onStart: () {
          Navigator.pop(context);
          showFindMyselfSheet(
            context,
            people: widget.familyMembers,
          );
        },
        onCancel: state == _LinkState.pending ? _withdrawClaim : null,
      );
    }

    // One row for the profile itself. "Account details" only edited the
    // login's display name and avatar — a second, private identity sitting
    // beside the family record everyone actually sees. The family record is
    // the profile. The two rows under it are about the login, not the person.
    return Column(
      children: [
        _ActionTile(
          icon: Icons.edit_rounded,
          label: 'Edit profile',
          subtitle: 'Photo, details & marital status',
          color: context.colors.accent,
          isDark: isDark,
          onTap: () {
            Navigator.pop(context);
            widget.onEditLinkedProfile();
          },
        ),
        const SizedBox(height: 8),
        _buildAccountSecurity(isDark),
      ],
    );
  }

  /// Password and account removal. Both were entirely absent: there was no way
  /// to change a password you still knew, and no way to leave.
  Widget _buildAccountSecurity(bool isDark) {
    return Column(
      children: [
        _ActionTile(
          icon: Icons.lock_outline_rounded,
          label: 'Change password',
          subtitle: 'Update your sign-in password',
          color: context.colors.secondary,
          isDark: isDark,
          onTap: _changePassword,
        ),
        const SizedBox(height: 8),
        _ActionTile(
          icon: Icons.person_off_outlined,
          label: 'Delete my account',
          subtitle: 'Your place in the tree stays',
          color: AppTheme.error,
          isDark: isDark,
          onTap: _deleteAccount,
        ),
      ],
    );
  }

  Future<void> _changePassword() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final messenger = ScaffoldMessenger.of(context);

    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change password'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentController,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Current password',
                ),
                validator: (v) => (v ?? '').isEmpty
                    ? 'Enter your current password'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
                validator: (v) => (v ?? '').length < 6
                    ? 'At least 6 characters'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );

    if (submitted == true) {
      try {
        await AuthService().changePassword(
          currentPassword: currentController.text,
          newPassword: newController.text,
        );
        messenger.showSnackBar(
          const SnackBar(content: Text('Password changed')),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(messageForError(e)),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }

    currentController.dispose();
    newController.dispose();
  }

  Future<void> _deleteAccount() async {
    final passwordController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete your account?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your login is removed for good. Your place in the family tree '
              'stays where it is — it just stops being linked to you, so '
              'someone can claim it later.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: passwordController,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Confirm with your password',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep my account'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete for good'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await AuthService().deleteAccount(password: passwordController.text);
        router.go('/');
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(messageForError(e)),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }

    passwordController.dispose();
  }

  /// Withdraws the pending claim after confirming, then refreshes the tile so
  /// the drawer shows the new state without needing to be reopened.
  Future<void> _withdrawClaim() async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Withdraw your claim?'),
        content: const Text(
          'The admin review will be cancelled. You can claim a different '
          'person straight away.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep waiting'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await LinkService().cancelMyRequest();
      ref.invalidate(linkStatusProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Claim withdrawn')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(messageForError(e)),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Widget _buildSignOut(bool isDark) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _confirmSignOut(isDark),
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: Text(
          'Sign Out',
          style: AppType.sans(fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.accentRose,
          side: BorderSide(color: AppTheme.accentRose.withValues(alpha: 0.45)),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(bool isDark) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor:
            context.colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Sign out?',
          style: AppType.sans(
            fontWeight: FontWeight.w700,
            color: context.colors.ink,
          ),
        ),
        content: Text(
          'Your family tree stays exactly where it is. You can sign back in any time.',
          style: AppType.sans(
            fontSize: 14,
            color: context.colors.inkSoft,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Stay',
              style: AppType.sans(
                color: context.colors.inkMuted,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.accentRose,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await ref.read(sessionProvider.notifier).signOut();
    if (!mounted) return;
    Navigator.pop(context);
    context.go('/');
  }
}

// ---------------------------------------------------------------------------
// Stats
// ---------------------------------------------------------------------------

/// Everything the drawer counts, computed once per build instead of once per
/// widget that wants a number.
class _FamilyStats {
  const _FamilyStats({
    required this.members,
    required this.generations,
    required this.relatives,
    required this.parents,
    required this.siblings,
    required this.spouses,
    required this.children,
    required this.daysToBirthday,
  });

  final int members;
  final int generations;

  /// Direct relatives of the linked person: parents, siblings, spouses, kids.
  final int relatives;
  final int parents;
  final int siblings;
  final int spouses;
  final int children;

  /// Days until the linked person's next birthday, or null when unknown.
  final int? daysToBirthday;

  factory _FamilyStats.from(List<Person> members, Person? linked) {
    final generations = _generationCount(members);

    if (linked == null) {
      return _FamilyStats(
        members: members.length,
        generations: generations,
        relatives: 0,
        parents: 0,
        siblings: 0,
        spouses: 0,
        children: 0,
        daysToBirthday: null,
      );
    }

    final rel = linked.relationships;
    // Siblings are derived rather than trusted: the explicit siblingIds list is
    // often empty on imported records, while shared parents are always there.
    final siblingIds = <String>{...rel.siblingIds};
    for (final parentId in rel.parentIds) {
      for (final person in members) {
        if (person.id != linked.id &&
            person.relationships.parentIds.contains(parentId)) {
          siblingIds.add(person.id);
        }
      }
    }

    final parents = rel.parentIds.length;
    final spouses = rel.spouseIds.length;
    final children = members
        .where((p) => p.relationships.parentIds.contains(linked.id))
        .length;

    return _FamilyStats(
      members: members.length,
      generations: generations,
      relatives: parents + siblingIds.length + spouses + children,
      parents: parents,
      siblings: siblingIds.length,
      spouses: spouses,
      children: children,
      daysToBirthday: _daysToBirthday(linked),
    );
  }

  static int? _daysToBirthday(Person person) {
    final birth = person.birthDate;
    if (birth == null || person.isDeceased) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var next = DateTime(today.year, birth.month, birth.day);
    if (next.isBefore(today)) {
      next = DateTime(today.year + 1, birth.month, birth.day);
    }
    return next.difference(today).inDays;
  }

  /// Longest root-to-leaf chain in the tree.
  ///
  /// Children are indexed once and each person's depth is memoised, so this
  /// stays linear even though a person reachable down two different branches
  /// gets visited more than once — the naive version both rescanned the whole
  /// list per person and undercounted those shared descendants.
  static int _generationCount(List<Person> members) {
    if (members.isEmpty) return 0;

    final childrenOf = <String, List<String>>{};
    for (final person in members) {
      for (final parentId in person.relationships.parentIds) {
        (childrenOf[parentId] ??= <String>[]).add(person.id);
      }
    }

    final memo = <String, int>{};
    final onPath = <String>{};

    int depth(String personId) {
      final cached = memo[personId];
      if (cached != null) return cached;
      // A malformed record that lists itself among its own ancestors would
      // otherwise recurse forever.
      if (!onPath.add(personId)) return 1;

      var deepest = 0;
      for (final childId in childrenOf[personId] ?? const <String>[]) {
        final childDepth = depth(childId);
        if (childDepth > deepest) deepest = childDepth;
      }

      onPath.remove(personId);
      return memo[personId] = deepest + 1;
    }

    var deepest = 0;
    for (final person in members) {
      if (person.relationships.parentIds.isNotEmpty) continue;
      final rootDepth = depth(person.id);
      if (rootDepth > deepest) deepest = rootDepth;
    }

    // Every record claims a parent — the data is cyclic, so call it one layer.
    return deepest == 0 ? 1 : deepest;
  }
}

// ---------------------------------------------------------------------------
// Identity card
// ---------------------------------------------------------------------------

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.user,
    required this.linkState,
    required this.isAdmin,
    required this.isDark,
    required this.onChangePhoto,
  });

  final AppUser? user;
  final _LinkState linkState;
  final bool isAdmin;
  final bool isDark;
  final VoidCallback onChangePhoto;

  @override
  Widget build(BuildContext context) {
    final name = user?.displayName.isNotEmpty == true
        ? user!.displayName
        : (user?.email.split('@').first ?? 'Guest');
    final photo = user?.photoURL;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF0F766E),
                  const Color(0xFF115E59),
                  AppTheme.primaryDeep
                ]
              : [
                  ElegantColors.terracotta,
                  ElegantColors.sienna,
                  ElegantColors.copper
                ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: (context.colors.accent)
                .withValues(alpha: 0.35),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Decorative concentric rings, echoing the tree's orbit lines.
            Positioned(
              right: -46,
              top: -46,
              child: _Rings(color: Colors.white.withValues(alpha: 0.10)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
              child: Column(
                children: [
                  _Avatar(
                    photoUrl: photo,
                    fallbackInitials: _initials(name),
                    onTap: onChangePhoto,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.sans(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    user?.email ?? 'Not signed in',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.sans(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Badge(
                        icon: isAdmin
                            ? Icons.workspace_premium_rounded
                            : Icons.person_rounded,
                        label: isAdmin ? 'Admin' : 'Member',
                      ),
                      switch (linkState) {
                        _LinkState.verified => const _Badge(
                            icon: Icons.verified_rounded,
                            label: 'Linked',
                          ),
                        _LinkState.pending => const _Badge(
                            icon: Icons.hourglass_top_rounded,
                            label: 'Link pending',
                          ),
                        _ => const _Badge(
                            icon: Icons.link_off_rounded,
                            label: 'Not linked',
                            muted: true,
                          ),
                      },
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.photoUrl,
    required this.fallbackInitials,
    required this.onTap,
  });

  final String? photoUrl;
  final String fallbackInitials;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 82,
            height: 82,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.95),
                  Colors.white.withValues(alpha: 0.45),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.22),
                image: photoUrl != null
                    ? DecorationImage(
                        image: NetworkImage(photoUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              alignment: Alignment.center,
              child: photoUrl != null
                  ? null
                  : Text(
                      fallbackInitials,
                      style: AppType.sans(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: const Icon(
                Icons.photo_camera_rounded,
                size: 14,
                color: ElegantColors.charcoal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.icon,
    required this.label,
    this.muted = false,
  });

  final IconData icon;
  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: muted ? 0.12 : 0.22),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withValues(alpha: muted ? 0.22 : 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 13, color: Colors.white.withValues(alpha: muted ? 0.7 : 1)),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppType.sans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
              color: Colors.white.withValues(alpha: muted ? 0.75 : 1),
            ),
          ),
        ],
      ),
    );
  }
}

/// Three concentric outlines used as a corner flourish on the identity card.
class _Rings extends StatelessWidget {
  const _Rings({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 160,
      child: CustomPaint(painter: _RingsPainter(color)),
    );
  }
}

class _RingsPainter extends CustomPainter {
  const _RingsPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = color;
    final center = Offset(size.width / 2, size.height / 2);
    for (final radius in [size.width / 2, size.width / 3, size.width / 5]) {
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_RingsPainter oldDelegate) => oldDelegate.color != color;
}

// ---------------------------------------------------------------------------
// Stats row
// ---------------------------------------------------------------------------

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats, required this.isDark});

  final _FamilyStats stats;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Icons.layers_rounded,
            value: stats.generations,
            label: 'Generations',
            color: context.colors.secondary,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon: Icons.groups_2_rounded,
            value: stats.members,
            label: 'Members',
            color: context.colors.gold,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon: Icons.favorite_rounded,
            value: stats.relatives,
            label: 'Relatives',
            color: context.colors.rose,
            isDark: isDark,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.isDark,
  });

  final IconData icon;
  final int value;
  final String label;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: _panelDecoration(isDark),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(height: 9),
          // Counts up from zero so the numbers feel earned rather than pasted.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.toDouble()),
            duration: const Duration(milliseconds: 850),
            curve: Curves.easeOutCubic,
            builder: (context, animated, _) => Text(
              animated.round().toString(),
              style: AppType.sans(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                height: 1.1,
                color: context.colors.ink,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.sans(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: context.colors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Lineage card
// ---------------------------------------------------------------------------

class _LineageCard extends StatelessWidget {
  const _LineageCard({
    required this.person,
    required this.stats,
    required this.isDark,
  });

  final Person person;
  final _FamilyStats stats;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final accent = context.colors.secondary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_tree_rounded, size: 16, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'In the tree as ${person.fullName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.sans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.colors.ink,
                  ),
                ),
              ),
            ],
          ),
          if (person.lifespan.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              person.age != null
                  ? '${person.lifespan}  ·  ${person.age} years'
                  : person.lifespan,
              style: AppType.sans(
                fontSize: 13,
                color: context.colors.inkMuted,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (stats.parents > 0)
                _RelationChip(
                    label: 'Parents',
                    count: stats.parents,
                    color: ElegantColors.softBlue,
                    isDark: isDark),
              if (stats.siblings > 0)
                _RelationChip(
                    label: 'Siblings',
                    count: stats.siblings,
                    color: ElegantColors.sage,
                    isDark: isDark),
              if (stats.spouses > 0)
                _RelationChip(
                    label: 'Spouse',
                    count: stats.spouses,
                    color: ElegantColors.dustyRose,
                    isDark: isDark),
              if (stats.children > 0)
                _RelationChip(
                    label: 'Children',
                    count: stats.children,
                    color: ElegantColors.gold,
                    isDark: isDark),
              if (stats.relatives == 0)
                _RelationChip(
                    label: 'No relatives linked yet',
                    color: ElegantColors.warmGray,
                    isDark: isDark),
            ],
          ),
          if (stats.daysToBirthday != null) ...[
            const SizedBox(height: 14),
            _BirthdayStrip(days: stats.daysToBirthday!, isDark: isDark),
          ],
        ],
      ),
    );
  }
}

class _RelationChip extends StatelessWidget {
  const _RelationChip({
    required this.label,
    this.count,
    required this.color,
    required this.isDark,
  });

  final String label;
  final int? count;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.16 : 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (count != null) ...[
            Text(
              '$count',
              style: AppType.sans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: context.colors.ink,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: AppType.sans(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: context.colors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

class _BirthdayStrip extends StatelessWidget {
  const _BirthdayStrip({required this.days, required this.isDark});

  final int days;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final isToday = days == 0;
    final color = isToday
        ? (context.colors.gold)
        : (context.colors.rose);

    final message = isToday
        ? 'Happy birthday! 🎉'
        : days == 1
            ? 'Birthday tomorrow'
            : 'Birthday in $days days';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(Icons.cake_rounded, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppType.sans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.colors.ink,
              ),
            ),
          ),
          if (!isToday)
            // A year-long progress arc — how far around the calendar we are.
            SizedBox(
              width: 22,
              height: 22,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1 - (days / 365)),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => CircularProgressIndicator(
                  value: value,
                  strokeWidth: 3,
                  backgroundColor: color.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Actions
// ---------------------------------------------------------------------------

class _QuickTile extends StatefulWidget {
  const _QuickTile({
    required this.icon,
    required this.label,
    required this.caption,
    required this.color,
    required this.isDark,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final String caption;
  final Color color;
  final bool isDark;

  /// Null renders the tile as a read-only status card — no ripple, no hover.
  final VoidCallback? onTap;
  final String? badge;

  @override
  State<_QuickTile> createState() => _QuickTileState();
}

class _QuickTileState extends State<_QuickTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onTap != null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = interactive),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.03 : 1,
        duration: const Duration(milliseconds: 160),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(13),
              decoration: _panelDecoration(
                widget.isDark,
                borderColor:
                    _hovered ? widget.color.withValues(alpha: 0.55) : null,
                radius: 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: widget.color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(widget.icon, color: widget.color, size: 18),
                      ),
                      const Spacer(),
                      if (widget.badge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.accentRose,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            widget.badge!,
                            style: AppType.sans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Flexible so a large system text scale ellipsises the
                  // caption rather than blowing the tile's fixed height.
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.sans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: widget.isDark
                                ? Colors.white
                                : ElegantColors.charcoal,
                          ),
                        ),
                        Text(
                          widget.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.sans(
                            fontSize: 12,
                            color: widget.isDark
                                ? Colors.white54
                                : ElegantColors.warmGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: _panelDecoration(isDark),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppType.sans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: context.colors.ink,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: AppType.sans(
                        fontSize: 12,
                        color: context.colors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: context.colors.inkMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Where the signed-in account stands with linking, flattened into the one
/// shape the drawer needs to render: an icon, a label, a caption and a tone.
enum _LinkState {
  /// The status endpoint has not answered yet (or failed). Still offer the
  /// flow — the sheet re-reads status and will show the truth there.
  unknown,
  notLinked,
  pending,

  /// An admin turned the claim down. Kept separate from [notLinked] so the
  /// member is told, rather than being dropped back to a screen that looks
  /// exactly like never having asked.
  rejected,
  verified;

  static _LinkState fromStatus(LinkStatus status) {
    if (status.isVerified || status.status == 'verified') return verified;
    if (status.status == 'pending') return pending;
    if (status.status == 'rejected') return rejected;
    return notLinked;
  }

  IconData get icon => switch (this) {
        verified => Icons.verified_rounded,
        pending => Icons.hourglass_top_rounded,
        rejected => Icons.info_outline_rounded,
        _ => Icons.link_rounded,
      };

  String get label => switch (this) {
        verified => 'Linked',
        pending => 'Link pending',
        rejected => 'Not approved',
        _ => 'Link account',
      };

  String get caption => switch (this) {
        verified => 'Verified member',
        pending => 'Awaiting review',
        rejected => 'Tap to see why',
        notLinked => 'Claim your record',
        unknown => 'Check your status',
      };

  /// Takes a context rather than a bool: the palette now comes from the theme,
  /// so a caller cannot pick the wrong pair of colours by hand.
  Color color(BuildContext context) => switch (this) {
        verified => context.colors.secondary,
        pending => context.colors.gold,
        rejected => context.colors.danger,
        _ => context.colors.accent,
      };
}

/// Fills the Account section for an account that owns no person record.
///
/// It replaces the edit rows rather than sitting beside them: there is no
/// family record to edit yet, and the one useful action is getting linked.
class _LinkCallToAction extends StatelessWidget {
  const _LinkCallToAction({
    required this.state,
    required this.isDark,
    required this.onStart,
    this.status,
    this.onCancel,
  });

  final _LinkState state;
  final bool isDark;
  final VoidCallback onStart;

  /// The full status, so a pending card can name the person claimed and a
  /// rejected one can show the admin's reason.
  final LinkStatus? status;

  /// Withdraw a pending claim. Null when there is nothing to withdraw.
  final Future<void> Function()? onCancel;

  String get _heading => switch (state) {
        _LinkState.pending => 'Your claim is being reviewed',
        _LinkState.rejected => 'Your claim was not approved',
        _ => 'You are not linked to the tree yet',
      };

  String get _explanation {
    final who = status?.personName;
    return switch (state) {
      _LinkState.pending => who == null
          ? 'An admin is checking your claim. Once it is approved, your record '
              'becomes editable and the tree opens on your branch.'
          : 'You asked to be linked to $who. Once an admin approves it, that '
              'record becomes yours to edit.',
      _LinkState.rejected => status?.reason != null
          ? 'An admin did not link you to ${who ?? 'that person'}. They said: '
              '"${status!.reason}"'
          : 'An admin did not link you to ${who ?? 'that person'}. They did not '
              'leave a reason — try claiming a different person, or ask them '
              'directly.',
      _ => 'Linking connects this login to your person in the family. It '
          'unlocks editing your own record, personal stats, and a tree that '
          'opens on your branch.',
    };
  }

  String get _actionLabel => switch (state) {
        _LinkState.pending => 'View claim status',
        _LinkState.rejected => 'Claim a different person',
        _ => 'Find myself in the tree',
      };

  IconData get _actionIcon => switch (state) {
        _LinkState.pending => Icons.visibility_rounded,
        _LinkState.rejected => Icons.person_search_rounded,
        _ => Icons.person_search_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final pending = state == _LinkState.pending;
    final color = state.color(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: isDark ? 0.18 : 0.13),
            color.withValues(alpha: isDark ? 0.06 : 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(state.icon, size: 19, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _heading,
                  style: AppType.sans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: context.colors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Text(
            _explanation,
            style: AppType.sans(
              fontSize: 13.5,
              height: 1.4,
              color: context.colors.inkSoft,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onStart,
              icon: Icon(_actionIcon, size: 17),
              label: Text(
                _actionLabel,
                style: AppType.sans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          // Someone who picked the wrong relative should be able to correct it
          // themselves rather than wait out a review they know is wrong.
          if (pending && onCancel != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => onCancel!(),
                style: TextButton.styleFrom(
                  foregroundColor: context.colors.inkMuted,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: Text(
                  'Withdraw this claim',
                  style: AppType.sans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Lays tiles out two to a row, letting a lone final tile span the full width
/// so an odd count reads as deliberate instead of leaving a hole in the grid.
class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.tiles});

  final List<Widget> tiles;

  static const _gap = 10.0;

  /// Tall enough for the icon chip, a label and a caption at default text
  /// scale; past that the tile's own Flexible takes over.
  static const _tileHeight = 108.0;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    for (var i = 0; i < tiles.length; i += 2) {
      final isLastAlone = i == tiles.length - 1;
      rows.add(
        SizedBox(
          height: _tileHeight,
          child: isLastAlone
              ? tiles[i]
              : Row(
                  children: [
                    Expanded(child: tiles[i]),
                    const SizedBox(width: _gap),
                    Expanded(child: tiles[i + 1]),
                  ],
                ),
        ),
      );
      if (i + 2 < tiles.length) rows.add(const SizedBox(height: _gap));
    }

    return Column(children: rows);
  }
}

// ---------------------------------------------------------------------------
// Preferences
// ---------------------------------------------------------------------------

class _PreferencesCard extends ConsumerWidget {
  const _PreferencesCard({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(appLocaleProvider);

    return Container(
      decoration: _panelDecoration(isDark),
      child: Column(
        children: [
          // Theme
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 11, 9, 11),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: (isDark
                            ? AppTheme.accentGold
                            : ElegantColors.softPurple)
                        .withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    themeMode == ThemeMode.dark
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    size: 18,
                    color:
                        isDark ? AppTheme.accentGold : ElegantColors.softPurple,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    'Dark mode',
                    style: AppType.sans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: context.colors.ink,
                    ),
                  ),
                ),
                Switch.adaptive(
                  value: themeMode == ThemeMode.dark,
                  activeThumbColor:
                      context.colors.accent,
                  onChanged: (_) =>
                      ref.read(themeModeProvider.notifier).toggleTheme(),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            indent: 13,
            endIndent: 13,
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : ElegantColors.champagne,
          ),
          // Language
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: (context.colors.secondary)
                        .withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.translate_rounded,
                    size: 18,
                    color: context.colors.secondary,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    'Language',
                    style: AppType.sans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: context.colors.ink,
                    ),
                  ),
                ),
                _LocaleSwitch(current: locale, isDark: isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LocaleSwitch extends ConsumerWidget {
  const _LocaleSwitch({required this.current, required this.isDark});

  final Locale current;
  final bool isDark;

  static const _labels = {'en': 'EN', 'am': 'አማ'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = context.colors.accent;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : ElegantColors.parchment,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: AppLocaleNotifier.supportedLocales.map((locale) {
          final selected = locale.languageCode == current.languageCode;
          return GestureDetector(
            onTap: () => ref.read(appLocaleProvider.notifier).setLocale(locale),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? accent : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _labels[locale.languageCode] ??
                    locale.languageCode.toUpperCase(),
                style: AppType.sans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? Colors.white
                      : (context.colors.inkMuted),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small shared pieces
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {required this.isDark});

  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text.toUpperCase(),
          style: AppType.sans(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.3,
            color: context.colors.inkMuted,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : ElegantColors.champagne,
          ),
        ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Icon(
            Icons.park_rounded,
            size: 15,
            color: context.colors.hairline,
          ),
          const SizedBox(height: 5),
          Text(
            'Family Tree · v1.0.0',
            style: AppType.sans(
              fontSize: 12,
              color: context.colors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// The one surface treatment every card in the drawer shares.
BoxDecoration _panelDecoration(
  bool isDark, {
  Color? borderColor,
  double radius = 14,
}) {
  return BoxDecoration(
    color: isDark
        ? Colors.white.withValues(alpha: 0.05)
        : ElegantColors.warmWhite.withValues(alpha: 0.9),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: borderColor ??
          (isDark
              ? Colors.white.withValues(alpha: 0.09)
              : ElegantColors.champagne),
    ),
    boxShadow: isDark
        ? null
        : [
            BoxShadow(
              color: ElegantColors.warmGray.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
  );
}
