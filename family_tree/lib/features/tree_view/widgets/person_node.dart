import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/data/models/person.dart';

/// Elegant portrait card for a person node
class PersonNode extends StatefulWidget {
  final Person person;
  final int generation;
  final bool isSelected;
  final bool isFocused;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final double scale;
  final Color? color;
  final bool isDimmed;

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
    this.scale = 1.0,
    this.color,
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
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
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
    final generationColor = widget.color ?? AppTheme.getGenerationColor(widget.generation);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Subtle dimming - only reduce opacity slightly, no blur or scale change
    final double targetOpacity = widget.isDimmed ? 0.5 : 1.0;
    
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
          child: Container(
            width: 140, // Slightly wider for better proportions
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
                        : (isDark ? AppTheme.cardDark : AppTheme.cardLight).withValues(alpha: isDark ? 0.7 : 0.9),
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
                              (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                              (isDark ? Colors.white : Colors.black).withValues(alpha: 0.02),
                            ],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Profile photo with glowing ring
                      _buildProfilePhoto(generationColor),
                      const SizedBox(height: AppTheme.spaceSm),
                      
                      // Name with elegant typography
                      Text(
                        widget.person.fullName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                              letterSpacing: 0.3,
                              shadows: isDark ? [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ] : null,
                            ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      // Lifespan
                      if (widget.person.lifespan.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.black : Colors.grey).withValues(alpha: isDark ? 0.3 : 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            widget.person.lifespan,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontSize: 10,
                                  color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                                  fontWeight: FontWeight.w500,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                      
                      // Relationship badges
                      if (widget.person.relationships.spouses.isNotEmpty) ...[
                        const SizedBox(height: AppTheme.spaceXs),
                        _buildRelationshipBadge(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePhoto(Color ringColor) {
    return Stack(
      children: [
        // Generation color ring
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
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.cardDark,
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: ClipOval(
                  child: _buildPhoto(),
                ),
              ),
            ),
          ),
        ),
        
        // Deceased overlay
        if (widget.person.isDeceased)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.backgroundDark,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.textMuted,
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.church,
                size: 12,
                color: AppTheme.textMuted,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPhoto() {
    if (widget.person.profilePhotoUrl != null &&
        widget.person.profilePhotoUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: widget.person.profilePhotoUrl!,
        fit: BoxFit.cover,
        width: 64,
        height: 64,
        placeholder: (context, url) => _buildPlaceholder(),
        errorWidget: (context, url, error) => _buildPlaceholder(),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    // Use initials or default avatar
    final initials = widget.person.firstName.isNotEmpty
        ? widget.person.firstName[0] +
            (widget.person.lastName.isNotEmpty ? widget.person.lastName[0] : '')
        : '?';
    
    return Container(
      width: 64,
      height: 64,
      color: AppTheme.surfaceDark,
      child: Center(
        child: Text(
          initials.toUpperCase(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildRelationshipBadge() {
    final spouse = widget.person.relationships.spouses.first;
    final icon = spouse.type == RelationshipType.marriage
        ? Icons.favorite
        : spouse.type == RelationshipType.adoption
            ? Icons.favorite_border
            : Icons.link;
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppTheme.accentTeal.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 10,
            color: AppTheme.accentTeal,
          ),
          const SizedBox(width: 2),
          Text(
            spouse.type.value,
            style: TextStyle(
              fontSize: 9,
              color: AppTheme.accentTeal,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
