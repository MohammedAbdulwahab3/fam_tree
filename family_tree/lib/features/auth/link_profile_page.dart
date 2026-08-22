import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/data/models/person.dart';
import 'package:family_tree/data/repositories/person_repository.dart';
import 'package:family_tree/features/auth/providers/auth_provider.dart';

class LinkProfilePage extends ConsumerStatefulWidget {
  const LinkProfilePage({super.key});

  @override
  ConsumerState<LinkProfilePage> createState() => _LinkProfilePageState();
}

class _LinkProfilePageState extends ConsumerState<LinkProfilePage>
    with TickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _repository = PersonRepository();
  
  List<Person> _allPersons = [];
  List<Person> _filteredPersons = [];
  Person? _selectedPerson;
  bool _isLoading = true;
  bool _isLinking = false;
  
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
    _loadPersons();
  }

  /// Extract first name from user's display name or email
  String? _getUserFirstName() {
    final user = ref.read(authStateProvider).value;
    if (user == null) return null;
    
    // Try display name first
    if (user.displayName != null && user.displayName!.isNotEmpty) {
      return user.displayName!.split(' ').first;
    }
    
    // Try email prefix
    if (user.email != null && user.email!.isNotEmpty) {
      final emailPrefix = user.email!.split('@').first;
      // Capitalize first letter
      return emailPrefix[0].toUpperCase() + emailPrefix.substring(1);
    }
    
    return null;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadPersons() async {
    try {
      final persons = await _repository.getFamilyMembers('main-family-tree');
      
      // Auto-search by user's name
      final userName = _getUserFirstName();
      List<Person> filtered = persons;
      
      if (userName != null && userName.isNotEmpty) {
        _searchController.text = userName;
        final lowerName = userName.toLowerCase();
        
        // Find matching persons by first name
        filtered = persons.where((person) {
          return person.firstName.toLowerCase().contains(lowerName) ||
                 person.lastName.toLowerCase().contains(lowerName);
        }).toList();
        
        // If no matches, show all
        if (filtered.isEmpty) {
          filtered = persons;
          _searchController.clear();
        }
      }
      
      setState(() {
        _allPersons = persons;
        _filteredPersons = filtered;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading family members: $e')),
        );
      }
    }
  }

  void _filterPersons(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredPersons = _allPersons;
      } else {
        _filteredPersons = _allPersons.where((person) {
          final fullName = '${person.firstName} ${person.lastName}'.toLowerCase();
          return fullName.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  Future<void> _linkProfile() async {
    if (_selectedPerson == null) return;
    
    setState(() => _isLinking = true);
    
    try {
      final user = ref.read(authStateProvider).value;
      if (user != null) {
        await _repository.linkPersonToUser(_selectedPerson!.id, user.uid);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully linked to ${_selectedPerson!.fullName}!'),
              backgroundColor: Colors.green,
            ),
          );
          // Go to dashboard to see linked profile
          context.go('/dashboard');
        }
      }
    } catch (e) {
      setState(() => _isLinking = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error linking profile: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _skipForNow() {
    context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
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
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _isLoading
                      ? _buildLoadingState()
                      : _buildContent(),
                ),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Animated icon
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: child,
              );
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.primaryGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryLight.withValues(alpha: 0.4),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.person_add_alt_1_rounded,
                size: 48,
                color: Colors.white,
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          Text(
            'Link Your Profile',
            style: GoogleFonts.playfairDisplay(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          
          const SizedBox(height: 12),
          
          Text(
            'Find yourself in the family tree and link your account',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppTheme.primaryLight),
          const SizedBox(height: 16),
          Text(
            'Loading family members...',
            style: GoogleFonts.inter(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Search bar
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.primaryLight.withValues(alpha: 0.3),
              ),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _filterPersons,
              style: GoogleFonts.inter(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search by name...',
                hintStyle: GoogleFonts.inter(color: AppTheme.textMuted),
                prefixIcon: const Icon(Icons.search, color: AppTheme.primaryLight),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppTheme.textMuted),
                        onPressed: () {
                          _searchController.clear();
                          _filterPersons('');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Person count
          Text(
            '${_filteredPersons.length} family members found',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Person list
          Expanded(
            child: _filteredPersons.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    itemCount: _filteredPersons.length,
                    itemBuilder: (context, index) {
                      final person = _filteredPersons[index];
                      final isSelected = _selectedPerson?.id == person.id;
                      
                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: Duration(milliseconds: 300 + (index * 50).clamp(0, 500)),
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
                        child: _buildPersonCard(person, isSelected),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.person_search_rounded,
            size: 64,
            color: AppTheme.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            'No family members found',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search term',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonCard(Person person, bool isSelected) {
    final age = person.birthDate != null
        ? DateTime.now().year - person.birthDate!.year
        : null;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPerson = isSelected ? null : person;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryLight.withValues(alpha: 0.15)
              : AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryLight
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryLight.withValues(alpha: 0.2),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: isSelected
                      ? [AppTheme.primaryLight, AppTheme.accentTeal]
                      : [AppTheme.textMuted, AppTheme.textSecondary],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.surfaceDark,
                  ),
                  child: person.profilePhotoUrl != null
                      ? ClipOval(
                          child: Image.network(
                            person.profilePhotoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildAvatarIcon(person),
                          ),
                        )
                      : _buildAvatarIcon(person),
                ),
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Person info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.fullName,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppTheme.primaryLight : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (person.birthDate != null) ...[
                        const Icon(
                          Icons.cake_outlined,
                          size: 14,
                          color: AppTheme.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${person.birthDate!.year}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        if (age != null) ...[
                          Text(
                            ' ($age years)',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(width: 12),
                      Icon(
                        person.gender == 'male' ? Icons.male : Icons.female,
                        size: 14,
                        color: person.gender == 'male' 
                            ? Colors.blue.shade300 
                            : Colors.pink.shade300,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Selection indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? AppTheme.primaryLight
                    : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryLight
                      : AppTheme.textMuted,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 18,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarIcon(Person person) {
    return Center(
      child: Icon(
        person.gender == 'male' ? Icons.person : Icons.person_2,
        size: 28,
        color: AppTheme.textSecondary,
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark.withValues(alpha: 0.8),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Column(
        children: [
          // Link button
          SizedBox(
            width: double.infinity,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                gradient: _selectedPerson != null
                    ? AppTheme.primaryGradient
                    : null,
                color: _selectedPerson == null
                    ? AppTheme.textMuted.withValues(alpha: 0.3)
                    : null,
                borderRadius: BorderRadius.circular(16),
                boxShadow: _selectedPerson != null
                    ? AppTheme.shadowGlow
                    : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _selectedPerson != null && !_isLinking
                      ? _linkProfile
                      : null,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: _isLinking
                        ? const Center(
                            child: SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.link_rounded,
                                color: _selectedPerson != null
                                    ? Colors.white
                                    : AppTheme.textMuted,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _selectedPerson != null
                                    ? 'Link as ${_selectedPerson!.firstName}'
                                    : 'Select a person to link',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: _selectedPerson != null
                                      ? Colors.white
                                      : AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Skip button
          TextButton(
            onPressed: _skipForNow,
            child: Text(
              'Skip for now',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          Text(
            'You can link your profile later from settings',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
