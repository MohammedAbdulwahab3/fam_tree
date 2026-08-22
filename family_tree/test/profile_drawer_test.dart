import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_tree/data/models/app_user.dart';
import 'package:family_tree/data/models/person.dart';
import 'package:family_tree/data/services/link_service.dart';
import 'package:family_tree/features/auth/providers/auth_provider.dart';
import 'package:family_tree/features/notifications/notifications_screen.dart';
import 'package:family_tree/features/tree_view/widgets/profile_drawer.dart';
import 'package:family_tree/providers/admin_provider.dart';
import 'package:family_tree/providers/link_provider.dart';

/// A four-generation line with a spouse and a sibling hanging off it:
///
///   grandpa ── grandma
///        └── dad ── mum
///              ├── me ── partner
///              │     └── kid
///              └── sister
List<Person> _family() {
  final now = DateTime(2026, 1, 1);

  Person p(
    String id,
    String first, {
    List<String> parents = const [],
    List<String> spouses = const [],
    DateTime? birthDate,
  }) {
    return Person(
      id: id,
      familyTreeId: 'test-tree',
      authUserId: id == 'me' ? 'auth-me' : null,
      firstName: first,
      lastName: 'Tester',
      birthDate: birthDate,
      relationships: Relationships(
        parentIds: parents,
        spouses: spouses
            .map((s) => RelationshipConnection(
                  personId: s,
                  type: RelationshipType.marriage,
                ))
            .toList(),
      ),
      createdAt: now,
      updatedAt: now,
    );
  }

  return [
    p('grandpa', 'Grandpa', spouses: ['grandma']),
    p('grandma', 'Grandma', spouses: ['grandpa']),
    p('dad', 'Dad', parents: ['grandpa', 'grandma'], spouses: ['mum']),
    p('mum', 'Mum', spouses: ['dad']),
    p('me', 'Me',
        parents: ['dad', 'mum'],
        spouses: ['partner'],
        birthDate: DateTime(1990, 6, 15)),
    p('partner', 'Partner', spouses: ['me']),
    p('sister', 'Sister', parents: ['dad', 'mum']),
    p('kid', 'Kid', parents: ['me', 'partner']),
  ];
}

LinkStatus _notLinked() => LinkStatus(isVerified: false, status: 'not_linked');

LinkStatus _pending(String personId, {String? personName}) => LinkStatus(
      isVerified: false,
      status: 'pending',
      requestId: 'req-1',
      personId: personId,
      personName: personName,
      requestedAt: DateTime.now().subtract(const Duration(hours: 3)),
    );

LinkStatus _rejected({String? reason}) => LinkStatus(
      isVerified: false,
      status: 'rejected',
      requestId: 'req-1',
      personId: 'sister',
      personName: 'Aster Bekele',
      reason: reason,
      requestedAt: DateTime.now().subtract(const Duration(days: 2)),
      processedAt: DateTime.now().subtract(const Duration(days: 1)),
    );

