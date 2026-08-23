import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/data/models/person.dart';
import 'package:family_tree/data/services/link_service.dart';
import 'package:family_tree/features/linking/find_myself_sheet.dart';
import 'package:family_tree/features/linking/link_status.dart';

/// Stands in for the network. Records what it was asked to link so a test can
/// assert the request carried the person the user actually picked.
class _FakeLinkService implements LinkService {
  _FakeLinkService({
    LinkStatus? status,
    this.failWith,
  }) : status = status ?? LinkStatus(isVerified: false, status: 'not_linked');

  LinkStatus status;
  final Object? failWith;

  String? requestedPersonId;
  int requestCount = 0;

  @override
  Future<LinkStatus> getMyLinkStatus() async => status;

  @override
  Future<LinkRequest> requestLink(String personId) async {
    requestCount++;
    requestedPersonId = personId;
    if (failWith != null) throw failWith!;

    status = LinkStatus(
      isVerified: false,
      status: 'pending',
      requestId: 'req-1',
      personId: personId,
      requestedAt: DateTime.now(),
    );
    return LinkRequest(
      id: 'req-1',
      userId: 'auth-me',
      personId: personId,
      familyTreeId: 'test-tree',
      status: 'pending',
      requestedAt: DateTime.now(),
    );
  }

  @override
  Future<List<LinkRequest>> getPendingRequests() async => const [];

  @override
  Future<LinkRequest> updateLinkStatus(
    String requestId,
    String status, {
    String? reason,
  }) =>
      throw UnimplementedError();

  int cancelCount = 0;

  @override
  Future<void> cancelMyRequest() async {
    cancelCount++;
    status = LinkStatus(isVerified: false, status: 'not_linked');
  }
}

List<Person> _family() {
  final now = DateTime(2026, 1, 1);

  Person p(
    String id,
    String first, {
    String? owner,
    DateTime? birth,
    List<String> parents = const [],
  }) =>
      Person(
        id: id,
        familyTreeId: 'test-tree',
        authUserId: owner,
        firstName: first,
        lastName: 'Tester',
        birthDate: birth,
        relationships: Relationships(parentIds: parents),
        createdAt: now,
        updatedAt: now,
      );

  return [
    p('taken', 'Claimed', owner: 'someone-else'),
    p('free-a', 'Amara', birth: DateTime(1972, 4, 2)),
    p('free-b', 'Bekele', parents: ['free-a']),
    p('free-c', 'Chaltu', parents: ['free-a']),
  ];
}

Widget _harness(_FakeLinkService service, List<Person> members) {
  return ProviderScope(
    overrides: [linkServiceProvider.overrideWithValue(service)],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showFindMyselfSheet(context, people: members),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('offers only records nobody has claimed', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_harness(_FakeLinkService(), _family()));
    await _openSheet(tester);

    expect(find.text('Amara Tester'), findsOneWidget);
    expect(find.text('Bekele Tester'), findsOneWidget);
    expect(find.text('Chaltu Tester'), findsOneWidget);
    // Already owned by another account — claiming it could only be rejected.
    expect(find.text('Claimed Tester'), findsNothing);
  });

  // Names repeat in a family, so a name alone does not identify anybody. Every
  // candidate carries the relatives that tell two of them apart.
  testWidgets('shows each candidate with their family around them',
      (tester) async {
    _phone(tester);
    await tester.pumpWidget(_harness(_FakeLinkService(), _family()));
    await _openSheet(tester);

    expect(find.text('Child of Amara Tester'), findsNWidgets(2));
    expect(find.textContaining('Parent of Bekele, Chaltu'), findsOneWidget);
  });

  testWidgets('filters the list as you type', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_harness(_FakeLinkService(), _family()));
    await _openSheet(tester);

    await tester.enterText(find.byType(TextField), 'bek');
    await tester.pump();

    expect(find.text('Bekele Tester'), findsOneWidget);
    expect(find.text('Amara Tester'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    expect(find.textContaining('Nobody matches'), findsOneWidget);
  });

  // Nothing is sent from the list. Picking somebody opens a confirmation that
  // restates the whole relationship, because a wrong claim costs the member
  // another wait and an admin a rejection.
  testWidgets('confirms who you are before sending anything', (tester) async {
    _phone(tester);
    final service = _FakeLinkService();
    await tester.pumpWidget(_harness(service, _family()));
    await _openSheet(tester);

    await tester.tap(find.text('Bekele Tester'));
    await tester.pumpAndSettle();

    expect(find.text('You are saying you are'), findsOneWidget);
    expect(find.text('Your parent'), findsOneWidget);
    expect(service.requestCount, 0, reason: 'nothing sent until confirmed');

    await tester.tap(find.text('Yes, this is me'));
    await tester.pumpAndSettle();

    expect(service.requestCount, 1);
    expect(service.requestedPersonId, 'free-b');
    expect(find.text('An admin is checking'), findsOneWidget);
  });

  testWidgets('backing out of the confirmation sends nothing', (tester) async {
    _phone(tester);
    final service = _FakeLinkService();
    await tester.pumpWidget(_harness(service, _family()));
    await _openSheet(tester);

    await tester.tap(find.text('Amara Tester'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No, go back'));
    await tester.pumpAndSettle();

    expect(service.requestCount, 0);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('turns a duplicate-request conflict into plain language',
      (tester) async {
    _phone(tester);
    final service = _FakeLinkService(
      failWith: Exception('You already have a claim waiting for review.'),
    );
    await tester.pumpWidget(_harness(service, _family()));
    await _openSheet(tester);

    await tester.tap(find.text('Amara Tester'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, this is me'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('already have a claim waiting'),
      findsOneWidget,
    );
  });

  testWidgets('a pending account sees its claim, not the picker',
      (tester) async {
    _phone(tester);
    final service = _FakeLinkService(
      status: LinkStatus(
        isVerified: false,
        status: 'pending',
        requestId: 'req-1',
        personId: 'free-c',
        personName: 'Chaltu Tester',
        requestedAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    );
    await tester.pumpWidget(_harness(service, _family()));
    await _openSheet(tester);

    expect(find.text('An admin is checking'), findsOneWidget);
    expect(find.textContaining('Chaltu Tester'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  // A rejection that says nothing leaves the member with no move except to
  // claim the same person again.
  testWidgets('a rejected member sees the reason and can look again',
      (tester) async {
    _phone(tester);
    final service = _FakeLinkService(
      status: LinkStatus(
        isVerified: false,
        status: 'rejected',
        personName: 'Amara Tester',
        reason: 'That is your aunt, not you',
      ),
    );
    await tester.pumpWidget(_harness(service, _family()));
    await _openSheet(tester);

    expect(find.textContaining('That is your aunt'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('a verified account is told it is already done', (tester) async {
    _phone(tester);
    final service = _FakeLinkService(
      status: LinkStatus(isVerified: true, status: 'verified'),
    );
    await tester.pumpWidget(_harness(service, _family()));
    await _openSheet(tester);

    expect(find.text('You are already in the tree'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('says so when every record is already claimed', (tester) async {
    _phone(tester);
    final allTaken = _family()
        .map((p) => Person(
              id: p.id,
              familyTreeId: p.familyTreeId,
              authUserId: 'someone-else',
              firstName: p.firstName,
              lastName: p.lastName,
              relationships: p.relationships,
              createdAt: p.createdAt,
              updatedAt: p.updatedAt,
            ))
        .toList();

    await tester.pumpWidget(_harness(_FakeLinkService(), allTaken));
    await _openSheet(tester);

    expect(find.text('Everyone has been claimed'), findsOneWidget);
  });
}
