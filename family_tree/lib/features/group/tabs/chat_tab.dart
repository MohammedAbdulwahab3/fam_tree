
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/core/theme/elegant_theme.dart';
import 'package:family_tree/core/widgets/video_player_widget.dart';
import 'package:family_tree/core/widgets/full_screen_image_viewer.dart';
import 'package:family_tree/data/models/message.dart';
import 'package:family_tree/data/repositories/group_repository.dart';
import 'package:family_tree/data/services/storage_service.dart';
import 'package:family_tree/features/auth/providers/auth_provider.dart';
import 'package:google_fonts/google_fonts.dart' hide Config;
import 'package:intl/intl.dart';
import 'package:family_tree/providers/admin_provider.dart';

/// Provider for messages stream
final messagesProvider = StreamProvider.family<List<Message>, String>((ref, familyTreeId) {
  final repository = GroupRepository();
  return repository.watchMessages(familyTreeId);
});

/// Chat tab for family messaging
class ChatTab extends ConsumerStatefulWidget {
  final bool isDark;
  
  const ChatTab({Key? key, this.isDark = true}) : super(key: key);

  @override
  ConsumerState<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends ConsumerState<ChatTab> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GroupRepository _repository = GroupRepository();
  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  bool _showEmojiPicker = false;
  Message? _replyingTo;
  int _lastMessageCount = 0;
  bool _isFirstLoad = true;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia({required bool isVideo, required ImageSource source}) async {
    try {
      final XFile? pickedFile = isVideo
          ? await _picker.pickVideo(source: source)
          : await _picker.pickImage(source: source, imageQuality: 70);

      if (pickedFile == null) return;

      setState(() => _isUploading = true);

      // Use XFile directly
      final bytes = await pickedFile.readAsBytes();
      final fileName = pickedFile.name;
      
      final url = isVideo
          ? await _storageService.uploadVideo(fileName, bytes)
          : await _storageService.uploadImage(fileName, bytes);

      if (url == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Media upload failed. Storage might not be enabled.')),
          );
        }
        return;
      }