Widget _harness({
  required List<Person> members,
  Person? linked,
  bool isAdmin = false,
  LinkStatus? linkStatus,
  Brightness brightness = Brightness.light,
}) {
  final user = AppUser(
    id: 'auth-me',
    email: 'me@example.com',
    name: 'Me Tester',
    role: isAdmin ? 'admin' : 'member',
  );

  return ProviderScope(
    overrides: [
      // The drawer must never reach the network to render.
      authStateProvider.overrideWith((ref) => Stream.value(user)),
      userRoleProvider.overrideWith((ref) async => user),
      unreadCountProvider.overrideWith((ref) => Stream.value(3)),
      linkStatusProvider.overrideWith(
        (ref) async =>
            linkStatus ??
            (linked != null
                ? LinkStatus(isVerified: true, status: 'verified')
                : _notLinked()),
      ),
    ],
    child: MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(
        endDrawer: ProfileDrawer(
          familyMembers: members,
          linkedPerson: linked,
          onChangePhoto: () {},
          onEditLinkedProfile: () {},
        ),
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Scaffold.of(context).openEndDrawer(),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

/// The drawer is a tall scrolling column; give it a viewport that fits so
/// off-screen widgets don't read as missing ones.
void _useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// The drawer runs a staggered entrance plus count-up tweens, so
/// pumpAndSettle is fine but the fixed pumps keep failures readable.
Future<void> _openDrawer(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 1200));
}

void main() {
  group('family stats', () {
    testWidgets('counts generations, members and direct relatives',
        (tester) async {
      _useTallScreen(tester);

      final members = _family();
      final me = members.firstWhere((p) => p.id == 'me');

      await tester.pumpWidget(_harness(members: members, linked: me));
      await _openDrawer(tester);

      expect(find.text('Generations'), findsOneWidget);
      expect(find.text('Members'), findsOneWidget);
      expect(find.text('Relatives'), findsOneWidget);

      // grandpa -> dad -> me -> kid
      expect(find.text('4'), findsOneWidget);
      // everyone in the list
      expect(find.text('8'), findsOneWidget);
      // 2 parents + 1 sibling + 1 spouse + 1 child
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('breaks the relative count down by relationship',
        (tester) async {
      _useTallScreen(tester);

      final members = _family();
      final me = members.firstWhere((p) => p.id == 'me');

      await tester.pumpWidget(_harness(members: members, linked: me));
      await _openDrawer(tester);

      expect(find.text('In the tree as Me Tester'), findsOneWidget);
      expect(find.text('Parents'), findsOneWidget);
      // Derived from the shared parents, not the (empty) siblingIds list.
      expect(find.text('Siblings'), findsOneWidget);
      expect(find.text('Spouse'), findsOneWidget);
      expect(find.text('Children'), findsOneWidget);
    });

    testWidgets('survives an empty tree', (tester) async {
      _useTallScreen(tester);

      await tester.pumpWidget(_harness(members: const [], linked: null));
      await _openDrawer(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Members'), findsOneWidget);
    });
  });

  group('quick actions', () {
    testWidgets('no longer offers export or the full-tree jump',
        (tester) async {
      _useTallScreen(tester);

      final members = _family();
      await tester.pumpWidget(_harness(
        members: members,
        linked: members.firstWhere((p) => p.id == 'me'),
      ));
      await _openDrawer(tester);

      expect(find.text('Export'), findsNothing);
      expect(find.text('Full Tree'), findsNothing);
      // What stays.
      expect(find.text('Family Feed'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
    });

    testWidgets('badges the unread notification count', (tester) async {
      _useTallScreen(tester);

      final members = _family();
      await tester.pumpWidget(_harness(
        members: members,
        linked: members.firstWhere((p) => p.id == 'me'),
      ));
      await _openDrawer(tester);

      expect(find.text('3 unread'), findsOneWidget);
    });

    testWidgets('hides the admin panel from ordinary members', (tester) async {
      _useTallScreen(tester);

      final members = _family();
      await tester.pumpWidget(_harness(
        members: members,
        linked: members.firstWhere((p) => p.id == 'me'),
      ));
      await _openDrawer(tester);

      expect(find.text('Member'), findsOneWidget);
      expect(find.text('Admin Panel'), findsNothing);
    });

    testWidgets('surfaces the admin panel for admins', (tester) async {
      _useTallScreen(tester);

      final members = _family();
      await tester.pumpWidget(_harness(
        members: members,
        linked: members.firstWhere((p) => p.id == 'me'),
        isAdmin: true,
      ));
      await _openDrawer(tester);

      expect(find.text('Admin'), findsOneWidget);
      expect(find.text('Admin Panel'), findsOneWidget);
    });
  });

  group('link state', () {
    testWidgets('an unlinked account is offered the link flow, not edits',
        (tester) async {
      _useTallScreen(tester);

      await tester.pumpWidget(_harness(
        members: _family(),
        linked: null,
        linkStatus: _notLinked(),
      ));
      await _openDrawer(tester);

      expect(find.text('Not linked'), findsOneWidget);
      expect(find.text('Link account'), findsOneWidget);
      expect(find.text('You are not linked to the tree yet'), findsOneWidget);
      expect(find.text('Find myself in the tree'), findsOneWidget);

      // Editing is gated on the link — there is no record to edit yet.
      expect(find.text('Edit profile'), findsNothing);
    });

    testWidgets('a pending request reports itself instead of re-offering',
        (tester) async {
      _useTallScreen(tester);

      await tester.pumpWidget(_harness(
        members: _family(),
        linked: null,
        linkStatus: _pending('sister', personName: 'Aster Bekele'),
      ));
      await _openDrawer(tester);

      // Said twice on purpose: the identity badge and the quick-action tile.
      expect(find.text('Link pending'), findsNWidgets(2));
      expect(find.text('Awaiting review'), findsOneWidget);
      expect(find.text('Your claim is being reviewed'), findsOneWidget);
      expect(find.text('View claim status'), findsOneWidget);
      expect(find.text('Find myself in the tree'), findsNothing);

      // Naming who was claimed lets someone spot they picked the wrong
      // relative without waiting for the review to come back.
      expect(
        find.textContaining('You asked to be linked to Aster Bekele'),
        findsOneWidget,
      );

      // And they can take it back rather than wait it out.
      expect(find.text('Withdraw this claim'), findsOneWidget);
    });

    testWidgets('a rejected claim shows the admin\'s reason', (tester) async {
      _useTallScreen(tester);

      await tester.pumpWidget(_harness(
        members: _family(),
        linked: null,
        linkStatus: _rejected(reason: 'That is your uncle, not you'),
      ));
      await _openDrawer(tester);

      expect(find.text('Your claim was not approved'), findsOneWidget);
      expect(
        find.textContaining('That is your uncle, not you'),
        findsOneWidget,
      );

      // The way forward is offered, so the member is not stuck.
      expect(find.text('Claim a different person'), findsOneWidget);

      // A rejection is never dressed up as never having asked.
      expect(find.text('You are not linked to the tree yet'), findsNothing);
      expect(find.text('Withdraw this claim'), findsNothing);
    });

    testWidgets('a rejection with no reason still explains what to do',
        (tester) async {
      _useTallScreen(tester);

      await tester.pumpWidget(_harness(
        members: _family(),
        linked: null,
        linkStatus: _rejected(),
      ));
      await _openDrawer(tester);

      expect(find.text('Your claim was not approved'), findsOneWidget);
      expect(
        find.textContaining('They did not leave a reason'),
        findsOneWidget,
      );
      expect(find.text('Claim a different person'), findsOneWidget);
    });

    testWidgets('a linked account gets both edit rows', (tester) async {
      _useTallScreen(tester);

      final members = _family();
      await tester.pumpWidget(_harness(
        members: members,
        linked: members.firstWhere((p) => p.id == 'me'),
      ));
      await _openDrawer(tester);

      expect(find.text('Linked'), findsNWidgets(2));
      expect(find.text('Verified member'), findsOneWidget);
      // One row now: the family record *is* the profile.
      expect(find.text('Edit profile'), findsOneWidget);
      expect(find.text('Account details'), findsNothing);
      expect(find.text('Request to link my account'), findsNothing);
    });
  });
}
