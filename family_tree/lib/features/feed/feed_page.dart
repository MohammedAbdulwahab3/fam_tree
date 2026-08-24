import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:family_tree/core/config.dart';
import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/core/theme/app_colors.dart';
import 'package:family_tree/core/theme/elegant_theme.dart';
import 'package:family_tree/core/utils/platform_image_picker.dart';
import 'package:family_tree/core/widgets/aurora_background.dart';
import 'package:family_tree/core/widgets/theme_toggle_button.dart';
import 'package:family_tree/core/widgets/tree_mark.dart';
import 'package:family_tree/data/models/post.dart';
import 'package:family_tree/data/repositories/group_repository.dart';
import 'package:family_tree/data/services/api_service.dart';
import 'package:family_tree/data/services/storage_service.dart';
import 'package:family_tree/features/auth/session.dart';
import 'package:family_tree/features/feed/widgets/post_card.dart';
import 'package:family_tree/core/design/typography.dart';

/// The family tree this build shows. Set at build time — see [AppConfig].
const String kFeedFamilyTreeId = AppConfig.familyTreeId;

/// The one repository the feed reads and writes through.
///
/// There used to be two — one built inside the stream provider, one held by the
/// page's state — each with its own cache and its own polling loop. Pull to
/// refresh force-fetched on the instance whose result was then discarded, so
/// every refresh cost an extra round trip that changed nothing.
final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  return GroupRepository();
});

/// Posts for the family feed.
final postsProvider = StreamProvider<List<Post>>((ref) {
  return ref.watch(groupRepositoryProvider).watchPosts();
});

