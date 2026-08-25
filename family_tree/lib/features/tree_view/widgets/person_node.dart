import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:family_tree/core/localization/person_localization.dart';
import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/core/theme/app_colors.dart';
import 'package:family_tree/data/models/person.dart';
import 'package:family_tree/features/tree_view/services/tree_layout_service.dart';
import 'package:family_tree/core/design/typography.dart';

enum PersonNodeVariant { classic, modernWide, treePlaque }

/// Person node used across the different family tree layouts.
class PersonNode extends StatefulWidget {
  static const double classicWidth = 140.0;

  static const double classicHeight = 160.0;
  static const double modernWidth = TreeLayoutService.nodeWidth;
  static const double modernHeight = TreeLayoutService.nodeHeight;
  static const double treePlaqueWidth = 220.0;
  static const double treePlaqueHeight = 110.0;

  final Person person;
  final int generation;
  final bool isSelected;
  final bool isFocused;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onAddChildTapped;
  final double scale;
  final Color? color;
  final bool isDimmed;
  final PersonNodeVariant variant;

  const PersonNode({
    super.key,
    required this.person,
    this.generation = 0,
    this.isSelected = false,
    this.isFocused = true,
    this.isDimmed = false,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onAddChildTapped,
    this.scale = 1.0,
    this.color,
    this.variant = PersonNodeVariant.classic,
  });

  @override
  State<PersonNode> createState() => _PersonNodeState();
}

