import 'package:flutter_test/flutter_test.dart';

import 'package:family_tree/data/models/person.dart';

Person _p(String id, {List<String> parents = const []}) => Person(
      id: id,
      familyTreeId: 'test-tree',
      firstName: id,
      lastName: 'Test',
      relationships: Relationships(parentIds: parents),
      createdAt: DateTime(2020, 1, 1),
      updatedAt: DateTime(2020, 1, 1),
    );

void main() {
  test('counts nobody for a person with no children', () {
    final tree = [_p('a')];
    expect(countDescendants('a', tree), 0);
  });

  test('counts children, grandchildren and below', () {
    // a -> b, c ; b -> d ; d -> e
    final tree = [
      _p('a'),
      _p('b', parents: ['a']),
      _p('c', parents: ['a']),
      _p('d', parents: ['b']),
      _p('e', parents: ['d']),
    ];

    expect(countDescendants('a', tree), 4);
    expect(countDescendants('b', tree), 2);
    expect(countDescendants('c', tree), 0);
    expect(countDescendants('e', tree), 0);
  });

  test('counts a person reachable by two paths once', () {
    // Both parents of 'child' descend from 'root', so a naive walk would
    // reach the child twice and report one person too many.
    final tree = [
      _p('root'),
      _p('mum', parents: ['root']),
      _p('dad', parents: ['root']),
      _p('child', parents: ['mum', 'dad']),
    ];

    expect(countDescendants('root', tree), 3);
  });

  test('terminates when a record is its own ancestor', () {
    // Nothing in the schema forbids this, and a plain recursion over it
    // runs until the stack gives out.
    final tree = [
      _p('a', parents: ['c']),
      _p('b', parents: ['a']),
      _p('c', parents: ['b']),
    ];

    expect(countDescendants('a', tree), 2);
  });

  test('ignores people in no relation to the person asked about', () {
    final tree = [
      _p('a'),
      _p('b', parents: ['a']),
      _p('stranger'),
      _p('strangers-child', parents: ['stranger']),
    ];

    expect(countDescendants('a', tree), 1);
  });
}
