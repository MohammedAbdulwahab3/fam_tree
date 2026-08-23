import 'dart:convert';

import 'package:family_tree/core/logging.dart';
import 'package:family_tree/data/models/person.dart';
import 'package:family_tree/data/services/api_service.dart';
import 'package:family_tree/data/services/local_cache_service.dart';

/// Reads and writes the family tree.
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
      } catch (error, stack) {
        log('Could not refresh the family tree', error, stack);
        // Hold the last known tree rather than blanking the screen; a dropped
        // connection should not look like a family with nobody in it.
        yield (_lastTreeId == familyTreeId ? _lastPersons : null) ??
            await _loadFromCache(familyTreeId);
      }

      await Future<void>.delayed(pollInterval);
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

  /// Get all persons in a family tree, falling back to the offline cache.
  Future<List<Person>> getFamilyMembers(String familyTreeId) async {
    try {
      // Ask the server whether anything changed since the version we hold. If
      // not it answers 304 with no body, and we reuse what we already parsed.
      final canReuse = _lastTreeId == familyTreeId && _lastPersons != null;
      final conditional = <String, String>{
        if (canReuse && _lastEtag != null) 'If-None-Match': _lastEtag!,
      };

      final response = await _api.get('/api/persons', headers: conditional);

      if (response.statusCode == 304 && canReuse) {
        return _lastPersons!;
      }

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
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

      // A refused or failed read falls back to what we already have rather
      // than showing an empty tree.
      log('Loading the tree returned ${response.statusCode}');
      return (canReuse ? _lastPersons : null) ??
          await _loadFromCache(familyTreeId);
    } catch (error, stack) {
      log('Could not load the family tree', error, stack);
      return (_lastTreeId == familyTreeId ? _lastPersons : null) ??
          await _loadFromCache(familyTreeId);
    }
  }

  Future<List<Person>> _loadFromCache(String familyTreeId) async {
    try {
      final cached = await _cache.getCachedPersons();
      return cached.where((p) => p.familyTreeId == familyTreeId).toList();
    } catch (error, stack) {
      log('Could not read the offline copy of the tree', error, stack);
      return const [];
    }
  }

  /// Get a single person.
  Future<Person?> getPerson(String personId) async {
    try {
      final response = await _api.get('/api/persons/$personId');
      if (response.statusCode == 200) {
        return Person.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      }
      return null;
    } catch (error, stack) {
      log('Could not load person $personId', error, stack);
      return null;
    }
  }

  /// Add a new person. Creating people is an admin action, so this posts to the
  /// admin route.
  ///
  /// Only the new person's parents are sent. The server derives the other
  /// direction, which is what removed the old two-request dance — create the
  /// child, then update the parent to list them — where a failure in between
  /// left the tree inconsistent.
  Future<String> addPerson(Person person) async {
    final response = await _api.post(
      '/api/admin/persons',
      body: person.toJson(),
    );
    ApiService.ensureOk(response, whileDoing: 'adding the person');
    invalidate();

    return (jsonDecode(response.body) as Map<String, dynamic>)['id'] as String;
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

  /// Delete a person, and optionally everyone below them.
  ///
  /// The server does the whole subtree in one transaction. The app used to
  /// issue one request per descendant, so a failure partway left half a family
  /// gone with no way to tell which half.
  Future<void> deletePerson(String personId, {bool cascade = false}) async {
    final response = await _api.delete(
      '/api/admin/persons/$personId${cascade ? '?cascade=true' : ''}',
    );
    ApiService.ensureOk(response, whileDoing: 'removing the person');
    invalidate();
  }

  /// Search persons by name, across every locale a name is recorded in.
  Future<List<Person>> searchPersons(String familyTreeId, String query) async {
    final all = await getFamilyMembers(familyTreeId);
    return all.where((person) => person.matchesNameQuery(query)).toList();
  }

  /// Everyone below [personId] in the tree, nearest first.
  ///
  /// Iterative and visited-guarded. The recursive version had neither: a child
  /// id that no longer resolved fell back to the first person in the list, and
  /// a cycle — which the admin screen can produce — recursed until the stack
  /// ran out.
  Future<List<Person>> getDescendants(String personId) async {
    final person = await getPerson(personId);
    if (person == null) return const [];

    final all = await getFamilyMembers(person.familyTreeId);
    return _walk(
      all,
      from: personId,
      step: (index, current) => index.childrenOf(current),
    );
  }

  /// Everyone above [personId] in the tree, nearest first.
  Future<List<Person>> getAncestors(String personId) async {
    final person = await getPerson(personId);
    if (person == null) return const [];

    final all = await getFamilyMembers(person.familyTreeId);
    return _walk(
      all,
      from: personId,
      step: (index, current) => current.relationships.parentIds
          .map(index.byId)
          .whereType<Person>()
          .toList(),
    );
  }

  /// Find the person record linked to an account, if any.
  Future<Person?> getPersonByAuthUserId(
    String familyTreeId,
    String authUserId,
  ) async {
    final all = await getFamilyMembers(familyTreeId);
    for (final person in all) {
      if (person.authUserId == authUserId) return person;
    }
    return null;
  }

  /// Breadth-first walk out from [from], excluding the starting person.
  static List<Person> _walk(
    List<Person> all, {
    required String from,
    required List<Person> Function(FamilyIndex index, Person current) step,
  }) {
    final index = FamilyIndex(all);
    final start = index.byId(from);
    if (start == null) return const [];

    final found = <Person>[];
    final seen = <String>{from};
    final queue = <Person>[start];

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      for (final next in step(index, current)) {
        if (seen.add(next.id)) {
          found.add(next);
          queue.add(next);
        }
      }
    }

    return found;
  }
}

/// An id-keyed view of a family, built once and reused.
///
/// Every traversal in the app used to scan the whole list to resolve one id,
/// which made walking the tree quadratic, and used `firstWhere(orElse: () =>
/// persons.first)` when an id did not resolve — silently substituting an
/// unrelated person for a missing one.
class FamilyIndex {
  FamilyIndex(List<Person> people)
      : _byId = {for (final p in people) p.id: p},
        _childrenOf = _buildChildren(people);

  final Map<String, Person> _byId;
  final Map<String, List<Person>> _childrenOf;

  static Map<String, List<Person>> _buildChildren(List<Person> people) {
    final children = <String, List<Person>>{};
    for (final person in people) {
      for (final parentId in person.relationships.parentIds) {
        (children[parentId] ??= <Person>[]).add(person);
      }
    }
    return children;
  }

  /// The person with this id, or null. Never a stand-in.
  Person? byId(String id) => _byId[id];

  /// This person's children, in display order.
  List<Person> childrenOf(Person person) =>
      _childrenOf[person.id] ?? const <Person>[];

  /// Everyone whose parents are all outside this list — the tops of the tree.
  ///
  /// Computed in one pass. The old form asked, for every person, whether any of
  /// their parent ids matched any person in the list, which is quadratic and
  /// was written out separately in four places.
  List<Person> roots(List<Person> people) {
    final roots = people
        .where((p) => !p.relationships.parentIds.any(_byId.containsKey))
        .toList();
    // A tree where everybody has a parent is a cycle. Pick a starting point so
    // the canvas draws something rather than nothing.
    if (roots.isEmpty && people.isNotEmpty) roots.add(people.first);
    return roots;
  }
}
