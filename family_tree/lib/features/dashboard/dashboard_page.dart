import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/core/theme/elegant_theme.dart';
import 'package:family_tree/data/models/person.dart';
import 'package:family_tree/data/repositories/person_repository.dart';
import 'package:family_tree/features/auth/providers/auth_provider.dart';
import 'package:family_tree/providers/admin_provider.dart';

/// Main dashboard after authentication
/// Shows user profile, family stats, and navigation options
class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage>
    with TickerProviderStateMixin {
  final PersonRepository _repository = PersonRepository();
  
  Person? _linkedPerson;
  List<Person> _familyMembers = [];
  bool _isLoading = true;
  bool _isLinked = false;
  
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _loadUserData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) {
      if (mounted) context.go('/login');
      return;
    }

    try {
      // Check if user is linked to a person in family tree
      final person = await _repository.getPersonByAuthUserId(user.uid);
      final allMembers = await _repository.getFamilyMembers('main-family-tree');
      
      setState(() {
        _linkedPerson = person;
        _isLinked = person != null;
        _familyMembers = allMembers;
        _isLoading = false;
      });
      
      _fadeController.forward();
    } catch (e) {
      setState(() => _isLoading = false);
      _fadeController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : ElegantColors.cream,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.surfaceDark : ElegantColors.warmWhite,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.account_tree_rounded, color: ElegantColors.terracotta),
            const SizedBox(width: 8),
            Text(
              'Family Tree',
              style: GoogleFonts.playfairDisplay(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : ElegantColors.charcoal,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.home_rounded, size: 18),
            label: Text('Home', style: GoogleFonts.cormorantGaramond(fontWeight: FontWeight.w600)),
            style: TextButton.styleFrom(
              foregroundColor:  isDark ? Colors.white70 : ElegantColors.warmGray,
            ),
          ),
          TextButton.icon(
            onPressed: () => context.go('/demo'),
            icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
            label: Text('Demo', style: GoogleFonts.cormorantGaramond(fontWeight: FontWeight.w600)),
            style: TextButton.styleFrom(
              foregroundColor: isDark ? Colors.white70 : ElegantColors.warmGray,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: isDark ? null : ElegantColors.cream,
          gradient: isDark
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.backgroundDark,
                    AppTheme.primaryDeep.withValues(alpha: 0.3),
                    AppTheme.accentTeal.withValues(alpha: 0.2),
                  ],
                )
              : null,
        ),
        child: Stack(
          children: [
            SafeArea(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : FadeTransition(
                      opacity: _fadeAnimation,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 800;
                          final isAdmin = ref.watch(userRoleProvider).value?.isAdmin ?? false;
                          
                          if (isWide) {
                            // Web layout - side by side
                            return _buildWebLayout(user, isDark, isAdmin, constraints);
                          } else {
                            // Mobile layout - stacked
                            return _buildMobileLayout(user, isDark, isAdmin);
                          }
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// Web layout - uses full width with elegant design
  Widget _buildWebLayout(dynamic user, bool isDark, bool isAdmin, BoxConstraints constraints) {
    return Column(
      children: [
        // Top bar with admin access
        if (isAdmin) _buildAdminBanner(isDark),
        
        // Main content
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left sidebar - Profile
              Container(
                width: 320,
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.surfaceDark : ElegantColors.warmWhite,
                  border: Border(
                    right: BorderSide(
                      color: isDark ? Colors.white10 : ElegantColors.champagne,
                    ),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildWebProfileSection(user, isDark),
                      const SizedBox(height: 24),
                      _buildWebStatsSection(isDark),
                    ],
                  ),
                ),
              ),
              
              // Main content area
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Welcome section
                      _buildWebWelcomeSection(isDark),
                      const SizedBox(height: 32),
                      
                      // Quick actions as cards
                      _buildWebActionsGrid(isDark),
                      const SizedBox(height: 32),
                      
                      // Family preview
                      _buildFamilyPreview(isDark),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  /// Mobile layout - stacked vertically
  Widget _buildMobileLayout(dynamic user, bool isDark, bool isAdmin) {
    return Column(
      children: [
        if (isAdmin) _buildAdminBanner(isDark),
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(user, isDark)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _isLinked ? _buildProfileCard(isDark) : _buildLinkPrompt(isDark),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildStatsRow(isDark),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildQuickActions(isDark),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildFamilyPreview(isDark),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ],
    );
  }
  
  /// Web profile section in sidebar
  Widget _buildWebProfileSection(dynamic user, bool isDark) {
    return Column(
      children: [
        // Avatar
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: ElegantColors.warmGradient,
            boxShadow: [
              BoxShadow(
                color: ElegantColors.terracotta.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: _linkedPerson?.profilePhotoUrl != null
              ? ClipOval(
                  child: Image.network(
                    _linkedPerson!.profilePhotoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text(
                        _linkedPerson?.firstName[0].toUpperCase() ?? '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                )
              : Center(
                  child: Text(
                    _linkedPerson?.firstName[0].toUpperCase() ?? user?.email?[0].toUpperCase() ?? '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
        ),
        
        const SizedBox(height: 16),
        
        // Name
        Text(
          _linkedPerson?.fullName ?? user?.displayName ?? 'Welcome',
          style: GoogleFonts.playfairDisplay(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : ElegantColors.charcoal,
          ),
          textAlign: TextAlign.center,
        ),
        
        if (_linkedPerson?.lifespan.isNotEmpty == true) ...[
          const SizedBox(height: 4),
          Text(
            _linkedPerson!.lifespan,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 15,
              color: isDark ? Colors.white70 : ElegantColors.warmGray,
            ),
          ),
        ],
        
        if (!_isLinked) ...[
          const SizedBox(height: 16),
          Text(
            'Link your profile to see your family tree',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 14,
              color: ElegantColors.warmGray,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => context.go('/link-profile'),
            icon: const Icon(Icons.link_rounded, size: 18),
            label: Text('Link Profile', style: GoogleFonts.cormorantGaramond(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: ElegantColors.terracotta,
              foregroundColor: Colors.white,
            ),
          ),
        ] else ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () => _showEditProfileDialog(),
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: Text('Edit', style: GoogleFonts.cormorantGaramond()),
                style: TextButton.styleFrom(
                  foregroundColor: isDark ? Colors.white70 : ElegantColors.warmGray,
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () async {
                  await ref.read(authControllerProvider.notifier).signOut();
                  if (mounted) context.go('/');
                },
                icon: const Icon(Icons.logout_rounded, size: 16),
                label: Text('Sign Out', style: GoogleFonts.cormorantGaramond()),
                style: TextButton.styleFrom(
                  foregroundColor: isDark ? Colors.white70 : ElegantColors.warmGray,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
  
  /// Web stats section
  Widget _buildWebStatsSection(bool isDark) {
    final descendants = _linkedPerson != null
        ? _familyMembers.where((p) => 
            p.relationships.parentIds.contains(_linkedPerson!.id)).length
        : 0;
    
    final generations = _calculateGenerations();
    
    return Column(
      children: [
        _buildWebStatItem(Icons.people_alt_rounded, '${_familyMembers.length}', 'Family Members', 
            isDark ? AppTheme.accentTeal : ElegantColors.terracotta, isDark),
        const SizedBox(height: 12),
        _buildWebStatItem(Icons.account_tree_rounded, '$generations', 'Generations', 
            isDark ? AppTheme.primaryLight : ElegantColors.sage, isDark),
        const SizedBox(height: 12),
        _buildWebStatItem(Icons.child_care_rounded, '$descendants', 'Your Children', 
            isDark ? AppTheme.accentGold : ElegantColors.gold, isDark),
      ],
    );
  }
  
  Widget _buildWebStatItem(IconData icon, String value, String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : ElegantColors.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white10 : ElegantColors.champagne),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : ElegantColors.charcoal,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : ElegantColors.warmGray,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  /// Web welcome section
  Widget _buildWebWelcomeSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome to Your Family Tree',
          style: GoogleFonts.playfairDisplay(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : ElegantColors.charcoal,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isLinked 
              ? 'Explore your lineage and connect with your family history.'
              : 'Link your profile to discover your family connections.',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 18,
            color: isDark ? Colors.white70 : ElegantColors.warmGray,
          ),
        ),
      ],
    );
  }
  
  /// Web actions grid
  Widget _buildWebActionsGrid(bool isDark) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildWebActionCard(
          icon: Icons.account_tree_rounded,
          title: 'View My Family',
          description: 'See your descendants and family connections',
          color: ElegantColors.terracotta,
          isDark: isDark,
          onTap: () => context.go('/tree'),
        ),
        _buildWebActionCard(
          icon: Icons.groups_rounded,
          title: 'Family Group',
          description: 'Chat and events with family members',
          color: ElegantColors.sage,
          isDark: isDark,
          onTap: () => context.go('/group'),
        ),
        if (_isLinked)
          _buildWebActionCard(
            icon: Icons.edit_rounded,
            title: 'Edit Profile',
            description: 'Update your personal information',
            color: ElegantColors.copper,
            isDark: isDark,
            onTap: () => _showEditProfileDialog(),
          ),
      ],
    );
  }
  
  Widget _buildWebActionCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.surfaceDark : ElegantColors.warmWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white10 : ElegantColors.champagne),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.1),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : ElegantColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : ElegantColors.warmGray,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: isDark ? Colors.white30 : ElegantColors.warmGray,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(dynamic user, bool isDark) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : ElegantColors.warmWhite,
        borderRadius: BorderRadius.circular(20),
        border: isDark ? null : Border.all(color: ElegantColors.champagne),
        boxShadow: [
          BoxShadow(
            color: isDark 
                ? Colors.black.withValues(alpha: 0.2)
                : ElegantColors.sienna.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // User avatar
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isDark ? AppTheme.primaryGradient : ElegantColors.warmGradient,
              boxShadow: [
                BoxShadow(
                  color: isDark 
                      ? AppTheme.primaryLight.withValues(alpha: 0.3)
                      : ElegantColors.terracotta.withValues(alpha: 0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: user?.photoURL != null
                ? ClipOval(
                    child: Image.network(
                      user!.photoURL!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 26,
                  ),
          ),
          
          const SizedBox(width: 16),
          
          // Greeting
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back!',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: isDark ? AppTheme.textSecondaryDark : ElegantColors.warmGray,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _linkedPerson?.fullName ?? user?.displayName ?? user?.email ?? 'Family Member',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppTheme.textPrimaryDark : ElegantColors.charcoal,
                  ),
                ),
              ],
            ),
          ),
          
          // Sign out button
          Container(
            decoration: BoxDecoration(
              color: isDark 
                  ? Colors.white.withValues(alpha: 0.1)
                  : ElegantColors.cream,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: () async {
                await ref.read(authControllerProvider.notifier).signOut();
                if (mounted) context.go('/');
              },
              icon: Icon(
                Icons.logout_rounded,
                color: isDark ? AppTheme.textSecondaryDark : ElegantColors.warmGray,
              ),
              tooltip: 'Sign Out',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: isDark ? AppTheme.primaryGradient : ElegantColors.warmGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isDark 
                ? AppTheme.primaryLight.withValues(alpha: 0.3)
                : ElegantColors.terracotta.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Profile photo
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.2),
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: _linkedPerson?.profilePhotoUrl != null
                ? ClipOval(
                    child: Image.network(
                      _linkedPerson!.profilePhotoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        _linkedPerson?.gender == 'male' ? Icons.person : Icons.person_2,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  )
                : Icon(
                    _linkedPerson?.gender == 'male' ? Icons.person : Icons.person_2,
                    color: Colors.white,
                    size: 40,
                  ),
          ),
          
          const SizedBox(height: 16),
          
          Text(
            _linkedPerson?.fullName ?? 'Your Profile',
            style: GoogleFonts.playfairDisplay(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          
          if (_linkedPerson?.lifespan.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              _linkedPerson!.lifespan,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
          
          const SizedBox(height: 20),
          
          // Action buttons row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Edit Profile button
              OutlinedButton.icon(
                onPressed: () => _showEditProfileDialog(),
                icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                label: Text(
                  'Edit Profile',
                  style: GoogleFonts.cormorantGaramond(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.6)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
              const SizedBox(width: 12),
              // View Tree button
              ElevatedButton.icon(
                onPressed: () => context.go('/tree'),
                icon: const Icon(Icons.account_tree_rounded, size: 16),
                label: Text(
                  'View Family',
                  style: GoogleFonts.cormorantGaramond(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: ElegantColors.terracotta,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  /// Calculate the number of generations in the family tree
  int _calculateGenerations() {
    if (_familyMembers.isEmpty) return 0;
    
    // Find root persons (those with no parents)
    final roots = _familyMembers.where((p) => p.relationships.parentIds.isEmpty).toList();
    if (roots.isEmpty) return 1;
    
    int maxDepth = 0;
    
    // For each root, calculate depth using BFS
    for (final root in roots) {
      final depth = _getPersonDepth(root.id, {});
      if (depth > maxDepth) maxDepth = depth;
    }
    
    return maxDepth;
  }
  
  /// Get the depth of a person in the tree (how many generations below them)
  int _getPersonDepth(String personId, Set<String> visited) {
    if (visited.contains(personId)) return 0;
    visited.add(personId);
    
    final person = _familyMembers.firstWhere(
      (p) => p.id == personId,
      orElse: () => _familyMembers.first,
    );
    
    if (person.relationships.childrenIds.isEmpty) return 1;
    
    int maxChildDepth = 0;
    for (final childId in person.relationships.childrenIds) {
      final childDepth = _getPersonDepth(childId, visited);
      if (childDepth > maxChildDepth) maxChildDepth = childDepth;
    }
    
    return maxChildDepth + 1;
  }
  
  void _showEditProfileDialog() {
    if (_linkedPerson == null) return;
    
    final firstNameController = TextEditingController(text: _linkedPerson!.firstName);
    final lastNameController = TextEditingController(text: _linkedPerson!.lastName);
    final bioController = TextEditingController(text: _linkedPerson!.bio ?? '');
    final birthYearController = TextEditingController(
      text: _linkedPerson!.birthDate?.year.toString() ?? '',
    );
    String gender = _linkedPerson!.gender ?? 'male';
    bool isLoading = false;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: ElegantColors.warmWhite,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: ElegantColors.terracotta.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        color: ElegantColors.terracotta,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'Edit Your Profile',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: ElegantColors.charcoal,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: ElegantColors.warmGray),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // First Name
                _buildEditField(firstNameController, 'First Name', Icons.person_rounded),
                const SizedBox(height: 14),
                
                // Father Name (Last Name)
                _buildEditField(lastNameController, 'Father Name', Icons.person_outline_rounded),
                const SizedBox(height: 14),
                
                // Birth Year
                _buildEditField(birthYearController, 'Birth Year', Icons.cake_rounded, isNumber: true),
                const SizedBox(height: 14),
                
                // Gender
                Text(
                  'Gender',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 13,
                    color: ElegantColors.warmGray,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setDialogState(() => gender = 'male'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: gender == 'male' 
                                ? ElegantColors.terracotta 
                                : ElegantColors.cream,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: gender == 'male' 
                                  ? ElegantColors.terracotta 
                                  : ElegantColors.champagne,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.male_rounded,
                                size: 18,
                                color: gender == 'male' ? Colors.white : ElegantColors.warmGray,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Male',
                                style: GoogleFonts.cormorantGaramond(
                                  fontWeight: FontWeight.w600,
                                  color: gender == 'male' ? Colors.white : ElegantColors.charcoal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setDialogState(() => gender = 'female'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: gender == 'female' 
                                ? ElegantColors.dustyRose 
                                : ElegantColors.cream,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: gender == 'female' 
                                  ? ElegantColors.dustyRose 
                                  : ElegantColors.champagne,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.female_rounded,
                                size: 18,
                                color: gender == 'female' ? Colors.white : ElegantColors.warmGray,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Female',
                                style: GoogleFonts.cormorantGaramond(
                                  fontWeight: FontWeight.w600,
                                  color: gender == 'female' ? Colors.white : ElegantColors.charcoal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 14),
                
                // Bio
                _buildEditField(bioController, 'Bio (optional)', Icons.info_outline_rounded, maxLines: 3),
                
                const SizedBox(height: 24),
                
                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : () async {
                      if (firstNameController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('First name is required')),
                        );
                        return;
                      }
                      
                      setDialogState(() => isLoading = true);
                      
                      try {
                        // Parse birth year
                        DateTime? birthDate;
                        if (birthYearController.text.isNotEmpty) {
                          final year = int.tryParse(birthYearController.text);
                          if (year != null) {
                            birthDate = DateTime(year);
                          }
                        }
                        
                        final updatedPerson = _linkedPerson!.copyWith(
                          firstName: firstNameController.text.trim(),
                          lastName: lastNameController.text.trim(),
                          gender: gender,
                          bio: bioController.text.trim().isEmpty ? null : bioController.text.trim(),
                          birthDate: birthDate,
                        );
                        
                        await _repository.updatePerson(updatedPerson);
                        
                        if (mounted) {
                          Navigator.pop(context);
                          setState(() {
                            _linkedPerson = updatedPerson;
                          });
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text('Profile updated successfully!'),
                                ],
                              ),
                              backgroundColor: ElegantColors.sage,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isLoading = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: ElegantColors.rust,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ElegantColors.terracotta,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Save Changes',
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildEditField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isNumber = false,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      style: GoogleFonts.cormorantGaramond(
        fontSize: 16,
        color: ElegantColors.charcoal,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.cormorantGaramond(color: ElegantColors.warmGray),
        prefixIcon: Icon(icon, color: ElegantColors.terracotta, size: 20),
        filled: true,
        fillColor: ElegantColors.cream,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ElegantColors.champagne),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ElegantColors.champagne),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ElegantColors.terracotta, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildLinkPrompt(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : ElegantColors.warmWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark 
              ? AppTheme.primaryLight.withValues(alpha: 0.3)
              : ElegantColors.champagne,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark 
                ? Colors.black.withValues(alpha: 0.2)
                : ElegantColors.sienna.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark 
                  ? AppTheme.primaryLight.withValues(alpha: 0.1)
                  : ElegantColors.terracotta.withValues(alpha: 0.1),
            ),
            child: Icon(
              Icons.person_add_alt_1_rounded,
              size: 44,
              color: isDark ? AppTheme.primaryLight : ElegantColors.terracotta,
            ),
          ),
          
          const SizedBox(height: 20),
          
          Text(
            'Link Your Profile',
            style: GoogleFonts.playfairDisplay(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: isDark ? AppTheme.textPrimaryDark : ElegantColors.charcoal,
            ),
          ),
          
          const SizedBox(height: 10),
          
          Text(
            'Connect your account to your profile in the family tree to unlock all features',
            textAlign: TextAlign.center,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 16,
              color: isDark ? AppTheme.textSecondaryDark : ElegantColors.warmGray,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Link button
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: isDark ? AppTheme.primaryGradient : ElegantColors.warmGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: isDark 
                      ? AppTheme.primaryLight.withValues(alpha: 0.3)
                      : ElegantColors.terracotta.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.go('/link-profile'),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.link_rounded, color: Colors.white),
                      const SizedBox(width: 10),
                      Text(
                        'Link Now',
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 14),
          
          TextButton(
            onPressed: () => context.go('/tree'),
            child: Text(
              'Skip and explore tree',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 15,
                color: isDark ? AppTheme.textSecondaryDark : ElegantColors.warmGray,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(bool isDark) {
    final descendants = _linkedPerson != null
        ? _familyMembers.where((p) => 
            p.relationships.parentIds.contains(_linkedPerson!.id)).length
        : 0;
    
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.people_alt_rounded,
            value: '${_familyMembers.length}',
            label: 'Family Members',
            color: isDark ? AppTheme.accentTeal : ElegantColors.terracotta,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.account_tree_rounded,
            value: '5',
            label: 'Generations',
            color: isDark ? AppTheme.primaryLight : ElegantColors.sage,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.child_care_rounded,
            value: '$descendants',
            label: 'Descendants',
            color: isDark ? AppTheme.accentGold : ElegantColors.gold,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : ElegantColors.warmWhite,
        borderRadius: BorderRadius.circular(18),
        border: isDark ? null : Border.all(color: ElegantColors.champagne),
        boxShadow: [
          BoxShadow(
            color: isDark 
                ? Colors.black.withValues(alpha: 0.2)
                : ElegantColors.sienna.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.playfairDisplay(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: isDark ? AppTheme.textPrimaryDark : ElegantColors.charcoal,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.textSecondaryDark : ElegantColors.warmGray,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: isDark ? AppTheme.textPrimaryDark : ElegantColors.charcoal,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.account_tree_rounded,
                title: 'Family Tree',
                subtitle: 'Visual tree view',
                color: isDark ? AppTheme.primaryLight : ElegantColors.terracotta,
                isDark: isDark,
                onTap: () => context.go('/tree'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                icon: Icons.groups_rounded,
                title: 'Family Group',
                subtitle: 'Chat & events',
                color: isDark ? AppTheme.accentTeal : ElegantColors.sage,
                isDark: isDark,
                onTap: () => context.go('/group'),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  /// Elegant admin banner at top of page
  Widget _buildAdminBanner(bool isDark) {
    return Material(
      color: isDark ? const Color(0xFF2A2520) : ElegantColors.charcoal,
      child: InkWell(
        onTap: () => context.go('/admin'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: ElegantColors.gold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: ElegantColors.gold,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: ElegantColors.gold,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'ADMIN',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: ElegantColors.charcoal,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Open Dashboard',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: ElegantColors.gold,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.surfaceDark : ElegantColors.warmWhite,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? color.withValues(alpha: 0.2) : ElegantColors.champagne,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark 
                    ? Colors.black.withValues(alpha: 0.2)
                    : ElegantColors.sienna.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppTheme.textPrimaryDark : ElegantColors.charcoal,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 14,
                  color: isDark ? AppTheme.textSecondaryDark : ElegantColors.warmGray,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFamilyPreview(bool isDark) {
    final previewMembers = _familyMembers.take(5).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Family Members',
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark ? AppTheme.textPrimaryDark : ElegantColors.charcoal,
              ),
            ),
            TextButton.icon(
              onPressed: () => context.go('/tree'),
              icon: Icon(Icons.arrow_forward, size: 16, 
                color: isDark ? AppTheme.primaryLight : ElegantColors.terracotta),
              label: Text(
                'View All',
                style: GoogleFonts.cormorantGaramond(
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppTheme.primaryLight : ElegantColors.terracotta,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.surfaceDark : ElegantColors.warmWhite,
            borderRadius: BorderRadius.circular(18),
            border: isDark ? null : Border.all(color: ElegantColors.champagne),
            boxShadow: [
              BoxShadow(
                color: isDark 
                    ? Colors.black.withValues(alpha: 0.2)
                    : ElegantColors.sienna.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: previewMembers.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(36),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.family_restroom,
                          size: 52,
                          color: isDark 
                              ? AppTheme.textMutedDark 
                              : ElegantColors.warmGray.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'No family members yet',
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 16,
                            color: isDark ? AppTheme.textSecondaryDark : ElegantColors.warmGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: previewMembers.asMap().entries.map((entry) {
                    final index = entry.key;
                    final person = entry.value;
                    final isLast = index == previewMembers.length - 1;
                    
                    return Column(
                      children: [
                        _buildPersonTile(person, isDark),
                        if (!isLast)
                          Divider(
                            height: 1,
                            indent: 72,
                            color: isDark 
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.black.withValues(alpha: 0.05),
                          ),
                      ],
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildPersonTile(Person person, bool isDark) {
    // Get a color based on person index for variety
    final colorIndex = person.firstName.hashCode % ElegantColors.branchColors.length;
    final personColor = isDark 
        ? (person.gender == 'male' ? Colors.blue.shade400 : Colors.pink.shade400)
        : ElegantColors.branchColors[colorIndex.abs()];
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go('/tree'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: personColor,
                  boxShadow: [
                    BoxShadow(
                      color: personColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: person.profilePhotoUrl != null
                    ? ClipOval(
                        child: Image.network(
                          person.profilePhotoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text(
                              person.firstName[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          person.firstName[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
              ),
              
              const SizedBox(width: 14),
              
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person.fullName,
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppTheme.textPrimaryDark : ElegantColors.charcoal,
                      ),
                    ),
                    if (person.birthDate != null)
                      Text(
                        'Born ${person.birthDate!.year}',
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 13,
                          color: isDark ? AppTheme.textSecondaryDark : ElegantColors.warmGray,
                        ),
                      ),
                  ],
                ),
              ),
              
              Icon(
                Icons.chevron_right,
                color: isDark ? AppTheme.textMutedDark : ElegantColors.warmGray,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
