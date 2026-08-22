import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_tree/data/models/post.dart';
import 'package:family_tree/features/feed/feed_page.dart';

// The page runs an endless ambient background, so pumpAndSettle never returns.
Widget _harness({
  required Size size,
  required List<Post> posts,
  Brightness brightness = Brightness.dark,
}) {
  return ProviderScope(
    overrides: [
      postsProvider(kFeedFamilyTreeId).overrideWith((ref) => Stream.value(posts)),
    ],
    child: MediaQuery(
      data: MediaQueryData(size: size),
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: const FeedPage(),
      ),
    ),
  );
}

Post _post(String id, String body) => Post(
      id: id,
      familyTreeId: kFeedFamilyTreeId,
      userId: 'u1',
      userName: 'Mohammed',
      content: body,
      photos: const [],
      videos: const [],
      files: const [],
      createdAt: DateTime.now(),
      reactions: const {},
    );

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// Each PostCard subscribes to GroupRepository.watchComments, an endless
/// 3-second polling loop. Tear the tree down and let that timer elapse so the
/// generator finishes, otherwise the test ends with a pending timer.
Future<void> _drainPollers(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 4));
}

void main() {
  for (final entry in {
    'desktop': const Size(1280, 900),
    'mobile': const Size(390, 844),
  }.entries) {
    testWidgets('renders on ${entry.key} without overflow', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _harness(size: entry.value, posts: [_post('1', 'Hello family')]),
      );
      await _settle(tester);

      expect(find.text('Family Feed'), findsOneWidget);
      expect(find.text('Hello family'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _drainPollers(tester);
    });
  }

  testWidgets('light theme renders cleanly', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(
      size: const Size(1280, 900),
      posts: [_post('1', 'Hello')],
      brightness: Brightness.light,
    ));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    await _drainPollers(tester);
  });

  testWidgets('composer is always present at the top of the feed',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _harness(size: const Size(1280, 900), posts: [_post('1', 'Hi')]),
    );
    await _settle(tester);

    expect(find.text('Share something with the family…'), findsOneWidget);
    // Collapsed until focused: no Post button yet.
    expect(find.text('Post'), findsNothing);
    await _drainPollers(tester);
  });

  testWidgets('composer expands with actions once tapped', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(size: const Size(1280, 900), posts: []));
    await _settle(tester);

    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Post'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty feed invites the first post', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(size: const Size(1280, 900), posts: []));
    await _settle(tester);

    expect(find.text('No stories yet'), findsOneWidget);
    // The composer stays available so there is somewhere to start.
    expect(find.text('Share something with the family…'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
