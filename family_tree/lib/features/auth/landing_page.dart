import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/core/theme/app_colors.dart';
import 'package:family_tree/core/theme/elegant_theme.dart';
import 'package:family_tree/core/widgets/aurora_background.dart';
import 'package:family_tree/core/widgets/tree_mark.dart';
import 'package:family_tree/providers/family_stats_provider.dart';
import 'package:family_tree/data/services/auth_service.dart';
import 'package:family_tree/features/auth/session.dart';
import 'package:family_tree/providers/theme_provider.dart';
import 'package:family_tree/core/design/typography.dart';

/// Stunning landing page with modern animations, floating particles,
/// and emotionally rich design that celebrates family connections.
class LandingPage extends ConsumerStatefulWidget {
  const LandingPage({super.key});

  @override
  ConsumerState<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends ConsumerState<LandingPage>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _particleController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;

  String? _hoveredFeature;
  final List<_Particle> _particles = [];
  final int _particleCount = 30;

  @override
  void initState() {
    super.initState();
    
    // Main entrance animations
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.1, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    // Particle animation
    _particleController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    // Pulse animation for glow effects
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Generate particles
    _generateParticles();

    _mainController.forward();
  }

  void _generateParticles() {
    final random = math.Random();
    for (int i = 0; i < _particleCount; i++) {
      _particles.add(_Particle(
        x: random.nextDouble(),
        y: random.nextDouble(),
        size: random.nextDouble() * 4 + 2,
        speed: random.nextDouble() * 0.3 + 0.1,
        opacity: random.nextDouble() * 0.5 + 0.1,
        delay: random.nextDouble(),
      ));
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    _particleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 768;
    final isTablet = size.width >= 768 && size.width < 1200;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Ambient aurora — same light that sits behind the sign-in screen.
          AuroraBackground(
            animation: _particleController,
            isDark: isDark,
            intensity: 0.85,
          ),

          // Floating particles
          AnimatedBuilder(
            animation: _particleController,
            builder: (context, child) => CustomPaint(
              size: size,
              painter: _ParticlePainter(
                particles: _particles,
                progress: _particleController.value,
                color: context.colors.accent,
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Top navigation bar
                _buildNavBar(context, isMobile, isDark),

                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile
                            ? 20
                            : isTablet
                                ? 48
                                : size.width * 0.1,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: isMobile ? 40 : 80),

                          // Hero Section with animations
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: SlideTransition(
                              position: _slideAnimation,
                              child: _buildHeroSection(context, isMobile, isDark),
                            ),
                          ),

                          SizedBox(height: isMobile ? 60 : 100),

                          // Features with staggered animation
                          _buildFeaturesSection(context, isMobile, isDark),

                          SizedBox(height: isMobile ? 60 : 100),

                          // Stats section
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: _buildStatsSection(context, isMobile, isDark),
                          ),

                          SizedBox(height: isMobile ? 60 : 100),

                          // CTA Section
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: _buildCTASection(context, isMobile, isDark),
                          ),

                          const SizedBox(height: 60),

                          // Footer
                          _buildFooter(context, isDark),

                          const SizedBox(height: 32),
                        ],
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


