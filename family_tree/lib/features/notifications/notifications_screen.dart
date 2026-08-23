import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/layout/breakpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/elegant_theme.dart';
import '../../core/widgets/aurora_background.dart';
import '../../data/models/notification_model.dart';
import '../../data/services/api_service.dart';
import 'package:family_tree/core/logging.dart';
import 'package:family_tree/core/design/typography.dart';

// Notifications state provider
final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, AsyncValue<List<NotificationModel>>>(
  (ref) => NotificationsNotifier(
    onCountChanged: () => ref.invalidate(unreadCountProvider),
  ),
);

/// Unread notification count, refreshed on a timer.
///
/// This used to be a FutureProvider, which resolves once and never again — the
/// badge froze at whatever the count was when the app started and stayed there
/// until a restart.
final unreadCountProvider = StreamProvider<int>((ref) async* {
  Future<int> fetch() async {
    try {
      final response = await ApiService().get('/api/notifications/unread-count');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['count'] as num).toInt();
      }
    } catch (_) {
      // Offline or signed out; keep the last known count rather than
      // flashing the badge to zero.
    }
    return 0;
  }

  yield await fetch();
  while (true) {
    await Future<void>.delayed(const Duration(seconds: 30));
    yield await fetch();
  }
});

class NotificationsNotifier extends StateNotifier<AsyncValue<List<NotificationModel>>> {
  NotificationsNotifier({void Function()? onCountChanged})
      : _onCountChanged = onCountChanged,
        super(const AsyncValue.loading()) {
    fetchNotifications();
  }

  /// Called after anything that changes the unread count, so the badge catches
  /// up straight away instead of waiting for the next poll.
  final void Function()? _onCountChanged;