class _PersonNodeState extends State<PersonNode>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  void _onHoverChanged(bool hovering) {
    setState(() => _isHovered = hovering);
    if (hovering) {
      _hoverController.forward();
    } else {
      _hoverController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final targetOpacity = widget.isDimmed ? 0.45 : 1.0;

    return MouseRegion(
      onEnter: (_) => _onHoverChanged(true),
      onExit: (_) => _onHoverChanged(false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        onLongPress: widget.onLongPress,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value * widget.scale,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: targetOpacity,
                child: widget.isDimmed
                    ? ColorFiltered(
                        colorFilter: ColorFilter.mode(
                          isDark ? Colors.grey.shade700 : Colors.grey.shade400,
                          BlendMode.saturation,
                        ),
                        child: child,
                      )
                    : child,
              ),
            );
          },
          child: widget.variant == PersonNodeVariant.treePlaque
              ? _buildTreePlaque(context)
              : widget.variant == PersonNodeVariant.modernWide
                  ? _buildModernWideCard(context)
                  : _buildClassicCard(context),
        ),
      ),
    );
  }

  /// Warm stone. A remembered person is drawn in aged sepia rather than their
  /// generation's colour — it reads across the whole tree at a glance without
  /// resorting to anything grim.
  static const Color _memorialAccent = Color(0xFF9C8B7A);

  /// The colour this card is drawn in.
  Color get _accentColor {
    if (widget.person.isDeceased) return _memorialAccent;
    return widget.color ?? AppTheme.getGenerationColor(widget.generation);
  }

  Widget _buildModernWideCard(BuildContext context) {
    final generationColor = _accentColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lifespan = widget.person.localizedLifespan(context);
    final nameStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: context.colors.ink,
          letterSpacing: 0.1,
          height: 1.1,
          shadows: isDark
              ? [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        );

    return Container(
      width: PersonNode.modernWidth,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: _isHovered || widget.isSelected
            ? [
                BoxShadow(
                  color: generationColor.withValues(alpha: 0.4),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
                ...AppTheme.shadowMd,
              ]
            : AppTheme.shadowSm,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: PersonNode.modernHeight,
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? AppTheme.primaryLight.withValues(alpha: isDark ? 0.2 : 0.15)
                  : (context.colors.surfaceRaised)
                      .withValues(alpha: isDark ? 0.7 : 0.9),
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              border: Border.all(
                color: widget.isSelected
                    ? AppTheme.primaryLight
                    : generationColor.withValues(alpha: 0.5),
                width: widget.isSelected ? 2.5 : 1.5,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.isSelected
                    ? [
                        AppTheme.primaryLight.withValues(alpha: 0.25),
                        AppTheme.primaryLight.withValues(alpha: 0.1),
                      ]
                    : [
                        (context.colors.ink).withValues(alpha: 0.05),
                        (context.colors.ink).withValues(alpha: 0.02),
                      ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: LinearGradient(
                      colors: [
                        generationColor,
                        generationColor.withValues(alpha: 0.65),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 54,
                  child: Center(
                    child: Text(
                      widget.person.localizedFullName(context),
                      style: nameStyle,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        alignment: WrapAlignment.center,
                        children: [
                          if (lifespan.isNotEmpty)
                            _buildMetaChip(
                              icon: Icons.schedule_rounded,
                              label: lifespan,
                              accent: generationColor,
                            ),
                          if (_hasSpouse) _buildModernRelationshipBadge(),
                          if (widget.person.isDeceased)
                            _buildMetaChip(
                              icon: Icons.local_florist_rounded,
                              label: 'In memory',
                              accent: generationColor,
                            ),
                        ],
                      ),
                    ),
                    if (widget.onAddChildTapped != null) ...[
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: widget.onAddChildTapped,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryLight.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryLight.withValues(
                                  alpha: 0.35,
                                ),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.add,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTreePlaque(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor =
        widget.isSelected ? const Color(0xFF5B3B1F) : const Color(0xFF6B5037);
    final shadowColor = widget.isSelected
        ? const Color(0xFF5B3B1F).withValues(alpha: 0.28)
        : Colors.black.withValues(alpha: 0.12);

    return Container(
      width: PersonNode.treePlaqueWidth,
      height: PersonNode.treePlaqueHeight,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A231D) : const Color(0xFFF8F0DF),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: borderColor, width: widget.isSelected ? 2.4 : 2),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: widget.isSelected || _isHovered ? 14 : 8,
            offset: const Offset(0, 4),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [
                  const Color(0xFF352C24),
                  const Color(0xFF241E18),
                ]
              : [
                  const Color(0xFFF9F3E5),
                  const Color(0xFFF1E5CF),
                ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Text(
            widget.person.localizedFullName(context),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppType.sans(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              height: 1.15,
              color: isDark ? const Color(0xFFF6E7C4) : const Color(0xFF4F3724),
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClassicCard(BuildContext context) {
    final generationColor = _accentColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: PersonNode.classicWidth,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: _isHovered || widget.isSelected
            ? [
                BoxShadow(
                  color: generationColor.withValues(alpha: 0.4),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
                ...AppTheme.shadowMd,
              ]
            : AppTheme.shadowSm,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.all(AppTheme.spaceSm),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? AppTheme.primaryLight.withValues(alpha: isDark ? 0.2 : 0.15)
                  : (context.colors.surfaceRaised)
                      .withValues(alpha: isDark ? 0.7 : 0.9),
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              border: Border.all(
                color: widget.isSelected
                    ? AppTheme.primaryLight
                    : generationColor.withValues(alpha: 0.5),
                width: widget.isSelected ? 2.5 : 1.5,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.isSelected
                    ? [
                        AppTheme.primaryLight.withValues(alpha: 0.25),
                        AppTheme.primaryLight.withValues(alpha: 0.1),
                      ]
                    : [
                        (context.colors.ink).withValues(alpha: 0.05),
                        (context.colors.ink).withValues(alpha: 0.02),
                      ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildProfilePhoto(generationColor, context),
                // Above the name rather than below it: the canvas draws the
                // expand-descendants control over the bottom edge of the card,
                // which sat squarely on top of the spouse's name.
                if (_hasSpouse) ...[
                  const SizedBox(height: AppTheme.spaceXs),
                  _buildRelationshipBadge(context),
                ],
                const SizedBox(height: AppTheme.spaceSm),
                SizedBox(
                  height: 40,
                  child: Text(
                    widget.person.localizedFullName(context),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppTheme.textPrimaryDark
                              : AppTheme.textPrimaryLight,
                          letterSpacing: 0.3,
                          height: 1.2,
                          shadows: isDark
                              ? [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    blurRadius: 2,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.onAddChildTapped != null) ...[
                  const SizedBox(height: AppTheme.spaceSm),
                  GestureDetector(
                    onTap: widget.onAddChildTapped,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePhoto(Color ringColor, BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                ringColor,
                ringColor.withValues(alpha: 0.6),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.colors.surfaceRaised,
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: ClipOval(
                  child: _buildPhoto(context),
                ),
              ),
            ),
          ),
        ),
        if (widget.person.isDeceased)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.backgroundDark,
                shape: BoxShape.circle,
                border: Border.all(color: _memorialAccent, width: 1),
              ),
              child: const Icon(
                Icons.local_florist_rounded,
                size: 12,
                color: _memorialAccent,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPhoto(BuildContext context) {
    final photo = _buildPhotoRaw(context);
    if (!widget.person.isDeceased) return photo;
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        0.393,
        0.769,
        0.189,
        0,
        0,
        0.349,
        0.686,
        0.168,
        0,
        0,
        0.272,
        0.534,
        0.131,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ]),
      child: photo,
    );
  }

  /// Decode width for node avatars. Generous enough for a 3x display of the
  /// largest avatar the canvas draws, and a fraction of a source photo.
  static const int _avatarDecodeWidth = 240;

  /// Fills whatever the caller gives it.
  ///
  /// This used to hardcode 64x64 while the avatar ring only leaves 60x60
  /// inside its padding, so every photo was laid out slightly larger than the
  /// circle clipping it — the reason faces sat cropped and off-centre.
  Widget _buildPhotoRaw(BuildContext context) {
    final url = widget.person.profilePhotoUrl;
    if (url == null || url.isEmpty) return _buildPlaceholder(context);

    return SizedBox.expand(
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        // Centre the crop on the upper part of the frame: portraits put the
        // face above the middle, and a dead-centre cover crop clips foreheads.
        alignment: const Alignment(0, -0.2),
        // Decode to roughly the size actually drawn. Without this every node
        // held a full-resolution bitmap in memory — a tree of two hundred
        // people meant hundreds of megabytes for circles 60 pixels across.
        memCacheWidth: _avatarDecodeWidth,
        placeholder: (context, url) => _buildPlaceholder(context),
        errorWidget: (context, url, error) => _buildPlaceholder(context),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    // Initials on a tinted disc, in the current theme. This used to be
    // hardcoded `AppTheme.surfaceDark` with light text, so in light mode every
    // person without a photo showed as a black circle — which reads as a photo
    // that failed to load rather than as a placeholder.
    final colors = context.colors;

    return Container(
      color: colors.surfaceRaised,
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Text(
            widget.person.localizedInitials(context),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: colors.inkSoft,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRelationshipBadge(BuildContext context) {
    final icon = _spouseIcon;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.accentTeal.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: AppTheme.accentTeal),
          const SizedBox(width: 2),
          Flexible(
            child: Text(
              _spouseLabel(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                color: AppTheme.accentTeal,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip({
    required IconData icon,
    String? label,
    required Color accent,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: label == null ? 8 : 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: accent),
          if (label != null) ...[
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Somebody is shown as married if either the tree records the marriage or
  /// their record simply names a spouse. Most people who marry into a family
  /// never get a record of their own, so keying this off the link alone left
  /// the commonest case invisible on the canvas.
  bool get _hasSpouse =>
      widget.person.relationships.spouses.isNotEmpty ||
      (widget.person.spouseName?.trim().isNotEmpty ?? false);

  /// The linked spouse's relationship word, or the name written on the record.
  String _spouseLabel(BuildContext context) {
    final spouses = widget.person.relationships.spouses;
    if (spouses.isNotEmpty) {
      return localizeRelationshipType(context, spouses.first.type);
    }
    return widget.person.spouseName!.trim();
  }

  IconData get _spouseIcon {
    final spouses = widget.person.relationships.spouses;
    if (spouses.isEmpty) return Icons.favorite;
    return switch (spouses.first.type) {
      RelationshipType.marriage => Icons.favorite,
      RelationshipType.adoption => Icons.favorite_border,
      _ => Icons.link,
    };
  }

  Widget _buildModernRelationshipBadge() {
    final icon = _spouseIcon;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.accentTeal.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppTheme.accentTeal.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppTheme.accentTeal),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              _spouseLabel(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.accentTeal,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
