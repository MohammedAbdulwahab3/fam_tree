import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_tree/data/models/notification_model.dart';
import 'package:family_tree/features/notifications/notifications_screen.dart';

NotificationModel _n({
  required String id,
  required String title,
  String body = 'Something happened in the family',
  String type = 'new_post',
  bool unread = true,
}) {
  return NotificationModel(
    id: id,
    userId: 'me',
    type: type,
    entityType: 'post',
    entityId: 'post-1',
    title: title,
    body: body,
    data: const {},
    sentAt: DateTime.now().subtract(const Duration(hours: 2)),
    readAt: unread ? null : DateTime.now(),
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
  );
}

/// Serves a fixed list without touching the network.
class _FakeNotifier extends NotificationsNotifier {
  _FakeNotifier(List<NotificationModel> items) {
    state = AsyncValue.data(items);
  }

  @override
  Future<void> fetchNotifications() async {}

  @override
  Future<String?> deleteNotification(String id) async {
    state = AsyncValue.data(
      state.value!.where((n) => n.id != id).toList(),
    );
    return null;
  }

  @override
  Future<void> markAsRead(String id) async {}

  @override
  Future<void> markAllAsRead() async {}
}

Widget _harness({
  required Size size,
  Brightness brightness = Brightness.dark,
  List<NotificationModel>? items,
  AsyncValue<List<NotificationModel>>? override,
}) {
  final notifier = _FakeNotifier(items ?? const []);
  if (override != null) notifier.state = override;

  return ProviderScope(
    overrides: [
      notificationsProvider.overrideWith((ref) => notifier),
      unreadCountProvider.overrideWith((ref) => Stream.value(0)),
    ],
    child: MediaQuery(
      data: MediaQueryData(size: size),
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: const NotificationsScreen(),
      ),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  final sizes = {
    'desktop': const Size(1440, 900),
    'tablet': const Size(900, 1000),
    'mobile': const Size(360, 780),
  };

  final sample = [
    _n(id: '1', title: 'New post from Anna Girma'),
    _n(
      id: '2',
      title: 'Bereket commented on your post',
      type: 'new_comment',
      unread: false,
    ),
    _n(
      id: '3',
      title: 'Tomorrow: Meskel gathering',
      type: 'event_reminder',
      body: 'A much longer body that has to wrap and then be cut off cleanly '
          'rather than pushing the row out past the edge of the screen.',
    ),
  ];

  for (final entry in sizes.entries) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'renders on ${entry.key} in ${brightness.name} without overflow',
        (tester) async {
          tester.view.physicalSize = entry.value;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(_harness(
            size: entry.value,
            brightness: brightness,
            items: sample,
          ));
          await _settle(tester);

          expect(find.text('Notifications'), findsOneWidget);
          expect(find.text('New post from Anna Girma'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('counts the unread ones and offers to clear them',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(size: const Size(900, 1000), items: sample));
    await _settle(tester);

    // Two of the three are unread.
    expect(find.text('2 unread'), findsOneWidget);
    expect(find.text('Mark all read'), findsOneWidget);
  });

  testWidgets('hides the mark-all action when everything is read',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(
      size: const Size(900, 1000),
      items: [_n(id: '1', title: 'Old news', unread: false)],
    ));
    await _settle(tester);

    expect(find.textContaining('unread'), findsNothing);
    expect(find.text('Mark all read'), findsNothing);
  });

  testWidgets('empty state explains what will appear here', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(size: const Size(390, 844), items: const []));
    await _settle(tester);

    expect(find.text('Nothing new'), findsOneWidget);
    expect(find.textContaining('will show up'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an error offers a way to try again', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(
      size: const Size(390, 844),
      override: AsyncValue.error('boom', StackTrace.empty),
    ));
    await _settle(tester);

    expect(find.text('Could not load your notifications'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('swiping a notification away removes the row', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(size: const Size(390, 844), items: sample));
    await _settle(tester);

    expect(find.text('New post from Anna Girma'), findsOneWidget);
    await tester.drag(
      find.text('New post from Anna Girma'),
      const Offset(-500, 0),
    );
    // The aurora backdrop animates forever, so pumpAndSettle would never
    // return; pump past the dismiss animation instead.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('New post from Anna Girma'), findsNothing);
  });

  testWidgets('survives a large system text size', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationsProvider.overrideWith((ref) => _FakeNotifier(sample)),
          unreadCountProvider.overrideWith((ref) => Stream.value(0)),
        ],
        child: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 780),
            textScaler: TextScaler.linear(1.6),
          ),
          child: MaterialApp(
            theme: ThemeData(brightness: Brightness.dark),
            home: const NotificationsScreen(),
          ),
        ),
      ),
    );
    await _settle(tester);

    expect(tester.takeException(), isNull);
  });
}
