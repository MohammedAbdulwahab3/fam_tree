import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../data/models/notification_model.dart';
import '../../data/services/api_service.dart';
import 'dart:convert';
import 'package:go_router/go_router.dart';

// Notifications state provider
final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, AsyncValue<List<NotificationModel>>>(
  (ref) => NotificationsNotifier(),
);

// Unread count provider
final unreadCountProvider = FutureProvider<int>((ref) async {
  final response = await ApiService().get('/api/notifications/unread-count');
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return data['count'] as int;
  }
  return 0;
});

class NotificationsNotifier extends StateNotifier<AsyncValue<List<NotificationModel>>> {
  NotificationsNotifier() : super(const AsyncValue.loading()) {
    fetchNotifications();
  }

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

  Future<void> deleteNotification(String notificationId) async {
    try {
      // Optimistic update
      final previousState = state;
      if (state.hasValue) {
        state = AsyncValue.data(
          state.value!.where((n) => n.id != notificationId).toList(),
        );
      }

      final response = await ApiService().delete('/api/notifications/$notificationId');
      if (response.statusCode != 200) {
        // Revert on failure
        state = previousState;
        print('Failed to delete notification');
      }
    } catch (e) {
      print('Error deleting notification: $e');
      // Revert on error
      fetchNotifications();
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await ApiService().put('/api/notifications/$notificationId/read');
      // Optimistic update
      if (state.hasValue) {
        state = AsyncValue.data(
          state.value!.map((n) {
            if (n.id == notificationId) {
              // Create a copy with readAt set to now (mocking it for UI)
              // Since NotificationModel fields are final, we can't easily modify it without copyWith
              // Assuming we fetch again or just ignore for now as the UI will update on next fetch
              // For better UX, we should implement copyWith on NotificationModel
              return n; 
            }
            return n;
          }).toList(),
        );
      }
      fetchNotifications(); // Refresh to get server state
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await ApiService().put('/api/notifications/read-all');
      fetchNotifications(); // Refresh
    } catch (e) {
      print('Error marking all as read: $e');
    }
  }
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            onPressed: () {
              ref.read(notificationsProvider.notifier).markAllAsRead();
            },
            tooltip: 'Mark all as read',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              _showNotificationSettings(context);
            },
            tooltip: 'Notification Settings',
          ),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No notifications yet', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(notificationsProvider.notifier).fetchNotifications();
            },
            child: ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return Dismissible(
                  key: Key(notification.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (direction) {
                    ref.read(notificationsProvider.notifier).deleteNotification(notification.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Notification deleted')),
                    );
                  },
                  child: NotificationCard(
                    notification: notification,
                    onTap: () {
                      if (notification.isUnread) {
                        ref.read(notificationsProvider.notifier).markAsRead(notification.id);
                      }
                      _navigateToEntity(context, notification);
                    },
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.read(notificationsProvider.notifier).fetchNotifications();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
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
        print('Unknown entity type: ${notification.entityType}');
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
      print('Error fetching preferences: $e');
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
      print('Error updating preference: $e');
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

class NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const NotificationCard({
    super.key,
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: notification.isUnread ? Colors.blue.shade50 : null,
      child: ListTile(
        leading: _getIcon(),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.isUnread ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              notification.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              timeago.format(notification.sentAt),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: notification.isUnread
            ? Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              )
            : null,
        onTap: onTap,
      ),
    );
  }

  Widget _getIcon() {
    IconData iconData;
    Color color;

    switch (notification.type) {
      case 'event_reminder':
        iconData = Icons.event;
        color = Colors.orange;
        break;
      case 'new_post':
        iconData = Icons.article;
        color = Colors.blue;
        break;
      case 'new_comment':
        iconData = Icons.comment;
        color = Colors.green;
        break;
      case 'new_message':
        iconData = Icons.message;
        color = Colors.purple;
        break;
      case 'mention':
        iconData = Icons.alternate_email;
        color = Colors.teal;
        break;
      default:
        iconData = Icons.notifications;
        color = Colors.grey;
    }

    return CircleAvatar(
      backgroundColor: color.withOpacity(0.2),
      child: Icon(iconData, color: color, size: 20),
    );
  }
}
