import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:family_tree/data/models/person.dart';
import 'package:family_tree/core/logging.dart';

/// Local cache service for offline family tree data
class LocalCacheService {
  static const String _personsKey = 'cached_persons';
  static const String _lastUpdatedKey = 'cache_last_updated';
  
  static LocalCacheService? _instance;
  SharedPreferences? _prefs;
  
  LocalCacheService._();
  
  static LocalCacheService get instance {
    _instance ??= LocalCacheService._();
    return _instance!;
  }
  
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }
  
  /// Save persons to local cache
  Future<void> cachePersons(List<Person> persons) async {
    await init();
    final jsonList = persons.map((p) => p.toJson()).toList();
    await _prefs?.setString(_personsKey, jsonEncode(jsonList));
    await _prefs?.setString(_lastUpdatedKey, DateTime.now().toIso8601String());
  }
  
  /// Get cached persons
  Future<List<Person>> getCachedPersons() async {
    await init();
    final jsonString = _prefs?.getString(_personsKey);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }
    
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList
          .map((json) => Person.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      log('Could not read the offline copy of the tree', e);
      return [];
    }
  }
  
  /// Get last cache update time
  Future<DateTime?> getLastUpdated() async {
    await init();
    final timestamp = _prefs?.getString(_lastUpdatedKey);
    if (timestamp == null) return null;
    return DateTime.tryParse(timestamp);
  }
  
  /// Check if cache exists
  Future<bool> hasCache() async {
    await init();
    return _prefs?.containsKey(_personsKey) ?? false;
  }
  
  /// Clear the cache
  Future<void> clearCache() async {
    await init();
    await _prefs?.remove(_personsKey);
    await _prefs?.remove(_lastUpdatedKey);
  }
}
