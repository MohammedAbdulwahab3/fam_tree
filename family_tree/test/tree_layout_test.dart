import 'package:flutter_test/flutter_test.dart';

import 'package:family_tree/data/models/person.dart';
import 'package:family_tree/data/repositories/person_repository.dart';
import 'package:family_tree/features/tree_view/services/tree_layout_service.dart';

Person _person(String id, {List<String> parents = const []}) => Person(
      id: id,
      familyTreeId: 'test-tree',
      firstName: id,
      lastName: '',
      relationships: Relationships(parentIds: parents),
      createdAt: DateTime(2020),
      updatedAt: DateTime(2020),
    );

void main() {
  group('TreeLayoutService', () {
    test('places everyone exactly once', () {
      final people = [
        _person('gran'),
        _person('mum', parents: ['gran']),
        _person('uncle', parents: ['gran']),
        _person('me', parents: ['mum']),
      ];

      final layout = TreeLayoutService.calculate(people);

      expect(layout.positions.keys.toSet(), people.map((p) => p.id).toSet());
    });

    test('generations come from the walk, not from the y coordinate', () {
      final people = [
        _person('gran'),
        _person('mum', parents: ['gran']),
        _person('me', parents: ['mum']),
      ];

      final layout = TreeLayoutService.calculate(people, levelSeparation: 137);

      expect(layout.generations['gran'], 0);
      expect(layout.generations['mum'], 1);
      expect(layout.generations['me'], 2);
    });

    test('children sit below their parent', () {
      final people = [
        _person('parent'),
        _person('child', parents: ['parent']),
      ];

      final layout = TreeLayoutService.calculate(people, levelSeparation: 400);

      expect(
        layout.positions['child']!.dy,
        greaterThan(layout.positions['parent']!.dy),
      );
    });

    // A child with two parents used to be appended to both parents' child
    // lists, so its whole subtree was measured and positioned twice — the
    // second pass overwriting the first.
    test('a child with two parents is laid out once', () {
      final people = [
        _person('dad'),
        _person('mum'),
        _person('kid', parents: ['dad', 'mum']),
        _person('grandkid', parents: ['kid']),
      ];

      final layout = TreeLayoutService.calculate(people);

      expect(layout.positions.length, 4);
      expect(layout.generations['kid'], 1);
      expect(layout.generations['grandkid'], 2);
    });

    // Nothing stops the admin screen making someone their own ancestor, and
    // the old recursion had no visited set — a single bad edge overflowed the
    // stack rather than producing a layout.
    test('a cycle does not hang or overflow', () {
      final people = [
        _person('a', parents: ['b']),
        _person('b', parents: ['a']),
      ];

      final layout = TreeLayoutService.calculate(people);

      expect(layout.positions.length, 2);
    });

    test('a person listed as their own parent is tolerated', () {
      final people = [_person('lonely', parents: ['lonely'])];

      final layout = TreeLayoutService.calculate(people);

      expect(layout.positions.containsKey('lonely'), isTrue);
    });

    test('a parent outside the list leaves the child as a root', () {
      final people = [_person('orphan', parents: ['not-here'])];

      final layout = TreeLayoutService.calculate(people);

      expect(layout.generations['orphan'], 0);
    });

    test('separate families are laid out side by side, not on top', () {
      final people = [
        _person('familyA'),
        _person('childA', parents: ['familyA']),
        _person('familyB'),
        _person('childB', parents: ['familyB']),
      ];

      final layout = TreeLayoutService.calculate(people);

      final xs = layout.positions.values.map((o) => o.dx).toSet();
      expect(xs.length, layout.positions.length,
          reason: 'no two people should share a column');
    });

    test('an empty tree is an empty layout', () {
      expect(TreeLayoutService.calculate([]).positions, isEmpty);
    });
  });

  group('FamilyIndex', () {
    test('resolves a person by id, and returns null for a stranger', () {
      final index = FamilyIndex([_person('a'), _person('b')]);

      expect(index.byId('a')?.id, 'a');
      // This used to fall back to the first person in the list, silently
      // substituting an unrelated relative for a missing one.
      expect(index.byId('nobody'), isNull);
    });

    test('lists children in both directions of a two-parent link', () {
      final dad = _person('dad');
      final mum = _person('mum');
      final kid = _person('kid', parents: ['dad', 'mum']);
      final index = FamilyIndex([dad, mum, kid]);

      expect(index.childrenOf(dad).map((p) => p.id), ['kid']);
      expect(index.childrenOf(mum).map((p) => p.id), ['kid']);
      expect(index.childrenOf(kid), isEmpty);
    });

    test('roots are the people whose parents are all outside the list', () {
      final people = [
        _person('gran'),
        _person('mum', parents: ['gran']),
        _person('adopted', parents: ['someone-not-here']),
      ];

      final roots = FamilyIndex(people).roots(people).map((p) => p.id).toSet();

      expect(roots, {'gran', 'adopted'});
    });

    test('a fully cyclic family still yields a starting point', () {
      final people = [
        _person('a', parents: ['b']),
        _person('b', parents: ['a']),
      ];

      expect(FamilyIndex(people).roots(people), hasLength(1));
    });

    test('an empty family has no roots', () {
      expect(FamilyIndex(const []).roots(const []), isEmpty);
    });
  });
}
