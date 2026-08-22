import 'dart:convert';
import 'package:family_tree/data/models/person.dart';
import 'package:family_tree/data/models/post.dart';
import 'package:family_tree/data/models/appointment.dart';
import 'package:family_tree/data/models/app_user.dart';
import 'package:family_tree/data/repositories/person_repository.dart';
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
      ApiService.ensureOk(response, whileDoing: 'adding the person');
      PersonRepository.invalidate();
      return jsonDecode(response.body)['id'];
    } catch (e) {
      print('Error adding person: $e');
      rethrow;
    }
  }

  /// Update a person (admin only)
  Future<void> updatePerson(Person person) async {
    try {
      final response = await _api.put(
        '/api/admin/persons/${person.id}',
        body: person.toJson(),
      );
      ApiService.ensureOk(response, whileDoing: 'saving the person');
      PersonRepository.invalidate();
    } catch (e) {
      print('Error updating person: $e');
      rethrow;
    }
  }

  /// Delete a person (admin only)
  Future<void> deletePerson(String personId) async {
    try {
      final response = await _api.delete('/api/admin/persons/$personId');
      ApiService.ensureOk(response, whileDoing: 'removing the person');
      PersonRepository.invalidate();
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
      ApiService.ensureOk(response, whileDoing: 'publishing the post');
      return jsonDecode(response.body)['id'] ?? '';
    } catch (e) {
      print('Error creating post: $e');
      rethrow;
    }
  }

  /// Delete a post (admin only)
  Future<void> deletePost(String postId) async {
    try {
      final response = await _api.delete('/api/admin/posts/$postId');
      ApiService.ensureOk(response, whileDoing: 'deleting the post');
    } catch (e) {
      print('Error deleting post: $e');
      rethrow;
    }
  }

  /// Update a post (admin only)
  Future<void> updatePost(Post post) async {
    try {
      final response = await _api.put(
        '/api/admin/posts/${post.id}',
        body: post.toJson(),
      );
      ApiService.ensureOk(response, whileDoing: 'updating the post');
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
      ApiService.ensureOk(response, whileDoing: 'creating the event');
      return jsonDecode(response.body)['id'] ?? '';
    } catch (e) {
      print('Error creating event: $e');
      rethrow;
    }
  }

  /// Update an event (admin only)
  Future<void> updateEvent(Appointment event) async {
    try {
      final response = await _api.put(
        '/api/admin/events/${event.id}',
        body: event.toJson(),
      );
      ApiService.ensureOk(response, whileDoing: 'updating the event');
    } catch (e) {
      print('Error updating event: $e');
      rethrow;
    }
  }

  /// Delete an event (admin only)
  Future<void> deleteEvent(String eventId) async {
    try {
      final response = await _api.delete('/api/admin/events/$eventId');
      ApiService.ensureOk(response, whileDoing: 'cancelling the event');
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
      final response = await _api.put(
        '/api/admin/users/$userId/role',
        body: {'role': role},
      );
      ApiService.ensureOk(response, whileDoing: 'changing the role');
    } catch (e) {
      print('Error updating user role: $e');
      rethrow;
    }
  }

  /// Delete a user (admin only)
  Future<void> deleteUser(String userId) async {
    try {
      final response = await _api.delete('/api/admin/users/$userId');
      ApiService.ensureOk(response, whileDoing: 'deleting the account');
    } catch (e) {
      print('Error deleting user: $e');
      rethrow;
    }
  }

  /// Ban a user (admin only)
  Future<void> banUser(String userId, {String? reason}) async {
    try {
      final response = await _api.put(
        '/api/admin/users/$userId/ban',
        body: {'banned': true, 'reason': reason ?? ''},
      );
      ApiService.ensureOk(response, whileDoing: 'suspending the account');
    } catch (e) {
      print('Error banning user: $e');
      rethrow;
    }
  }

  /// Unban a user (admin only)
  Future<void> unbanUser(String userId) async {
    try {
      final response = await _api.put(
        '/api/admin/users/$userId/ban',
        body: {'banned': false},
      );
      ApiService.ensureOk(response, whileDoing: 'restoring the account');
    } catch (e) {
      print('Error unbanning user: $e');
      rethrow;
    }
  }

  /// Issue a one-time password reset code for a member who is locked out.
  ///
  /// Returns the code for the admin to pass on however they normally reach
  /// that relative — there is no mail server, so the admin recognising a
  /// family member is what stands in for a verification email.
  Future<String> issueResetCode(String userId) async {
    final response = await _api.post('/api/admin/users/$userId/reset-code');
    ApiService.ensureOk(response, whileDoing: 'creating a reset code');
    return jsonDecode(response.body)['code'] as String;
  }

  // ===== ANNOUNCEMENTS =====

  /// Send announcement to all users
  Future<void> sendAnnouncement({
    required String title,
    required String message,
  }) async {
    try {
      final response = await _api.post(
        '/api/admin/announcements',
        body: {
          'title': title,
          'message': message,
        },
      );
      ApiService.ensureOk(response, whileDoing: 'sending the announcement');
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
      ApiService.ensureOk(response, whileDoing: 'exporting the tree');
      return jsonDecode(response.body);
    } catch (e) {
      print('Error exporting data: $e');
      rethrow;
    }
  }
}