  Widget _buildNavBar(BuildContext context, bool isMobile, bool isDark) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 32,
        vertical: 16,
      ),
      child: Row(
        children: [
          // Logo — Flexible so a narrow phone ellipsizes the wordmark rather
          // than overflowing the bar.
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TreeMark(isDark: isDark, size: 40),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'Mammedu Family',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.sans(
                      fontSize: isMobile ? 19 : 22,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppTheme.textPrimaryDark
                          : AppTheme.textPrimaryLight,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Theme toggle
          _buildThemeToggle(isDark),

          const SizedBox(width: 12),

          // Sign In / Logout button - responsive and auth-aware
          Consumer(
            builder: (context, ref, _) {
              final isSignedIn =
                  ref.watch(isSignedInProvider);
              
              if (isSignedIn) {
                // Show Logout button
                return isMobile
                  ? IconButton(
                      onPressed: () async {
                        await AuthService().signOut();
                      },
                      icon: Icon(
                        Icons.logout_rounded,
                        color: context.colors.accent,
                      ),
                      tooltip: 'Logout',
                    )
                  : OutlinedButton.icon(
                      onPressed: () async {
                        await AuthService().signOut();
                      },
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('Logout'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.colors.accent,
                        side: BorderSide(
                          color: context.colors.accent,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    );
              } else {
                // Show Sign In button
                return isMobile
                  ? IconButton(
                      onPressed: () => context.go('/login'),
                      icon: Icon(
                        Icons.account_circle_rounded,
                        color: context.colors.accent,
                      ),
                      tooltip: 'Sign In',
                    )
                  : OutlinedButton.icon(
                      onPressed: () => context.go('/login'),
                      icon: const Icon(Icons.account_circle_rounded, size: 18),
                      label: const Text('Sign In'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.colors.accent,
                        side: BorderSide(
                          color: context.colors.accent,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildThemeToggle(bool isDark) {
    return GestureDetector(
      onTap: () => ref.read(themeModeProvider.notifier).toggleTheme(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.1),
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) => RotationTransition(
            turns: animation,
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            key: ValueKey(isDark),
            color: isDark ? AppTheme.accentGold : AppTheme.primaryDeep,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context, bool isMobile, bool isDark) {
    return Column(
      children: [
        // The app mark, breathing gently.
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) => Transform.scale(
            scale: _pulseAnimation.value * 0.05 + 0.975,
            child: TreeMark(
              isDark: isDark,
              size: isMobile ? 104.0 : 140.0,
              glow: _pulseAnimation.value,
            ),
          ),
        ),

        SizedBox(height: isMobile ? 32 : 48),

        // App Title with animated gradient
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: isDark
                ? [AppTheme.primaryLight, AppTheme.accentTeal, AppTheme.accentCyan]
                : [AppTheme.primaryDeep, AppTheme.accentTeal, AppTheme.primaryLight],
          ).createShader(bounds),
          child: Text(
            'Mammedu Family',
            style: AppType.sans(
              fontSize: isMobile ? 48 : 72,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.1,
              letterSpacing: -2,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        const SizedBox(height: 16),

        // Tagline with beautiful typography
        Text(
          'Our Roots, Our Legacy, Our Story',
          style: AppType.sans(
            fontSize: isMobile ? 24 : 32,
            fontWeight: FontWeight.w500,
            fontStyle: FontStyle.italic,
            color: isDark
                ? AppTheme.textSecondaryDark
                : ElegantColors.warmGray,
            height: 1.4,
            letterSpacing: 0.3,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 24),

        // Emotional subtitle
        Container(
          constraints: const BoxConstraints(maxWidth: 700),
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 8.0 : 24.0),
          child: Text(
            'Explore the Mammedu family lineage through generations. Celebrate our ancestors, preserve our memories, and stay connected with our heritage.',
            style: AppType.sans(
              fontSize: isMobile ? 15 : 18,
              color: context.colors.inkMuted,
              height: 1.7,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        const SizedBox(height: 40),

        // Primary CTA Button - Explore Tree (no auth required)
        _buildPrimaryButton(
          context: context,
          label: 'View Our Tree',
          icon: Icons.account_tree_rounded,
          onTap: () => context.go('/tree'),
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildPrimaryButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryLight.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text(
                label,
                style: AppType.sans(
                  fontSize: 16,
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

  Widget _buildFeaturesSection(BuildContext context, bool isMobile, bool isDark) {
    final features = [
      _FeatureData(
        icon: Icons.account_tree_rounded,
        title: 'Smart Tree Views',
        description: 'Navigate large family trees with intelligent zoom, minimap, and semantic grouping',
        color: AppTheme.primaryLight,
        gradient: [AppTheme.primaryLight, AppTheme.primaryDeep],
      ),
      _FeatureData(
        icon: Icons.auto_stories_rounded,
        title: 'Rich Life Stories',
        description: 'Capture photos, memories, and milestones that bring each ancestor to life',
        color: AppTheme.accentTeal,
        gradient: [AppTheme.accentTeal, AppTheme.accentCyan],
      ),
      /*
      _FeatureData(
        icon: Icons.hub_rounded,
        title: 'Radial & Timeline',
        description: 'View your heritage in stunning radial patterns or chronological timelines',
        color: AppTheme.accentCyan,
        gradient: [AppTheme.accentCyan, AppTheme.info],
      ),
      */
      _FeatureData(
        icon: Icons.touch_app_rounded,
        title: 'Easy Navigation',
        description: 'Tap to select, double-tap for details, explore each branch of our family',
        color: AppTheme.accentGold,
        gradient: [AppTheme.accentGold, AppTheme.warning],
      ),
    ];

    return Column(
      children: [
        // Section title
        Text(
          'Our Family Features',
          style: AppType.sans(
            fontSize: isMobile ? 32 : 42,
            fontWeight: FontWeight.bold,
            color: context.colors.ink,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Designed for the Mammedu family',
          style: AppType.sans(
            fontSize: isMobile ? 16 : 18,
            color: context.colors.inkMuted,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 48),

        // Features grid
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            int columns = width < 600 ? 1 : (width < 900 ? 2 : 3);
            final cardWidth = (width - (columns - 1) * 24) / columns;

            return Wrap(
              spacing: 24,
              runSpacing: 24,
              children: features.asMap().entries.map((entry) {
                final index = entry.key;
                final feature = entry.value;

                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 600 + (index * 100)),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) => Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 30 * (1 - value)),
                      child: child,
                    ),
                  ),
                  child: SizedBox(
                    width: columns == 1 ? double.infinity : cardWidth,
                    child: _buildFeatureCard(feature, isMobile, isDark),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFeatureCard(_FeatureData feature, bool isMobile, bool isDark) {
    final hovered = _hoveredFeature == feature.title;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hoveredFeature = feature.title),
      onExit: (_) => setState(() => _hoveredFeature = null),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, hovered ? -6 : 0, 0),
        padding: EdgeInsets.all(isMobile ? 24.0 : 28.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    Colors.white.withValues(alpha: hovered ? 0.12 : 0.08),
                    Colors.white.withValues(alpha: 0.03),
                  ]
                : [
                    Colors.white.withValues(alpha: hovered ? 0.95 : 0.85),
                    Colors.white.withValues(alpha: 0.62),
                  ],
          ),
          border: Border.all(
            color: feature.color.withValues(alpha: hovered ? 0.45 : 0.22),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: feature.color
                  .withValues(alpha: hovered ? 0.28 : (isDark ? 0.12 : 0.10)),
              blurRadius: hovered ? 34 : 24,
              offset: Offset(0, hovered ? 16 : 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon with gradient background
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: feature.gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: feature.color.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                feature.icon,
                color: Colors.white,
                size: 28,
              ),
            ),

            const SizedBox(height: 20),

            // Title
            Text(
              feature.title,
              style: AppType.sans(
                fontSize: isMobile ? 18 : 20,
                fontWeight: FontWeight.bold,
                color: context.colors.ink,
                letterSpacing: -0.3,
              ),
            ),

            const SizedBox(height: 10),

            // Description
            Text(
              feature.description,
              style: AppType.sans(
                fontSize: isMobile ? 14 : 15,
                color: context.colors.inkSoft,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context, bool isMobile, bool isDark) {
    // Real counts, read from the public tree endpoint. Falls back to a quiet
    // placeholder rather than inventing a number if the backend is unreachable.
    final stats = ref.watch(familyStatsProvider);
    final data = stats.valueOrNull ?? FamilyStats.unknown;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 24 : 48,
            vertical: isMobile ? 32 : 44,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      Colors.white.withValues(alpha: 0.09),
                      Colors.white.withValues(alpha: 0.03),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.85),
                      Colors.white.withValues(alpha: 0.60),
                    ],
            ),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.9),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.07),
                blurRadius: 34,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Wrap(
            spacing: isMobile ? 24 : 56,
            runSpacing: 28,
            alignment: WrapAlignment.spaceEvenly,
            children: [
              _statTile(
                value: data.people,
                suffix: '',
                label: 'Relatives',
                isMobile: isMobile,
                isDark: isDark,
              ),
              _statTile(
                value: data.generations,
                suffix: '',
                label: 'Generations',
                isMobile: isMobile,
                isDark: isDark,
              ),
              _statTile(
                value: null,
                suffix: '\u221e',
                label: 'Memories',
                isMobile: isMobile,
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// One headline figure. Numeric values count up once the data lands.
  Widget _statTile({
    required int? value,
    required String suffix,
    required String label,
    required bool isMobile,
    required bool isDark,
  }) {
    final Widget figure;
    if (value == null) {
      figure = Text(
        suffix,
        style: AppType.sans(
          fontSize: isMobile ? 38 : 52,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    } else {
      figure = TweenAnimationBuilder<int>(
        tween: IntTween(begin: 0, end: value),
        duration: const Duration(milliseconds: 1100),
        curve: Curves.easeOutCubic,
        builder: (context, shown, _) => Text(
          value == 0 ? '\u2014' : '$shown',
          style: AppType.sans(
            fontSize: isMobile ? 38 : 52,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            height: 1.0,
          ),
        ),
      );
    }

    return SizedBox(
      width: isMobile ? 130 : 170,
      child: Column(
        children: [
          ShaderMask(
            shaderCallback: (bounds) =>
                AppTheme.primaryGradient.createShader(bounds),
            child: figure,
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: AppType.sans(
              fontSize: isMobile ? 13 : 15,
              letterSpacing: 0.6,
              color: isDark
                  ? AppTheme.textSecondaryDark
                  : ElegantColors.warmGray,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCTASection(BuildContext context, bool isMobile, bool isDark) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 32 : 56),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryLight.withValues(alpha: 0.3),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Ready to Explore Our Heritage?',
            style: AppType.sans(
              fontSize: isMobile ? 28 : 38,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Discover the Mammedu family tree and connect with our roots.',
            style: AppType.sans(
              fontSize: isMobile ? 16 : 18,
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => context.go('/tree'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'Explore Tree',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.sans(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryDeep,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.arrow_forward_rounded, color: AppTheme.primaryDeep, size: 22),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Divider(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 24),
          Text(
            'Made with ❤️ for families everywhere',
            style: AppType.sans(
              fontSize: 14,
              color: context.colors.inkMuted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '© ${DateTime.now().year} Family Tree. All rights reserved.',
            style: AppType.sans(
              fontSize: 12,
              color: isDark
                  ? AppTheme.textMutedDark.withValues(alpha: 0.7)
                  : AppTheme.textMutedLight.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// ============ SUPPORTING CLASSES ============

/// Particle data for floating animation
class _Particle {
  final double x;
  final double y;
  final double size;
  final double speed;
  final double opacity;
  final double delay;

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.delay,
  });
}

/// Custom painter for floating particles
class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final Color color;

  _ParticlePainter({
    required this.particles,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final adjustedProgress = (progress + particle.delay) % 1.0;
      final x = particle.x * size.width;
      final y = ((particle.y + adjustedProgress * particle.speed) % 1.2) * size.height;
      
      final paint = Paint()
        ..color = color.withValues(alpha: particle.opacity * (1 - adjustedProgress * 0.5))
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(x, y),
        particle.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) => true;
}

/// Feature data model
class _FeatureData {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final List<Color> gradient;

  _FeatureData({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.gradient,
  });
}