      await _sendMessage(
        text: isVideo ? '🎥 Video' : '📷 Photo',
        type: isVideo ? 'video' : 'image',
        mediaUrl: url,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending media: $e')),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt, color: AppTheme.primaryLight),
            title: const Text('Take Photo', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              _pickMedia(isVideo: false, source: ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.image, color: AppTheme.primaryLight),
            title: const Text('Choose Photo', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              _pickMedia(isVideo: false, source: ImageSource.gallery);
            },
          ),
          ListTile(
            leading: const Icon(Icons.videocam, color: AppTheme.primaryLight),
            title: const Text('Record Video', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              _pickMedia(isVideo: true, source: ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.video_library, color: AppTheme.primaryLight),
            title: const Text('Choose Video', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              _pickMedia(isVideo: true, source: ImageSource.gallery);
            },
          ),
          const SizedBox(height: AppTheme.spaceMd),
        ],
      ),
    );
  }

  Future<void> _sendMessage({String? text, String type = 'text', String? mediaUrl}) async {
    final messageText = text ?? _messageController.text.trim();
    if (messageText.isEmpty && mediaUrl == null) return;

    final user = ref.read(authStateProvider).value;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to send messages')),
      );
      return;
    }

    // Use consistent family tree ID
    const familyTreeId = 'main-family-tree';

    final message = Message(
      id: '',
      familyTreeId: familyTreeId,
      userId: user.uid,
      userName: user.displayName ?? 'Anonymous',
      userPhoto: user.photoURL,
      text: messageText,
      sentAt: DateTime.now(),
      type: type,
      mediaUrl: mediaUrl,
    );

    _messageController.clear();
    
    try {
      await _repository.sendMessage(message);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e'), backgroundColor: AppTheme.error),
        );
      }
    }

    // Scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final userRole = ref.watch(userRoleProvider);
    final isAdmin = userRole.value?.isAdmin ?? false;
    const familyTreeId = 'main-family-tree';
    final messagesAsync = ref.watch(messagesProvider(familyTreeId));

    return Column(
      children: [
        // Messages list
        Expanded(
          child: messagesAsync.when(
            data: (messages) {
              if (messages.isEmpty) {
                return _buildEmptyState();
              }

              // Only auto-scroll to bottom on first load or when new messages arrive
              // Don't scroll when user is viewing older messages
              if (messages.isNotEmpty) {
                final hasNewMessages = messages.length > _lastMessageCount;
                final shouldAutoScroll = _isFirstLoad || hasNewMessages;
                
                if (shouldAutoScroll) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients) {
                      // Check if user is near the bottom before scrolling
                      final position = _scrollController.position;
                      final isNearBottom = position.pixels >= position.maxScrollExtent - 100 || _isFirstLoad;
                      
                      if (isNearBottom) {
                        _scrollController.animateTo(
                          position.maxScrollExtent,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      }
                    }
                    _isFirstLoad = false;
                  });
                }
                _lastMessageCount = messages.length;
              }

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(AppTheme.spaceMd),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  final isOwnMessage = message.userId == user?.uid;
                  return _buildMessageBubble(message, isOwnMessage, isAdmin);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Text(
                'Error loading messages: $error',
                style: GoogleFonts.inter(color: AppTheme.error),
              ),
            ),
          ),
        ),

          // Reply bar (when replying to a message)
          if (_replyingTo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceSm),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark.withValues(alpha: 0.8),
                border: Border(
                  left: BorderSide(color: AppTheme.primaryLight, width: 3),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Replying to ${_replyingTo!.userName}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryLight,
                          ),
                        ),
                        Text(
                          _replyingTo!.text.length > 50 
                              ? '${_replyingTo!.text.substring(0, 50)}...' 
                              : _replyingTo!.text,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _replyingTo = null),
                    icon: const Icon(Icons.close, color: AppTheme.textMuted, size: 18),
                  ),
                ],
              ),
            ),

          // Message input
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark.withValues(alpha: 0.5),
              border: Border(
                top: BorderSide(color: AppTheme.primaryLight.withValues(alpha: 0.2)),
              ),
            ),
            child: Column(
              children: [
                if (_isUploading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: AppTheme.spaceSm),
                    child: LinearProgressIndicator(),
                  ),
                Row(
                  children: [
                    // Attachment button
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryLight),
                      onPressed: _showAttachmentOptions,
                    ),
                    // Emoji button
                    IconButton(
                      icon: Icon(
                        _showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions_outlined,
                        color: AppTheme.primaryLight,
                      ),
                      onPressed: () {
                        setState(() => _showEmojiPicker = !_showEmojiPicker);
                      },
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        onTap: () {
                          if (_showEmojiPicker) {
                            setState(() => _showEmojiPicker = false);
                          }
                        },
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: GoogleFonts.inter(color: AppTheme.textMuted),
                          filled: true,
                          fillColor: AppTheme.surfaceDark,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spaceMd,
                            vertical: AppTheme.spaceSm,
                          ),
                        ),
                        style: GoogleFonts.inter(color: AppTheme.textPrimary),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceSm),
                    Container(
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                      ),
                      child: IconButton(
                        onPressed: () => _sendMessage(),
                        icon: const Icon(Icons.send, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Emoji Picker Panel
          if (_showEmojiPicker)
            SizedBox(
              height: 250,
              child: EmojiPicker(
                onEmojiSelected: (category, emoji) {
                  _messageController.text += emoji.emoji;
                  _messageController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _messageController.text.length),
                  );
                },
                config: Config(
                  height: 250,
                  checkPlatformCompatibility: true,
                  emojiViewConfig: EmojiViewConfig(
                    backgroundColor: AppTheme.surfaceDark,
                    columns: 8,
                    emojiSizeMax: 28,
                  ),
                  categoryViewConfig: CategoryViewConfig(
                    backgroundColor: AppTheme.surfaceDark,
                    indicatorColor: AppTheme.primaryLight,
                    iconColorSelected: AppTheme.primaryLight,
                    iconColor: AppTheme.textMuted,
                  ),
                  bottomActionBarConfig: const BottomActionBarConfig(
                    enabled: false,
                  ),
                  searchViewConfig: SearchViewConfig(
                    backgroundColor: AppTheme.surfaceDark,
                    buttonIconColor: AppTheme.textMuted,
                  ),
                ),
              ),
            ),
      ],
    );
  }

  Widget _buildMessageBubble(Message message, bool isOwnMessage, bool isAdmin) {
    final heroTag = 'chat_image_${message.id}';
    
    return GestureDetector(
      onLongPress: () => _showMessageOptions(message, isOwnMessage, isAdmin),
      onHorizontalDragEnd: (details) {
        // Swipe right to reply
        if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
          setState(() => _replyingTo = message);
        }
      },
      child: Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
      child: Row(
        mainAxisAlignment: isOwnMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isOwnMessage) ...[
            // Other user's avatar
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
              child: message.userPhoto != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                      child: Image.network(message.userPhoto!, fit: BoxFit.cover),
                    )
                  : const Icon(Icons.person, color: Colors.white, size: 16),
            ),
            const SizedBox(width: AppTheme.spaceXs),
          ],

          // Message bubble
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(AppTheme.spaceSm),
              decoration: BoxDecoration(
                gradient: isOwnMessage
                    ? AppTheme.primaryGradient
                    : null,
                color: isOwnMessage ? null : AppTheme.surfaceDark,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isOwnMessage ? AppTheme.radiusMd : 0),
                  topRight: Radius.circular(isOwnMessage ? 0 : AppTheme.radiusMd),
                  bottomLeft: Radius.circular(AppTheme.radiusMd),
                  bottomRight: Radius.circular(AppTheme.radiusMd),
                ),
              ),
              child: Column(
                crossAxisAlignment:isOwnMessage
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (!isOwnMessage)
                    Text(
                      message.userName,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryLight,
                      ),
                    ),
                  
                  // Media content
                  if (message.type == 'image' && message.mediaUrl != null)
                    GestureDetector(
                      onTap: () => FullScreenImageViewer.show(
                        context, 
                        message.mediaUrl!,
                        heroTag: heroTag,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(top: AppTheme.spaceXs, bottom: AppTheme.spaceXs),
                        child: Hero(
                          tag: heroTag,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                            child: Image.network(
                              message.mediaUrl!,
                              width: 200,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  width: 200,
                                  height: 150,
                                  color: Colors.black12,
                                  child: const Center(child: CircularProgressIndicator()),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 200,
                                  height: 150,
                                  color: Colors.black12,
                                  child: const Center(child: Icon(Icons.broken_image, color: Colors.white)),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    )
                  else if (message.type == 'video' && message.mediaUrl != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppTheme.spaceXs, bottom: AppTheme.spaceXs),
                      child: SizedBox(
                        width: 200,
                        height: 150,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                          child: VideoPlayerWidget(videoUrl: message.mediaUrl!),
                        ),
                      ),
                    ),

                  if (message.text.isNotEmpty)
                    Text(
                      message.text,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: isOwnMessage ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                  const SizedBox(height: AppTheme.spaceXs),
                  Text(
                    DateFormat('HH:mm').format(message.sentAt),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: isOwnMessage
                          ? Colors.white.withValues(alpha: 0.7)
                          : AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (isOwnMessage)
            const SizedBox(width: AppTheme.spaceXs),
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
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: AppTheme.textMuted,
          ),
          const SizedBox(height: AppTheme.spaceMd),
          Text(
            'No messages yet',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Text(
            'Start the conversation!',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _showMessageOptions(Message message, bool isOwnMessage, bool isAdmin) {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDark ? AppTheme.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Copy (for text messages, available to everyone)
          if (message.type == 'text' && message.text.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.copy_rounded, color: AppTheme.primaryLight),
              title: Text('Copy', style: TextStyle(color: widget.isDark ? Colors.white : Colors.black)),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.text));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Message copied'),
                    duration: Duration(seconds: 1),
                    backgroundColor: AppTheme.success,
                  ),
                );
              },
            ),
          
          // Reply (available to everyone)
          ListTile(
            leading: const Icon(Icons.reply_rounded, color: AppTheme.primaryLight),
            title: Text('Reply', style: TextStyle(color: widget.isDark ? Colors.white : Colors.black)),
            onTap: () {
              Navigator.pop(context);
              setState(() => _replyingTo = message);
            },
          ),
          
          // Edit (only for own text messages)
          if (isOwnMessage && message.type == 'text')
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: AppTheme.primaryLight),
              title: Text('Edit', style: TextStyle(color: widget.isDark ? Colors.white : Colors.black)),
              onTap: () {
                Navigator.pop(context);
                _showEditMessageDialog(message);
              },
            ),
          
          // Delete (for own messages or admins)
          if (isOwnMessage || isAdmin)
            ListTile(
              leading: const Icon(Icons.delete_rounded, color: Colors.red),
              title: Text('Delete', style: TextStyle(color: widget.isDark ? Colors.white : Colors.black)),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteMessage(message);
              },
            ),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showEditMessageDialog(Message message) {
    final controller = TextEditingController(text: message.text);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: widget.isDark ? AppTheme.surfaceDark : Colors.white,
        title: Text('Edit Message', style: TextStyle(color: widget.isDark ? Colors.white : Colors.black)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
          style: TextStyle(color: widget.isDark ? Colors.white : Colors.black),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              
              try {
                final updatedMessage = message.copyWith(text: controller.text.trim());
                await _repository.updateMessage(updatedMessage);
                if (mounted) Navigator.pop(context);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating message: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteMessage(Message message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: widget.isDark ? AppTheme.surfaceDark : Colors.white,
        title: Text('Delete Message', style: TextStyle(color: widget.isDark ? Colors.white : Colors.black)),
        content: Text(
          'Are you sure you want to delete this message?',
          style: TextStyle(color: widget.isDark ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await _repository.deleteMessage(message.id);
                if (mounted) Navigator.pop(context);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting message: $e')),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
