import 'package:family_tree/data/models/person.dart';

class DummyDataService {
  static List<Person> getDummyFamily() {
    final now = DateTime.now();
    
    // Generation 1
    final grandpa = Person(
      id: 'grandpa-1',
      familyTreeId: 'dummy-tree',
      firstName: 'Arthur',
      lastName: 'Sterling',
      birthDate: DateTime(1950, 3, 15),
      gender: 'male',
      bio: 'A wise and gentle soul who spent his life building homes and hearts.',
      relationships: Relationships(
        childrenIds: ['dad-1', 'aunt-1', 'uncle-1'],
      ),
      createdAt: now,
      updatedAt: now,
    );

    // Generation 2 (Children of Grandpa)
    final dad = Person(
      id: 'dad-1',
      familyTreeId: 'dummy-tree',
      firstName: 'Michael',
      lastName: 'Sterling',
      birthDate: DateTime(1978, 4, 10),
      gender: 'male',
      bio: 'A dedicated architect who designs sustainable buildings.',
      relationships: Relationships(
        parentIds: ['grandpa-1'], // Only Grandpa
        childrenIds: ['me-1', 'sibling-1'],
      ),
      createdAt: now,
      updatedAt: now,
    );

    final aunt = Person(
      id: 'aunt-1',
      familyTreeId: 'dummy-tree',
      firstName: 'Emily',
      lastName: 'Chen',
      birthDate: DateTime(1975, 9, 5),
      gender: 'female',
      bio: 'A talented artist whose paintings capture everyday beauty.',
      relationships: Relationships(
        parentIds: ['grandpa-1'], // Only Grandpa
        childrenIds: ['cousin-1', 'cousin-2'],
      ),
      createdAt: now,
      updatedAt: now,
    );

    final uncle = Person(
      id: 'uncle-1',
      familyTreeId: 'dummy-tree',
      firstName: 'David',
      lastName: 'Sterling',
      birthDate: DateTime(1982, 2, 18),
      gender: 'male',
      bio: 'An innovative software engineer building the future.',
      relationships: Relationships(
        parentIds: ['grandpa-1'], // Only Grandpa
      ),
      createdAt: now,
      updatedAt: now,
    );

    // Generation 3 (Grandchildren)
    // Children of Dad
    final me = Person(
      id: 'me-1',
      familyTreeId: 'dummy-tree',
      firstName: 'Alex',
      lastName: 'Sterling',
      birthDate: DateTime(2006, 6, 25),
      gender: 'non-binary',
      bio: 'A creative soul exploring technology and art.',
      relationships: Relationships(
        parentIds: ['dad-1'], // Only Dad
        siblingIds: ['sibling-1'],
      ),
      createdAt: now,
      updatedAt: now,
    );

    final sibling = Person(
      id: 'sibling-1',
      familyTreeId: 'dummy-tree',
      firstName: 'Jamie',
      lastName: 'Sterling',
      birthDate: DateTime(2010, 3, 12),
      gender: 'female',
      bio: 'A bright student who loves science.',
      relationships: Relationships(
        parentIds: ['dad-1'], // Only Dad
        siblingIds: ['me-1'],
      ),
      createdAt: now,
      updatedAt: now,
    );

    // Children of Aunt
    final cousin1 = Person(
      id: 'cousin-1',
      familyTreeId: 'dummy-tree',
      firstName: 'Maya',
      lastName: 'Chen',
      birthDate: DateTime(2008, 7, 8),
      gender: 'female',
      bio: 'An aspiring musician who plays violin.',
      relationships: Relationships(
        parentIds: ['aunt-1'], // Only Aunt
        siblingIds: ['cousin-2'],
      ),
      createdAt: now,
      updatedAt: now,
    );

    final cousin2 = Person(
      id: 'cousin-2',
      familyTreeId: 'dummy-tree',
      firstName: 'Ryan',
      lastName: 'Chen',
      birthDate: DateTime(2012, 11, 30),
      gender: 'male',
      bio: 'A young athlete with big dreams.',
      relationships: Relationships(
        parentIds: ['aunt-1'], // Only Aunt
        siblingIds: ['cousin-1'],
      ),
      createdAt: now,
      updatedAt: now,
    );

    // Removed Grandma and Mom to ensure single-parent lineage
    return [grandpa, dad, aunt, uncle, me, sibling, cousin1, cousin2];
  }
}
