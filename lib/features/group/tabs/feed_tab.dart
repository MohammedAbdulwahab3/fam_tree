import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/core/theme/elegant_theme.dart';
import 'package:family_tree/data/models/post.dart';
import 'package:family_tree/data/models/comment.dart';
import 'package:family_tree/data/repositories/group_repository.dart';
import 'package:family_tree/features/auth/providers/auth_provider.dart';
import 'package:family_tree/core/widgets/video_player_widget.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cached_network_image/cached_network_image.dart';

/// Provider for posts stream
final postsProvider = StreamProvider.family<List<Post>, String>((ref, familyTreeId) {
  final repository = GroupRepository();
  return repository.watchPosts(familyTreeId);
});

/// Feed tab showing all family posts
class FeedTab extends ConsumerStatefulWidget {
  final bool isDark;
  
  const FeedTab({super.key, this.isDark = true});

  @override
  ConsumerState<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends ConsumerState<FeedTab> {
  final GroupRepository _repository = GroupRepository();

  void _deletePost(String postId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: widget.isDark ? AppTheme.surfaceDark : ElegantColors.warmWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Post', style: GoogleFonts.playfairDisplay(
          color: widget.isDark ? AppTheme.textPrimary : ElegantColors.charcoal,
          fontWeight: FontWeight.w700,
        )),
        content: Text('Are you sure you want to delete this post?', 
          style: GoogleFonts.cormorantGaramond(
            color: widget.isDark ? AppTheme.textSecondary : ElegantColors.warmGray,
          )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.cormorantGaramond(
              color: widget.isDark ? AppTheme.textMuted : ElegantColors.warmGray,
            )),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: Text('Delete', style: GoogleFonts.cormorantGaramond(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _repository.deletePost(postId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    const familyTreeId = 'main-family-tree';
    final postsAsync = ref.watch(postsProvider(familyTreeId));

    return postsAsync.when(
      data: (posts) {
        if (posts.isEmpty) {
          return _buildEmptyState();
        }

        return RefreshIndicator(
          onRefresh: () async {
            // Force refresh by invalidating cache in repository
            await _repository.getPosts(forceRefresh: true);
            ref.invalidate(postsProvider(familyTreeId));
          },
          color: widget.isDark ? AppTheme.primaryLight : ElegantColors.terracotta,
          backgroundColor: widget.isDark ? AppTheme.surfaceDark : ElegantColors.warmWhite,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              final isOwnPost = post.userId == user?.uid;
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _PostCard(
                  post: post,
                  currentUserId: user?.uid ?? '',
                  isOwnPost: isOwnPost,
                  onDelete: () => _deletePost(post.id),
                  repository: _repository,
                  isDark: widget.isDark,
                ),
              );
            },
          ),
        );
      },
      loading: () => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
            ),
            const SizedBox(height: 16),
            Text('Loading posts...', style: GoogleFonts.inter(color: AppTheme.textMuted)),
          ],
        ),
      ),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppTheme.error.withOpacity(0.7)),
            const SizedBox(height: 16),
            Text('Error loading posts', style: GoogleFonts.inter(color: AppTheme.error, fontSize: 18)),
            const SizedBox(height: 8),
            Text('$error', style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.isDark 
                    ? [AppTheme.primaryLight.withOpacity(0.2), AppTheme.accentTeal.withOpacity(0.2)]
                    : [ElegantColors.terracotta.withOpacity(0.15), ElegantColors.sage.withOpacity(0.15)],
              ),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Icon(
              Icons.feed_outlined,
              size: 64,
              color: widget.isDark ? AppTheme.primaryLight : ElegantColors.terracotta,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No posts yet',
            style: GoogleFonts.playfairDisplay(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: widget.isDark ? AppTheme.textPrimary : ElegantColors.charcoal,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Posts from your family will appear here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 16,
              color: widget.isDark ? AppTheme.textSecondary : ElegantColors.warmGray,
            ),
          ),
        ],
      ),
    );
  }
}

/// Beautiful post card widget
class _PostCard extends StatefulWidget {
  final Post post;
  final String currentUserId;
  final bool isOwnPost;
  final VoidCallback onDelete;
  final GroupRepository repository;
  final bool isDark;

