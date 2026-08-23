import 'dart:convert';

import 'package:family_tree/core/logging.dart';
import 'package:family_tree/data/models/comment.dart';
import 'package:family_tree/data/models/post.dart';
import 'package:family_tree/data/services/api_service.dart';

/// One page of the feed, plus the cursor that fetches the next one.
class PostPage {
  const PostPage({
    required this.posts,
    required this.hasMore,
    this.nextCursor,
  });

  final List<Post> posts;
  final bool hasMore;
  final String? nextCursor;

  static const empty = PostPage(posts: [], hasMore: false);
}

/// Reads and writes the family feed.
///
/// Construct one per app, through [groupRepositoryProvider]. The feed used to
/// build two — one inside the stream provider and one in the page's state —
/// each with its own cache and its own polling loop, so every refresh made a
/// request whose result was then thrown away.
class GroupRepository {
  final ApiService _api = ApiService();

  List<Post>? _cachedPosts;
  DateTime? _lastPostsFetch;

  /// How long a fetched page stays fresh.
  static const cacheValidity = Duration(minutes: 5);

  /// How often the feed checks for new posts.
  static const pollInterval = Duration(seconds: 30);

  // ===== POSTS =====

  /// Watch the newest page of the feed. Emits only when something changed —
  /// an unchanged poll re-emits the identical list, which widgets comparing by
  /// identity treat as no change at all.
  Stream<List<Post>> watchPosts() async* {
    var last = const <Post>[];
    while (true) {
      try {
        last = (await getPosts()).posts;
      } catch (error) {
        log('Could not refresh the feed', error);
        if (_cachedPosts != null) last = _cachedPosts!;
      }
      // Yield on every pass, including a failed one. An `async*` generator
      // only learns that its listener has gone at a yield, so a loop that
      // yields solely on success keeps polling forever after the page is
      // closed — exactly while the network is failing, which is when it is
      // least wanted. `getPosts` hands back the identical list when nothing
      // changed, so re-yielding here still costs no relayout.
      yield last;
      await Future<void>.delayed(pollInterval);
    }
  }

  /// Fetch the newest page of posts.
  ///
  /// [before] pages backwards through the feed using the cursor from a previous
  /// page. Paging by timestamp rather than offset matters because the feed is
  /// written to while it is read: an offset silently repeats or skips a post
  /// whenever something new arrives between two pages.
  Future<PostPage> getPosts({bool forceRefresh = false, String? before}) async {
    final isFirstPage = before == null;

    if (isFirstPage &&
        !forceRefresh &&
        !_shouldFetch(_lastPostsFetch) &&
        _cachedPosts != null) {
      return PostPage(posts: _cachedPosts!, hasMore: true);
    }

    final query =
        before == null ? '' : '?before=${Uri.encodeQueryComponent(before)}';
    final response = await _api.get('/api/posts$query');
    ApiService.ensureOk(response, whileDoing: 'loading the feed');

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final posts = (body['posts'] as List<dynamic>? ?? [])
        .map((json) => Post.fromJson(json as Map<String, dynamic>))
        .toList(growable: false);

    if (isFirstPage) {
      _cachedPosts = posts;
      _lastPostsFetch = DateTime.now();
    }

    return PostPage(
      posts: posts,
      hasMore: body['hasMore'] as bool? ?? false,
      nextCursor: body['nextCursor'] as String?,
    );
  }

  /// Share a new post. Returns its id.
  Future<String> addPost(Post post) async {
    final response = await _api.post('/api/posts', body: post.toJson());
    ApiService.ensureOk(response, whileDoing: 'sharing your post');

    invalidate();
    return (jsonDecode(response.body) as Map<String, dynamic>)['id']
            as String? ??
        '';
  }

  /// Delete a post. Members may delete their own; admins may delete any.
  Future<void> deletePost(String postId) async {
    final response = await _api.delete('/api/posts/$postId');
    ApiService.ensureOk(response, whileDoing: 'deleting the post');

    // Only drop it from the cache once the server has confirmed, so a refused
    // delete no longer removes the post from the feed and then puts it back.
    _cachedPosts?.removeWhere((p) => p.id == postId);
    _lastPostsFetch = null;
  }

  /// Drop the cached page so the next read goes to the server.
  void invalidate() {
    _cachedPosts = null;
    _lastPostsFetch = null;
  }

  // ===== COMMENTS =====

  /// Watch a post's comments.
  Stream<List<Comment>> watchComments(String postId) async* {
    var last = const <Comment>[];
    while (true) {
      try {
        last = await getComments(postId);
      } catch (error) {
        log('Could not load comments', error);
      }
      // See watchPosts: yielding on the error path too is what lets a
      // cancelled subscription end this loop.
      yield last;
      await Future<void>.delayed(pollInterval);
    }
  }

  Future<List<Comment>> getComments(String postId) async {
    final response = await _api.get('/api/posts/$postId/comments');
    ApiService.ensureOk(response, whileDoing: 'loading the comments');

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['comments'] as List<dynamic>? ?? [])
        .map((json) => Comment.fromJson(json as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Add a comment to a post. Returns its id.
  Future<String> addComment(Comment comment) async {
    final response = await _api.post(
      '/api/posts/${comment.postId}/comments',
      body: comment.toJson(),
    );
    ApiService.ensureOk(response, whileDoing: 'posting your comment');

    return (jsonDecode(response.body) as Map<String, dynamic>)['id']
            as String? ??
        '';
  }

  Future<void> deleteComment(String commentId) async {
    final response = await _api.delete('/api/comments/$commentId');
    ApiService.ensureOk(response, whileDoing: 'deleting the comment');
  }

  Future<void> updateComment(Comment comment) async {
    final response = await _api.put(
      '/api/comments/${comment.id}',
      body: {'text': comment.text},
    );
    ApiService.ensureOk(response, whileDoing: 'saving your edit');
  }

  // ===== REACTIONS =====

  /// Set, change or clear the signed-in member's reaction to a post. Sending
  /// the same emoji twice takes it back.
  Future<void> toggleReaction(String postId, String emoji) async {
    final response = await _api.post(
      '/api/posts/$postId/reactions',
      body: {'emoji': emoji},
    );
    ApiService.ensureOk(response, whileDoing: 'saving your reaction');

    _lastPostsFetch = null;
  }

  bool _shouldFetch(DateTime? lastFetch) {
    if (lastFetch == null) return true;
    return DateTime.now().difference(lastFetch) > cacheValidity;
  }
}
