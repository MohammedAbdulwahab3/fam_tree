import 'dart:convert';

import 'package:family_tree/data/models/app_user.dart';
import 'package:family_tree/data/models/person.dart';
import 'package:family_tree/data/models/post.dart';
import 'package:family_tree/data/repositories/person_repository.dart';
import 'package:family_tree/data/services/api_service.dart';

/// Admin-only operations, against the `/api/admin/*` routes.
///
/// Nothing here catches and rethrows. Every method used to wrap its call in a
/// try/catch that logged the error and rethrew it unchanged, which added a line
/// to stdout and nothing else — the caller still had to handle the failure, and
/// [ApiService.ensureOk] already attaches the server's message.
class AdminRepository {
  final ApiService _api = ApiService();

  // ===== PEOPLE =====

  /// Add a person to the tree. Returns their new id.
  ///
  /// Only the new person's parents are sent; the server derives the reverse
  /// direction. This replaced a two-request sequence — create the child, then
  /// update the parent to list them — that left the tree inconsistent whenever
  /// the second request failed.
  Future<String> addPerson(Person person) async {
    final response = await _api.post('/api/admin/persons', body: person.toJson());
    ApiService.ensureOk(response, whileDoing: 'adding the person');
    PersonRepository.invalidate();

    return (jsonDecode(response.body) as Map<String, dynamic>)['id'] as String;
  }

  Future<void> updatePerson(Person person) async {
    final response = await _api.put(
      '/api/admin/persons/${person.id}',
      body: person.toJson(),
    );
    ApiService.ensureOk(response, whileDoing: 'saving the person');
    PersonRepository.invalidate();
  }

  /// Remove a person, and with [cascade] everyone below them.
  ///
  /// The server does the whole subtree in one transaction and scrubs the
  /// references their relatives held. The app used to send one request per
  /// descendant and leave dangling ids behind either way.
  Future<void> deletePerson(String personId, {bool cascade = false}) async {
    final response = await _api.delete(
      '/api/admin/persons/$personId${cascade ? '?cascade=true' : ''}',
    );
    ApiService.ensureOk(response, whileDoing: 'removing the person');
    PersonRepository.invalidate();
  }

  // ===== POSTS =====

  Future<String> createPost(Post post) async {
    final response = await _api.post('/api/admin/posts', body: post.toJson());
    ApiService.ensureOk(response, whileDoing: 'publishing the post');

    return (jsonDecode(response.body) as Map<String, dynamic>)['id'] as String? ?? '';
  }

  Future<void> deletePost(String postId) async {
    final response = await _api.delete('/api/admin/posts/$postId');
    ApiService.ensureOk(response, whileDoing: 'deleting the post');
  }

  // ===== MEMBERS =====

  Future<List<AppUser>> getUsers() async {
    final response = await _api.get('/api/admin/users');
    ApiService.ensureOk(response, whileDoing: 'loading the members');

    return (jsonDecode(response.body) as List<dynamic>)
        .map((json) => AppUser.fromJson(json as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> updateUserRole(String userId, String role) async {
    final response = await _api.put(
      '/api/admin/users/$userId/role',
      body: {'role': role},
    );
    ApiService.ensureOk(response, whileDoing: 'changing the role');
  }

  Future<void> deleteUser(String userId) async {
    final response = await _api.delete('/api/admin/users/$userId');
    ApiService.ensureOk(response, whileDoing: 'deleting the account');
  }

  Future<void> banUser(String userId, {String? reason}) async {
    final response = await _api.put(
      '/api/admin/users/$userId/ban',
      body: {'banned': true, 'reason': reason ?? ''},
    );
    ApiService.ensureOk(response, whileDoing: 'suspending the account');
  }

  Future<void> unbanUser(String userId) async {
    final response = await _api.put(
      '/api/admin/users/$userId/ban',
      body: {'banned': false},
    );
    ApiService.ensureOk(response, whileDoing: 'restoring the account');
  }

  /// Issue a one-time password reset code for a member who is locked out.
  ///
  /// Returns the code for the admin to pass on however they normally reach that
  /// relative — there is no mail server, so the admin recognising a family
  /// member is what stands in for a verification email.
  Future<String> issueResetCode(String userId) async {
    final response = await _api.post('/api/admin/users/$userId/reset-code');
    ApiService.ensureOk(response, whileDoing: 'creating a reset code');

    return (jsonDecode(response.body) as Map<String, dynamic>)['code'] as String;
  }

  // ===== ANNOUNCEMENTS =====

  /// Send an announcement to every member, as one notification each.
  Future<void> sendAnnouncement({
    required String title,
    required String message,
  }) async {
    final response = await _api.post(
      '/api/admin/announcements',
      body: {'title': title, 'message': message},
    );
    ApiService.ensureOk(response, whileDoing: 'sending the announcement');
  }
}
