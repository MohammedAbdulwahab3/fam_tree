import 'package:flutter/material.dart';
import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/core/theme/app_colors.dart';
import 'package:family_tree/core/theme/elegant_theme.dart';
import 'package:family_tree/data/models/post.dart';
import 'package:family_tree/data/models/comment.dart';
import 'package:family_tree/data/repositories/group_repository.dart';
import 'package:family_tree/data/services/api_service.dart';
import 'package:family_tree/core/widgets/video_player_widget.dart';
import 'package:family_tree/widgets/voice_message_widget.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:family_tree/core/design/typography.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final String currentUserId;
  final String currentUserName;
  final String? currentUserPhoto;
  final bool isOwnPost;
  final VoidCallback onDelete;
  final GroupRepository repository;
  final bool isDark;

  const PostCard({
    super.key,
    required this.post,
    required this.currentUserId,
    required this.currentUserName,
    this.currentUserPhoto,
    required this.isOwnPost,
    required this.onDelete,
    required this.repository,
    this.isDark = true,
  });

  @override
  State<PostCard> createState() => PostCardState();
}

class PostCardState extends State<PostCard>
    with SingleTickerProviderStateMixin {
  bool _showComments = false;
  late bool _isLiked;
  final TextEditingController _commentController = TextEditingController();
  late AnimationController _likeAnimController;
  late int _likeCount;

  @override
  void initState() {
    super.initState();
    _likeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _isLiked = widget.post.reactions.containsKey(widget.currentUserId);
    _likeCount = widget.post.reactions.length;
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only sync with actual post data when the post ID changes (different post)
    // This preserves local optimistic updates for the same post
    if (oldWidget.post.id != widget.post.id) {
      setState(() {
        _isLiked = widget.post.reactions.containsKey(widget.currentUserId);
        _likeCount = widget.post.reactions.length;
      });
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _likeAnimController.dispose();
    super.dispose();
  }

  void _toggleLike() async {
    // Store old values for rollback
    final wasLiked = _isLiked;
    final oldCount = _likeCount;

    // Optimistic UI update
    setState(() {
      _isLiked = !_isLiked;
      _likeCount = _isLiked ? _likeCount + 1 : _likeCount - 1;
    });
    _likeAnimController.forward().then((_) => _likeAnimController.reverse());

    try {
      await widget.repository.toggleReaction(widget.post.id, '❤️');
    } catch (e) {
      // Put the heart back the way it was, and say why — a like that silently
      // un-likes itself reads as the app being broken.
      if (mounted) {
        setState(() {
          _isLiked = wasLiked;
          _likeCount = oldCount;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(messageForError(e)),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: widget.isDark
              ? [
                  Colors.white.withValues(alpha: 0.09),
                  Colors.white.withValues(alpha: 0.035),
                ]
              : [
                  Colors.white.withValues(alpha: 0.92),
                  Colors.white.withValues(alpha: 0.72),
                ],
        ),
        border: Border.all(
          color: widget.isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.9),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: widget.isDark ? 0.32 : 0.07),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(),

          // Content
          if (widget.post.content.isNotEmpty) _buildContent(),

          // Media
          if (widget.post.photos.isNotEmpty || widget.post.videos.isNotEmpty)
            _buildMedia(),

          // Voice message
          if (widget.post.audioUrl != null) _buildAudioPlayer(),

          // Files/PDFs
          if (widget.post.files.isNotEmpty) _buildFiles(),

          // Actions
          _buildActions(),

          // Comments section
          if (_showComments) _buildCommentsSection(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: context.colors.brandGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: widget.isDark
                      ? AppTheme.primaryLight.withValues(alpha: 0.3)
                      : ElegantColors.terracotta.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: widget.post.userPhoto != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: CachedNetworkImage(
                      imageUrl: widget.post.userPhoto!,
                      fit: BoxFit.cover,
                      // A 48px avatar does not need a full-size decode.
                      memCacheWidth: 144,
                      placeholder: (_, __) =>
                          const Icon(Icons.person, color: Colors.white),
                      errorWidget: (_, __, ___) =>
                          const Icon(Icons.person, color: Colors.white),
                    ),
                  )
                : Center(
                    child: Text(
                      widget.post.userName.isNotEmpty
                          ? widget.post.userName[0].toUpperCase()
                          : '?',
                      style: AppType.sans(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 12),

          // Name and time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.post.userName,
                  style: AppType.sans(
                    color: context.colors.ink,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.access_time,
                        size: 12, color: context.colors.inkMuted),
                    const SizedBox(width: 4),
                    Text(
                      timeago.format(widget.post.createdAt),
                      style: AppType.sans(
                        color: context.colors.inkMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Menu
          if (widget.isOwnPost)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_horiz, color: context.colors.inkMuted),
              color: context.colors.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              onSelected: (value) {
                if (value == 'delete') widget.onDelete();
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(Icons.delete_outline,
                          color: AppTheme.error, size: 20),
                      const SizedBox(width: 8),
                      Text('Delete',
                          style: AppType.sans(color: AppTheme.error)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        widget.post.content,
        style: AppType.sans(
          color: context.colors.ink,
          fontSize: 16,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildAudioPlayer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.mic_rounded,
                size: 16,
                color: context.colors.accent,
              ),
              const SizedBox(width: 4),
              Text(
                'Voice Note',
                style: AppType.sans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.colors.inkMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          VoiceMessagePlayer(
            audioUrl: widget.post.audioUrl!,
            isDark: widget.isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildFiles() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.attach_file_rounded,
                size: 16,
                color: context.colors.inkMuted,
              ),
              const SizedBox(width: 4),
              Text(
                'Attachments',
                style: AppType.sans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.colors.inkMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.post.files.map((fileUrl) {
              final fileName = Uri.parse(fileUrl).pathSegments.last;
              final isPdf = fileName.toLowerCase().endsWith('.pdf');
              return GestureDetector(
                onTap: () async {
                  final uri = Uri.parse(fileUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: widget.isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : ElegantColors.cream,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: widget.isDark
                          ? Colors.white.withValues(alpha: 0.2)
                          : ElegantColors.warmGray.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPdf ? Icons.picture_as_pdf : Icons.insert_drive_file,
                        size: 18,
                        color: isPdf ? Colors.red : (context.colors.accent),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          fileName.length > 20
                              ? '${fileName.substring(0, 17)}...'
                              : fileName,
                          style: AppType.sans(
                            fontSize: 13,
                            color: context.colors.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.open_in_new,
                        size: 14,
                        color: context.colors.inkMuted,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMedia() {
    final allMedia = [...widget.post.photos, ...widget.post.videos];

    if (allMedia.length == 1) {
      return _buildSingleMedia(
          allMedia.first, widget.post.videos.contains(allMedia.first));
    }

    return Container(
      height: 200,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: allMedia.length,
        itemBuilder: (context, index) {
          final isVideo = widget.post.videos.contains(allMedia[index]);
          return Padding(
            padding:
                EdgeInsets.only(right: index < allMedia.length - 1 ? 8 : 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: isVideo
                  ? _buildVideoThumbnail(allMedia[index])
                  : _buildImageThumbnail(allMedia[index]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSingleMedia(String url, bool isVideo) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      constraints: const BoxConstraints(maxHeight: 400),
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(0),
        child: isVideo
            ? VideoPlayerWidget(videoUrl: url)
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  height: 200,
                  color: context.colors.surfaceRaised,
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (_, __, ___) => Container(
                  height: 200,
                  color: context.colors.surfaceRaised,
                  child: Icon(Icons.broken_image,
                      color: context.colors.inkMuted, size: 48),
                ),
              ),
      ),
    );
  }

  Widget _buildVideoThumbnail(String url) {
    return Container(
      width: 200,
      height: 200,
      color: Colors.black,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryDeep, AppTheme.primaryLight],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildImageThumbnail(String url) {
    return CachedNetworkImage(
      imageUrl: url,
      width: 200,
      height: 200,
      fit: BoxFit.cover,
      // A 200px tile in a grid of them; decoding each at full size is what
      // makes a photo-heavy feed stutter as you scroll.
      memCacheWidth: 600,
      placeholder: (_, __) => Container(
        width: 200,
        color: context.colors.surfaceRaised,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorWidget: (_, __, ___) => Container(
        width: 200,
        color: context.colors.surfaceRaised,
        child: Icon(Icons.broken_image, color: context.colors.inkMuted),
      ),
    );
  }

  Widget _buildActions() {
    // Use local _likeCount for proper optimistic updates

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
              color: widget.isDark
                  ? AppTheme.primaryLight.withValues(alpha: 0.1)
                  : ElegantColors.champagne),
        ),
      ),
      child: StreamBuilder<List<Comment>>(
        stream: widget.repository.watchComments(widget.post.id),
        builder: (context, snapshot) {
          final commentCount = snapshot.data?.length ?? 0;

          return Row(
            children: [
              // Like button with count
              _ActionButton(
                icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                label: _likeCount > 0 ? '$_likeCount' : '',
                color: _isLiked ? Colors.red : (context.colors.inkMuted),
                onTap: _toggleLike,
              ),
              const SizedBox(width: 20),

              // Comment button with count
              _ActionButton(
                icon: _showComments
                    ? Icons.chat_bubble
                    : Icons.chat_bubble_outline,
                label: commentCount > 0 ? '$commentCount' : '',
                color: _showComments
                    ? (context.colors.accent)
                    : (context.colors.inkMuted),
                onTap: () => setState(() => _showComments = !_showComments),
              ),
              const Spacer(),

              // Share — the handler existed but was never wired to anything.
              _ActionButton(
                icon: Icons.ios_share_rounded,
                label: '',
                color:
                    widget.isDark ? AppTheme.textMuted : ElegantColors.warmGray,
                onTap: _sharePost,
              ),
            ],
          );
        },
      ),
    );
  }

  void _sharePost() async {
    try {
      final String shareText =
          '${widget.post.userName} shared:\n\n${widget.post.content}';

      // Use share_plus for sharing
      await Share.share(
        shareText,
        subject: 'Check out this post from Family Tree',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not share: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Widget _buildCommentsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDark
            ? AppTheme.backgroundDark.withValues(alpha: 0.5)
            : ElegantColors.cream.withValues(alpha: 0.5),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Comments header
          Row(
            children: [
              Icon(
                Icons.chat_bubble_rounded,
                size: 16,
                color: context.colors.accent,
              ),
              const SizedBox(width: 8),
              Text(
                'Comments',
                style: AppType.sans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.colors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Comments list - show ALL comments
          StreamBuilder<List<Comment>>(
            stream: widget.repository.watchComments(widget.post.id),
            builder: (context, snapshot) {
              final comments = snapshot.data ?? [];

              if (comments.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 32,
                          color: widget.isDark
                              ? AppTheme.textMuted.withValues(alpha: 0.5)
                              : ElegantColors.warmGray.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No comments yet. Be the first!',
                          style: AppType.sans(
                            color: context.colors.inkMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Show all comments with scroll if many
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: comments.length > 4
                      ? const BouncingScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    return _CommentItem(
                      comment: comment,
                      isDark: widget.isDark,
                    );
                  },
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          // Add comment input
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: widget.isDark
                          ? AppTheme.primaryLight.withValues(alpha: 0.2)
                          : ElegantColors.champagne,
                    ),
                  ),
                  child: TextField(
                    controller: _commentController,
                    style: AppType.sans(
                      color: context.colors.ink,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Write a comment...',
                      hintStyle: AppType.sans(
                        color: context.colors.inkMuted,
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  gradient: widget.isDark
                      ? AppTheme.primaryGradient
                      : ElegantColors.warmGradient,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: IconButton(
                  tooltip: 'Send comment',
                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: () async {
                    if (_commentController.text.trim().isEmpty) return;

                    final comment = Comment(
                      id: '',
                      postId: widget.post.id,
                      userId: widget.currentUserId,
                      userName: widget.currentUserName,
                      userPhoto: widget.currentUserPhoto,
                      text: _commentController.text.trim(),
                      createdAt: DateTime.now(),
                    );

                    await widget.repository.addComment(comment);
                    _commentController.clear();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Action button for post actions
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppType.sans(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Comment item widget - TikTok style with user photos
class _CommentItem extends StatelessWidget {
  final Comment comment;
  final bool isDark;

  const _CommentItem({
    required this.comment,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar with user photo or initial
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: context.colors.brandGradient,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: (context.colors.accent).withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: comment.userPhoto != null && comment.userPhoto!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: CachedNetworkImage(
                      imageUrl: comment.userPhoto!,
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                      memCacheWidth: 108,
                      placeholder: (_, __) => Center(
                        child: Text(
                          comment.userName.isNotEmpty
                              ? comment.userName[0].toUpperCase()
                              : '?',
                          style: AppType.sans(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Center(
                        child: Text(
                          comment.userName.isNotEmpty
                              ? comment.userName[0].toUpperCase()
                              : '?',
                          style: AppType.sans(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      comment.userName.isNotEmpty
                          ? comment.userName[0].toUpperCase()
                          : '?',
                      style: AppType.sans(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 10),

          // Comment content - TikTok style bubble
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Username and time
                Row(
                  children: [
                    Text(
                      comment.userName,
                      style: AppType.sans(
                        color: context.colors.ink,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeago.format(comment.createdAt),
                      style: AppType.sans(
                        color: context.colors.inkMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Comment text
                Text(
                  comment.text,
                  style: AppType.sans(
                    color: context.colors.inkSoft,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
