import 'dart:convert';
import 'package:family_tree/data/models/person.dart';
import 'package:family_tree/data/services/api_service.dart';

/// Repository for Person CRUD operations using Go backend
class PersonRepository {
  final ApiService _api = ApiService();

  /// Get all persons (watches not supported with REST, use polling if needed)
  Stream<List<Person>> watchFamilyMembers(String familyTreeId) async* {
    while (true) {
      try {
        final persons = await getFamilyMembers(familyTreeId);
        yield persons;
      } catch (e) {
        print('Error in watchFamilyMembers: $e');
        yield [];
      }
      
      // Poll every 3 seconds for updates
      await Future.delayed(const Duration(seconds: 3));
    }
  }

  /// Get all persons in a family tree
  Future<List<Person>> getFamilyMembers(String familyTreeId) async {
    try {
      // Try authenticated endpoint first, fall back to public
      var response = await _api.get('/api/persons');
      
      // If unauthorized, try public endpoint
      if (response.statusCode == 401) {
        response = await _api.get('/public/persons', includeAuth: false);
      }
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data
            .map((json) => Person.fromJson(json as Map<String, dynamic>))
            .where((p) => p.familyTreeId == familyTreeId)
            .toList();
      }
      print('API response status: ${response.statusCode}');
      return [];
    } catch (e) {
      print('Error fetching family members: $e');
      return [];
    }
  }

  /// Get a single person
  Future<Person?> getPerson(String personId) async {
    try {
      final response = await _api.get('/api/persons/$personId');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Person.fromJson(data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error fetching person: $e');
      return null;
    }
  }

  /// Add a new person
  Future<String> addPerson(Person person) async {
    try {
      final json = person.toJson();
      final response = await _api.post(
        '/api/persons',
        body: json,
      );
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['id'];
      }
      throw Exception('Failed to create person');
    } catch (e) {
      print('Error adding person: $e');
      rethrow;
    }
  }

  /// Update a person
  Future<void> updatePerson(Person person) async {
    try {
      final json = person.toJson();
      await _api.put(
        '/api/persons/${person.id}',
        body: json,
      );
    } catch (e) {
      print('Error updating person: $e');
      rethrow;
    }
  }

  /// Delete a person
  Future<void> deletePerson(String personId) async {
    try {
      await _api.delete('/api/persons/$personId');
    } catch (e) {
      print('Error deleting person: $e');
      rethrow;
    }
  }

  /// Search persons by name
  Future<List<Person>> searchPersons(String familyTreeId, String query) async {
    try {
      final allPersons = await getFamilyMembers(familyTreeId);
      final lowerQuery = query.toLowerCase();
      return allPersons.where((person) {
        final fullName = '${person.firstName} ${person.lastName}'.toLowerCase();
        return fullName.contains(lowerQuery);
      }).toList();
    } catch (e) {
      print('Error searching persons: $e');
      return [];
    }
  }

  /// Get descendants of a person
  Future<List<Person>> getDescendants(String personId) async {
    try {
      final person = await getPerson(personId);
      if (person == null) return [];
      
      final allPersons = await getFamilyMembers(person.familyTreeId);
      final descendants = <Person>[];
      
      void findDescendants(String currentPersonId) {
        final currentPerson = allPersons.firstWhere(
          (p) => p.id == currentPersonId,
          orElse: () => allPersons.first,
        );
        
        for (var childId in currentPerson.relationships.childrenIds) {
          final child = allPersons.firstWhere(
            (p) => p.id == childId,
            orElse: () => allPersons.first,
          );
          if (child.id.isNotEmpty) {
            descendants.add(child);
            findDescendants(child.id);
          }
        }
      }
      
      findDescendants(personId);
      return descendants;
    } catch (e) {
      print('Error getting descendants: $e');
      return [];
    }
  }

  /// Find person by auth user ID
  Future<Person?> getPersonByAuthUserId(String authUserId) async {
    try {
      final response = await _api.get('/api/persons');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final persons = data.map((json) => Person.fromJson(json as Map<String, dynamic>)).toList();
        try {
          return persons.firstWhere((p) => p.authUserId == authUserId);
        } catch (e) {
          return null;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Link person to user
  Future<void> linkPersonToUser(String personId, String authUserId) async {
    try {
      final person = await getPerson(personId);
      if (person != null) {
        final updated = person.copyWith(authUserId: authUserId);
        await updatePerson(updated);
      }
    } catch (e) {
      print('Error linking person to user: $e');
      rethrow;
    }
  }

  /// Check if user can edit person
  Future<bool> canUserEdit(String personId, String authUserId) async {
    try {
      final person = await getPerson(personId);
      return person?.authUserId == authUserId;
    } catch (e) {
      return false;
    }
  }


  /// Get ancestors of a person (parents, grandparents, etc.)
  Future<List<Person>> getAncestors(String personId) async {
    try {
      final person = await getPerson(personId);
      if (person == null) return [];
      
      final allPersons = await getFamilyMembers(person.familyTreeId);
      final ancestors = <Person>[];
      
      void findAncestors(String currentPersonId) {
        final currentPerson = allPersons.firstWhere(
          (p) => p.id == currentPersonId,
          orElse: () => allPersons.first,
        );
        
        for (var parentId in currentPerson.relationships.parentIds) {
          final parent = allPersons.firstWhere(
            (p) => p.id == parentId,
            orElse: () => allPersons.first,
          );
          if (parent.id.isNotEmpty && !ancestors.any((a) => a.id == parent.id)) {
            ancestors.add(parent);
            findAncestors(parent.id);
          }
        }
      }
      
      findAncestors(personId);
      return ancestors;
    } catch (e) {
      print('Error getting ancestors: $e');
      return [];
    }
  }
}
