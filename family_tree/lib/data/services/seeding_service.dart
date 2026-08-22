import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:family_tree/data/models/person.dart';
import 'package:family_tree/data/services/firebase_service.dart';
import 'package:uuid/uuid.dart';

class SeedingService {
  static const _uuid = Uuid();

  static Future<void> seedData(String familyTreeId) async {
    final firestore = FirebaseService.firestore;
    final batch = firestore.batch();
    final peopleRef = firestore.collection('persons');

    // Helper to create a person
    Person createPerson({
      required String firstName,
      required String lastName,
      required DateTime birthDate,
      List<String> parentIds = const [],
      List<String> childrenIds = const [],
    }) {
      return Person(
        id: _uuid.v4(),
        familyTreeId: familyTreeId,
        firstName: firstName,
        lastName: lastName,
        birthDate: birthDate,
        gender: 'male',
        bio: 'Generated family member',
        relationships: Relationships(
          parentIds: parentIds,
          childrenIds: childrenIds,
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    // Root: Mohammed
    final root = createPerson(
      firstName: 'Mohammed',
      lastName: 'Al-Family',
      birthDate: DateTime(1900, 1, 1),
    );
    
    // Track all people to batch write later
    final allPeople = <Person>[root];
    
    // Generation 1: 3 sons (reduced from 4)
    final gen1Count = 3;
    for (var i = 0; i < gen1Count; i++) {
      final son = createPerson(
        firstName: _getMaleName(i),
        lastName: 'Al-Family',
        birthDate: DateTime(1930 + i * 2, 1, 1),
        parentIds: [root.id],
      );
      
      // Update Root with child
      allPeople[0] = allPeople[0].copyWith(
        relationships: Relationships(
          parentIds: allPeople[0].relationships.parentIds,
          spouses: allPeople[0].relationships.spouses,
          childrenIds: [...allPeople[0].relationships.childrenIds, son.id],
        ),
      );
      
      allPeople.add(son);
      final sonIndex = allPeople.length - 1;

      // Generation 2: 4 sons for each Gen 1 son
      final gen2Count = 4;
      for (var j = 0; j < gen2Count; j++) {
        final grandson = createPerson(
          firstName: _getMaleName(j + 10),
          lastName: 'Al-Family',
          birthDate: DateTime(1960 + j * 2, 1, 1),
          parentIds: [son.id],
        );

        // Update Son with child
        allPeople[sonIndex] = allPeople[sonIndex].copyWith(
          relationships: Relationships(
            parentIds: allPeople[sonIndex].relationships.parentIds,
            spouses: allPeople[sonIndex].relationships.spouses,
            childrenIds: [...allPeople[sonIndex].relationships.childrenIds, grandson.id],
          ),
        );

        allPeople.add(grandson);
        final grandsonIndex = allPeople.length - 1;

        // Generation 3: 3 sons for each Gen 2 son
        final gen3Count = 3;
        for (var k = 0; k < gen3Count; k++) {
          final greatGrandson = createPerson(
            firstName: _getMaleName(k + 20),
            lastName: 'Al-Family',
            birthDate: DateTime(1990 + k * 2, 1, 1),
            parentIds: [grandson.id],
          );

          // Update Grandson with child
          allPeople[grandsonIndex] = allPeople[grandsonIndex].copyWith(
            relationships: Relationships(
              parentIds: allPeople[grandsonIndex].relationships.parentIds,
              spouses: allPeople[grandsonIndex].relationships.spouses,
              childrenIds: [...allPeople[grandsonIndex].relationships.childrenIds, greatGrandson.id],
            ),
          );

          allPeople.add(greatGrandson);
          final greatGrandsonIndex = allPeople.length - 1;

          // Generation 4: ~2 sons for each Gen 3 son (some have 1, most have 2)
          // This creates approximately 68 people in Gen 4
          final gen4Count = (k % 3 == 0) ? 1 : 2; // Every 3rd person has 1 child, others have 2
          for (var l = 0; l < gen4Count; l++) {
            final greatGreatGrandson = createPerson(
              firstName: _getMaleName(l + 30),
              lastName: 'Al-Family',
              birthDate: DateTime(2020 + l, 1, 1),
              parentIds: [greatGrandson.id],
            );

            // Update GreatGrandson with child
            allPeople[greatGrandsonIndex] = allPeople[greatGrandsonIndex].copyWith(
              relationships: Relationships(
                parentIds: allPeople[greatGrandsonIndex].relationships.parentIds,
                spouses: allPeople[greatGrandsonIndex].relationships.spouses,
                childrenIds: [...allPeople[greatGrandsonIndex].relationships.childrenIds, greatGreatGrandson.id],
              ),
            );

            allPeople.add(greatGreatGrandson);
          }
        }
      }
    }

    // Batch write (split if > 500, but here ~250 max)
    for (final person in allPeople) {
      batch.set(peopleRef.doc(person.id), person.toFirestore());
    }

    await batch.commit();
  }

  /// Delete a specified number of people from database, keeping root + first 2 generations
  static Future<void> deletePeople(String familyTreeId, int count) async {
    final firestore = FirebaseService.firestore;
    
    // Get all persons
    final snapshot = await firestore
        .collection('persons')
        .where('familyTreeId', isEqualTo: familyTreeId)
        .get();
    
    final allPeople = snapshot.docs.map((doc) => Person.fromFirestore(doc)).toList();
    
    // Find root
    final root = allPeople.firstWhere((p) => p.relationships.parentIds.isEmpty);
    
    // Find Gen 1 (direct children of root)
    final gen1Ids = allPeople
        .where((p) => p.relationships.parentIds.contains(root.id))
        .map((p) => p.id)
        .toSet();
    
    // Find Gen 2 (grandchildren of root)
    final gen2Ids = allPeople
        .where((p) => p.relationships.parentIds.any((pid) => gen1Ids.contains(pid)))
        .map((p) => p.id)
        .toSet();
    
    // People to keep: root + gen1 + gen2
    final keepIds = {root.id, ...gen1Ids, ...gen2Ids};
    
    // People we can delete: everyone else
    final deletablePeople = allPeople
        .where((p) => !keepIds.contains(p.id))
        .toList();
    
    // Delete the specified count (or all deletable if count is higher)
    final toDelete = deletablePeople.take(count).toList();
    
    // Delete in batches of 500
    for (var i = 0; i < toDelete.length; i += 500) {
      final batch = firestore.batch();
      final end = (i + 500 < toDelete.length) ? i + 500 : toDelete.length;
      
      for (var j = i; j < end; j++) {
        final personRef = firestore.collection('persons').doc(toDelete[j].id);
        batch.delete(personRef);
      }
      
      await batch.commit();
    }
  }

  static String _getMaleName(int index) {
    const names = [
      'Ahmed', 'Ali', 'Omar', 'Hassan', 'Hussein', 'Khalid', 'Youssef', 'Ibrahim',
      'Abdullah', 'Abdulrahman', 'Fahad', 'Saud', 'Salman', 'Faisal', 'Hamza',
      'Mustafa', 'Mahmoud', 'Tariq', 'Zaid', 'Bilal', 'Anas', 'Amr', 'Sami',
      'Rami', 'Fadi', 'Majed', 'Nasser', 'Salem', 'Saeed', 'Rashid', 'Jamal',
      'Kamal', 'Adel', 'Hisham', 'Walid', 'Yasser', 'Ziad', 'Bassam', 'Ghassan',
      'Mazen', 'Nawaf', 'Talal', 'Turki', 'Bandar', 'Sultan', 'Naif', 'Mishal'
    ];
    return names[index % names.length];
  }
}