/// The family feed — the only surface that replaced the old tabbed group page.
class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({super.key});

  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends ConsumerState<FeedPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _auroraController;

  GroupRepository get _repository => ref.read(groupRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _auroraController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();
  }

  @override
  void dispose() {
    _auroraController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    _repository.invalidate();
    ref.invalidate(postsProvider);
  }

  Future<void> _deletePost(String postId, bool isDark) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: Text(
          'Delete post',
          style: AppType.sans(
            fontWeight: FontWeight.w700,
            color: context.colors.ink,
          ),
        ),
        content: Text(
          'This cannot be undone.',
          style: AppType.sans(
            fontSize: 14,
            color: context.colors.inkMuted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: AppType.sans()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: Text(
              'Delete',
              style: AppType.sans(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await _repository.deletePost(postId);
      ref.invalidate(postsProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(messageForError(e)),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider);
    final postsAsync = ref.watch(postsProvider);
    final isWide = MediaQuery.of(context).size.width >= 720;

    return Scaffold(
      body: Stack(
        children: [
          AuroraBackground(
            animation: _auroraController,
            isDark: isDark,
            intensity: 0.7,
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(isDark, isWide),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    color: AppTheme.accentTeal,
                    backgroundColor: context.colors.surface,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 680),
                        child: postsAsync.when(
                          data: (posts) => _buildList(posts, user, isDark),
                          loading: () => const Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.accentTeal,
                            ),
                          ),
                          error: (e, _) => _buildError(e, isDark),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark, bool isWide) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isWide ? 24 : 14,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.55),
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: context.colors.ink,
                ),
                tooltip: 'Back to the tree',
                onPressed: () => context.go('/tree'),
              ),
              const SizedBox(width: 4),
              TreeMark(isDark: isDark, size: 34),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  'Family Feed',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.sans(
                    fontSize: isWide ? 24 : 20,
                    fontWeight: FontWeight.bold,
                    color: context.colors.ink,
                  ),
                ),
              ),
              const Spacer(),
              ThemeToggleIcon(
                color: context.colors.ink,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<Post> posts, dynamic user, bool isDark) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      // +1 for the composer that always sits at the top of the feed, and one
      // more row for the empty-state invitation when there is nothing yet.
      itemCount: posts.isEmpty ? 2 : posts.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: _Composer(
              isDark: isDark,
              userName: user?.displayName ?? 'You',
              userPhoto: user?.photoURL,
              onPosted: _refresh,
              repository: _repository,
              currentUserId: user?.uid ?? '',
            ),
          );
        }

        if (posts.isEmpty) {
          // index 1 with no posts: invite the first one.
          return _buildEmptyState(isDark);
        }

        final post = posts[index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: PostCard(
            // Keyed on the post so that a refresh which prepends new posts
            // reuses each card's state against the right post rather than
            // against whatever now sits at that index.
            key: ValueKey(post.id),
            post: post,
            currentUserId: user?.uid ?? '',
            currentUserName: user?.displayName ?? 'Anonymous',
            currentUserPhoto: user?.photoURL,
            isOwnPost: post.userId == user?.uid,
            onDelete: () => _deletePost(post.id, isDark),
            repository: _repository,
            isDark: isDark,
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          Icon(
            Icons.auto_stories_outlined,
            size: 46,
            color: AppTheme.accentTeal.withValues(alpha: 0.55),
          ),
          const SizedBox(height: 18),
          Text(
            'No stories yet',
            style: AppType.sans(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: context.colors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Text(
              'Share a photo, a memory, or a bit of news — it will appear here for the whole family.',
              textAlign: TextAlign.center,
              style: AppType.sans(
                fontSize: 18,
                fontStyle: FontStyle.italic,
                height: 1.5,
                color: context.colors.inkMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(Object error, bool isDark) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Icon(Icons.cloud_off_rounded,
            size: 48, color: AppTheme.textMutedDark.withValues(alpha: 0.6)),
        const SizedBox(height: 16),
        Text(
          'Could not load the feed',
          textAlign: TextAlign.center,
          style: AppType.sans(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: context.colors.ink,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            '$error',
            textAlign: TextAlign.center,
            style: AppType.sans(
              fontSize: 13,
              color: context.colors.inkMuted,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: TextButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ),
      ],
    );
  }
}

/// Inline composer that sits at the top of the feed, replacing the old
/// floating-action-button dialog.
class _Composer extends StatefulWidget {
  final bool isDark;
  final String userName;
  final String? userPhoto;
  final String currentUserId;
  final GroupRepository repository;
  final Future<void> Function() onPosted;

  const _Composer({
    required this.isDark,
    required this.userName,
    required this.userPhoto,
    required this.currentUserId,
    required this.repository,
    required this.onPosted,
  });

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final PlatformImagePicker _picker = PlatformImagePicker();
  final StorageService _storage = StorageService();

  final List<PickedFile> _images = [];
  PickedFile? _video;

  bool _expanded = false;
  bool _busy = false;

  /// What the upload is doing, so the button can say more than "spinning".
  /// Null while idle.
  String? _uploadStage;
  double _uploadProgress = 0;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && !_expanded) {
        setState(() => _expanded = true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _canPost =>
      !_busy &&
      (_controller.text.trim().isNotEmpty ||
          _images.isNotEmpty ||
          _video != null);

  Future<void> _pickImages() async {
    if (_busy) return;
    try {
      final picked = await _picker.pickMultipleImages();
      if (picked.isNotEmpty) {
        setState(() {
          _images.addAll(picked);
          _expanded = true;
        });
      }
    } catch (e) {
      _toast('Could not pick images: $e', isError: true);
    }
  }

  Future<void> _pickVideo() async {
    if (_busy) return;
    try {
      final picked = await _picker.pickVideo();
      if (picked != null) {
        setState(() {
          _video = picked;
          _expanded = true;
        });
      }
    } catch (e) {
      _toast('Could not pick video: $e', isError: true);
    }
  }

  Future<void> _submit() async {
    if (!_canPost) return;
    setState(() => _busy = true);

    try {
      final attachments = _images.length + (_video != null ? 1 : 0);
      var done = 0;

      void report(String label, double fraction) {
        if (!mounted) return;
        setState(() {
          _uploadStage = label;
          // Spread each file's own progress across the whole batch, so the
          // bar moves steadily rather than restarting per photo.
          _uploadProgress =
              attachments == 0 ? 0 : (done + fraction) / attachments;
        });
      }

      final photoUrls = <String>[];
      for (var i = 0; i < _images.length; i++) {
        final image = _images[i];
        final label = _images.length == 1
            ? 'Uploading photo'
            : 'Uploading photo ${i + 1} of ${_images.length}';
        report(label, 0);
        final url = await _storage.uploadImage(
          image.name,
          image.bytes,
          onProgress: (p) => report(label, p),
        );
        if (url != null) photoUrls.add(url);
        done++;
      }

      final videoUrls = <String>[];
      if (_video != null) {
        report('Uploading video', 0);
        final url = await _storage.uploadVideo(
          _video!.name,
          _video!.bytes,
          onProgress: (p) => report('Uploading video', p),
        );
        if (url != null) videoUrls.add(url);
        done++;
      }

      if (mounted && attachments > 0) {
        setState(() {
          _uploadStage = 'Sharing';
          _uploadProgress = 1;
        });
      }

      await widget.repository.addPost(
        Post(
          id: '',
          familyTreeId: kFeedFamilyTreeId,
          userId: widget.currentUserId,
          userName: widget.userName,
          userPhoto: widget.userPhoto,
          content: _controller.text.trim(),
          photos: photoUrls,
          videos: videoUrls,
          files: const [],
          createdAt: DateTime.now(),
          reactions: const {},
        ),
      );

      _controller.clear();
      setState(() {
        _images.clear();
        _video = null;
        _expanded = false;
        _busy = false;
        _uploadStage = null;
        _uploadProgress = 0;
      });
      _focusNode.unfocus();
      await widget.onPosted();
      if (mounted) _toast('Shared with the family');
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _uploadStage = null;
          _uploadProgress = 0;
        });
      }
      _toast(messageForError(e), isError: true);
    }
  }

  void _toast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.error : AppTheme.primaryDeep,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  Colors.white.withValues(alpha: 0.10),
                  Colors.white.withValues(alpha: 0.04),
                ]
              : [
                  Colors.white.withValues(alpha: 0.94),
                  Colors.white.withValues(alpha: 0.74),
                ],
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.13)
              : Colors.white.withValues(alpha: 0.9),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.06),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(
                name: widget.userName,
                photo: widget.userPhoto,
                isDark: isDark,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  minLines: 1,
                  maxLines: _expanded ? 6 : 2,
                  enabled: !_busy,
                  onChanged: (_) => setState(() {}),
                  style: AppType.sans(
                    fontSize: 15,
                    height: 1.5,
                    color: context.colors.ink,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Share something with the family…',
                    hintStyle: AppType.sans(
                      fontSize: 15,
                      color: isDark
                          ? AppTheme.textMutedDark
                          : ElegantColors.warmGray,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_images.isNotEmpty || _video != null) ...[
            const SizedBox(height: 14),
            _buildAttachments(isDark),
          ],
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        _iconAction(
                          icon: Icons.image_outlined,
                          tooltip: 'Add photos',
                          isDark: isDark,
                          onTap: _pickImages,
                        ),
                        const SizedBox(width: 6),
                        _iconAction(
                          icon: Icons.videocam_outlined,
                          tooltip: 'Add a video',
                          isDark: isDark,
                          onTap: _pickVideo,
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () {
                                  _controller.clear();
                                  setState(() {
                                    _images.clear();
                                    _video = null;
                                    _expanded = false;
                                  });
                                  _focusNode.unfocus();
                                },
                          child: Text(
                            'Cancel',
                            style: AppType.sans(
                              fontSize: 13.5,
                              color: isDark
                                  ? AppTheme.textMutedDark
                                  : ElegantColors.warmGray,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _postButton(isDark),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachments(bool isDark) {
    return SizedBox(
      height: 84,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (var i = 0; i < _images.length; i++)
            _thumb(
              child: Image.memory(_images[i].bytes, fit: BoxFit.cover),
              onRemove: () => setState(() => _images.removeAt(i)),
            ),
          if (_video != null)
            _thumb(
              child: Container(
                color: Colors.black26,
                child: const Center(
                  child: Icon(Icons.play_circle_fill_rounded,
                      color: Colors.white, size: 28),
                ),
              ),
              onRemove: () => setState(() => _video = null),
            ),
        ],
      ),
    );
  }

  Widget _thumb({required Widget child, required VoidCallback onRemove}) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(width: 84, height: 84, child: child),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: _busy ? null : onRemove,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded,
                    size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconAction({
    required IconData icon,
    required String tooltip,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: _busy ? null : onTap,
        icon: Icon(icon, size: 21),
        color: AppTheme.accentTeal,
        splashRadius: 22,
      ),
    );
  }

  Widget _postButton(bool isDark) {
    return Opacity(
      opacity: _canPost ? 1 : 0.45,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          gradient: const LinearGradient(
            colors: [AppTheme.primaryDeep, AppTheme.accentTeal],
          ),
          boxShadow: _canPost
              ? [
                  BoxShadow(
                    color: AppTheme.accentTeal.withValues(alpha: 0.32),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : const [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _canPost ? _submit : null,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              child: _busy
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            // A determinate arc while bytes are moving: a
                            // spinner alone cannot be told apart from a hang.
                            value: _uploadStage == null || _uploadProgress <= 0
                                ? null
                                : _uploadProgress,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                        if (_uploadStage != null) ...[
                          const SizedBox(width: 10),
                          Text(
                            '$_uploadStage  ${(_uploadProgress * 100).round()}%',
                            style: AppType.sans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    )
                  : Text(
                      'Post',
                      style: AppType.sans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final String? photo;
  final bool isDark;

  const _Avatar(
      {required this.name, required this.photo, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [AppTheme.primaryDeep, AppTheme.accentTeal],
        ),
        border: Border.all(
          color: AppTheme.accentTeal.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: (photo != null && photo!.isNotEmpty)
          ? Image.network(photo!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _initial(initial))
          : _initial(initial),
    );
  }

  Widget _initial(String initial) => Center(
        child: Text(
          initial,
          style: AppType.sans(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
}
