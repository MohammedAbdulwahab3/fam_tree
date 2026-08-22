import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_tree/features/admin/post_composer_sheet.dart';

/// The composer replaces a dialog that was a lone textarea and hardcoded
/// `photos`, `videos` and `files` to empty — so the family feed could only ever
/// receive plain text even though `Post` has always carried attachments.
Widget _harness() {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            await PostComposerSheet.show(context, authorName: 'Mohammed');
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}


/// `FilledButton.icon` builds a private subclass, so `find.byType` misses it —
/// match the common supertype and locate it by its label instead.
ButtonStyleButton _publishButton(WidgetTester tester) {
  return tester.widget<ButtonStyleButton>(
    find.ancestor(
      of: find.text('Post to the family feed'),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    ).first,
  );
}

void main() {
  testWidgets('offers photo, video and file attachments', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness());
    await _open(tester);

    expect(find.text('Photos'), findsOneWidget);
    expect(find.text('Video'), findsOneWidget);
    expect(find.text('File'), findsOneWidget);
  });

  testWidgets('names the author so a post is never anonymous', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness());
    await _open(tester);

    expect(find.textContaining('Posting as Mohammed'), findsOneWidget);
  });

  testWidgets('will not publish an empty post', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness());
    await _open(tester);

    expect(_publishButton(tester).onPressed, isNull,
        reason: 'nothing written and nothing attached is not a post');
  });

  testWidgets('enables publishing once something is written', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness());
    await _open(tester);

    await tester.enterText(find.byType(TextField), 'Eid greetings to everyone');
    await tester.pump();

    expect(_publishButton(tester).onPressed, isNotNull);
    expect(find.text('25 / 5000'), findsOneWidget);
  });

  testWidgets('asks before throwing away written text', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness());
    await _open(tester);

    await tester.enterText(find.byType(TextField), 'A long memory…');
    await tester.pump();

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Discard this post?'), findsOneWidget);

    await tester.tap(find.text('Keep writing'));
    await tester.pumpAndSettle();
    // Still open, text intact.
    expect(find.text('A long memory…'), findsOneWidget);
  });

  test('the artboard no longer hardcodes empty attachments', () {
    final source =
        File('lib/features/admin/admin_family_artboard.dart').readAsStringSync();
    // The old dialog built every post with these three literals.
    expect(
      source.contains('photos: const [],\n          videos: const [],'),
      isFalse,
      reason: 'posts must carry the attachments the composer collected',
    );
    expect(source.contains('photos: composed.photos'), isTrue);
    expect(source.contains('videos: composed.videos'), isTrue);
    expect(source.contains('files: composed.files'), isTrue);
  });

  test('the header row has no create buttons left in it', () {
    final source =
        File('lib/features/admin/admin_family_artboard.dart').readAsStringSync();
    final header = source.substring(
      source.indexOf('Widget _buildArtboardHeader'),
      source.indexOf('Widget _buildInlineSearch'),
    );
    // Both live in the tools menu; only the menu's PopupMenuItem labels remain.
    expect(header.contains("label: 'Add member'"), isFalse);
    expect(header.contains("label: 'Add post'"), isFalse);
  });

  test('reload and tools sit left of the title', () {
    final source =
        File('lib/features/admin/admin_family_artboard.dart').readAsStringSync();
    // One row again: the three-band header started the tree halfway down the
    // screen, so everything shares a single bar.
    final header = source.substring(
      source.indexOf('Widget _buildArtboardHeader'),
      source.indexOf('Widget _roundIcon'),
    );
    final back = header.indexOf('Icons.arrow_back_rounded');
    final reload = header.indexOf('Icons.refresh_rounded');
    final tools = header.indexOf('_toolsMenu(');
    final title = header.indexOf("'Family Artboard'");

    for (final index in [back, reload, tools, title]) {
      expect(index, greaterThan(-1));
    }
    expect(back, lessThan(reload));
    expect(reload, lessThan(tools));
    expect(tools, lessThan(title),
        reason: 'every control belongs left of the title');
  });

  test('the header is a single row, not stacked bands', () {
    final source =
        File('lib/features/admin/admin_family_artboard.dart').readAsStringSync();
    // The stats band and subtitle ate roughly a third of the viewport.
    expect(source.contains('_headerStats('), isFalse);
    expect(source.contains('_headerTitleRow('), isFalse);
    expect(source.contains('_statPill('), isFalse);
  });
}