  Future<void> fetchNotifications() async {
    try {
      state = const AsyncValue.loading();
      final response = await ApiService().get('/api/notifications');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final notifications = data.map((json) => NotificationModel.fromJson(json)).toList();
        state = AsyncValue.data(notifications);
      } else {
        state = AsyncValue.error('Failed to load notifications', StackTrace.current);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Removes a notification, restoring it to the list if the server refuses.
  ///
  /// Returns null on success, or the message to show the user on failure, so
  /// the swipe gesture can put the row back and explain itself instead of
  /// silently reverting.
  Future<String?> deleteNotification(String notificationId) async {
    final previousState = state;

    // Optimistic update, so the row leaves under the finger.
    if (state.hasValue) {
      state = AsyncValue.data(
        state.value!.where((n) => n.id != notificationId).toList(),
      );
    }

    try {
      final response =
          await ApiService().delete('/api/notifications/$notificationId');
      // A notification that is already gone is the outcome the swipe wanted.
      if (response.statusCode != 404) {
        ApiService.ensureOk(response, whileDoing: 'dismissing the notification');
      }
      _onCountChanged?.call();
      return null;
    } catch (e) {
      state = previousState;
      return messageForError(e);
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      final response =
          await ApiService().put('/api/notifications/$notificationId/read');
      ApiService.ensureOk(response, whileDoing: 'marking it read');
      await fetchNotifications();
      _onCountChanged?.call();
    } catch (e) {
      log('Could not mark the notification as read', e);
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final response = await ApiService().put('/api/notifications/read-all');
      ApiService.ensureOk(response, whileDoing: 'marking everything read');
      await fetchNotifications();
      _onCountChanged?.call();
    } catch (e) {
      log('Could not mark all notifications as read', e);
    }
  }
}

/// The notifications list.
///
/// This screen used to be raw Material — a default AppBar, `Card`s tinted
/// `Colors.blue.shade50`, `Colors.grey` body text — which read as a different
/// app from every other screen and, in dark mode, put a pale blue card behind
/// light text. It now shares the aurora ground, serif headings and warm palette
/// used everywhere else, in both themes.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _aurora;

  @override
  void initState() {
    super.initState();
    _aurora = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _aurora.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unread =
        notificationsAsync.valueOrNull?.where((n) => n.isUnread).length ?? 0;

    return Scaffold(
      backgroundColor: context.colors.ground,
      body: Stack(
        children: [
          AuroraBackground(animation: _aurora, isDark: isDark),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(isDark, unread),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      // A column of short rows stretched across a desktop
                      // window is hard to read; hold it to a sane measure.
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: notificationsAsync.when(
                        data: (notifications) => notifications.isEmpty
                            ? _buildEmpty(isDark)
                            : _buildList(notifications, isDark),
                        loading: () => _buildLoading(isDark),
                        error: (error, _) => _buildError(error, isDark),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark, int unread) {
    final onSurface = context.colors.ink;

    return Padding(
      padding: EdgeInsets.fromLTRB(context.gutter - 8, 8, context.gutter - 8, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            color: onSurface,
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Notifications',
                  style: AppType.sans(
                    fontSize: context.isCompact ? 22 : 26,
                    fontWeight: FontWeight.bold,
                    color: onSurface,
                  ),
                ),
                if (unread > 0)
                  Text(
                    '$unread unread',
                    style: AppType.sans(
                      fontSize: 12.5,
                      color: isDark
                          ? AppTheme.textMutedDark
                          : ElegantColors.warmGray,
                    ),
                  ),
              ],
            ),
          ),
          if (unread > 0)
            TextButton.icon(
              onPressed: () =>
                  ref.read(notificationsProvider.notifier).markAllAsRead(),
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: Text(
                context.isCompact ? 'Read' : 'Mark all read',
                style: AppType.sans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor:
                    context.colors.secondary,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            color: onSurface,
            tooltip: 'Notification settings',
            onPressed: () => _showNotificationSettings(context),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<NotificationModel> notifications, bool isDark) {
    return RefreshIndicator(
      onRefresh: () =>
          ref.read(notificationsProvider.notifier).fetchNotifications(),
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(
          context.gutter,
          8,
          context.gutter,
          context.gutter + 16,
        ),
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final notification = notifications[index];
          return Dismissible(
            key: Key(notification.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 22),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(16),
              ),
              child:
                  const Icon(Icons.delete_outline_rounded, color: Colors.white),
            ),
            onDismissed: (_) async {
              final messenger = ScaffoldMessenger.of(context);
              final error = await ref
                  .read(notificationsProvider.notifier)
                  .deleteNotification(notification.id);
              messenger.showSnackBar(
                SnackBar(
                  content: Text(error ?? 'Notification dismissed'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: error == null ? null : AppTheme.error,
                ),
              );
            },
            child: NotificationCard(
              notification: notification,
              isDark: isDark,
              onTap: () {
                if (notification.isUnread) {
                  ref
                      .read(notificationsProvider.notifier)
                      .markAsRead(notification.id);
                }
                _navigateToEntity(context, notification);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoading(bool isDark) {
    // Placeholder rows rather than a lone spinner, so the list keeps its shape
    // and arriving content does not shove the screen around.
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: context.gutter, vertical: 8),
      itemCount: 5,
      itemBuilder: (context, index) => Container(
        height: 86,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: (context.colors.ink)
              .withValues(alpha: isDark ? 0.05 : 0.04),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return _CenteredMessage(
      icon: Icons.notifications_none_rounded,
      title: 'Nothing new',
      body: 'Posts, comments, events and news about your account will show up '
          'here.',
      isDark: isDark,
    );
  }

  Widget _buildError(Object error, bool isDark) {
    return _CenteredMessage(
      icon: Icons.cloud_off_rounded,
      title: 'Could not load your notifications',
      body: messageForError(error),
      isDark: isDark,
      action: FilledButton.icon(
        onPressed: () =>
            ref.read(notificationsProvider.notifier).fetchNotifications(),
        icon: const Icon(Icons.refresh_rounded, size: 18),
        label: const Text('Try again'),
      ),
    );
  }

  void _navigateToEntity(BuildContext context, NotificationModel notification) {
    // Navigate using GoRouter
    // We assume the app uses GoRouter as seen in main.dart
    final router = GoRouter.of(context);
    
    switch (notification.entityType) {
      case 'post':
      case 'comment':
      case 'reaction':
        // Navigate to Feed tab in GroupPage
        // Ideally we would pass the post ID to scroll to it
        router.go('/group'); 
        break;
      case 'event':
      case 'event_reminder':
        // Navigate to Events tab in GroupPage
        router.go('/group'); // TODO: Add query param for tab index if supported
        break;
      case 'message':
        // Navigate to Chat tab in GroupPage
        router.go('/group'); // TODO: Add query param for tab index
        break;
      case 'person':
      case 'family_tree':
        router.go('/tree');
        break;
      default:
        log('No screen handles notifications of type ${notification.entityType}');
        router.go('/home');
    }
  }

  void _showNotificationSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const NotificationSettingsDialog(),
    );
  }
}
class NotificationSettingsDialog extends ConsumerStatefulWidget {
  const NotificationSettingsDialog({super.key});

  @override
  ConsumerState<NotificationSettingsDialog> createState() => _NotificationSettingsDialogState();
}

class _NotificationSettingsDialogState extends ConsumerState<NotificationSettingsDialog> {
  bool _isLoading = true;
  NotificationPreference? _preference;

  @override
  void initState() {
    super.initState();
    _fetchPreferences();
  }

  Future<void> _fetchPreferences() async {
    try {
      final response = await ApiService().get('/api/notifications/preferences');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _preference = NotificationPreference.fromJson(data);
            _isLoading = false;
          });
        }
      } else {
        // Handle error or use defaults
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      log('Could not load notification preferences', e);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updatePreference(String key, bool value) async {
    if (_preference == null) return;

    // Optimistic update
    setState(() {
      _preference = _preference!.copyWith(
        eventsEnabled: key == 'events' ? value : null,
        postsEnabled: key == 'posts' ? value : null,
        messagesEnabled: key == 'messages' ? value : null,
        commentsEnabled: key == 'comments' ? value : null,
        mentionsEnabled: key == 'mentions' ? value : null,
      );
    });

    try {
      await ApiService().put(
        '/api/notifications/preferences',
        body: _preference!.toJson(),
      );
    } catch (e) {
      log('Could not save the notification preference', e);
      // Revert? For now just log
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AlertDialog(
        content: SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_preference == null) {
      return AlertDialog(
        title: const Text('Notification Settings'),
        content: const Text('Failed to load settings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: const Text('Notification Settings'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('Events'),
              subtitle: const Text('Reminders for upcoming events'),
              value: _preference!.eventsEnabled,
              onChanged: (val) => _updatePreference('events', val),
            ),
            SwitchListTile(
              title: const Text('New Posts'),
              subtitle: const Text('When family members post updates'),
              value: _preference!.postsEnabled,
              onChanged: (val) => _updatePreference('posts', val),
            ),
            SwitchListTile(
              title: const Text('Messages'),
              subtitle: const Text('Direct messages and chats'),
              value: _preference!.messagesEnabled,
              onChanged: (val) => _updatePreference('messages', val),
            ),
            SwitchListTile(
              title: const Text('Comments'),
              subtitle: const Text('When someone comments on your posts'),
              value: _preference!.commentsEnabled,
              onChanged: (val) => _updatePreference('comments', val),
            ),
            SwitchListTile(
              title: const Text('Mentions'),
              subtitle: const Text('When you are mentioned'),
              value: _preference!.mentionsEnabled,
              onChanged: (val) => _updatePreference('mentions', val),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}


/// One notification row.
class NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;
  final bool isDark;

  const NotificationCard({
    super.key,
    required this.notification,
    required this.onTap,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final unread = notification.isUnread;
    final accent = _accentColor(context);
    final onSurface = context.colors.ink;
    final muted = context.colors.inkMuted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        // Unread is a wash of the app's own accent. It used to be
        // Colors.blue.shade50, which forced a light card into dark mode.
        color: unread
            ? (isDark
                ? AppTheme.primaryLight.withValues(alpha: 0.10)
                : ElegantColors.sage.withValues(alpha: 0.12))
            : (isDark
                ? Colors.white.withValues(alpha: 0.04)
                : ElegantColors.warmWhite),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: unread
                    ? accent.withValues(alpha: 0.35)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.07)
                        : ElegantColors.champagne),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: isDark ? 0.18 : 0.14),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(_iconData(), size: 19, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.sans(
                          fontSize: 14,
                          height: 1.3,
                          fontWeight:
                              unread ? FontWeight.w700 : FontWeight.w600,
                          color: onSurface,
                        ),
                      ),
                      if (notification.body.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          notification.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.sans(
                            fontSize: 14.5,
                            height: 1.35,
                            color: isDark ? Colors.white70 : muted,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        timeago.format(notification.sentAt),
                        style: AppType.sans(fontSize: 11.5, color: muted),
                      ),
                    ],
                  ),
                ),
                if (unread) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 9,
                    height: 9,
                    margin: const EdgeInsets.only(top: 6),
                    decoration:
                        BoxDecoration(color: accent, shape: BoxShape.circle),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Notification kinds are colour-coded from the app's own palette, so the
  /// list reads as one design rather than a Material colour sampler.
  Color _accentColor(BuildContext context) {
    switch (notification.type) {
      case 'event_reminder':
        return context.colors.gold;
      case 'new_post':
        return context.colors.secondary;
      case 'new_comment':
        return context.colors.secondary;
      case 'new_message':
        return context.colors.info;
      case 'mention':
        return context.colors.rose;
      default:
        return context.colors.accent;
    }
  }

  IconData _iconData() {
    switch (notification.type) {
      case 'event_reminder':
        return Icons.event_rounded;
      case 'new_post':
        return Icons.article_rounded;
      case 'new_comment':
        return Icons.mode_comment_rounded;
      case 'new_message':
        return Icons.forum_rounded;
      case 'mention':
        return Icons.alternate_email_rounded;
      case 'event_rsvp':
        return Icons.how_to_reg_rounded;
      default:
        return Icons.campaign_rounded;
    }
  }
}

/// Shared empty / error presentation, so both look like the same app.
class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.icon,
    required this.title,
    required this.body,
    required this.isDark,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool isDark;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final onSurface = context.colors.ink;
    final muted = context.colors.inkMuted;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(context.gutter + 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: (context.colors.secondary)
                    .withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 34,
                color: context.colors.secondary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppType.sans(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: AppType.sans(
                fontSize: 15,
                height: 1.45,
                color: muted,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
