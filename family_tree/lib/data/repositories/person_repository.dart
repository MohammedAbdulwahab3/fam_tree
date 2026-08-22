import 'dart:convert';
import 'package:family_tree/data/models/person.dart';
import 'package:family_tree/data/services/api_service.dart';
import 'package:family_tree/data/services/local_cache_service.dart';

/// Repository for Person CRUD operations using Go backend
class PersonRepository {
  final ApiService _api = ApiService();
  final LocalCacheService _cache = LocalCacheService.instance;

  /// How often the tree checks for changes.
  ///
  /// This was three seconds. A family tree changes a few times a year, and each
  /// poll re-downloaded every person, re-parsed them, rewrote the whole list to
  /// disk, and handed the canvas a new list object that made it recompute the
  /// layout of the entire tree — twenty times a minute, on a phone.
  static const Duration pollInterval = Duration(seconds: 30);

  /// The last response we saw, kept so an unchanged poll can hand back the very
  /// same list object. Widgets compare by identity, so returning the same
  /// instance is what stops a no-op poll from triggering a relayout.
  static String? _lastEtag;
  static List<Person>? _lastPersons;

  /// Which tree [_lastPersons] was filtered for. The cached list is post-filter,
  /// so reusing it for a different tree would show the wrong family.
  static String? _lastTreeId;

  /// Get all persons. Emits only when something has actually changed —
  /// unchanged polls re-emit the identical list.
  Stream<List<Person>> watchFamilyMembers(String familyTreeId) async* {
    while (true) {
      try {
        yield await getFamilyMembers(familyTreeId);
      } catch (e) {
        print('Error in watchFamilyMembers: $e');
        // Hold the last known tree rather than blanking the screen; a dropped
        // connection should not look like a family with nobody in it.
        yield (_lastTreeId == familyTreeId ? _lastPersons : null) ??
            await _loadFromCache(familyTreeId);
      }

      await Future.delayed(pollInterval);
    }
  }

  /// Drop the cached response so the next read goes to the server.
  ///
  /// Call this after a write: the ETag we hold is for the version before the
  /// change, and we want the new one immediately rather than at the next poll.
  static void invalidate() {
    _lastEtag = null;
    _lastPersons = null;
    _lastTreeId = null;
  }

  /// Get all persons in a family tree (with offline cache fallback)
  Future<List<Person>> getFamilyMembers(String familyTreeId) async {
    try {
      // Ask the server whether anything changed since the version we hold. If
      // not it answers 304 with no body, and we reuse what we already parsed.
      final canReuse = _lastTreeId == familyTreeId && _lastPersons != null;
      final conditional = <String, String>{
        if (canReuse && _lastEtag != null) 'If-None-Match': _lastEtag!,
      };

      var response = await _api.get('/api/persons', headers: conditional);

      // If unauthorized, try public endpoint
      if (response.statusCode == 401) {
        response = await _api.get(
          '/public/persons',
          includeAuth: false,
          headers: conditional,
        );
      }

      if (response.statusCode == 304 && canReuse) {
        return _lastPersons!;
      }

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final persons = data
            .map((json) => Person.fromJson(json as Map<String, dynamic>))
            .where((p) => p.familyTreeId == familyTreeId)
            .toList(growable: false);

        _lastEtag = response.headers['etag'];
        _lastPersons = persons;
        _lastTreeId = familyTreeId;

        // Cache for offline access. Only on a real change — this writes the
        // whole list to disk, which is not something to do on a timer.
        await _cache.cachePersons(persons);

        return persons;
      }
      print('API response status: ${response.statusCode}');

      // API failed, try to load from cache
      return (canReuse ? _lastPersons : null) ?? await _loadFromCache(familyTreeId);
    } catch (e) {
      print('Error fetching family members: $e');
      // Network error - fall back to what we have
      return (_lastTreeId == familyTreeId ? _lastPersons : null) ??
          await _loadFromCache(familyTreeId);
    }
  }
  
  /// Load persons from local cache
  Future<List<Person>> _loadFromCache(String familyTreeId) async {
    try {
      final cachedPersons = await _cache.getCachedPersons();
      if (cachedPersons.isNotEmpty) {
        print('PersonRepository: Loaded ${cachedPersons.length} persons from cache');
        return cachedPersons.where((p) => p.familyTreeId == familyTreeId).toList();
      }
    } catch (e) {
      print('Error loading from cache: $e');
    }
    return [];
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

  /// Add a new person.
  ///
  /// Creating people is an admin action, so this posts to the admin route. It
  /// used to post to `/api/persons`, which the backend does not serve, so the
  /// call always 404'd.
  Future<String> addPerson(Person person) async {
    final response = await _api.post(
      '/api/admin/persons',
      body: person.toJson(),
    );
    ApiService.ensureOk(response, whileDoing: 'adding the person');
    invalidate();

    final data = jsonDecode(response.body);
    return data['id'];
  }

  /// Update a person. The backend allows this for the person's own linked
  /// account, and for admins on anyone.
  Future<void> updatePerson(Person person) async {
    final response = await _api.put(
      '/api/persons/${person.id}',
      body: person.toJson(),
    );
    ApiService.ensureOk(response, whileDoing: 'saving the profile');
    invalidate();
  }

  /// Delete a person. Admin-only on the backend, hence the admin route.
  Future<void> deletePerson(String personId) async {
    final response = await _api.delete('/api/admin/persons/$personId');
    ApiService.ensureOk(response, whileDoing: 'removing the person');
    invalidate();
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
