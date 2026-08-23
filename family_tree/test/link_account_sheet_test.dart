import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_tree/data/models/person.dart';
import 'package:family_tree/data/services/link_service.dart';
import 'package:family_tree/features/tree_view/widgets/link_account_sheet.dart';
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

  Person p(String id, String first, {String? owner, DateTime? birth}) => Person(
        id: id,
        familyTreeId: 'test-tree',
        authUserId: owner,
        firstName: first,
        lastName: 'Tester',
        birthDate: birth,
        relationships: Relationships(),
        createdAt: now,
        updatedAt: now,
      );

  return [
    p('taken', 'Claimed', owner: 'someone-else'),
    p('free-a', 'Amara', birth: DateTime(1972, 4, 2)),
    p('free-b', 'Bekele'),
    p('free-c', 'Chaltu'),
  ];
}

Widget _harness(_FakeLinkService service, List<Person> members) {
  return ProviderScope(
    overrides: [linkServiceProvider.overrideWithValue(service)],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                LinkAccountSheet.show(context, familyMembers: members),
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

void main() {
  testWidgets('offers only records nobody has claimed', (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(_FakeLinkService(), _family()));
    await _openSheet(tester);

    expect(find.text('Amara Tester'), findsOneWidget);
    expect(find.text('Bekele Tester'), findsOneWidget);
    expect(find.text('Chaltu Tester'), findsOneWidget);
    // Already owned by another account — requesting it could only be rejected.
    expect(find.text('Claimed Tester'), findsNothing);
  });

  testWidgets('filters the list as you type', (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(_FakeLinkService(), _family()));
    await _openSheet(tester);

    await tester.enterText(find.byType(TextField), 'bek');
    await tester.pump();

    expect(find.text('Bekele Tester'), findsOneWidget);
    expect(find.text('Amara Tester'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    expect(find.textContaining('Nobody in the tree matches'), findsOneWidget);
  });

  testWidgets('sends the picked person and then shows the pending state',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final service = _FakeLinkService();
    await tester.pumpWidget(_harness(service, _family()));
    await _openSheet(tester);

    // Nothing is submittable until a person is chosen.
    expect(find.text('Pick the person you are in the tree'), findsOneWidget);

    await tester.tap(find.text('Bekele Tester'));
    await tester.pumpAndSettle();
    expect(find.text('Request to link as Bekele'), findsOneWidget);

    await tester.tap(find.text('Request to link as Bekele'));
    await tester.pumpAndSettle();

    expect(service.requestCount, 1);
    expect(service.requestedPersonId, 'free-b');
    // The sheet re-reads status, which is now pending.
    expect(find.text('Waiting for approval'), findsOneWidget);
    expect(find.textContaining('Bekele Tester'), findsOneWidget);
  });

  testWidgets('turns a duplicate-request conflict into plain language',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final service = _FakeLinkService(
      failWith: Exception('Pending request already exists'),
    );
    await tester.pumpWidget(_harness(service, _family()));
    await _openSheet(tester);

    await tester.tap(find.text('Amara Tester'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Request to link as Amara'));
    await tester.pumpAndSettle();

    expect(
      find.text('You already have a request waiting for review.'),
      findsOneWidget,
    );
  });

  testWidgets('a pending account sees its request, not the picker',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final service = _FakeLinkService(
      status: LinkStatus(
        isVerified: false,
        status: 'pending',
        requestId: 'req-1',
        personId: 'free-c',
        requestedAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    );
    await tester.pumpWidget(_harness(service, _family()));
    await _openSheet(tester);

    expect(find.text('Waiting for approval'), findsOneWidget);
    expect(find.text('Sent 2 days ago'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('a verified account is told it is already done', (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final service = _FakeLinkService(
      status: LinkStatus(isVerified: true, status: 'verified'),
    );
    await tester.pumpWidget(_harness(service, _family()));
    await _openSheet(tester);

    expect(find.text('Your account is linked'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('says so when every record is already claimed', (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

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

    expect(
      find.text('Every record already belongs to an account'),
      findsOneWidget,
    );
  });
}
