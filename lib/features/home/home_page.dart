import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/features/auth/providers/auth_provider.dart';
// Removed: UserSetupDialog - now using /link-profile page instead
import 'package:family_tree/data/repositories/person_repository.dart';
import 'package:family_tree/data/models/person.dart';
import 'package:google_fonts/google_fonts.dart';

/// Beautiful home page showing user and their descendants
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final PersonRepository _repository = PersonRepository();
  Person? _userPerson;
  List<Person> _subtree = [];
  bool _isLoading = true;
  bool _needsLink = false;

  @override
  void initState() {
    super.initState();
    _checkUserSetup();
  }

  Future<void> _checkUserSetup() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      // Check if user has a linked Person record
      final person = await _repository.getPersonByAuthUserId(user.uid);
      
      if (person == null) {
        // User needs to link their profile - show banner
        setState(() {
          _needsLink = true;
          _isLoading = false;
        });
      } else {
        // User has a linked profile, load their subtree
        setState(() => _userPerson = person);
        await _loadSubtree();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
    }
  }

  Future<void> _loadSubtree() async {
    if (_userPerson == null) return;

    try {
      final descendants = await _repository.getDescendants(_userPerson!.id);
      setState(() {
        _subtree = [_userPerson!, ...descendants];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading family tree: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = authState.value;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.backgroundDark,
              AppTheme.primaryDeep.withValues(alpha: 0.3),
              AppTheme.accentTeal.withValues(alpha: 0.2),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar
              Padding(
                padding: const EdgeInsets.all(AppTheme.spaceMd),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'My Family',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.account_tree, color: AppTheme.primaryLight),
                          tooltip: 'View Full Tree',
                          onPressed: () => context.go('/tree'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout, color: AppTheme.textSecondary),
                          tooltip: 'Sign Out',
                          onPressed: () async {
                            final authController = ref.read(authControllerProvider.notifier);
                            await authController.signOut();
                            if (context.mounted) {
                              context.go('/');
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _needsLink
                        ? _buildLinkProfileBanner()
                        : SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd),
                        child: Column(
                          children: [
                                // User Profile Card
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(AppTheme.spaceLg),
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.primaryGradient,
                                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                                    boxShadow: AppTheme.shadowGlow,
                                  ),
                                  child: Column(
                                    children: [
                                      // Avatar
                                      Container(
                                        width: 100,
                                        height: 100,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.3),
                                          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 3,
                                          ),
                                        ),
                                        child: _userPerson?.profilePhotoUrl != null
                                            ? ClipRRect(
                                                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                                                child: Image.network(
                                                  _userPerson!.profilePhotoUrl!,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return const Icon(
                                                      Icons.person,
                                                      size: 50,
                                                      color: Colors.white,
                                                    );
                                                  },
                                                ),
                                              )
                                            : const Icon(
                                                Icons.person,
                                                size: 50,
                                                color: Colors.white,
                                              ),
                                      ),

                                      const SizedBox(height: AppTheme.spaceMd),

                                      // Name
                                      Text(
                                        _userPerson?.fullName ?? 'You',
                                        style: GoogleFonts.playfairDisplay(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),

                                      if (_userPerson?.lifespan.isNotEmpty == true) ...[
                                        const SizedBox(height: AppTheme.spaceXs),
                                        Text(
                                          _userPerson!.lifespan,
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            color: Colors.white.withValues(alpha: 0.9),
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],

                                      const SizedBox(height: AppTheme.spaceLg),

                                      // Stats
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          _buildStat(
                                            icon: Icons.people,
                                            value: (_subtree.length - 1).toString(),
                                            label: 'Descendants',
                                          ),
                                          Container(
                                            height: 40,
                                            width: 1,
                                            color: Colors.white.withValues(alpha: 0.3),
                                          ),
                                          _buildStat(
                                            icon: Icons.family_restroom,
                                            value: _subtree.length.toString(),
                                            label: 'Total',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: AppTheme.spaceLg),

                                // Quick Actions
                                Text(
                                  'Quick Actions',
                                  style: GoogleFonts.inter(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),

                                const SizedBox(height: AppTheme.spaceMd),

                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildActionCard(
                                        context,
                                        icon: Icons.groups,
                                        title: 'Family Group',
                                        description: 'Chat, posts & events',
                                        color: AppTheme.accentCyan,
                                        onTap: () => context.go('/group'),
                                      ),
                                    ),
                                    const SizedBox(width: AppTheme.spaceMd),
                                    Expanded(
                                      child: _buildActionCard(
                                        context,
                                        icon: Icons.account_tree,
                                        title: 'Family Tree',
                                        description: 'Visual tree view',
                                        color: AppTheme.primaryLight,
                                        onTap: () => context.go('/tree'),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: AppTheme.spaceLg),

                                // Descendants Section
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'My Descendants',
                                      style: GoogleFonts.inter(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: () => context.go('/tree'),
                                      icon: const Icon(Icons.account_tree, size: 16),
                                      label: const Text('View Tree'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppTheme.primaryLight,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: AppTheme.spaceMd),

                                // Descendants List or Empty State
                                if (_subtree.length <= 1)
                                  _buildEmptyState()
                                else
                                  Column(
                                    children: _subtree.skip(1).map((person) {
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: AppTheme.spaceMd),
                                        child: _buildPersonCard(person),
                                      );
                                    }).toList(),
                                  ),

                                const SizedBox(height: AppTheme.spaceXl),

                                // Action Button
                                _buildActionButton(
                                  label: 'Explore Full Family Tree',
                                  icon: Icons.account_tree,
                                  onTap: () => context.go('/tree'),
                                ),

                                const SizedBox(height: AppTheme.spaceXl),
                              ],
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinkProfileBanner() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.primaryGradient,
                boxShadow: AppTheme.shadowGlow,
              ),
              child: const Icon(
                Icons.person_add_alt_1_rounded,
                size: 64,
                color: Colors.white,
              ),
            ),
            
            const SizedBox(height: AppTheme.spaceLg),
            
            Text(
              'Link Your Profile',
              style: GoogleFonts.playfairDisplay(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            
            const SizedBox(height: AppTheme.spaceMd),
            
            Text(
              'Connect your account to your profile\nin the family tree',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
            ),
            
            const SizedBox(height: AppTheme.spaceXl),
            
            // Link Profile Button
            Container(
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                boxShadow: AppTheme.shadowGlow,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => context.go('/link-profile'),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceXl,
                      vertical: AppTheme.spaceMd,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.link, color: Colors.white),
                        const SizedBox(width: AppTheme.spaceSm),
                        Text(
                          'Link Profile Now',
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
              ),
            ),
            
            const SizedBox(height: AppTheme.spaceMd),
            
            // Skip button
            TextButton(
              onPressed: () => context.go('/tree'),
              child: Text(
                'Skip and Explore Tree',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: AppTheme.spaceXs),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }

  Widget _buildPersonCard(Person person) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: AppTheme.glassDecoration(),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryLight, AppTheme.accentTeal],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            ),
            child: person.profilePhotoUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    child: Image.network(
                      person.profilePhotoUrl!,
                      fit: BoxFit.cover,
                      width: 50,
                      height: 50,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          person.gender == 'male' ? Icons.male : Icons.female,
                          color: Colors.white,
                          size: 24,
                        );
                      },
                    ),
                  )
                : Icon(
                    person.gender == 'male' ? Icons.male : Icons.female,
                    color: Colors.white,
                    size: 24,
                  ),
          ),

          const SizedBox(width: AppTheme.spaceMd),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${person.firstName} ${person.lastName}',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (person.birthDate != null) ...[
                  const SizedBox(height: AppTheme.spaceXs),
                  Text(
                    'Born ${person.birthDate}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const Icon(
            Icons.chevron_right,
            color: AppTheme.textMuted,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceXl),
      decoration: AppTheme.glassDecoration(),
      child: Column(
        children: [
          const Icon(
            Icons.family_restroom,
            size: 64,
            color: AppTheme.textMuted,
          ),
          const SizedBox(height: AppTheme.spaceMd),
          Text(
            'No descendants yet',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Text(
            'Start building your family tree by adding family members',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spaceLg),
          ElevatedButton.icon(
            onPressed: () => context.go('/tree'),
            icon: const Icon(Icons.add),
            label: const Text('Add Family Member'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spaceMd),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            boxShadow: AppTheme.shadowGlow,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: AppTheme.spaceSm),
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

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spaceMd),
          decoration: AppTheme.glassDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spaceSm),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: AppTheme.spaceSm),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: AppTheme.spaceXs),
              Text(
                description,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
