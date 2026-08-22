import 'dart:convert';
import 'package:family_tree/data/models/post.dart';
import 'package:family_tree/data/models/message.dart';
import 'package:family_tree/data/models/appointment.dart';
import 'package:family_tree/data/models/comment.dart';
import 'package:family_tree/data/services/api_service.dart';

/// Repository for family group operations (posts, chat, events)
/// Uses Go backend API instead of Firestore
class GroupRepository {
  final ApiService _api = ApiService();

  // ===== CACHE =====
  List<Post>? _cachedPosts;
  DateTime? _lastPostsFetch;
  
  List<Message>? _cachedMessages;
  DateTime? _lastMessagesFetch;
  
  List<Appointment>? _cachedEvents;
  DateTime? _lastEventsFetch;
  
  final Duration _cacheValidity = const Duration(minutes: 5);

  // ===== POSTS =====

  /// Watch all posts (polling-based since REST doesn't support real-time)
  Stream<List<Post>> watchPosts(String familyTreeId) async* {
    // Yield cached data immediately if available
    if (_cachedPosts != null) yield _cachedPosts!;
    
    while (true) {
      try {
        // Only fetch if cache is expired or empty
        if (_shouldFetch(_lastPostsFetch)) {
          final posts = await getPosts();
          yield posts;
        } else if (_cachedPosts != null) {
          yield _cachedPosts!;
        }
      } catch (e) {
        print('Error fetching posts: $e');
        if (_cachedPosts != null) yield _cachedPosts!;
      }
      await Future.delayed(const Duration(seconds: 5)); // Increased polling interval
    }
  }

