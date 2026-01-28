import 'dart:convert';
import 'package:family_tree/data/models/person.dart';
import 'package:family_tree/data/models/post.dart';
import 'package:family_tree/data/models/appointment.dart';
import 'package:family_tree/data/models/app_user.dart';
import 'package:family_tree/data/services/api_service.dart';

/// Repository for admin-only operations
/// Uses /api/admin/* endpoints that require admin role
class AdminRepository {
  final ApiService _api = ApiService();

  // ===== PERSON MANAGEMENT =====

  /// Add a new person (admin only)
  Future<String> addPerson(Person person) async {
    try {
      final response = await _api.post(
        '/api/admin/persons',
        body: person.toJson(),
      );
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['id'];
      }
      throw Exception('Failed to create person: ${response.body}');
    } catch (e) {
      print('Error adding person: $e');
      rethrow;
    }
  }

  /// Update a person (admin only)
  Future<void> updatePerson(Person person) async {
    try {
      await _api.put(
        '/api/admin/persons/${person.id}',
        body: person.toJson(),
      );
    } catch (e) {
      print('Error updating person: $e');
      rethrow;
    }
  }

  /// Delete a person (admin only)
  Future<void> deletePerson(String personId) async {
    try {
      await _api.delete('/api/admin/persons/$personId');
    } catch (e) {
      print('Error deleting person: $e');
      rethrow;
    }
  }

  // ===== POST MANAGEMENT =====

  /// Create a new post (admin only)
  Future<String> createPost(Post post) async {
    try {
      final response = await _api.post(
        '/api/admin/posts',
        body: post.toJson(),
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['id'] ?? '';
      }
      throw Exception('Failed to create post: ${response.body}');
    } catch (e) {
      print('Error creating post: $e');
      rethrow;
    }
  }

  /// Delete a post (admin only)
  Future<void> deletePost(String postId) async {
    try {
      await _api.delete('/api/admin/posts/$postId');
    } catch (e) {
      print('Error deleting post: $e');
      rethrow;
    }
  }

  /// Update a post (admin only)
  Future<void> updatePost(Post post) async {
    try {
      await _api.put(
        '/api/admin/posts/${post.id}',
        body: post.toJson(),
      );
    } catch (e) {
      print('Error updating post: $e');
      rethrow;
    }
  }

  // ===== EVENT MANAGEMENT =====

  /// Create a new event (admin only)
  Future<String> createEvent(Appointment event) async {
    try {
      final response = await _api.post(
        '/api/admin/events',
        body: event.toJson(),
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['id'] ?? '';
      }
      throw Exception('Failed to create event: ${response.body}');
    } catch (e) {
      print('Error creating event: $e');
      rethrow;
    }
  }

  /// Update an event (admin only)
  Future<void> updateEvent(Appointment event) async {
    try {
      await _api.put(
        '/api/admin/events/${event.id}',
        body: event.toJson(),
      );
    } catch (e) {
      print('Error updating event: $e');
      rethrow;
    }
  }

  /// Delete an event (admin only)
  Future<void> deleteEvent(String eventId) async {
    try {
      await _api.delete('/api/admin/events/$eventId');
    } catch (e) {
      print('Error deleting event: $e');
      rethrow;
    }
  }

  // ===== USER MANAGEMENT =====

  /// Get all users (admin only)
  Future<List<AppUser>> getUsers() async {
    try {
      final response = await _api.get('/api/admin/users');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => AppUser.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error getting users: $e');
      return [];
    }
  }

  /// Update user role (admin only)
  Future<void> updateUserRole(String userId, String role) async {
    try {
      await _api.put(
        '/api/admin/users/$userId/role',
        body: {'role': role},
      );
    } catch (e) {
      print('Error updating user role: $e');
      rethrow;
    }
  }

  /// Delete a user (admin only)
  Future<void> deleteUser(String userId) async {
    try {
      await _api.delete('/api/admin/users/$userId');
    } catch (e) {
      print('Error deleting user: $e');
      rethrow;
    }
  }

  /// Ban a user (admin only)
  Future<void> banUser(String userId, {String? reason}) async {
    try {
      await _api.put(
        '/api/admin/users/$userId/ban',
        body: {'banned': true, 'reason': reason ?? ''},
      );
    } catch (e) {
      print('Error banning user: $e');
      rethrow;
    }
  }

  /// Unban a user (admin only)
  Future<void> unbanUser(String userId) async {
    try {
      await _api.put(
        '/api/admin/users/$userId/ban',
        body: {'banned': false},
      );
    } catch (e) {
      print('Error unbanning user: $e');
      rethrow;
    }
  }

  // ===== ANNOUNCEMENTS =====

  /// Send announcement to all users
  Future<void> sendAnnouncement({
    required String title,
    required String message,
  }) async {
    try {
      await _api.post(
        '/api/admin/announcements',
        body: {
          'title': title,
          'message': message,
        },
      );
    } catch (e) {
      print('Error sending announcement: $e');
      rethrow;
    }
  }

  // ===== EXPORT DATA =====

  /// Export family tree data as JSON
  Future<Map<String, dynamic>> exportFamilyTreeData(String familyTreeId) async {
    try {
      final response = await _api.get('/api/admin/export/$familyTreeId');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Failed to export data: ${response.body}');
    } catch (e) {
      print('Error exporting data: $e');
      rethrow;
    }
  }

  // ===== AUDIT LOGS =====

  /// Get audit logs
  Future<List<AuditLog>> getAuditLogs({int limit = 50}) async {
    try {
      final response = await _api.get('/api/admin/audit-logs?limit=$limit');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => AuditLog.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error getting audit logs: $e');
      return [];
    }
  }
}

/// Model for audit log entries
class AuditLog {
  final String id;
  final String userId;
  final String userName;
  final String action;
  final String entityType;
  final String entityId;
  final Map<String, dynamic>? details;
  final DateTime createdAt;

  AuditLog({
    required this.id,
    required this.userId,
    required this.userName,
    required this.action,
    required this.entityType,
    required this.entityId,
    this.details,
    required this.createdAt,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      userName: json['user_name'] ?? 'Unknown',
      action: json['action'] ?? '',
      entityType: json['entity_type'] ?? '',
      entityId: json['entity_id'] ?? '',
      details: json['details'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}
