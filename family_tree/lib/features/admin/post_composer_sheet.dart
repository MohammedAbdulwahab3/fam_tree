import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/core/theme/app_colors.dart';
import 'package:family_tree/core/theme/elegant_theme.dart';
import 'package:family_tree/core/utils/platform_image_picker.dart';
import 'package:family_tree/data/services/storage_service.dart';
import 'package:family_tree/core/design/typography.dart';

/// One attachment the author has staged but not yet published.
class ComposerAttachment {
  ComposerAttachment({
    required this.name,
    required this.bytes,
    required this.kind,
  });

  final String name;
  final Uint8List bytes;
  final AttachmentKind kind;

  /// Filled in once the bytes reach the server.
  String? uploadedUrl;
  bool uploading = false;
  String? error;

  String get readableSize {
    final kb = bytes.lengthInBytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }
}

enum AttachmentKind { photo, video, file }

/// The result of composing a post: text plus everything that was uploaded.
class ComposedPost {
  const ComposedPost({
    required this.content,
    required this.photos,
    required this.videos,
    required this.files,
  });

  final String content;
  final List<String> photos;
  final List<String> videos;
  final List<String> files;
}

/// A real composer for family posts.
///
/// The old dialog was a bare textarea that hardcoded `photos`, `videos` and
/// `files` to empty — the [Post] model has always carried all three, so posting
/// a photo to the family feed was simply impossible from the admin page.
///
/// Attachments upload as they are added rather than on submit, so a slow
/// connection shows progress per item instead of one long freeze at the end,
/// and a single failed upload does not lose the written text.
class PostComposerSheet extends StatefulWidget {
  const PostComposerSheet({super.key, required this.authorName});

  final String authorName;

  static Future<ComposedPost?> show(
    BuildContext context, {
    required String authorName,
  }) {
    return showModalBottomSheet<ComposedPost>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PostComposerSheet(authorName: authorName),
    );
  }

  @override
  State<PostComposerSheet> createState() => _PostComposerSheetState();
}

class _PostComposerSheetState extends State<PostComposerSheet> {
  final TextEditingController _content = TextEditingController();
  final List<ComposerAttachment> _attachments = [];
  final StorageService _storage = StorageService();

  bool _publishing = false;
  String? _error;

  /// Anything larger than this is refused up front rather than failing halfway
  /// through an upload.
  static const int _maxBytes = 25 * 1024 * 1024;

  @override
  void initState() {
    super.initState();
    _content.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  bool get _busy => _attachments.any((a) => a.uploading);
  bool get _hasFailures => _attachments.any((a) => a.error != null);

  bool get _canPublish =>
      !_publishing &&
      !_busy &&
      (_content.text.trim().isNotEmpty || _attachments.isNotEmpty);

  Future<void> _addPhotos() async {
    final picked = await PlatformImagePicker().pickMultipleImages();
    for (final file in picked) {
      _stage(file.name, file.bytes, AttachmentKind.photo);
    }
  }

  Future<void> _addVideo() async {
    final picked = await PlatformImagePicker().pickVideo();
    if (picked != null) {
      _stage(picked.name, picked.bytes, AttachmentKind.video);
    }
  }

  Future<void> _addFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    for (final file in result?.files ?? const <PlatformFile>[]) {
      final bytes = file.bytes;
      if (bytes == null) continue;
      _stage(file.name, bytes, AttachmentKind.file);
    }
  }

  void _stage(String name, Uint8List bytes, AttachmentKind kind) {
    if (bytes.lengthInBytes > _maxBytes) {
      setState(() => _error = '"$name" is larger than 25 MB and was skipped.');
      return;
    }
    final attachment = ComposerAttachment(name: name, bytes: bytes, kind: kind);
    setState(() {
      _attachments.add(attachment);
      _error = null;
    });
    _upload(attachment);
  }