  /// Get all posts
  Future<List<Post>> getPosts({bool forceRefresh = false}) async {
    if (!forceRefresh && !_shouldFetch(_lastPostsFetch) && _cachedPosts != null) {
      return _cachedPosts!;
    }

    try {
      final response = await _api.get('/api/posts');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final posts = data.map((json) => Post.fromJson(json as Map<String, dynamic>)).toList();
        
        // Update cache
        _cachedPosts = posts;
        _lastPostsFetch = DateTime.now();
        return posts;
      }
      return _cachedPosts ?? [];
    } catch (e) {
      print('Error getting posts: $e');
      return _cachedPosts ?? [];
    }
  }

  /// Add a new post
  Future<String> addPost(Post post) async {
    final response = await _api.post('/api/posts', body: post.toJson());
    ApiService.ensureOk(response, whileDoing: 'sharing your post');

    final data = jsonDecode(response.body);
    // Invalidate cache to force refresh
    _lastPostsFetch = null;
    return data['id'] ?? '';
  }

  /// Delete a post
  Future<void> deletePost(String postId) async {
    final response = await _api.delete('/api/posts/$postId');
    ApiService.ensureOk(response, whileDoing: 'deleting the post');

    // Only drop it from the cache once the server has confirmed, so a refused
    // delete no longer removes the post from the feed and then puts it back.
    _cachedPosts?.removeWhere((p) => p.id == postId);
    _lastPostsFetch = null;
  }

  // ===== MESSAGES =====

  /// Watch all messages (polling-based)
  Stream<List<Message>> watchMessages(String familyTreeId) async* {
    if (_cachedMessages != null) yield _cachedMessages!;
    
    while (true) {
      try {
        // Always fetch fresh messages (real-time is important for chat)
        final messages = await getMessages(forceRefresh: true);
        yield messages;
      } catch (e) {
        print('Error fetching messages: $e');
        if (_cachedMessages != null) yield _cachedMessages!;
      }
      await Future.delayed(const Duration(seconds: 1)); // Fast polling for chat
    }
  }

  /// Get all messages
  Future<List<Message>> getMessages({bool forceRefresh = false}) async {
    if (!forceRefresh && !_shouldFetch(_lastMessagesFetch) && _cachedMessages != null) {
      return _cachedMessages!;
    }

    try {
      final response = await _api.get('/api/messages');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final messages = data.map((json) => Message.fromJson(json as Map<String, dynamic>)).toList();
        
        _cachedMessages = messages;
        _lastMessagesFetch = DateTime.now();
        return messages;
      }
      return _cachedMessages ?? [];
    } catch (e) {
      print('Error getting messages: $e');
      return _cachedMessages ?? [];
    }
  }

  /// Send a message
  Future<String> sendMessage(Message message) async {
    // Optimistic update - show the message in the thread immediately.
    final tempMessage = Message(
      id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
      familyTreeId: message.familyTreeId,
      userId: message.userId,
      userName: message.userName,
      userPhoto: message.userPhoto,
      text: message.text,
      type: message.type,
      mediaUrl: message.mediaUrl,
      sentAt: DateTime.now(),
    );
    _cachedMessages = [...(_cachedMessages ?? []), tempMessage];

    try {
      final response = await _api.post('/api/messages', body: message.toJson());
      ApiService.ensureOk(response, whileDoing: 'sending your message');

      final data = jsonDecode(response.body);
      _lastMessagesFetch = null; // Force refresh on next poll
      return data['id'] ?? '';
    } catch (_) {
      // However it failed, take the unsent message back out of the thread so
      // it is not left looking delivered.
      _cachedMessages?.removeWhere((m) => m.id == tempMessage.id);
      rethrow;
    }
  }

  /// Update a message
  Future<void> updateMessage(Message message) async {
    final response = await _api.put(
      '/api/messages/${message.id}',
      body: message.toJson(),
    );
    ApiService.ensureOk(response, whileDoing: 'editing the message');
    _lastMessagesFetch = null;
  }

  /// Delete a message
  Future<void> deleteMessage(String messageId) async {
    final response = await _api.delete('/api/messages/$messageId');
    ApiService.ensureOk(response, whileDoing: 'deleting the message');

    _cachedMessages?.removeWhere((m) => m.id == messageId);
    _lastMessagesFetch = null;
  }

  // ===== EVENTS =====

  /// Watch all events (polling-based)
  Stream<List<Appointment>> watchAppointments(String familyTreeId) async* {
    if (_cachedEvents != null) yield _cachedEvents!;
    
    while (true) {
      try {
        if (_shouldFetch(_lastEventsFetch)) {
          final events = await getEvents();
          yield events;
        } else if (_cachedEvents != null) {
          yield _cachedEvents!;
        }
      } catch (e) {
        print('Error fetching events: $e');
        if (_cachedEvents != null) yield _cachedEvents!;
      }
      await Future.delayed(const Duration(seconds: 5));
    }
  }

  /// Get all events
  Future<List<Appointment>> getEvents({bool forceRefresh = false}) async {
    if (!forceRefresh && !_shouldFetch(_lastEventsFetch) && _cachedEvents != null) {
      return _cachedEvents!;
    }

    try {
      final response = await _api.get('/api/events');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final events = data.map((json) => Appointment.fromJson(json as Map<String, dynamic>)).toList();
        
        _cachedEvents = events;
        _lastEventsFetch = DateTime.now();
        return events;
      }
      return _cachedEvents ?? [];
    } catch (e) {
      print('Error getting events: $e');
      return _cachedEvents ?? [];
    }
  }

  /// Add a new event
  Future<String> addAppointment(Appointment appointment) async {
    final response = await _api.post('/api/events', body: appointment.toJson());
    ApiService.ensureOk(response, whileDoing: 'creating the event');

    final data = jsonDecode(response.body);
    _lastEventsFetch = null;
    return data['id'] ?? '';
  }

  /// Delete an event
  Future<void> deleteAppointment(String appointmentId) async {
    final response = await _api.delete('/api/events/$appointmentId');
    ApiService.ensureOk(response, whileDoing: 'cancelling the event');

    _cachedEvents?.removeWhere((e) => e.id == appointmentId);
    _lastEventsFetch = null;
  }

  /// Toggle RSVP for an event with status (yes/maybe/no)
  Future<void> toggleRSVP(String eventId, String userId, [String status = 'yes']) async {
    final response =
        await _api.post('/api/events/$eventId/rsvp', body: {'status': status});
    ApiService.ensureOk(response, whileDoing: 'saving your reply');
    _lastEventsFetch = null;
  }

  /// Update an existing appointment
  Future<void> updateAppointment(Appointment appointment) async {
    final response =
        await _api.put('/api/events/${appointment.id}', body: appointment.toJson());
    ApiService.ensureOk(response, whileDoing: 'updating the event');
    _lastEventsFetch = null;
  }

  // ===== COMMENTS =====

  /// Watch comments for a post (polling-based)
  Stream<List<Comment>> watchComments(String postId) async* {
    while (true) {
      try {
        final comments = await getComments(postId);
        yield comments;
      } catch (e) {
        print('Error fetching comments: $e');
        yield [];
      }
      await Future.delayed(const Duration(seconds: 3));
    }
  }

  /// Get comments for a post
  Future<List<Comment>> getComments(String postId) async {
    try {
      final response = await _api.get('/api/posts/$postId/comments');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Comment.fromJson(json as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      print('Error getting comments: $e');
      return [];
    }
  }

  /// Add a comment to a post
  Future<String> addComment(Comment comment) async {
    final response = await _api.post(
      '/api/posts/${comment.postId}/comments',
      body: comment.toJson(),
    );
    ApiService.ensureOk(response, whileDoing: 'posting your comment');

    final data = jsonDecode(response.body);
    return data['id'] ?? '';
  }

  /// Delete a comment
  Future<void> deleteComment(String commentId) async {
    final response = await _api.delete('/api/comments/$commentId');
    ApiService.ensureOk(response, whileDoing: 'deleting the comment');
  }

  /// Update a comment
  Future<void> updateComment(Comment comment) async {
    final response =
        await _api.put('/api/comments/${comment.id}', body: {'text': comment.text});
    ApiService.ensureOk(response, whileDoing: 'saving your edit');
  }

  // ===== REACTIONS =====

  /// Toggle reaction on a post
  Future<void> toggleReaction(String postId, String userId, String emoji) async {
    // userId is ignored by the server, which takes the reacting user from the
    // token. The parameter stays for the existing call sites.
    final response = await _api.post(
      '/api/posts/$postId/reactions',
      body: {'emoji': emoji},
    );
    ApiService.ensureOk(response, whileDoing: 'saving your reaction');

    // Invalidate cache to force refresh with new reaction count
    _lastPostsFetch = null;
  }

  // ===== HELPER =====
  bool _shouldFetch(DateTime? lastFetch) {
    if (lastFetch == null) return true;
    return DateTime.now().difference(lastFetch) > _cacheValidity;
  }
}
