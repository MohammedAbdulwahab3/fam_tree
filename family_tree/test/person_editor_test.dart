import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_tree/data/models/person.dart';
import 'package:family_tree/features/admin/person_editor.dart';

Person _person({
  required String id,
  required String first,
  String last = 'Mammaduu',
  List<String> parents = const [],
}) {
  return Person(
    id: id,
    familyTreeId: 'main-family-tree',
    firstName: first,
    lastName: last,
    relationships: Relationships(parentIds: parents),
    createdAt: DateTime(2020),
    updatedAt: DateTime(2020),
  );
}

/// Opens the editor and hands back whatever it returned.
Future<Person?> _open(
  WidgetTester tester, {
  required List<Person> people,
  Person? existing,
  Person? preSelectedParent,
}) async {
  Person? result;
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => ElevatedButton(
        onPressed: () async {
          result = await showPersonEditor(
            context: context,
            people: people,
            existing: existing,
            preSelectedParent: preSelectedParent,
          );
        },
        child: const Text('open'),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  final father = _person(id: 'dad', first: 'Issa');
  final mother = _person(id: 'mum', first: 'Fatuma');
  final child = _person(id: 'kid', first: 'Sara', parents: ['dad']);
  final people = [father, mother, child];

  setUp(() {
    // The form is long; a roomy surface keeps everything reachable.
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('every part of the record is offered, adding and editing',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // The fields that used to exist only on the add form, or nowhere at all.
    const expected = [
      'First name *',
      "Father's name",
      'Father',
      'Mother',
      'Spouse name',
      'Occupation',
      'Education',
      'Interests',
      'About them',
      'Born in',
      'Lives in',
      'Phone',
      'Email',
      'Choose a photo',
      'Add a photo',
      'Add an event',
      'Marital status',
      'Has passed away',
    ];

    for (final existing in [null, child]) {
      await _open(tester, people: people, existing: existing);
      for (final label in expected) {
        expect(
          find.text(label),
          findsWidgets,
          reason: '$label missing when '
              '${existing == null ? 'adding' : 'editing'}',
        );
      }
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('a second parent can be chosen from the people in the tree',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _open(tester, people: people, existing: child);

    // The mother dropdown offers everyone who is not in the child's own
    // subtree — picking one records a second parent, which the app could not
    // express at all before.
    final mother = find.byType(DropdownButtonFormField<String?>).last;
    await tester.ensureVisible(mother);
    await tester.pumpAndSettle();
    await tester.tap(mother);
    await tester.pumpAndSettle();
    expect(find.text('Fatuma Mammaduu').hitTestable(), findsWidgets);
  });

  testWidgets('a person is never offered as their own ancestor',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _open(tester, people: people, existing: father);

    // Issa's own child must not be selectable as Issa's parent, or the tree
    // grows a loop the canvas walks forever.
    final fatherPicker = find.byType(DropdownButtonFormField<String?>).first;
    await tester.ensureVisible(fatherPicker);
    await tester.pumpAndSettle();
    await tester.tap(fatherPicker);
    await tester.pumpAndSettle();
    expect(find.text('Sara Mammaduu'), findsNothing);
  });
}
