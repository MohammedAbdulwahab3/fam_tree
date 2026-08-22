import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:family_tree/data/models/person.dart';
import 'package:family_tree/data/services/firebase_service.dart';

/// Repository for Person CRUD operations and real-time updates
class PersonRepository {
  final FirebaseFirestore _firestore = FirebaseService.firestore;

  /// Watch all persons in a family tree
  Stream<List<Person>> watchFamilyMembers(String familyTreeId) {
    return _firestore
        .collection('persons')
        .where('familyTreeId', isEqualTo: familyTreeId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Person.fromFirestore(doc)).toList());
  }

  /// Get a single person
  Future<Person?> getPerson(String personId) async {
    final doc = await _firestore.collection('persons').doc(personId).get();
    if (!doc.exists) return null;
    return Person.fromFirestore(doc);
  }

  /// Add a new person
  Future<String> addPerson(Person person) async {
    final docRef = await _firestore.collection('persons').add(
          person.toFirestore(),
        );
    return docRef.id;
  }

  /// Update a person
  Future<void> updatePerson(Person person) async {
    await _firestore
        .collection('persons')
        .doc(person.id)
        .update(person.toFirestore());
  }

  /// Delete a person
  Future<void> deletePerson(String personId) async {
    await _firestore.collection('persons').doc(personId).delete();
  }

  /// Search persons by name
  Future<List<Person>> searchPersons(String familyTreeId, String query) async {
    final snapshot = await _firestore
        .collection('persons')
        .where('familyTreeId', isEqualTo: familyTreeId)
        .get();

    final persons = snapshot.docs
        .map((doc) => Person.fromFirestore(doc))
        .where((person) =>
            person.fullName.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return persons;
  }

  /// Get all ancestors of a person
  Future<List<Person>> getAncestors(String personId) async {
    final person = await getPerson(personId);
    if (person == null) return [];

    final ancestors = <Person>[];
    final queue = [...person.relationships.parentIds];
    final visited = <String>{};

    while (queue.isNotEmpty) {
      final id = queue.removeAt(0);
      if (visited.contains(id)) continue;
      visited.add(id);

      final ancestor = await getPerson(id);
      if (ancestor != null) {
        ancestors.add(ancestor);
        queue.addAll(ancestor.relationships.parentIds);
      }
    }

    return ancestors;
  }

  /// Get all descendants of a person
  Future<List<Person>> getDescendants(String personId) async {
    final person = await getPerson(personId);
    if (person == null) return [];

    final descendants = <Person>[];
    final queue = [...person.relationships.childrenIds];
    final visited = <String>{};

    while (queue.isNotEmpty) {
      final id = queue.removeAt(0);
      if (visited.contains(id)) continue;
      visited.add(id);

      final descendant = await getPerson(id);
      if (descendant != null) {
        descendants.add(descendant);
        queue.addAll(descendant.relationships.childrenIds);
      }
    }

    return descendants;
  }

  /// Get person by Firebase Auth user ID
  Future<Person?> getPersonByAuthUserId(String authUserId) async {
    final snapshot = await _firestore
        .collection('persons')
        .where('authUserId', isEqualTo: authUserId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return Person.fromFirestore(snapshot.docs.first);
  }

  /// Link a person to a Firebase Auth user
  Future<void> linkPersonToUser(String personId, String authUserId) async {
    await _firestore.collection('persons').doc(personId).update({
      'authUserId': authUserId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Check if a user can edit a person (only their own record)
  bool canUserEdit(Person person, String authUserId) {
    return person.authUserId == authUserId;
  }

  /// Get user's subtree (themselves + all descendants)
  Future<List<Person>> getUserSubtree(String authUserId) async {
    final userPerson = await getPersonByAuthUserId(authUserId);
    if (userPerson == null) return [];

    final descendants = await getDescendants(userPerson.id);
    return [userPerson, ...descendants];
  }
}
