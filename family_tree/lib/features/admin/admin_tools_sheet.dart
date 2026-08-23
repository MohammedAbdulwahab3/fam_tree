import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/core/theme/app_colors.dart';
import 'package:family_tree/core/theme/elegant_theme.dart';
import 'package:family_tree/data/models/app_user.dart';
import 'package:family_tree/data/models/post.dart';
import 'package:family_tree/data/repositories/admin_repository.dart';
import 'package:family_tree/data/repositories/group_repository.dart';
import 'package:family_tree/features/auth/session.dart';

enum AdminTool { members, posts }

/// Members and posts management, presented as a sheet over the artboard so the
/// board stays the single admin surface instead of a second dashboard page.
class AdminToolsSheet extends ConsumerStatefulWidget {
  final AdminTool tool;

  const AdminToolsSheet({super.key, required this.tool});

  static Future<void> open(BuildContext context, AdminTool tool) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AdminToolsSheet(tool: tool),
    );
  }

  @override
  ConsumerState<AdminToolsSheet> createState() => _AdminToolsSheetState();
}

class _AdminToolsSheetState extends ConsumerState<AdminToolsSheet> {
  final _adminRepo = AdminRepository();
  final _groupRepo = GroupRepository();
  final _searchController = TextEditingController();

  List<AppUser> _users = [];
  List<Post> _posts = [];
  String _query = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      if (widget.tool == AdminTool.members) {
        _users = await _adminRepo.getUsers();
      } else {
        _posts = (await _groupRepo.getPosts(forceRefresh: true)).posts;
      }
    } catch (e) {
      _toast(readableError(e), isError: true);
    }
    if (mounted) setState(() => _loading = false);
  }

  void _toast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppTheme.error : AppTheme.primaryDeep,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  List<AppUser> get _filteredUsers {
    if (_query.isEmpty) return _users;
    final q = _query.toLowerCase();
    return _users
        .where((u) =>
            u.name.toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q))
        .toList();
  }

  List<Post> get _filteredPosts {
    if (_query.isEmpty) return _posts;
    final q = _query.toLowerCase();
    return _posts
        .where((p) =>
            p.content.toLowerCase().contains(q) ||
            p.userName.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMembers = widget.tool == AdminTool.members;
    final count = isMembers ? _users.length : _posts.length;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141B24) : ElegantColors.warmWhite,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : ElegantColors.champagne,
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: (context.colors.ink)
                    .withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Icon(
                    isMembers
                        ? Icons.people_outline_rounded
                        : Icons.forum_outlined,
                    color: AppTheme.accentTeal,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isMembers ? 'Members' : 'Posts',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: context.colors.ink,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _pill('$count', AppTheme.accentTeal),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v.trim()),
                style: GoogleFonts.inter(fontSize: 14.5),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: isMembers
                      ? 'Search by name or email…'
                      : 'Search posts…',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.accentTeal))
                  : ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      children: isMembers
                          ? _filteredUsers
                              .map((u) => _memberRow(u, isDark))
                              .toList()
                          : _filteredPosts
                              .map((p) => _postRow(p, isDark))
                              .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _shell({
    required bool isDark,
    required Color accent,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.9),
        border: Border.all(color: accent.withValues(alpha: 0.26)),
      ),
      child: child,
    );
  }

  Widget _avatar(IconData icon, Color accent) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient:
              LinearGradient(colors: [accent, accent.withValues(alpha: 0.6)]),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      );

  Widget _tag(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: color,
          ),
        ),
      );

  // ---------------------------------------------------------------- members

  Widget _memberRow(AppUser user, bool isDark) {
    final currentUserId = ref.read(currentUserProvider)?.uid;
    final isSelf = user.id == currentUserId;
    final accent = user.isBanned
        ? AppTheme.error
        : (user.isAdmin ? AppTheme.accentGold : AppTheme.accentTeal);

    return _shell(
      isDark: isDark,
      accent: accent,
      child: Row(
        children: [
          _avatar(
            user.isBanned
                ? Icons.block_rounded
                : (user.isAdmin
                    ? Icons.shield_moon_rounded
                    : Icons.person_rounded),
            accent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.name.isEmpty ? user.email : user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color:
                              context.colors.ink,
                        ),
                      ),
                    ),
                    if (isSelf) ...[
                      const SizedBox(width: 6),
                      _tag('you', AppTheme.accentTeal),
                    ],
                    if (user.isAdmin) ...[
                      const SizedBox(width: 6),
                      _tag('admin', AppTheme.accentGold),
                    ],
                    if (user.isBanned) ...[
                      const SizedBox(width: 6),
                      _tag('suspended', AppTheme.error),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  user.isBanned && user.banReason.isNotEmpty
                      ? '${user.email}  ·  ${user.banReason}'
                      : user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark
                        ? AppTheme.textMutedDark
                        : ElegantColors.warmGray,
                  ),
                ),
              ],
            ),
          ),
          // Self-targeting actions are hidden: the backend refuses them.
          if (!isSelf)
            PopupMenuButton<String>(
              tooltip: 'Manage',
              icon: const Icon(Icons.more_vert_rounded, size: 20),
              onSelected: (v) => _onMemberAction(v, user),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: user.isAdmin ? 'demote' : 'promote',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      user.isAdmin
                          ? Icons.remove_moderator_outlined
                          : Icons.add_moderator_outlined,
                      size: 20,
                    ),
                    title: Text(user.isAdmin ? 'Make member' : 'Make admin'),
                  ),
                ),
                PopupMenuItem(
                  value: user.isBanned ? 'unban' : 'ban',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      user.isBanned
                          ? Icons.lock_open_rounded
                          : Icons.block_rounded,
                      size: 20,
                    ),
                    title: Text(user.isBanned ? 'Restore access' : 'Suspend'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'reset-code',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.vpn_key_outlined, size: 20),
                    title: Text('Password reset code'),
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete_outline_rounded,
                        size: 20, color: Colors.red),
                    title: Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _onMemberAction(String action, AppUser user) async {
    try {
      switch (action) {
        case 'promote':
          await _adminRepo.updateUserRole(user.id, 'admin');
          _toast('${user.name} is now an admin');
        case 'demote':
          await _adminRepo.updateUserRole(user.id, 'member');
          _toast('${user.name} is now a member');
        case 'ban':
          final reason = await _askReason(user);
          if (reason == null) return;
          await _adminRepo.banUser(user.id, reason: reason);
          _toast('${user.name} suspended');
        case 'unban':
          await _adminRepo.unbanUser(user.id);
          _toast('${user.name} restored');
        case 'reset-code':
          final code = await _adminRepo.issueResetCode(user.id);
          if (!mounted) return;
          await _showResetCode(user, code);
        case 'delete':
          final ok = await confirmDialog(
            context,
            title: 'Delete ${user.name}?',
            message: 'This permanently removes the account.',
          );
          if (!ok) return;
          await _adminRepo.deleteUser(user.id);
          _toast('${user.name} deleted');
      }
      await _load();
    } catch (e) {
      // The backend refuses unsafe actions (last admin, self-target).
      _toast(readableError(e), isError: true);
    }
  }

  /// Shows the issued code so the admin can read it out or copy it.
  Future<void> _showResetCode(AppUser user, String code) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Reset code for this account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Give this to ${user.name} yourself — by phone or message. They '
              'enter it on the "Forgot your password?" screen with their email '
              'and a new password.',
              style: const TextStyle(height: 1.4),
            ),
            const SizedBox(height: 16),
            SelectableText(
              code,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Good for 2 hours, and only once.',
              style: TextStyle(fontSize: 12.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              Navigator.pop(dialogContext);
              _toast('Code copied');
            },
            child: const Text('Copy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<String?> _askReason(AppUser user) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Suspend ${user.name}',
            style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'They are signed out immediately and cannot sign back in until restored.',
              style: GoogleFonts.inter(fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Suspend'),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ posts

  Widget _postRow(Post post, bool isDark) {
    const accent = AppTheme.accentGold;
    final attachments = post.photos.length + post.videos.length;
    return _shell(
      isDark: isDark,
      accent: accent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _avatar(Icons.person_rounded, accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.userName,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.colors.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  post.content.isEmpty ? '(no text)' : post.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    height: 1.45,
                    color: isDark
                        ? AppTheme.textSecondaryDark
                        : ElegantColors.warmGray,
                  ),
                ),
                if (attachments > 0) ...[
                  const SizedBox(height: 5),
                  _tag('$attachments attachment${attachments == 1 ? '' : 's'}',
                      accent),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 19),
            color: AppTheme.error,
            tooltip: 'Delete post',
            onPressed: () async {
              final ok = await confirmDialog(
                context,
                title: 'Delete this post?',
                message: 'It disappears from the family feed for everyone.',
              );
              if (!ok) return;
              try {
                await _adminRepo.deletePost(post.id);
                _toast('Post deleted');
                await _load();
              } catch (e) {
                _toast(readableError(e), isError: true);
              }
            },
          ),
        ],
      ),
    );
  }
}

/// Pulls the backend's own message out of a thrown error so the UI can show it
/// instead of a raw exception string.
String readableError(Object e) {
  final text = e.toString();
  final match = RegExp(r'"error"\s*:\s*"([^"]+)"').firstMatch(text);
  if (match != null) return match.group(1)!;
  return text.replaceAll('Exception: ', '');
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(title,
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700)),
      content:
          Text(message, style: GoogleFonts.inter(fontSize: 13.5, height: 1.5)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: AppTheme.error),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
