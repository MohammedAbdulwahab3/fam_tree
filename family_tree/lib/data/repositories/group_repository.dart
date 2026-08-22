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
    try {
      final response = await _api.post('/api/posts', body: post.toJson());
      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Invalidate cache to force refresh
        _lastPostsFetch = null; 
        return data['id'] ?? '';
      }
      print('Create post failed with status ${response.statusCode}: ${response.body}');
      throw Exception('Failed to create post (${response.statusCode})');
    } catch (e) {
      print('Error adding post: $e');
      rethrow;
    }
  }

  /// Delete a post
  Future<void> deletePost(String postId) async {
    try {
      await _api.delete('/api/posts/$postId');
      // Optimistic update
      _cachedPosts?.removeWhere((p) => p.id == postId);
    } catch (e) {
      print('Error deleting post: $e');
      rethrow;
    }
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
    try {
      // Optimistic update - add message to cache immediately
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
      
      final response = await _api.post('/api/messages', body: message.toJson());
      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _lastMessagesFetch = null; // Force refresh on next poll
        return data['id'] ?? '';
      }
      // Remove temp message on failure
      _cachedMessages?.removeWhere((m) => m.id == tempMessage.id);
      print('Send message failed with status ${response.statusCode}: ${response.body}');
      throw Exception('Failed to send message (${response.statusCode})');
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
  }

  /// Update a message
  Future<void> updateMessage(Message message) async {
    try {
      await _api.put(
        '/api/messages/${message.id}',
        body: message.toJson(),
      );
      _lastMessagesFetch = null;
    } catch (e) {
      print('Error updating message: $e');
      rethrow;
    }
  }

  /// Delete a message
  Future<void> deleteMessage(String messageId) async {
    try {
      await _api.delete('/api/messages/$messageId');
      _cachedMessages?.removeWhere((m) => m.id == messageId);
    } catch (e) {
      print('Error deleting message: $e');
      rethrow;
    }
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
    try {
      final response = await _api.post('/api/events', body: appointment.toJson());
      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _lastEventsFetch = null;
        return data['id'] ?? '';
      }
      print('Create event failed with status ${response.statusCode}: ${response.body}');
      throw Exception('Failed to create event (${response.statusCode})');
    } catch (e) {
      print('Error adding event: $e');
      rethrow;
    }
  }

  /// Delete an event
  Future<void> deleteAppointment(String appointmentId) async {
    try {
      await _api.delete('/api/events/$appointmentId');
      _cachedEvents?.removeWhere((e) => e.id == appointmentId);
    } catch (e) {
      print('Error deleting event: $e');
      rethrow;
    }
  }

  /// Toggle RSVP for an event with status (yes/maybe/no)
  Future<void> toggleRSVP(String eventId, String userId, [String status = 'yes']) async {
    try {
      await _api.post('/api/events/$eventId/rsvp', body: {'status': status});
      _lastEventsFetch = null;
    } catch (e) {
      print('Error toggling RSVP: $e');
      rethrow;
    }
  }

  /// Update an existing appointment
  Future<void> updateAppointment(Appointment appointment) async {
    try {
      await _api.put('/api/events/${appointment.id}', body: appointment.toJson());
      _lastEventsFetch = null;
    } catch (e) {
      print('Error updating event: $e');
      rethrow;
    }
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
    try {
      final response = await _api.post(
        '/api/posts/${comment.postId}/comments',
        body: comment.toJson(),
      );
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['id'] ?? '';
      }
      throw Exception('Failed to add comment');
    } catch (e) {
      print('Error adding comment: $e');
      rethrow;
    }
  }

  /// Delete a comment
  Future<void> deleteComment(String commentId) async {
    try {
      await _api.delete('/api/comments/$commentId');
    } catch (e) {
      print('Error deleting comment: $e');
      rethrow;
    }
  }

  /// Update a comment
  Future<void> updateComment(Comment comment) async {
    try {
      await _api.put('/api/comments/${comment.id}', body: comment.toJson());
    } catch (e) {
      print('Error updating comment: $e');
      rethrow;
    }
  }

  // ===== REACTIONS =====

  /// Toggle reaction on a post
  Future<void> toggleReaction(String postId, String userId, String emoji) async {
    try {
      await _api.post(
        '/api/posts/$postId/reactions',
        body: {'emoji': emoji, 'userId': userId},
      );
    } catch (e) {
      print('Error toggling reaction: $e');
      rethrow;
    }
  }

  // ===== HELPER =====
  bool _shouldFetch(DateTime? lastFetch) {
    if (lastFetch == null) return true;
    return DateTime.now().difference(lastFetch) > _cacheValidity;
  }
}
