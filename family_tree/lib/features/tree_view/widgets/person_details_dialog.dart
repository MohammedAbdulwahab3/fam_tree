import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_tree/data/models/person.dart';
import 'package:family_tree/data/repositories/person_repository.dart';
import 'package:family_tree/features/auth/providers/auth_provider.dart';
import 'package:family_tree/core/theme/app_theme.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'package:intl/intl.dart';

class PersonDetailsDialog extends ConsumerStatefulWidget {
  final Person person;
  final List<Person> spouses;
  final List<Person> children;
  final Function(String) onPersonTapped;

  const PersonDetailsDialog({
    super.key,
    required this.person,
    this.spouses = const [],
    this.children = const [],
    required this.onPersonTapped,
  });

  @override
  ConsumerState<PersonDetailsDialog> createState() => _PersonDetailsDialogState();
}

class _PersonDetailsDialogState extends ConsumerState<PersonDetailsDialog>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _slideController;
  late AnimationController _shimmerController;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Scale animation for entrance
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );
    
    // Slide animation for content
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    // Shimmer animation for decorative elements
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
    
    // Start animations
    _scaleController.forward();
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _slideController.forward();
    });
  }
  
  @override
  void dispose() {
    _scaleController.dispose();
    _slideController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final repository = PersonRepository();
    final canEditFuture = user != null
        ? repository.canUserEdit(widget.person.id, user.uid)
        : Future.value(false);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final generation = _getGeneration();
    final genColor = AppTheme.getGenerationColor(generation);

    return FutureBuilder<bool>(
      future: canEditFuture,
      initialData: false,
      builder: (context, snapshot) {
        final canEdit = snapshot.data ?? false;

        return Center(
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 400,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                margin: const EdgeInsets.all(24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? [
                                  AppTheme.surfaceDark.withValues(alpha: 0.95),
                                  AppTheme.backgroundDark.withValues(alpha: 0.9),
                                ]
                              : [
                                  Colors.white.withValues(alpha: 0.95),
                                  Colors.grey.shade50.withValues(alpha: 0.9),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: genColor.withValues(alpha: 0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: genColor.withValues(alpha: 0.2),
                            blurRadius: 40,
                            spreadRadius: 5,
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildAnimatedHeader(context, canEdit, isDark, genColor),
                          Flexible(
                            child: SlideTransition(
                              position: _slideAnimation,
                              child: FadeTransition(
                                opacity: _slideController,
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildInfoCards(isDark, genColor),
                                      if (widget.person.bio != null && widget.person.bio!.isNotEmpty) ...[
                                        const SizedBox(height: 20),
                                        _buildBioSection(isDark),
                                      ],
                                      if (widget.spouses.isNotEmpty) ...[
                                        const SizedBox(height: 20),
                                        _buildFamilySection('Spouse', widget.spouses, Icons.favorite, isDark),
                                      ],
                                      if (widget.children.isNotEmpty) ...[
                                        const SizedBox(height: 20),
                                        _buildFamilySection('Children', widget.children, Icons.child_care, isDark),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          _buildFooter(context, canEdit, isDark, genColor),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  int _getGeneration() {
    // Simple generation estimation based on birth year
    if (widget.person.birthDate == null) return 2;
    final year = widget.person.birthDate!.year;
    final currentYear = DateTime.now().year;
    return ((currentYear - year) / 25).floor().clamp(0, 5);
  }

  Widget _buildAnimatedHeader(BuildContext context, bool canEdit, bool isDark, Color genColor) {
    final dateFormat = DateFormat('MMMM d, yyyy');
    final birthDate = widget.person.birthDate != null 
        ? dateFormat.format(widget.person.birthDate!) 
        : 'Unknown';
    final isAlive = widget.person.deathDate == null;
    final age = _calculateAge();

    return SizedBox(
      height: 200,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Animated gradient background
          AnimatedBuilder(
            animation: _shimmerController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      genColor.withValues(alpha: 0.3),
                      genColor.withValues(alpha: 0.1),
                      AppTheme.primaryLight.withValues(alpha: 0.2),
                    ],
                    stops: [
                      0,
                      0.5 + 0.3 * math.sin(_shimmerController.value * 2 * math.pi),
                      1,
                    ],
                  ),
                ),
              );
            },
          ),
          
          // Decorative circles
          Positioned(
            top: -30,
            right: -30,
            child: AnimatedBuilder(
              animation: _shimmerController,
              builder: (context, _) {
                return Transform.rotate(
                  angle: _shimmerController.value * 2 * math.pi,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 2,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Close button
          Positioned(
            top: 12,
            right: 12,
            child: _buildCloseButton(context, isDark),
          ),
          
          // View only badge
          if (!canEdit)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.visibility, size: 14, color: Colors.white.withValues(alpha: 0.8)),
                    const SizedBox(width: 4),
                    Text(
                      'View Only',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // Profile section
          Positioned(
            bottom: -50,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Animated avatar
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: child,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [genColor, AppTheme.primaryLight],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: genColor.withValues(alpha: 0.4),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? AppTheme.surfaceDark : Colors.white,
                        border: Border.all(
                          color: isDark ? AppTheme.surfaceDark : Colors.white,
                          width: 4,
                        ),
                      ),
                      child: ClipOval(
                        child: widget.person.profilePhotoUrl != null
                            ? Image.network(
                                widget.person.profilePhotoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _buildAvatarPlaceholder(isDark),
                              )
                            : _buildAvatarPlaceholder(isDark),
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

  Widget _buildCloseButton(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.2),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: const Icon(
          Icons.close_rounded,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildAvatarPlaceholder(bool isDark) {
    return Container(
      color: isDark ? AppTheme.surfaceDark : Colors.grey.shade200,
      child: Icon(
        Icons.person_rounded,
        size: 50,
        color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
      ),
    );
  }

  Widget _buildInfoCards(bool isDark, Color genColor) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final birthDate = widget.person.birthDate != null 
        ? dateFormat.format(widget.person.birthDate!) 
        : 'Unknown';
    final age = _calculateAge();
    final isAlive = widget.person.deathDate == null;

    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          // Name with animation
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: Column(
              children: [
                Text(
                  widget.person.fullName,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: genColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: genColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isAlive ? Icons.cake_rounded : Icons.history_rounded,
                            size: 14,
                            color: genColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            age,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : AppTheme.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isAlive) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Living',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Info cards
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  icon: Icons.cake_outlined,
                  label: 'Born',
                  value: birthDate,
                  isDark: isDark,
                  color: genColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                  icon: Icons.family_restroom_rounded,
                  label: 'Family',
                  value: '${widget.spouses.length + widget.children.length} members',
                  isDark: isDark,
                  color: AppTheme.accentTeal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark 
            ? Colors.white.withValues(alpha: 0.05) 
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white54 : AppTheme.textSecondaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.textPrimaryLight,
            ),
          ),
        ],
      ),
    );
  }

  String _calculateAge() {
    if (widget.person.birthDate == null) return 'Unknown';
    
    final birth = widget.person.birthDate!;
    final end = widget.person.deathDate ?? DateTime.now();
    int age = end.year - birth.year;
    if (end.month < birth.month || (end.month == birth.month && end.day < birth.day)) {
      age--;
    }
    
    if (widget.person.deathDate != null) {
      return 'Lived $age years';
    }
    return '$age years old';
  }

  Widget _buildBioSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark 
            ? Colors.white.withValues(alpha: 0.03) 
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_stories_rounded,
                size: 18,
                color: AppTheme.primaryLight,
              ),
              const SizedBox(width: 8),
              Text(
                'Biography',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.person.bio!,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: isDark ? Colors.white70 : AppTheme.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFamilySection(String title, List<Person> relatives, IconData icon, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: AppTheme.accentTeal),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppTheme.textPrimaryLight,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.accentTeal.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${relatives.length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentTeal,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...relatives.asMap().entries.map((entry) {
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 400 + entry.key * 100),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(30 * (1 - value), 0),
                  child: child,
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildRelativeCard(entry.value, isDark),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRelativeCard(Person relative, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => widget.onPersonTapped(relative.id),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark 
                ? Colors.white.withValues(alpha: 0.05) 
                : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppTheme.primaryLight, AppTheme.accentTeal],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? AppTheme.surfaceDark : Colors.white,
                    ),
                    child: ClipOval(
                      child: relative.profilePhotoUrl != null
                          ? Image.network(
                              relative.profilePhotoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.person,
                                size: 24,
                                color: isDark ? Colors.white54 : Colors.grey,
                              ),
                            )
                          : Icon(
                              Icons.person,
                              size: 24,
                              color: isDark ? Colors.white54 : Colors.grey,
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      relative.fullName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                      ),
                    ),
                    if (relative.birthDate != null)
                      Text(
                        DateFormat('MMM yyyy').format(relative.birthDate!),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : AppTheme.textSecondaryLight,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: isDark ? Colors.white30 : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context, bool canEdit, bool isDark, Color genColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: Row(
        children: [
          if (canEdit)
            Expanded(
              child: _buildGradientButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Edit feature coming soon!')),
                  );
                },
                icon: Icons.edit_rounded,
                label: 'Edit Profile',
                gradient: [genColor, AppTheme.primaryLight],
              ),
            )
          else
            Expanded(
              child: _buildOutlineButton(
                onPressed: () => Navigator.of(context).pop(),
                label: 'Close',
                isDark: isDark,
              ),
            ),
          if (canEdit) ...[
            const SizedBox(width: 12),
            _buildOutlineButton(
              onPressed: () => Navigator.of(context).pop(),
              label: 'Close',
              isDark: isDark,
              compact: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGradientButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required List<Color> gradient,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradient),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: gradient.first.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOutlineButton({
    required VoidCallback onPressed,
    required String label,
    required bool isDark,
    bool compact = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: 14,
            horizontal: compact ? 20 : 0,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.1),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : AppTheme.textSecondaryLight,
            ),
          ),
        ),
      ),
    );
  }
}