  const _PostCard({
    required this.post,
    required this.currentUserId,
    required this.isOwnPost,
    required this.onDelete,
    required this.repository,
    this.isDark = true,
  });

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> with SingleTickerProviderStateMixin {
  bool _showComments = false;
  bool _isLiked = false;
  final TextEditingController _commentController = TextEditingController();
  late AnimationController _likeAnimController;

  @override
  void initState() {
    super.initState();
    _likeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _isLiked = widget.post.reactions.containsKey(widget.currentUserId);
  }

  @override
  void dispose() {
    _commentController.dispose();
    _likeAnimController.dispose();
    super.dispose();
  }

  void _toggleLike() async {
    setState(() {
      _isLiked = !_isLiked;
    });
    _likeAnimController.forward().then((_) => _likeAnimController.reverse());
    await widget.repository.toggleReaction(widget.post.id, widget.currentUserId, '❤️');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.isDark 
            ? AppTheme.surfaceDark.withOpacity(0.8)
            : ElegantColors.warmWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.isDark 
              ? AppTheme.primaryLight.withOpacity(0.1)
              : ElegantColors.champagne,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.isDark 
                ? Colors.black.withOpacity(0.2)
                : ElegantColors.sienna.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
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
          if (widget.post.photos.isNotEmpty || widget.post.videos.isNotEmpty) _buildMedia(),
          
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
              gradient: widget.isDark ? AppTheme.primaryGradient : ElegantColors.warmGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: widget.isDark 
                      ? AppTheme.primaryLight.withOpacity(0.3)
                      : ElegantColors.terracotta.withOpacity(0.3),
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
                      placeholder: (_, __) => const Icon(Icons.person, color: Colors.white),
                      errorWidget: (_, __, ___) => const Icon(Icons.person, color: Colors.white),
                    ),
                  )
                : Center(
                    child: Text(
                      widget.post.userName.isNotEmpty ? widget.post.userName[0].toUpperCase() : '?',
                      style: GoogleFonts.inter(
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
                  style: GoogleFonts.playfairDisplay(
                    color: widget.isDark ? AppTheme.textPrimary : ElegantColors.charcoal,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 12, 
                      color: widget.isDark ? AppTheme.textMuted : ElegantColors.warmGray),
                    const SizedBox(width: 4),
                    Text(
                      timeago.format(widget.post.createdAt),
                      style: GoogleFonts.cormorantGaramond(
                        color: widget.isDark ? AppTheme.textMuted : ElegantColors.warmGray,
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
              icon: Icon(Icons.more_horiz, 
                color: widget.isDark ? AppTheme.textMuted : ElegantColors.warmGray),
              color: widget.isDark ? AppTheme.surfaceDark : ElegantColors.warmWhite,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (value) {
                if (value == 'delete') widget.onDelete();
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(Icons.delete_outline, color: AppTheme.error, size: 20),
                      const SizedBox(width: 8),
                      Text('Delete', style: GoogleFonts.cormorantGaramond(color: AppTheme.error)),
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
        style: GoogleFonts.cormorantGaramond(
          color: widget.isDark ? AppTheme.textPrimary : ElegantColors.charcoal,
          fontSize: 16,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildMedia() {
    final allMedia = [...widget.post.photos, ...widget.post.videos];
    
    if (allMedia.length == 1) {
      return _buildSingleMedia(allMedia.first, widget.post.videos.contains(allMedia.first));
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
            padding: EdgeInsets.only(right: index < allMedia.length - 1 ? 8 : 0),
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
                  color: AppTheme.surfaceDark,
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (_, __, ___) => Container(
                  height: 200,
                  color: AppTheme.surfaceDark,
                  child: const Icon(Icons.broken_image, color: AppTheme.textMuted, size: 48),
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
              color: Colors.white.withOpacity(0.2),
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
      placeholder: (_, __) => Container(
        width: 200,
        color: AppTheme.surfaceDark,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorWidget: (_, __, ___) => Container(
        width: 200,
        color: AppTheme.surfaceDark,
        child: const Icon(Icons.broken_image, color: AppTheme.textMuted),
      ),
    );
  }

  Widget _buildActions() {
    final likeCount = widget.post.reactions.length;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppTheme.primaryLight.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          // Like button
          _ActionButton(
            icon: _isLiked ? Icons.favorite : Icons.favorite_border,
            label: likeCount > 0 ? '$likeCount' : 'Like',
            color: _isLiked ? Colors.red : AppTheme.textMuted,
            onTap: _toggleLike,
          ),
          const SizedBox(width: 24),
          
          // Comment button
          _ActionButton(
            icon: Icons.chat_bubble_outline,
            label: 'Comment',
            color: AppTheme.textMuted,
            onTap: () => setState(() => _showComments = !_showComments),
          ),
          const SizedBox(width: 24),
          
          // Share button
          _ActionButton(
            icon: Icons.share_outlined,
            label: 'Share',
            color: AppTheme.textMuted,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark.withOpacity(0.5),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Comments list
          StreamBuilder<List<Comment>>(
            stream: widget.repository.watchComments(widget.post.id),
            builder: (context, snapshot) {
              final comments = snapshot.data ?? [];
              
              if (comments.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No comments yet. Be the first!',
                    style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13),
                  ),
                );
              }
              
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: comments.length > 3 ? 3 : comments.length,
                itemBuilder: (context, index) {
                  final comment = comments[index];
                  return _CommentItem(comment: comment);
                },
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
                    color: AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.primaryLight.withOpacity(0.2)),
                  ),
                  child: TextField(
                    controller: _commentController,
                    style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Write a comment...',
                      hintStyle: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: () async {
                    if (_commentController.text.trim().isEmpty) return;
                    
                    final comment = Comment(
                      id: '',
                      postId: widget.post.id,
                      userId: widget.currentUserId,
                      userName: 'You', // This should come from auth
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
              style: GoogleFonts.inter(
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

/// Comment item widget
class _CommentItem extends StatelessWidget {
  final Comment comment;

  const _CommentItem({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                comment.userName.isNotEmpty ? comment.userName[0].toUpperCase() : '?',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(width: 10),
          
          // Comment content
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        comment.userName,
                        style: GoogleFonts.inter(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeago.format(comment.createdAt),
                        style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    comment.text,
                    style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
