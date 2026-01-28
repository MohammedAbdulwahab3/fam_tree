import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/providers/theme_provider.dart';
import 'package:google_fonts/google_fonts.dart';

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
          // Animated gradient background
          _buildAnimatedBackground(isDark),

          // Floating particles
          AnimatedBuilder(
            animation: _particleController,
            builder: (context, child) => CustomPaint(
              size: size,
              painter: _ParticlePainter(
                particles: _particles,
                progress: _particleController.value,
                color: isDark ? AppTheme.primaryLight : AppTheme.primaryDeep,
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

  Widget _buildAnimatedBackground(bool isDark) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppTheme.backgroundDark,
                  const Color(0xFF0D1F2D),
                  AppTheme.primaryDeep.withValues(alpha: 0.3),
                ]
              : [
                  const Color(0xFFF0FDF4),
                  const Color(0xFFECFDF5),
                  AppTheme.accentTeal.withValues(alpha: 0.1),
                ],
        ),
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
          // Logo
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_tree_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Family Tree',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                ),
              ),
            ],
          ),

          const Spacer(),

          // Demo button
          if (!isMobile)
            TextButton.icon(
              onPressed: () => context.go('/demo'),
              icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
              label: const Text('Demo'),
              style: TextButton.styleFrom(
                foregroundColor: isDark ? AppTheme.primaryLight : AppTheme.primaryDeep,
              ),
            ),
          
          // Dashboard button
          if (!isMobile)
            TextButton.icon(
              onPressed: () => context.go('/dashboard'),
              icon: const Icon(Icons.dashboard_rounded, size: 18),
              label: const Text('Dashboard'),
              style: TextButton.styleFrom(
                foregroundColor: isDark ? AppTheme.primaryLight : AppTheme.primaryDeep,
              ),
            ),

          // Theme toggle
          _buildThemeToggle(isDark),

          const SizedBox(width: 16),

          // Login button
          if (!isMobile)
            OutlinedButton.icon(
              onPressed: () => context.go('/login'),
              icon: const Icon(Icons.login, size: 18),
              label: const Text('Sign In'),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? AppTheme.primaryLight : AppTheme.primaryDeep,
                side: BorderSide(
                  color: isDark ? AppTheme.primaryLight : AppTheme.primaryDeep,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
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
        // Animated pulsing icon with glow
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) => Transform.scale(
            scale: _pulseAnimation.value * 0.1 + 0.95,
            child: Container(
              width: isMobile ? 100.0 : 140.0,
              height: isMobile ? 100.0 : 140.0,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryLight.withValues(
                      alpha: 0.2 + (_pulseAnimation.value - 0.8) * 0.3,
                    ),
                    blurRadius: 30 + (_pulseAnimation.value - 0.8) * 20,
                    spreadRadius: 5 + (_pulseAnimation.value - 0.8) * 10,
                  ),
                ],
              ),
              child: Icon(
                Icons.account_tree_rounded,
                size: isMobile ? 56.0 : 72.0,
                color: Colors.white,
              ),
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
            'Family Tree',
            style: GoogleFonts.playfairDisplay(
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
          'Discover Your Roots, Connect Your Legacy',
          style: GoogleFonts.inter(
            fontSize: isMobile ? 18 : 26,
            fontWeight: FontWeight.w500,
            color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
            height: 1.5,
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
            'A stunning, emotionally rich journey through generations. Preserve memories, celebrate connections, and explore your family story like never before.',
            style: GoogleFonts.inter(
              fontSize: isMobile ? 15 : 18,
              color: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight,
              height: 1.7,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        const SizedBox(height: 40),

        // CTA Buttons row
        Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: [
            _buildPrimaryButton(
              context: context,
              label: 'Explore Demo',
              icon: Icons.play_arrow_rounded,
              onTap: () => context.go('/demo'),
              isDark: isDark,
            ),
            _buildSecondaryButton(
              context: context,
              label: 'Get Started',
              icon: Icons.arrow_forward_rounded,
              onTap: () => context.go('/login'),
              isDark: isDark,
            ),
          ],
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
                style: GoogleFonts.inter(
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

  Widget _buildSecondaryButton({
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                icon,
                color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                size: 22,
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
        title: 'Intuitive Controls',
        description: 'Tap to select, double-tap for details, long-press to focus on a branch',
        color: AppTheme.accentGold,
        gradient: [AppTheme.accentGold, AppTheme.warning],
      ),
      _FeatureData(
        icon: Icons.devices_rounded,
        title: 'Works Everywhere',
        description: 'Beautifully responsive on web, phone, and tablet with seamless sync',
        color: AppTheme.accentRose,
        gradient: [AppTheme.accentRose, AppTheme.error],
      ),
      _FeatureData(
        icon: Icons.favorite_rounded,
        title: 'Built with Love',
        description: 'Every detail crafted to honor your family and celebrate your heritage',
        color: AppTheme.success,
        gradient: [AppTheme.success, AppTheme.primaryDeep],
      ),
    ];

    return Column(
      children: [
        // Section title
        Text(
          'Why Family Tree?',
          style: GoogleFonts.playfairDisplay(
            fontSize: isMobile ? 32 : 42,
            fontWeight: FontWeight.bold,
            color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Designed for families of all sizes',
          style: GoogleFonts.inter(
            fontSize: isMobile ? 16 : 18,
            color: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight,
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(isMobile ? 24.0 : 28.0),
        decoration: BoxDecoration(
          color: isDark
              ? AppTheme.cardDark.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? feature.color.withValues(alpha: 0.2)
                : feature.color.withValues(alpha: 0.15),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: feature.color.withValues(alpha: isDark ? 0.1 : 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
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
              style: GoogleFonts.inter(
                fontSize: isMobile ? 18 : 20,
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                letterSpacing: -0.3,
              ),
            ),

            const SizedBox(height: 10),

            // Description
            Text(
              feature.description,
              style: GoogleFonts.inter(
                fontSize: isMobile ? 14 : 15,
                color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context, bool isMobile, bool isDark) {
    final stats = [
      {'value': '∞', 'label': 'Family Members'},
      {'value': '4', 'label': 'View Modes'},
      {'value': '7', 'label': 'Generation Colors'},
      {'value': '100%', 'label': 'Free Forever'},
    ];

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 48,
        vertical: isMobile ? 32 : 48,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [AppTheme.surfaceDark, AppTheme.cardDark.withValues(alpha: 0.5)]
              : [Colors.white, AppTheme.cardLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Wrap(
        spacing: isMobile ? 24 : 48,
        runSpacing: 24,
        alignment: WrapAlignment.spaceEvenly,
        children: stats.map((stat) => SizedBox(
          width: isMobile ? 140 : 160,
          child: Column(
            children: [
              ShaderMask(
                shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
                child: Text(
                  stat['value']!,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: isMobile ? 36 : 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                stat['label']!,
                style: GoogleFonts.inter(
                  fontSize: isMobile ? 14 : 16,
                  color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        )).toList(),
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
            'Ready to Explore Your Heritage?',
            style: GoogleFonts.playfairDisplay(
              fontSize: isMobile ? 28 : 38,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Start building your family tree today. It\'s free, beautiful, and made with love.',
            style: GoogleFonts.inter(
              fontSize: isMobile ? 16 : 18,
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => context.go('/demo'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.play_arrow_rounded, color: AppTheme.primaryDeep, size: 22),
                        const SizedBox(width: 10),
                        Text(
                          'Try Demo',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryDeep,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => context.go('/login'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Get Started',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 22),
                      ],
                    ),
                  ),
                ),
              ),
            ],
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
            style: GoogleFonts.inter(
              fontSize: 14,
              color: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '© ${DateTime.now().year} Family Tree. All rights reserved.',
            style: GoogleFonts.inter(
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