  Future<void> _upload(ComposerAttachment attachment) async {
    setState(() {
      attachment.uploading = true;
      attachment.error = null;
    });
    try {
      final url = await _storage.uploadFile(attachment.name, attachment.bytes);
      if (!mounted) return;
      setState(() {
        attachment.uploading = false;
        if (url == null || url.isEmpty) {
          attachment.error = 'Upload failed';
        } else {
          attachment.uploadedUrl = url;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        attachment.uploading = false;
        attachment.error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _publish() {
    if (!_canPublish) return;

    if (_hasFailures) {
      setState(() => _error =
          'Some attachments did not upload. Retry or remove them first.');
      return;
    }

    setState(() => _publishing = true);
    List<String> urlsOf(AttachmentKind kind) => _attachments
        .where((a) => a.kind == kind && a.uploadedUrl != null)
        .map((a) => a.uploadedUrl!)
        .toList();

    Navigator.pop(
      context,
      ComposedPost(
        content: _content.text.trim(),
        photos: urlsOf(AttachmentKind.photo),
        videos: urlsOf(AttachmentKind.video),
        files: urlsOf(AttachmentKind.file),
      ),
    );
  }

  Future<bool> _confirmDiscard() async {
    if (_content.text.trim().isEmpty && _attachments.isEmpty) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Discard this post?',
            style: AppType.sans(fontWeight: FontWeight.w700)),
        content: Text(
          'What you have written and attached will be lost.',
          style: AppType.sans(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep writing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.accentRose),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmDiscard() && mounted) navigator.pop();
      },
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scroll) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [AppTheme.surfaceDark, AppTheme.backgroundDark]
                  : [ElegantColors.warmWhite, ElegantColors.cream],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            children: [
              _handle(isDark),
              _header(isDark),
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  children: [
                    _editor(isDark),
                    const SizedBox(height: 14),
                    _attachBar(isDark),
                    if (_attachments.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _attachmentList(isDark),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      _errorBox(isDark),
                    ],
                  ],
                ),
              ),
              _publishBar(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _handle(bool isDark) => Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(top: 12, bottom: 4),
        decoration: BoxDecoration(
          color: context.colors.hairline,
          borderRadius: BorderRadius.circular(2),
        ),
      );

  Widget _header(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'New post',
                  style: AppType.sans(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: context.colors.ink,
                  ),
                ),
                Text(
                  'Posting as ${widget.authorName} · the whole family sees this',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.sans(
                    fontSize: 13.5,
                    color: context.colors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: () async {
              final navigator = Navigator.of(context);
              if (await _confirmDiscard() && mounted) navigator.pop();
            },
            icon: Icon(Icons.close_rounded, color: context.colors.inkSoft),
          ),
        ],
      ),
    );
  }

  Widget _editor(bool isDark) {
    final accent = context.colors.accent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        TextField(
          controller: _content,
          autofocus: true,
          minLines: 5,
          maxLines: 12,
          maxLength: 5000,
          style: AppType.sans(
            fontSize: 15,
            height: 1.45,
            color: context.colors.ink,
          ),
          decoration: InputDecoration(
            hintText: 'Share news, a memory, or a photo with the family…',
            hintStyle: AppType.sans(
              fontSize: 15,
              color: context.colors.inkMuted,
            ),
            counterText: '',
            filled: true,
            fillColor: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : ElegantColors.warmWhite,
            contentPadding: const EdgeInsets.all(16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : ElegantColors.champagne,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : ElegantColors.champagne,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: accent, width: 1.6),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, right: 4),
          child: Text(
            '${_content.text.characters.length} / 5000',
            style: AppType.sans(
              fontSize: 11,
              color: _content.text.characters.length > 4800
                  ? AppTheme.accentRose
                  : (context.colors.inkMuted),
            ),
          ),
        ),
      ],
    );
  }

  Widget _attachBar(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _attachButton(
            icon: Icons.photo_library_rounded,
            label: 'Photos',
            color: context.colors.secondary,
            isDark: isDark,
            onTap: _addPhotos,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _attachButton(
            icon: Icons.videocam_rounded,
            label: 'Video',
            color: context.colors.rose,
            isDark: isDark,
            onTap: _addVideo,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _attachButton(
            icon: Icons.attach_file_rounded,
            label: 'File',
            color: context.colors.gold,
            isDark: isDark,
            onTap: _addFile,
          ),
        ),
      ],
    );
  }

  Widget _attachButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _publishing ? null : onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.14 : 0.1),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 5),
              Text(
                label,
                style: AppType.sans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.colors.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _attachmentList(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_attachments.length} attachment'
          '${_attachments.length == 1 ? '' : 's'}',
          style: AppType.sans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: context.colors.inkMuted,
          ),
        ),
        const SizedBox(height: 10),
        ..._attachments.map((a) => _attachmentTile(a, isDark)),
      ],
    );
  }

  Widget _attachmentTile(ComposerAttachment attachment, bool isDark) {
    final tone = switch (attachment.kind) {
      AttachmentKind.photo => context.colors.secondary,
      AttachmentKind.video => context.colors.rose,
      AttachmentKind.file => context.colors.gold,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : ElegantColors.warmWhite,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: attachment.error != null
              ? AppTheme.accentRose.withValues(alpha: 0.5)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.09)
                  : ElegantColors.champagne),
        ),
      ),
      child: Row(
        children: [
          // Photos preview from the staged bytes, so what you see is exactly
          // what will be published.
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: SizedBox(
              width: 44,
              height: 44,
              child: attachment.kind == AttachmentKind.photo
                  ? Image.memory(attachment.bytes, fit: BoxFit.cover)
                  : Container(
                      color: tone.withValues(alpha: 0.15),
                      child: Icon(
                        attachment.kind == AttachmentKind.video
                            ? Icons.movie_rounded
                            : Icons.description_rounded,
                        color: tone,
                        size: 21,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.sans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: context.colors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                if (attachment.uploading)
                  Row(
                    children: [
                      SizedBox(
                        width: 11,
                        height: 11,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.8, color: tone),
                      ),
                      const SizedBox(width: 7),
                      Text('Uploading…',
                          style: AppType.sans(fontSize: 11.5, color: tone)),
                    ],
                  )
                else if (attachment.error != null)
                  Text(
                    attachment.error!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.sans(
                        fontSize: 11.5, color: AppTheme.accentRose),
                  )
                else
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          size: 12, color: AppTheme.success),
                      const SizedBox(width: 5),
                      Text(
                        attachment.readableSize,
                        style: AppType.sans(
                          fontSize: 11.5,
                          color:
                              isDark ? Colors.white54 : ElegantColors.warmGray,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (attachment.error != null)
            IconButton(
              tooltip: 'Retry',
              icon: const Icon(Icons.refresh_rounded, size: 18),
              onPressed: () => _upload(attachment),
            ),
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: () => setState(() => _attachments.remove(attachment)),
          ),
        ],
      ),
    );
  }

  Widget _errorBox(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.accentRose.withValues(alpha: isDark ? 0.14 : 0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentRose.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 17, color: AppTheme.accentRose),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: AppType.sans(
                fontSize: 12.5,
                height: 1.35,
                color: context.colors.inkSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _publishBar(bool isDark) {
    final accent = context.colors.accent;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : ElegantColors.warmWhite,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : ElegantColors.champagne,
          ),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _canPublish ? _publish : null,
          icon: _publishing || _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.send_rounded, size: 18),
          label: Text(
            _busy
                ? 'Waiting for uploads…'
                : _publishing
                    ? 'Posting…'
                    : 'Post to the family feed',
            style: AppType.sans(fontWeight: FontWeight.w600),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}
