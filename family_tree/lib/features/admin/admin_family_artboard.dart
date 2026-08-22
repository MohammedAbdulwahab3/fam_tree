import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:family_tree/data/models/person.dart';
import 'package:family_tree/data/repositories/person_repository.dart';
import 'package:family_tree/data/repositories/admin_repository.dart';
import 'package:family_tree/core/theme/elegant_theme.dart';
import 'package:family_tree/core/theme/app_theme.dart';

/// Alias for backward compatibility
typedef ArtboardColors = ElegantColors;

/// Beautiful Admin Family Artboard
/// An elegant, high-fidelity view for managing the family tree
class AdminFamilyArtboard extends ConsumerStatefulWidget {
  final bool showBackButton;
  
  const AdminFamilyArtboard({
    Key? key,
    this.showBackButton = true,
  }) : super(key: key);

  @override
  ConsumerState<AdminFamilyArtboard> createState() => _AdminFamilyArtboardState();
}

class _AdminFamilyArtboardState extends ConsumerState<AdminFamilyArtboard>
    with TickerProviderStateMixin {
  final PersonRepository _personRepo = PersonRepository();
  final AdminRepository _adminRepo = AdminRepository();
  
  List<Person> _persons = [];
  List<Person> _filteredPersons = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedGeneration = 'All';
  Person? _selectedPerson;
  
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final List<String> _generations = ['All', 'Gen 1', 'Gen 2', 'Gen 3', 'Gen 4', 'Gen 5'];
  
  // Map to cache branch colors for each person
  Map<String, Color> _branchColorMap = {};
  
  // Track collapsed branches
  Set<String> _collapsedBranches = {};
  
  // Multi-select mode for batch operations
  bool _isMultiSelectMode = false;
  Set<String> _selectedPersonIds = {};
  
  // Layout mode: 'tree' for horizontal tree, 'list' for compact vertical, 'focus' for one family at a time
  String _layoutMode = 'focus';
  
  // Stack of focused persons for drill-down navigation
  List<String> _focusStack = [];
  
  // Zoom level for tree view (controlled by buttons only)
  double _zoomLevel = 1.0;
  final ScrollController _verticalScrollController = ScrollController(initialScrollOffset: 500);
  final ScrollController _horizontalScrollController = ScrollController(initialScrollOffset: 500);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _loadData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final persons = await _personRepo.getFamilyMembers('main-family-tree');
      setState(() {
        _persons = persons;
        _filteredPersons = persons;
        _isLoading = false;
        _buildBranchColorMap();
      });
      _fadeController.forward();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }
  
  /// Build a map of person ID to their family branch color
  void _buildBranchColorMap() {
    _branchColorMap = {};
    
    // Find root (Gen 1 - Mohammed)
    final roots = _persons.where((p) => p.relationships.parentIds.isEmpty).toList();
    
    // Assign gold color to roots
    for (final root in roots) {
      _branchColorMap[root.id] = ArtboardColors.gold;
    }
    
    // Find Gen 2 (children of root) and assign each a unique branch color
    final gen2 = _persons.where((p) => 
      roots.any((root) => p.relationships.parentIds.contains(root.id))).toList();
    
    for (int i = 0; i < gen2.length; i++) {
      final branchColor = ArtboardColors.branchColors[i % ArtboardColors.branchColors.length];
      _branchColorMap[gen2[i].id] = branchColor;
      // Propagate this color to all descendants
      _assignBranchColorToDescendants(gen2[i].id, branchColor);
    }
  }
  
  /// Recursively assign branch color to all descendants
  void _assignBranchColorToDescendants(String parentId, Color color) {
    final children = _persons.where((p) => 
      p.relationships.parentIds.contains(parentId)).toList();
    
    for (final child in children) {
      _branchColorMap[child.id] = color;
      _assignBranchColorToDescendants(child.id, color);
    }
  }
  
  /// Get the branch color for a person
  Color _getBranchColor(Person person) {
    return _branchColorMap[person.id] ?? ArtboardColors.warmGray;
  }

  void _filterPersons() {
    setState(() {
      _filteredPersons = _persons.where((p) {
        final matchesSearch = _searchQuery.isEmpty ||
            p.fullName.toLowerCase().contains(_searchQuery.toLowerCase());
        
        if (_selectedGeneration == 'All') return matchesSearch;
        
        // Simple generation detection based on parent chain depth
        final genNum = int.tryParse(_selectedGeneration.replaceAll('Gen ', '')) ?? 0;
        final personGen = _getGenerationNumber(p);
        return matchesSearch && personGen == genNum;
      }).toList();
    });
  }

  int _getGenerationNumber(Person person) {
    if (person.relationships.parentIds.isEmpty) return 1;
    
    // Find parent and get their generation
    final parent = _persons.where((p) => 
      person.relationships.parentIds.contains(p.id)).firstOrNull;
    if (parent == null) return 1;
    
    return _getGenerationNumber(parent) + 1;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : ArtboardColors.cream,
      body: Stack(
        children: [
          // Subtle pattern background
          _buildPatternBackground(),
          
          // Main content
          SafeArea(
            child: Column(
              children: [
                // Header with back navigation
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.go('/admin'),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.1) : ArtboardColors.warmWhite,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? Colors.white.withOpacity(0.1) : ArtboardColors.champagne,
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_back_rounded,
                            size: 20,
                            color: isDark ? Colors.white : ArtboardColors.charcoal,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Family Artboard',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : ArtboardColors.charcoal,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildFilterBar(),
                Expanded(
                  child: _isLoading
                      ? _buildLoadingState()
                      : _buildFamilyGrid(),
                ),
              ],
            ),
          ),
          
          // Selected person detail panel
          if (_selectedPerson != null)
            _buildDetailPanel(),
        ],
      ),
    );
  }

  Widget _buildPatternBackground() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Positioned.fill(
      child: CustomPaint(
        painter: _PatternPainter(isDark: isDark),
      ),
    );
  }
  
  // Helper method to get color based on theme
  Color _getTextColor(BuildContext context, Color lightColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.white : lightColor;
  }
  
  Color _getBackgroundColor(BuildContext context, Color lightColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppTheme.surfaceDark : lightColor;
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        
        if (isMobile) {
          // Mobile layout - vertical stack
          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back button and badge row
                Row(
                  children: [
                    if (widget.showBackButton) ...[
                      _buildElegantButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => context.go('/admin'),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: ArtboardColors.terracotta.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: ArtboardColors.terracotta.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.family_restroom_rounded,
                              size: 14,
                              color: ArtboardColors.terracotta,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'FAMILY ARTBOARD',
                              style: GoogleFonts.cormorantGaramond(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                                color: ArtboardColors.terracotta,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Title
                Text(
                  'Mohammed\'s Legacy',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : ArtboardColors.charcoal,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_persons.length} members • ${_generations.length - 1} generations',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : ArtboardColors.warmGray,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Stats - horizontal compact
                Row(
                  children: [
                    Expanded(
                      child: _buildCompactStatBadge('${_persons.length}', 'Members', ArtboardColors.terracotta),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildCompactStatBadge('5', 'Generations', ArtboardColors.sage),
                    ),
                  ],
                ),
              ],
            ),
          );
        }
        
        // Desktop layout - original horizontal design
        return Container(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              if (widget.showBackButton) ...[
                _buildElegantButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => context.go('/admin'),
                ),
                const SizedBox(width: 20),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: ArtboardColors.terracotta.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: ArtboardColors.terracotta.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.family_restroom_rounded,
                                size: 16,
                                color: ArtboardColors.terracotta,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'FAMILY ARTBOARD',
                                style: GoogleFonts.cormorantGaramond(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2,
                                  color: ArtboardColors.terracotta,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Mohammed\'s Legacy',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: ArtboardColors.charcoal,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_persons.length} family members across ${_generations.length - 1} generations',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 16,
                        color: ArtboardColors.warmGray,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatBadge('${_persons.length}', 'Members', ArtboardColors.terracotta),
              const SizedBox(width: 12),
              _buildStatBadge('5', 'Generations', ArtboardColors.sage),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatBadge(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: ArtboardColors.warmWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.playfairDisplay(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 12,
              color: ArtboardColors.warmGray,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatBadge(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ArtboardColors.warmWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 11,
              color: ArtboardColors.warmGray,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 900;
        
        if (isMobile) {
          // Mobile layout - horizontally scrollable with all controls
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ArtboardColors.warmWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ArtboardColors.champagne),
                  boxShadow: [
                    BoxShadow(
                      color: ArtboardColors.sienna.withOpacity(0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Search
                    Container(
                      width: 200,
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: ArtboardColors.champagne),
                      ),
                      child: TextField(
                        onChanged: (value) {
                          _searchQuery = value;
                          _filterPersons();
                        },
                        cursorColor: ArtboardColors.terracotta,
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 15,
                          color: Colors.black87, // Always dark text on white background
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search...',
                          hintStyle: GoogleFonts.cormorantGaramond(
                            color: Colors.black45, // Clear hint color
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                          ),
                          border: InputBorder.none,
                          icon: Icon(
                            Icons.search_rounded,
                            size: 20,
                            color: ArtboardColors.terracotta,
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    
                    // Generation filters
                    ...List.generate(_generations.length, (index) {
                      final gen = _generations[index];
                      final isSelected = _selectedGeneration == gen;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _selectedGeneration = gen);
                            _filterPersons();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? ArtboardColors.terracotta : ArtboardColors.cream,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? ArtboardColors.terracotta : ArtboardColors.champagne,
                              ),
                            ),
                            child: Text(
                              gen,
                              style: GoogleFonts.cormorantGaramond(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? Colors.white : ArtboardColors.warmGray,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    
                    const SizedBox(width: 10),  // Simplified - removed layout toggles
                    
                    // Multi-select
                    GestureDetector(
                      onTap: () => setState(() {
                        _isMultiSelectMode = !_isMultiSelectMode;
                        if (!_isMultiSelectMode) _selectedPersonIds.clear();
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: _isMultiSelectMode ? ArtboardColors.terracotta : ArtboardColors.cream,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _isMultiSelectMode ? ArtboardColors.terracotta : ArtboardColors.champagne,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isMultiSelectMode ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                              size: 16,
                              color: _isMultiSelectMode ? Colors.white : ArtboardColors.warmGray,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Select',
                              style: GoogleFonts.cormorantGaramond(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _isMultiSelectMode ? Colors.white : ArtboardColors.warmGray,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 10),
                    
                    // Add Person
                    GestureDetector(
                      onTap: _showAddPersonDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: ArtboardColors.terracotta,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.person_add_rounded, size: 16, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              'Add',
                              style: GoogleFonts.cormorantGaramond(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 6),
                    
                    // Refresh
                    GestureDetector(
                      onTap: _loadData,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: ArtboardColors.cream,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: ArtboardColors.champagne),
                        ),
                        child: Icon(
                          Icons.refresh_rounded,
                          size: 20,
                          color: ArtboardColors.terracotta,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        
        // Desktop layout - full controls
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ArtboardColors.warmWhite,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ArtboardColors.champagne),
            boxShadow: [
              BoxShadow(
                color: ArtboardColors.sienna.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Search
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: ArtboardColors.cream,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    onChanged: (value) {
                      _searchQuery = value;
                      _filterPersons();
                    },
                    cursorColor: ArtboardColors.terracotta,
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 16,
                      color: ArtboardColors.charcoal,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search family members...',
                      hintStyle: GoogleFonts.cormorantGaramond(
                        color: ArtboardColors.warmGray.withOpacity(0.6),
                        fontStyle: FontStyle.italic,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: ArtboardColors.champagne),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: ArtboardColors.champagne),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: ArtboardColors.terracotta, width: 2),
                      ),
                      filled: true,
                      fillColor: ElegantColors.cream,
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: ArtboardColors.terracotta.withOpacity(0.7),
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Generation filter
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: ArtboardColors.cream,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: _generations.map((gen) {
                    final isSelected = _selectedGeneration == gen;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedGeneration = gen);
                        _filterPersons();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? ArtboardColors.terracotta : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          gen,
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : ArtboardColors.warmGray,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              
              // Removed layout toggles - focus mode only
              
              const SizedBox(width: 12),
              
              // Multi-select toggle
              GestureDetector(
                onTap: () => setState(() {
                  _isMultiSelectMode = !_isMultiSelectMode;
                  if (!_isMultiSelectMode) _selectedPersonIds.clear();
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _isMultiSelectMode ? ArtboardColors.terracotta : ArtboardColors.warmWhite,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isMultiSelectMode ? ArtboardColors.terracotta : ArtboardColors.champagne,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isMultiSelectMode ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                        size: 16,
                        color: _isMultiSelectMode ? Colors.white : ArtboardColors.warmGray,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Select',
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _isMultiSelectMode ? Colors.white : ArtboardColors.warmGray,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Batch delete button (only when multi-select is active)
              if (_isMultiSelectMode && _selectedPersonIds.isNotEmpty) ...[ 
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _confirmBatchDelete,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: ArtboardColors.rust,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.delete_sweep_rounded, size: 16, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          'Delete (${_selectedPersonIds.length})',
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              
              // Batch add button
              if (_isMultiSelectMode) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _showBatchAddDialog(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: ArtboardColors.sage,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.group_add_rounded, size: 16, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          'Add Multiple',
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              
              const SizedBox(width: 12),
              
              // Add Person button
              GestureDetector(
                onTap: _showAddPersonDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: ArtboardColors.terracotta,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_add_rounded, size: 18, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        'Add Person',
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(width: 8),
              
              // Refresh button
              _buildElegantButton(
                icon: Icons.refresh_rounded,
                onTap: _loadData,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLayoutToggle(String mode, IconData icon, String label, {bool isFirst = false, bool isLast = false}) {
    final isActive = _layoutMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _layoutMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? ArtboardColors.terracotta : Colors.transparent,
          borderRadius: BorderRadius.horizontal(
            left: isFirst ? const Radius.circular(11) : Radius.zero,
            right: isLast ? const Radius.circular(11) : Radius.zero,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isActive ? Colors.white : ArtboardColors.warmGray),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isActive ? Colors.white : ArtboardColors.warmGray,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactLayoutToggle(String mode, IconData icon) {
    final isActive = _layoutMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _layoutMode = mode),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isActive ? ArtboardColors.terracotta : ArtboardColors.cream,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? ArtboardColors.terracotta : ArtboardColors.champagne,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isActive ? Colors.white : ArtboardColors.warmGray,
        ),
      ),
    );
  }

  Widget _buildFamilyGrid() {
    // Find root person (no parents = generation 1)
    final roots = _filteredPersons.where((p) => 
      p.relationships.parentIds.isEmpty).toList();
    
    if (roots.isEmpty && _filteredPersons.isNotEmpty) {
      return _buildFlatGrid();
    }

    // Always use focus layout (simplified)
    return _buildFocusLayout(roots);
  }

  /// Focus layout - recursive drill-down approach
  Widget _buildFocusLayout(List<Person> roots) {
    if (roots.isEmpty) return const SizedBox();
    
    final patriarch = roots.first;
    
    // Determine current focused person
    Person? currentPerson;
    if (_focusStack.isEmpty) {
      currentPerson = patriarch;
    } else {
      currentPerson = _persons.firstWhere(
        (p) => p.id == _focusStack.last,
        orElse: () => patriarch,
      );
    }
    
    // Get children of current person
    final children = _persons.where((p) => 
      p.relationships.parentIds.contains(currentPerson!.id)).toList();

    return FadeTransition(
      opacity: _fadeAnimation,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(animation),
              child: child,
            ),
          );
        },
        child: _buildDrillDownView(currentPerson!, children),
      ),
    );
  }

  Widget _buildDrillDownView(Person person, List<Person> children) {
    final color = _getBranchColor(person);
    final generation = _getGenerationNumber(person);
    final isRoot = _focusStack.isEmpty;
    final childCount = children.length;
    
    // Get siblings for navigation (children of parent)
    List<Person> siblings = [];
    int currentIndex = 0;
    if (!isRoot && person.relationships.parentIds.isNotEmpty) {
      final parentId = person.relationships.parentIds.first;
      siblings = _persons.where((p) => 
        p.relationships.parentIds.contains(parentId)).toList();
      currentIndex = siblings.indexWhere((p) => p.id == person.id);
    }

    return Column(
      key: ValueKey(person.id),
      children: [
        // Navigation header
        if (!isRoot) _buildDrillDownNav(person, color, siblings, currentIndex),
        
        // Main content - aligned to top, horizontally centered
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                  // Current person - large card
                  _buildLargeFocusCard(person, color, generation, isRoot, childCount),
                  
                  if (children.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    
                    // Connecting line
                    Container(
                      width: 3,
                      height: 24,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    
                    const SizedBox(height: 10),
                    
                    // Children label
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: ArtboardColors.cream,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withOpacity(0.2)),
                      ),
                      child: Text(
                        '${children.length} ${children.length == 1 ? "Child" : "Children"}',
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 18),
                    
                    // Children cards - dynamic spacing
                    Wrap(
                      spacing: _getCardSpacing(childCount),
                      runSpacing: _getCardSpacing(childCount),
                      alignment: WrapAlignment.center,
                      children: children.asMap().entries.map((entry) => 
                        _buildChildCard(entry.value, entry.key, childCount)
                      ).toList(),
                    ),
                  
                    const SizedBox(height: 32),
                  
                    // Hint
                    if (children.any((c) => _persons.any((p) => p.relationships.parentIds.contains(c.id))))
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.touch_app_rounded, size: 18, color: ArtboardColors.warmGray),
                          const SizedBox(width: 8),
                          Text(
                            'Tap to explore descendants',
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: 14,
                              color: ArtboardColors.warmGray,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                  ] else ...[
                  const SizedBox(height: 60),
                  // No children message
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: ArtboardColors.cream.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.family_restroom_rounded, size: 40, color: ArtboardColors.warmGray.withOpacity(0.5)),
                        const SizedBox(height: 12),
                        Text(
                          'No children recorded',
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 16,
                            color: ArtboardColors.warmGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
        
        // Bottom navigation
        if (!isRoot) _buildDrillDownFooterNav(siblings, currentIndex),
      ],
    );
  }

  Widget _buildDrillDownNav(Person person, Color color, List<Person> siblings, int currentIndex) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: ArtboardColors.warmWhite,
        border: Border(bottom: BorderSide(color: ArtboardColors.champagne)),
        boxShadow: [
          BoxShadow(color: ArtboardColors.sienna.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => setState(() {
              if (_focusStack.isNotEmpty) _focusStack.removeLast();
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: ArtboardColors.cream,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ArtboardColors.champagne),
              ),
              child: Row(
                children: [
                  const Icon(Icons.arrow_back_rounded, size: 18, color: ArtboardColors.charcoal),
                  const SizedBox(width: 8),
                  Text(
                    'Back',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: ArtboardColors.charcoal,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Breadcrumb path
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _focusStack.clear()),
                    child: Text(
                      'Home',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 14,
                        color: ArtboardColors.terracotta,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ..._focusStack.map((id) {
                    final p = _persons.firstWhere((p) => p.id == id, orElse: () => person);
                    final pColor = _getBranchColor(p);
                    final isLast = id == _focusStack.last;
                    return Row(
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.chevron_right_rounded, size: 16, color: ArtboardColors.warmGray),
                        ),
                        GestureDetector(
                          onTap: isLast ? null : () {
                            final idx = _focusStack.indexOf(id);
                            setState(() => _focusStack = _focusStack.sublist(0, idx + 1));
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isLast ? pColor.withOpacity(0.15) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              p.firstName,
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 14,
                                fontWeight: isLast ? FontWeight.w700 : FontWeight.w500,
                                color: isLast ? pColor : ArtboardColors.warmGray,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
          
          // Generation indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Gen ${_getGenerationNumber(person)}',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Dynamic sizing helpers
  double _getCardSpacing(int count) {
    if (count <= 3) return 16;
    if (count <= 6) return 12;
    return 8;
  }
  
  double _getChildCardWidth(int count) {
    if (count == 1) return 170;
    if (count == 2) return 155;
    if (count <= 4) return 140;
    if (count <= 6) return 120;
    if (count <= 9) return 105;
    return 95;
  }
  
  double _getChildAvatarSize(int count) {
    if (count <= 2) return 48;
    if (count <= 4) return 42;
    if (count <= 6) return 36;
    return 30;
  }
  
  double _getChildFontSize(int count) {
    if (count <= 2) return 14;
    if (count <= 4) return 13;
    if (count <= 6) return 12;
    return 11;
  }

  Widget _buildLargeFocusCard(Person person, Color color, int generation, bool isRoot, int childCount) {
    final avatarSize = childCount > 6 ? 55.0 : 70.0;
    final nameFontSize = childCount > 6 ? 18.0 : 22.0;
    final padding = childCount > 6 ? 16.0 : 20.0;
    final maxWidth = childCount > 6 ? 380.0 : 420.0;
    
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: ArtboardColors.warmWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.12), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          // Avatar - dynamic size
          Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withOpacity(0.85), color],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Center(
              child: Text(
                person.firstName[0].toUpperCase(),
                style: GoogleFonts.playfairDisplay(fontSize: avatarSize * 0.4, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isRoot) ...[
                        const Icon(Icons.star_rounded, size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        isRoot ? 'PATRIARCH' : 'GEN $generation',
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 5),
                
                // Name - dynamic size
                Text(
                  person.fullName,
                  style: GoogleFonts.playfairDisplay(fontSize: nameFontSize, fontWeight: FontWeight.w700, color: ArtboardColors.charcoal),
                ),
                
                if (person.lifespan.isNotEmpty)
                  Text(
                    person.lifespan,
                    style: GoogleFonts.cormorantGaramond(fontSize: 12, color: ArtboardColors.warmGray),
                  ),
                
                const SizedBox(height: 4),
                
                // Stats
                Text(
                  '${_getDescendantCount(person)} descendants',
                  style: GoogleFonts.cormorantGaramond(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                ),
              ],
            ),
          ),
          
          // Actions
          Column(
            children: [
              _buildMiniAction(Icons.edit_rounded, ArtboardColors.sage, () => _showEditDialog(person)),
              const SizedBox(height: 6),
              _buildMiniAction(Icons.person_add_alt_rounded, color, () => _showUnifiedAddDialog(preSelectedParent: person)),
              if (!isRoot) ...[
                const SizedBox(height: 6),
                _buildMiniAction(Icons.delete_outline_rounded, ArtboardColors.rust, () => _confirmDelete(person)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChildCard(Person person, int index, int totalChildren) {
    final color = _getBranchColor(person);
    final descendantCount = _getDescendantCount(person);
    final hasChildren = descendantCount > 0;
    final generation = _getGenerationNumber(person);
    
    // Dynamic sizing based on total children
    final cardWidth = _getChildCardWidth(totalChildren);
    final avatarSize = _getChildAvatarSize(totalChildren);
    final fontSize = _getChildFontSize(totalChildren);
    final isCompact = totalChildren > 6;
    final padding = isCompact ? 10.0 : 16.0;
    
    return LongPressDraggable<Person>(
      data: person,
      delay: const Duration(milliseconds: 300),
      hapticFeedbackOnStart: true,
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(24),
        child: Opacity(
          opacity: 0.8,
          child: Container(
            width: cardWidth,
            height: cardWidth * 1.2,
            decoration: BoxDecoration(
              color: ArtboardColors.warmWhite,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: color, width: 2),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: avatarSize,
                    height: avatarSize,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color.withOpacity(0.8), color],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        person.firstName[0].toUpperCase(),
                        style: GoogleFonts.playfairDisplay(
                          fontSize: avatarSize * 0.4,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    person.firstName,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w700,
                      color: ArtboardColors.charcoal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      child: DragTarget<Person>(
        onWillAccept: (data) => data != null && data.id != person.id,
        onAccept: (draggedPerson) => _swapPersons(draggedPerson, person),
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;
          return GestureDetector(
            onTap: () => setState(() => _focusStack.add(person.id)),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 200 + (index * 40)),
                curve: Curves.easeOutBack,
                builder: (context, value, child) {
                  return Transform.scale(scale: value, child: Opacity(opacity: value, child: child));
                },
                child: Container(
                  width: cardWidth,
                  padding: EdgeInsets.all(padding),
                  decoration: BoxDecoration(
                    color: ArtboardColors.warmWhite,
                    borderRadius: BorderRadius.circular(isCompact ? 14 : 18),
                    border: Border.all(
                      color: isHovering ? color : color.withOpacity(0.3), 
                      width: isHovering ? 2 : 1
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(isHovering ? 0.2 : 0.08), 
                        blurRadius: isHovering ? 16 : 10, 
                        offset: const Offset(0, 4)
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Avatar - dynamic size
                      Container(
                        width: avatarSize,
                        height: avatarSize,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [color.withOpacity(0.85), color],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: color.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 2))],
                        ),
                        child: Center(
                          child: Text(
                            person.firstName[0].toUpperCase(),
                            style: GoogleFonts.playfairDisplay(fontSize: avatarSize * 0.44, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ),
                      ),
                      
                      SizedBox(height: isCompact ? 6 : 10),
                      
                      // Name
                      Text(
                        person.firstName,
                        style: GoogleFonts.playfairDisplay(fontSize: fontSize, fontWeight: FontWeight.w700, color: ArtboardColors.charcoal),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      if (!isCompact)
                        Text(
                          person.lastName,
                          style: GoogleFonts.cormorantGaramond(fontSize: fontSize - 2, color: ArtboardColors.warmGray),
                          overflow: TextOverflow.ellipsis,
                        ),
                      
                      SizedBox(height: isCompact ? 4 : 8),
                      
                      // Descendants or explore
                      Text(
                        hasChildren ? '$descendantCount desc.' : 'No children',
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: isCompact ? 9 : 11, 
                          fontWeight: hasChildren ? FontWeight.w600 : FontWeight.w400,
                          color: hasChildren ? color : ArtboardColors.warmGray,
                        ),
                      ),
                      
                      SizedBox(height: isCompact ? 4 : 8),
                      
                      // Admin Actions Row - Edit/Delete
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Edit button
                          GestureDetector(
                            onTap: () => _showEditDialog(person),
                            child: Container(
                              padding: EdgeInsets.all(isCompact ? 6 : 8),
                              decoration: BoxDecoration(
                                color: ArtboardColors.sage.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.edit_rounded,
                                size: isCompact ? 14 : 18,
                                color: ArtboardColors.sage,
                              ),
                            ),
                          ),
                          SizedBox(width: isCompact ? 6 : 10),
                          // Explore/View button
                          GestureDetector(
                            onTap: () => setState(() => _focusStack.add(person.id)),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 14, vertical: isCompact ? 5 : 7),
                              decoration: BoxDecoration(
                                color: hasChildren ? color : ArtboardColors.warmGray.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                hasChildren ? 'Explore' : 'View',
                                style: GoogleFonts.cormorantGaramond(fontSize: isCompact ? 10 : 12, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                            ),
                          ),
                          SizedBox(width: isCompact ? 6 : 10),
                          // Delete button
                          GestureDetector(
                            onTap: () => _confirmDelete(person),
                            child: Container(
                              padding: EdgeInsets.all(isCompact ? 6 : 8),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.delete_rounded,
                                size: isCompact ? 14 : 18,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDrillDownFooterNav(List<Person> siblings, int currentIndex) {
    final hasPrev = currentIndex > 0;
    final hasNext = currentIndex < siblings.length - 1;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: ArtboardColors.warmWhite,
        border: Border(top: BorderSide(color: ArtboardColors.champagne)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous sibling
          if (hasPrev)
            _buildSiblingNavButton(siblings[currentIndex - 1], true)
          else
            const SizedBox(width: 140),
          
          // Back to parent
          GestureDetector(
            onTap: () => setState(() {
              if (_focusStack.isNotEmpty) _focusStack.removeLast();
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: ArtboardColors.charcoal,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.arrow_upward_rounded, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'Back to Parent',
                    style: GoogleFonts.cormorantGaramond(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          
          // Next sibling
          if (hasNext)
            _buildSiblingNavButton(siblings[currentIndex + 1], false)
          else
            const SizedBox(width: 140),
        ],
      ),
    );
  }

  Widget _buildSiblingNavButton(Person sibling, bool isPrev) {
    final color = _getBranchColor(sibling);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (_focusStack.isNotEmpty) {
            _focusStack[_focusStack.length - 1] = sibling.id;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPrev) Icon(Icons.arrow_back_rounded, size: 16, color: color),
            if (isPrev) const SizedBox(width: 8),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Center(
                child: Text(
                  sibling.firstName[0],
                  style: GoogleFonts.playfairDisplay(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              sibling.firstName,
              style: GoogleFonts.cormorantGaramond(fontSize: 13, fontWeight: FontWeight.w700, color: color),
            ),
            if (!isPrev) const SizedBox(width: 8),
            if (!isPrev) Icon(Icons.arrow_forward_rounded, size: 16, color: color),
          ],
        ),
      ),
    );
  }


  /// Compact vertical list layout
  Widget _buildListLayout(List<Person> roots) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...roots.map((root) => _buildCompactTreeNode(root, 0)),
          ],
        ),
      ),
    );
  }

  /// Horizontal tree layout
  Widget _buildTreeLayout(List<Person> roots) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          // Zoom controls
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildZoomButton(Icons.remove_rounded, () {
                  setState(() => _zoomLevel = (_zoomLevel - 0.1).clamp(0.3, 2.0));
                }),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: ArtboardColors.cream,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${(_zoomLevel * 100).toInt()}%',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: ArtboardColors.charcoal,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _buildZoomButton(Icons.add_rounded, () {
                  setState(() => _zoomLevel = (_zoomLevel + 0.1).clamp(0.3, 2.0));
                }),
                const SizedBox(width: 20),
                _buildZoomButton(Icons.fit_screen_rounded, () {
                  setState(() => _zoomLevel = 1.0);
                }),
              ],
            ),
          ),
          
          // Tree content - scrollable with padding above
          Expanded(
            child: SingleChildScrollView(
              controller: _verticalScrollController,
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                controller: _horizontalScrollController,
                scrollDirection: Axis.horizontal,
                child: Transform.scale(
                  scale: _zoomLevel,
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: 500, // Allow scrolling "up"
                      bottom: 500,
                      left: 500,
                      right: 500,
                    ),
                    child: Column(
                      children: [
                        ...roots.map((root) => _buildHorizontalTreeNode(root, 0)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoomButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: ArtboardColors.warmWhite,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ArtboardColors.champagne),
          boxShadow: [
            BoxShadow(
              color: ArtboardColors.sienna.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: ArtboardColors.terracotta),
      ),
    );
  }

  /// Horizontal tree node (original tree layout)
  Widget _buildHorizontalTreeNode(Person person, int depth) {
    final children = _filteredPersons.where((p) => 
      p.relationships.parentIds.contains(person.id)).toList();
    final generation = depth + 1;
    final branchColor = _getBranchColor(person);
    final isRoot = depth == 0;

    return Column(
      children: [
        // The person node
        isRoot 
            ? _buildRootPersonCard(person, branchColor)
            : _buildTreePersonCard(person, generation, branchColor),
        
        // Connector line down if has children
        if (children.isNotEmpty) ...[
          // Vertical line from parent
          Container(
            width: 6,
            height: isRoot ? 80 : 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: branchColor,
              boxShadow: [
                BoxShadow(
                  color: branchColor.withOpacity(0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          
          // Horizontal connector bar for multiple children
          if (children.length > 1)
            Container(
              height: 6,
              width: (children.length * 210.0) + 30,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: ArtboardColors.charcoal.withOpacity(0.7),
                boxShadow: [
                  BoxShadow(
                    color: ArtboardColors.charcoal.withOpacity(0.3),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          
          // Children row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children.map((child) {
              final childColor = _getBranchColor(child);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    // Vertical drop line
                    Container(
                      width: 6,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: childColor,
                        boxShadow: [
                          BoxShadow(
                            color: childColor.withOpacity(0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildHorizontalTreeNode(child, depth + 1),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
        
        // Extra spacing
        SizedBox(height: isRoot ? 30 : 20),
      ],
    );
  }

  /// Special large card for root/patriarch (tree view)
  Widget _buildRootPersonCard(Person person, Color branchColor) {
    final isSelected = _selectedPerson?.id == person.id;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedPerson = person),
      child: Container(
        width: 260,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                ArtboardColors.warmWhite,
                ArtboardColors.champagne.withOpacity(0.5),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: branchColor,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: branchColor.withOpacity(0.35),
                blurRadius: 25,
                spreadRadius: 4,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: ArtboardColors.gold.withOpacity(0.15),
                blurRadius: 50,
                spreadRadius: 8,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Crown/Patriarch badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [branchColor, branchColor.withOpacity(0.8)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: branchColor.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, size: 16, color: Colors.white),
                    const SizedBox(width: 5),
                    Text(
                      'PATRIARCH',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(Icons.star_rounded, size: 16, color: Colors.white),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // Large Avatar
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [branchColor.withOpacity(0.85), branchColor],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: branchColor.withOpacity(0.45),
                      blurRadius: 18,
                      spreadRadius: 4,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    person.firstName[0].toUpperCase(),
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 38,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Name
              Text(
                person.firstName,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: ArtboardColors.charcoal,
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                person.lastName,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 16,
                  color: ArtboardColors.warmGray,
                  fontStyle: FontStyle.italic,
                ),
              ),
              
              // Lifespan
              if (person.lifespan.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: ArtboardColors.cream,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    person.lifespan,
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 12,
                      color: ArtboardColors.warmGray,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              
              const SizedBox(height: 16),
              
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildMiniAction(
                    Icons.edit_rounded,
                    ArtboardColors.sage,
                    () => _showEditDialog(person),
                  ),
                  const SizedBox(width: 8),
                  _buildMiniAction(
                    Icons.person_add_alt_rounded,
                    ArtboardColors.copper,
                    () => _showUnifiedAddDialog(preSelectedParent: person),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Compact vertical tree - much easier to read
  Widget _buildCompactTreeNode(Person person, int depth) {
    final children = _filteredPersons.where((p) => 
      p.relationships.parentIds.contains(person.id)).toList();
    final generation = depth + 1;
    final branchColor = _getBranchColor(person);
    final isRoot = depth == 0;
    final isCollapsed = _collapsedBranches.contains(person.id);
    final hasChildren = children.isNotEmpty;
    final isSelected = _selectedPerson?.id == person.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The person row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Indent based on depth
            if (depth > 0)
              SizedBox(width: depth * 40.0),
            
            // Vertical line connector for non-root
            if (depth > 0)
              Container(
                width: 3,
                height: isRoot ? 80 : 60,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: branchColor,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: branchColor.withOpacity(0.4),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            
            // Person card
            Expanded(
              child: _buildCompactPersonCard(
                person: person,
                generation: generation,
                branchColor: branchColor,
                isRoot: isRoot,
                isSelected: isSelected,
                hasChildren: hasChildren,
                isCollapsed: isCollapsed,
                onToggleCollapse: () {
                  setState(() {
                    if (isCollapsed) {
                      _collapsedBranches.remove(person.id);
                    } else {
                      _collapsedBranches.add(person.id);
                    }
                  });
                },
              ),
            ),
          ],
        ),
        
        // Children (if not collapsed)
        if (hasChildren && !isCollapsed)
          Padding(
            padding: EdgeInsets.only(left: depth * 40.0 + 20),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: branchColor.withOpacity(0.4),
                    width: 3,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children.map((child) => 
                  _buildCompactTreeNode(child, depth + 1)
                ).toList(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCompactPersonCard({
    required Person person,
    required int generation,
    required Color branchColor,
    required bool isRoot,
    required bool isSelected,
    required bool hasChildren,
    required bool isCollapsed,
    required VoidCallback onToggleCollapse,
  }) {
    return GestureDetector(
      onTap: () => setState(() => _selectedPerson = person),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: EdgeInsets.all(isRoot ? 20 : 14),
        decoration: BoxDecoration(
          color: isSelected 
              ? branchColor.withOpacity(0.1)
              : ArtboardColors.warmWhite,
          borderRadius: BorderRadius.circular(isRoot ? 20 : 14),
          border: Border.all(
            color: isSelected ? branchColor : ArtboardColors.champagne,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (isRoot)
              BoxShadow(
                color: branchColor.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            BoxShadow(
              color: ArtboardColors.sienna.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: isRoot ? 64 : 48,
              height: isRoot ? 64 : 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [branchColor.withOpacity(0.85), branchColor],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: branchColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  person.firstName[0].toUpperCase(),
                  style: GoogleFonts.playfairDisplay(
                    fontSize: isRoot ? 26 : 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            
            // Name and info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Patriarch badge for root
                      if (isRoot) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: branchColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, size: 12, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                'PATRIARCH',
                                style: GoogleFonts.cormorantGaramond(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      
                      // Generation badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: branchColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Gen $generation',
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: branchColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  
                  // Name
                  Text(
                    person.fullName,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: isRoot ? 22 : 16,
                      fontWeight: FontWeight.w700,
                      color: ArtboardColors.charcoal,
                    ),
                  ),
                  
                  // Lifespan
                  if (person.lifespan.isNotEmpty)
                    Text(
                      person.lifespan,
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 12,
                        color: ArtboardColors.warmGray,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  
                  // Children count
                  if (hasChildren)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${_getDescendantCount(person)} descendants',
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 11,
                          color: branchColor.withOpacity(0.8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Action buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildCompactAction(
                  Icons.edit_rounded,
                  ArtboardColors.sage,
                  () => _showEditDialog(person),
                ),
                const SizedBox(width: 6),
                _buildCompactAction(
                  Icons.person_add_alt_rounded,
                  ArtboardColors.copper,
                  () => _showUnifiedAddDialog(preSelectedParent: person),
                ),
                const SizedBox(width: 6),
                _buildCompactAction(
                  Icons.delete_outline_rounded,
                  ArtboardColors.dustyRose,
                  () => _confirmDelete(person),
                ),
                
                // Collapse/Expand button
                if (hasChildren) ...[
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: onToggleCollapse,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: branchColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: branchColor.withOpacity(0.3)),
                      ),
                      child: Icon(
                        isCollapsed 
                            ? Icons.expand_more_rounded 
                            : Icons.expand_less_rounded,
                        size: 20,
                        color: branchColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactAction(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }

  int _getDescendantCount(Person person) {
    final children = _persons.where((p) => 
      p.relationships.parentIds.contains(person.id)).toList();
    int count = children.length;
    for (final child in children) {
      count += _getDescendantCount(child);
    }
    return count;
  }

  Widget _buildFlatGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 280,
        mainAxisSpacing: 20,
        crossAxisSpacing: 20,
        childAspectRatio: 0.85,
      ),
      itemCount: _filteredPersons.length,
      itemBuilder: (context, index) {
        return _buildPersonCard(_filteredPersons[index], index);
      },
    );
  }

  Widget _buildTreeNode(Person person, int depth) {
    final children = _filteredPersons.where((p) => 
      p.relationships.parentIds.contains(person.id)).toList();
    final generation = depth + 1;
    final branchColor = _getBranchColor(person);
    final isRoot = depth == 0;

    return Column(
      children: [
        // The person node - root gets special treatment
        isRoot 
            ? _buildRootPersonCard(person, branchColor)
            : _buildTreePersonCard(person, generation, branchColor),
        
        // Connector line down if has children
        if (children.isNotEmpty) ...[
          // Vertical line from parent - TALL and solid with border
          Container(
            width: 8,
            height: isRoot ? 100 : 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: branchColor,
              border: Border.all(
                color: Colors.white,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: branchColor.withOpacity(0.6),
                  blurRadius: 12,
                  spreadRadius: 3,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 4,
                  offset: const Offset(2, 2),
                ),
              ],
            ),
          ),
          
          // Horizontal connector bar for multiple children
          if (children.length > 1)
            Container(
              height: 8,
              width: (children.length * 210.0) + 30,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: ArtboardColors.charcoal,
                border: Border.all(
                  color: Colors.white.withOpacity(0.5),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: ArtboardColors.charcoal.withOpacity(0.4),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          
          // Children row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children.map((child) {
              final childColor = _getBranchColor(child);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Column(
                  children: [
                    // Vertical drop line to each child - SOLID and VISIBLE
                    Container(
                      width: 8,
                      height: 70,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: childColor,
                        border: Border.all(
                          color: Colors.white,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: childColor.withOpacity(0.6),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(2, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildTreeNode(child, depth + 1),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
        
        // Extra spacing after each node
        SizedBox(height: isRoot ? 40 : 30),
      ],
    );
  }

  Widget _buildTreePersonCard(Person person, int generation, Color branchColor) {
    final isSelected = _selectedPerson?.id == person.id;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedPerson = person),
      child: Container(
        width: 200,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        child: Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ArtboardColors.warmWhite,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? branchColor : ArtboardColors.champagne,
                  width: isSelected ? 2.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected 
                        ? branchColor.withOpacity(0.25)
                        : ArtboardColors.sienna.withOpacity(0.1),
                    blurRadius: isSelected ? 20 : 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Generation badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: branchColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Gen $generation',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: branchColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Avatar
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [branchColor.withOpacity(0.85), branchColor],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: branchColor.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        person.firstName[0].toUpperCase(),
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Name
                  Text(
                    person.firstName,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: ArtboardColors.charcoal,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    person.lastName,
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 12,
                      color: ArtboardColors.warmGray,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  
                  // Lifespan
                  if (person.lifespan.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      person.lifespan,
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 11,
                        color: ArtboardColors.warmGray.withOpacity(0.8),
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 12),
                  
                  // Edit and Add buttons only
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildMiniAction(
                        Icons.edit_rounded,
                        ArtboardColors.sage,
                        () => _showEditDialog(person),
                      ),
                      const SizedBox(width: 8),
                      _buildMiniAction(
                        Icons.person_add_alt_rounded,
                        ArtboardColors.copper,
                        () => _showUnifiedAddDialog(preSelectedParent: person),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Delete button at top right - commented out for now
            // Positioned(
            //   top: 8,
            //   right: 8,
            //   child: GestureDetector(
            //     onTap: () => _confirmDelete(person),
            //     child: Container(
            //       padding: const EdgeInsets.all(6),
            //       decoration: BoxDecoration(
            //         color: ArtboardColors.dustyRose.withOpacity(0.15),
            //         borderRadius: BorderRadius.circular(8),
            //       ),
            //       child: Icon(
            //         Icons.close_rounded,
            //         size: 14,
            //         color: ArtboardColors.dustyRose,
            //       ),
            //     ),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniAction(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }

  Widget _buildPersonCard(Person person, int index) {
    final generation = _getGenerationNumber(person);
    final branchColor = _getBranchColor(person);
    final isSelected = _selectedPerson?.id == person.id;
    
    return LongPressDraggable<Person>(
      data: person,
      delay: const Duration(milliseconds: 300),
      hapticFeedbackOnStart: true,
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(24),
        child: Opacity(
          opacity: 0.8,
          child: Container(
            width: 200,
            height: 250,
            decoration: BoxDecoration(
              color: ArtboardColors.warmWhite,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: branchColor, width: 2),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [branchColor.withOpacity(0.8), branchColor],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        person.firstName[0].toUpperCase(),
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    person.firstName,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: ArtboardColors.charcoal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildCardContent(person, index, generation, branchColor, isSelected),
      ),
      onDragStarted: () {
        setState(() => _selectedPerson = person);
      },
      child: DragTarget<Person>(
        onWillAccept: (data) => data != null && data.id != person.id,
        onAccept: (draggedPerson) {
          _swapPersons(draggedPerson, person);
        },
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            transform: Matrix4.identity()..scale(isHovering ? 1.05 : (isSelected ? 1.02 : 1.0)),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: isHovering
                  ? [
                      BoxShadow(
                        color: branchColor.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : [],
            ),
            child: _buildCardContent(person, index, generation, branchColor, isSelected),
          );
        },
      ),
    );
  }
  
  Widget _buildCardContent(Person person, int index, int generation, Color branchColor, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _selectedPerson = person),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()
          ..scale(isSelected ? 1.02 : 1.0),
        decoration: BoxDecoration(
          color: ArtboardColors.warmWhite,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? branchColor : ArtboardColors.champagne,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected 
                  ? branchColor.withOpacity(0.2)
                  : ArtboardColors.sienna.withOpacity(0.08),
              blurRadius: isSelected ? 24 : 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative corner accent
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: branchColor.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(24),
                    bottomLeft: Radius.circular(60),
                  ),
                ),
              ),
            ),
            
            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Generation badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: branchColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Gen $generation',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: branchColor,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Avatar
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            branchColor.withOpacity(0.8),
                            branchColor,
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: branchColor.withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          person.firstName[0].toUpperCase(),
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Name
                  Text(
                    person.firstName,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: ArtboardColors.charcoal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    person.lastName,
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 14,
                      color: ArtboardColors.warmGray,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Lifespan
                  if (person.lifespan.isNotEmpty)
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 14,
                          color: ArtboardColors.warmGray.withOpacity(0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          person.lifespan,
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 13,
                            color: ArtboardColors.warmGray,
                          ),
                        ),
                      ],
                    ),
                  
                  const Spacer(),
                  
                  // Action buttons
                  Row(
                    children: [
                      _buildCardAction(
                        Icons.edit_rounded,
                        ArtboardColors.sage,
                        () => _showEditDialog(person),
                      ),
                      const SizedBox(width: 8),
                      _buildCardAction(
                        Icons.person_add_alt_rounded,
                        ArtboardColors.copper,
                        () => _showUnifiedAddDialog(preSelectedParent: person),
                      ),
                      const Spacer(),
                      _buildCardAction(
                        Icons.delete_outline_rounded,
                        ArtboardColors.dustyRose,
                        () => _confirmDelete(person),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardAction(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  Widget _buildDetailPanel() {
    final person = _selectedPerson!;
    final generation = _getGenerationNumber(person);
    final branchColor = _getBranchColor(person);
    
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      width: 380,
      child: GestureDetector(
        onTap: () {}, // Prevent tap through
        child: Container(
          decoration: BoxDecoration(
            color: ArtboardColors.warmWhite,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(32),
              bottomLeft: Radius.circular(32),
            ),
            boxShadow: [
              BoxShadow(
                color: ArtboardColors.charcoal.withOpacity(0.15),
                blurRadius: 40,
                offset: const Offset(-10, 0),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      branchColor.withOpacity(0.1),
                      ArtboardColors.warmWhite,
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(32),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: branchColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Generation $generation',
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: branchColor,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _selectedPerson = null),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: ArtboardColors.cream,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: ArtboardColors.warmGray,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Avatar
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [branchColor.withOpacity(0.8), branchColor],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: branchColor.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          person.firstName[0].toUpperCase(),
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 40,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    Text(
                      person.fullName,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: ArtboardColors.charcoal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (person.lifespan.isNotEmpty)
                      Text(
                        person.lifespan,
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 16,
                          color: ArtboardColors.warmGray,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
              
              // Details
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailSection('Bio', person.bio ?? 'No biography added yet.'),
                      const SizedBox(height: 20),
                      _buildRelationshipSection(person),
                    ],
                  ),
                ),
              ),
              
              // Actions
              Container(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildPanelButton(
                        'Edit Profile',
                        Icons.edit_rounded,
                        ArtboardColors.sage,
                        () => _showEditDialog(person),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildPanelButton(
                        'Add Child',
                        Icons.person_add_rounded,
                        ArtboardColors.terracotta,
                        () => _showUnifiedAddDialog(preSelectedParent: person),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.cormorantGaramond(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: ArtboardColors.terracotta,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: GoogleFonts.cormorantGaramond(
            fontSize: 15,
            color: ArtboardColors.charcoal,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildRelationshipSection(Person person) {
    final parents = _persons.where((p) => 
      person.relationships.parentIds.contains(p.id)).toList();
    final children = _persons.where((p) => 
      person.relationships.childrenIds.contains(p.id)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RELATIONSHIPS',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: ArtboardColors.terracotta,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 12),
        
        if (parents.isNotEmpty) ...[
          Text(
            'Parents',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 13,
              color: ArtboardColors.warmGray,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 8),
          ...parents.map((p) => _buildRelationChip(p)),
          const SizedBox(height: 16),
        ],
        
        if (children.isNotEmpty) ...[
          Text(
            'Children (${children.length})',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 13,
              color: ArtboardColors.warmGray,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: children.map((p) => _buildRelationChip(p)).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildRelationChip(Person person) {
    return GestureDetector(
      onTap: () => setState(() => _selectedPerson = person),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: ArtboardColors.cream,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ArtboardColors.champagne),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: ArtboardColors.terracotta.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  person.firstName[0],
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: ArtboardColors.terracotta,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              person.firstName,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ArtboardColors.charcoal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanelButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
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
              style: GoogleFonts.cormorantGaramond(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildElegantButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ArtboardColors.warmWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ArtboardColors.champagne),
          boxShadow: [
            BoxShadow(
              color: ArtboardColors.sienna.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: ArtboardColors.charcoal,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: _showAddPersonDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [ArtboardColors.terracotta, ArtboardColors.rust],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: ArtboardColors.terracotta.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_add_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Text(
              'Add Family Member',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(ArtboardColors.terracotta),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading family tree...',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 18,
              color: ArtboardColors.warmGray,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Color _getGenerationColor(int generation) {
    switch (generation) {
      case 1: return ArtboardColors.gold;
      case 2: return ArtboardColors.terracotta;
      case 3: return ArtboardColors.sage;
      case 4: return ArtboardColors.copper;
      case 5: return ArtboardColors.dustyRose;
      default: return ArtboardColors.warmGray;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UNIFIED ADD MEMBER DIALOG - Clean, Single Dialog for All Cases
  // ═══════════════════════════════════════════════════════════════════════════
  
  void _showAddPersonDialog() {
    _showUnifiedAddDialog();
  }

  void _showUnifiedAddDialog({Person? preSelectedParent}) {
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    String gender = 'male';
    bool isLoading = false;
    Person? selectedParent = preSelectedParent;
    final bool canAddAsRoot = _persons.isEmpty;
    bool addAsRoot = canAddAsRoot;
    
    // Pre-fill father name
    if (selectedParent != null) {
      lastNameController.text = selectedParent.firstName;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final accentColor = addAsRoot ? ArtboardColors.gold 
            : (selectedParent != null ? _getBranchColor(selectedParent!) : ArtboardColors.sage);

          return AlertDialog(
            backgroundColor: ArtboardColors.warmWhite,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    addAsRoot ? Icons.star_rounded : Icons.person_add_alt_1,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  addAsRoot ? 'Add Patriarch' : 'Add Child',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: ArtboardColors.charcoal,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Parent info (if adding child)
                  if (!addAsRoot && selectedParent != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: accentColor,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                selectedParent!.firstName[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Child of ${selectedParent!.firstName}',
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: ArtboardColors.charcoal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // First Name
                  TextField(
                    controller: firstNameController,
                    style: GoogleFonts.cormorantGaramond(fontSize: 16),
                    decoration: InputDecoration(
                      labelText: 'First Name *',
                      labelStyle: GoogleFonts.cormorantGaramond(color: ArtboardColors.warmGray),
                      prefixIcon: const Icon(Icons.person_rounded, color: ArtboardColors.warmGray, size: 20),
                      filled: true,
                      fillColor: ArtboardColors.cream,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Father/Family Name
                  TextField(
                    controller: lastNameController,
                    style: GoogleFonts.cormorantGaramond(fontSize: 16),
                    decoration: InputDecoration(
                      labelText: addAsRoot ? 'Family Name *' : 'Father Name',
                      labelStyle: GoogleFonts.cormorantGaramond(color: ArtboardColors.warmGray),
                      prefixIcon: const Icon(Icons.person_outline_rounded, color: ArtboardColors.warmGray, size: 20),
                      filled: true,
                      fillColor: ArtboardColors.cream,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Gender Selection - Simple buttons
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setDialogState(() => gender = 'male'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: gender == 'male' ? Colors.blue.withOpacity(0.15) : ArtboardColors.cream,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: gender == 'male' ? Colors.blue : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.male, color: gender == 'male' ? Colors.blue : ArtboardColors.warmGray),
                                const SizedBox(width: 6),
                                Text('Male', style: TextStyle(
                                  color: gender == 'male' ? Colors.blue : ArtboardColors.warmGray,
                                  fontWeight: gender == 'male' ? FontWeight.bold : FontWeight.normal,
                                )),
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
                              color: gender == 'female' ? Colors.pink.withOpacity(0.15) : ArtboardColors.cream,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: gender == 'female' ? Colors.pink : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.female, color: gender == 'female' ? Colors.pink : ArtboardColors.warmGray),
                                const SizedBox(width: 6),
                                Text('Female', style: TextStyle(
                                  color: gender == 'female' ? Colors.pink : ArtboardColors.warmGray,
                                  fontWeight: gender == 'female' ? FontWeight.bold : FontWeight.normal,
                                )),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: ArtboardColors.warmGray)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: isLoading ? null : () async {
                  if (firstNameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter first name'), backgroundColor: Colors.red),
                    );
                    return;
                  }
                  if (lastNameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter family/father name'), backgroundColor: Colors.red),
                    );
                    return;
                  }
                  
                  setDialogState(() => isLoading = true);
                  
                  final newPerson = Person(
                    id: '',
                    familyTreeId: 'main-family-tree',
                    firstName: firstNameController.text.trim(),
                    lastName: lastNameController.text.trim(),
                    gender: gender,
                    relationships: Relationships(
                      parentIds: addAsRoot ? [] : [selectedParent!.id],
                    ),
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  );
                  
                  try {
                    final newId = await _adminRepo.addPerson(newPerson);
                    
                    if (!addAsRoot && selectedParent != null) {
                      final updatedParent = selectedParent!.copyWith(
                        relationships: selectedParent!.relationships.copyWith(
                          childrenIds: [...selectedParent!.relationships.childrenIds, newId],
                        ),
                      );
                      await _adminRepo.updatePerson(updatedParent);
                    }
                    
                    Navigator.pop(context);
                    _loadData();
                    
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text('${firstNameController.text} added successfully!'),
                        backgroundColor: accentColor,
                      ),
                    );
                  } catch (e) {
                    setDialogState(() => isLoading = false);
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                },
                child: isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }
  
  Widget _buildModeChip(String title, String subtitle, IconData icon, bool selected, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : ArtboardColors.cream,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : ArtboardColors.champagne,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? color : ArtboardColors.warmGray, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.playfairDisplay(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: selected ? color : ArtboardColors.charcoal,
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 11,
                color: ArtboardColors.warmGray,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: ArtboardColors.terracotta),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.playfairDisplay(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: ArtboardColors.charcoal,
          ),
        ),
      ],
    );
  }
  
  // Drag-drop swap method
  void _swapPersons(Person draggedPerson, Person targetPerson) async {
    final tempTime = draggedPerson.createdAt;
    
    await _personRepo.updatePerson(
      draggedPerson.copyWith(createdAt: targetPerson.createdAt),
    );
    await _personRepo.updatePerson(
      targetPerson.copyWith(createdAt: tempTime),
    );
    
    _loadData();
  }

  void _showEditDialog(Person person) {
    final firstNameController = TextEditingController(text: person.firstName);
    final lastNameController = TextEditingController(text: person.lastName);
    final birthYearController = TextEditingController(text: person.birthDate?.year.toString() ?? '');
    final deathYearController = TextEditingController(text: person.deathDate?.year.toString() ?? '');
    final bioController = TextEditingController(text: person.bio ?? '');
    String gender = person.gender ?? 'male';
    bool isLoading = false;
    
    final color = _getBranchColor(person);
    final gen = _getGenerationNumber(person);
    final isRoot = person.relationships.parentIds.isEmpty;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: ArtboardColors.warmWhite,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            width: 450,
            constraints: const BoxConstraints(maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            person.firstName[0],
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Edit Profile',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: ArtboardColors.charcoal,
                              ),
                            ),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isRoot ? ArtboardColors.gold : color,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isRoot ? '★ PATRIARCH' : 'Gen $gen',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  person.fullName,
                                  style: GoogleFonts.cormorantGaramond(
                                    fontSize: 13,
                                    color: ArtboardColors.warmGray,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close, color: ArtboardColors.warmGray),
                      ),
                    ],
                  ),
                ),

                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildTextField(firstNameController, 'First Name *', Icons.person),
                        const SizedBox(height: 12),
                        _buildTextField(lastNameController, 'Father Name *', Icons.person_outline),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _buildTextField(birthYearController, 'Birth Year', Icons.cake, 1, true)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildTextField(deathYearController, 'Death Year', Icons.event, 1, true)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildGenderSelector(gender, (val) => setDialogState(() => gender = val)),
                        const SizedBox(height: 12),
                        _buildTextField(bioController, 'Biography', Icons.notes, 3),
                      ],
                    ),
                  ),
                ),

                // Actions
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ArtboardColors.cream,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                  ),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: isLoading ? null : () => Navigator.pop(context),
                        child: Text('Cancel', style: GoogleFonts.cormorantGaramond(color: ArtboardColors.warmGray)),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: isLoading ? null : () async {
                          if (firstNameController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Please enter first name'), backgroundColor: ArtboardColors.rust),
                            );
                            return;
                          }
                          
                          setDialogState(() => isLoading = true);
                          
                          DateTime? birthDate;
                          DateTime? deathDate;
                          if (birthYearController.text.isNotEmpty) {
                            birthDate = DateTime(int.tryParse(birthYearController.text) ?? 1900);
                          }
                          if (deathYearController.text.isNotEmpty) {
                            deathDate = DateTime(int.tryParse(deathYearController.text) ?? 2000);
                          }
                          
                          final updated = person.copyWith(
                            firstName: firstNameController.text.trim(),
                            lastName: lastNameController.text.trim(),
                            gender: gender,
                            birthDate: birthDate,
                            deathDate: deathDate,
                            bio: bioController.text.trim().isEmpty ? null : bioController.text.trim(),
                            updatedAt: DateTime.now(),
                          );
                          
                          try {
                            await _adminRepo.updatePerson(updated);
                            Navigator.pop(context);
                            _loadData();
                            setState(() => _selectedPerson = null);
                            
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Row(children: [
                                  const Icon(Icons.check_circle, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Text('${firstNameController.text} updated!'),
                                ]),
                                backgroundColor: ArtboardColors.sage,
                              ),
                            );
                          } catch (e) {
                            setDialogState(() => isLoading = false);
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: ArtboardColors.rust),
                            );
                          }
                        },
                        child: isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.save_rounded, size: 18, color: Colors.white),
                              const SizedBox(width: 6),
                              Text('Save Changes', style: GoogleFonts.cormorantGaramond(fontWeight: FontWeight.w700, color: Colors.white)),
                            ]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Get ancestry chain for a person
  List<Person> _getAncestryChain(Person person) {
    final chain = <Person>[person];
    var current = person;
    while (current.relationships.parentIds.isNotEmpty) {
      final parentId = current.relationships.parentIds.first;
      final parent = _persons.firstWhere((p) => p.id == parentId, orElse: () => current);
      if (parent.id == current.id) break;
      chain.insert(0, parent);
      current = parent;
    }
    return chain;
  }

  /// Get all descendants of a person (children, grandchildren, etc.)
  List<Person> _getAllDescendants(Person person) {
    final descendants = <Person>[];
    
    void addDescendants(String personId) {
      for (final p in _persons) {
        if (p.relationships.parentIds.contains(personId)) {
          descendants.add(p);
          addDescendants(p.id);
        }
      }
    }
    
    addDescendants(person.id);
    return descendants;
  }
  
  void _confirmDelete(Person person) {
    final descendants = _getAllDescendants(person);
    final totalToDelete = descendants.length + 1;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ArtboardColors.warmWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Delete ${person.firstName}?',
          style: GoogleFonts.playfairDisplay(
            color: ArtboardColors.charcoal,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This action cannot be undone.',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 15,
                color: ArtboardColors.warmGray,
              ),
            ),
            if (descendants.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ArtboardColors.rust.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ArtboardColors.rust.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_rounded, color: ArtboardColors.rust, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This will also delete ${descendants.length} descendant${descendants.length > 1 ? 's' : ''} (children, grandchildren, etc.)',
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: ArtboardColors.rust,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.cormorantGaramond(color: ArtboardColors.warmGray),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ArtboardColors.rust,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              try {
                // Delete all descendants first (bottom-up), then the person
                for (final desc in descendants.reversed) {
                  await _adminRepo.deletePerson(desc.id);
                }
                await _adminRepo.deletePerson(person.id);
                Navigator.pop(context);
                _loadData();
                setState(() {
                  _selectedPerson = null;
                  _focusStack.clear();
                });
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text('Deleted $totalToDelete family member${totalToDelete > 1 ? 's' : ''}'),
                    backgroundColor: ArtboardColors.sage,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: Text(
              'Delete ${totalToDelete > 1 ? 'All ($totalToDelete)' : ''}',
              style: GoogleFonts.cormorantGaramond(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Show dialog to add multiple children at once
  void _showBatchAddDialog() {
    final parentController = TextEditingController();
    Person? selectedParent;
    int childCount = 2;
    final childControllers = <Map<String, TextEditingController>>[];
    
    // Initialize controllers for children
    for (int i = 0; i < childCount; i++) {
      childControllers.add({
        'firstName': TextEditingController(),
        'lastName': TextEditingController(),
      });
    }
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: ArtboardColors.warmWhite,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            'Add Multiple Children',
            style: GoogleFonts.playfairDisplay(
              color: ArtboardColors.charcoal,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Parent selector
                  Text(
                    'Select Parent:',
                    style: GoogleFonts.cormorantGaramond(
                      fontWeight: FontWeight.w700,
                      color: ArtboardColors.charcoal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<Person>(
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: ArtboardColors.cream,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: ArtboardColors.champagne),
                      ),
                    ),
                    hint: Text('Choose a parent', style: GoogleFonts.cormorantGaramond()),
                    value: selectedParent,
                    items: _persons.map((p) => DropdownMenuItem(
                      value: p,
                      child: Text(p.fullName, style: GoogleFonts.cormorantGaramond()),
                    )).toList(),
                    onChanged: (person) => setDialogState(() => selectedParent = person),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Number of children
                  Row(
                    children: [
                      Text(
                        'Number of children:',
                        style: GoogleFonts.cormorantGaramond(
                          fontWeight: FontWeight.w700,
                          color: ArtboardColors.charcoal,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.remove_circle_outline, color: ArtboardColors.warmGray),
                        onPressed: childCount > 1 ? () {
                          setDialogState(() {
                            childCount--;
                            childControllers.removeLast();
                          });
                        } : null,
                      ),
                      Text(
                        '$childCount',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: ArtboardColors.charcoal,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.add_circle_outline, color: ArtboardColors.terracotta),
                        onPressed: childCount < 10 ? () {
                          setDialogState(() {
                            childCount++;
                            childControllers.add({
                              'firstName': TextEditingController(),
                              'lastName': TextEditingController(),
                            });
                          });
                        } : null,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Child fields
                  ...List.generate(childCount, (index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ArtboardColors.cream,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: ArtboardColors.champagne),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Child ${index + 1}',
                            style: GoogleFonts.cormorantGaramond(
                              fontWeight: FontWeight.w700,
                              color: ArtboardColors.terracotta,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: childControllers[index]['firstName'],
                                  style: GoogleFonts.cormorantGaramond(color: ArtboardColors.charcoal),
                                  decoration: InputDecoration(
                                    hintText: 'First Name',
                                    hintStyle: GoogleFonts.cormorantGaramond(color: ArtboardColors.warmGray),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: ArtboardColors.champagne),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: childControllers[index]['lastName'],
                                  style: GoogleFonts.cormorantGaramond(color: ArtboardColors.charcoal),
                                  decoration: InputDecoration(
                                    hintText: 'Last Name',
                                    hintStyle: GoogleFonts.cormorantGaramond(color: ArtboardColors.warmGray),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: ArtboardColors.champagne),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.cormorantGaramond(color: ArtboardColors.warmGray),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ArtboardColors.terracotta,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: selectedParent == null ? null : () async {
                Navigator.pop(context);
                
                int addedCount = 0;
                for (final controllers in childControllers) {
                  final firstName = controllers['firstName']!.text.trim();
                  final lastName = controllers['lastName']!.text.trim();
                  
                  if (firstName.isNotEmpty) {
                    final now = DateTime.now();
                    final newPerson = Person(
                      id: '',
                      familyTreeId: 'main-family-tree',
                      firstName: firstName,
                      lastName: lastName.isNotEmpty ? lastName : selectedParent!.lastName,
                      relationships: Relationships(
                        parentIds: [selectedParent!.id],
                      ),
                      createdAt: now,
                      updatedAt: now,
                    );
                    
                    try {
                      await _adminRepo.addPerson(newPerson);
                      addedCount++;
                    } catch (e) {
                      // Continue with others
                    }
                  }
                }
                
                _loadData();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Added $addedCount children to ${selectedParent!.firstName}'),
                    backgroundColor: ArtboardColors.sage,
                  ),
                );
              },
              child: Text(
                'Add All',
                style: GoogleFonts.cormorantGaramond(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Batch delete selected persons with cascade
  void _confirmBatchDelete() {
    if (_selectedPersonIds.isEmpty) return;
    
    // Get all selected persons and their descendants
    final personsToDelete = <Person>{};
    for (final id in _selectedPersonIds) {
      final person = _persons.firstWhere((p) => p.id == id, orElse: () => _persons.first);
      personsToDelete.add(person);
      personsToDelete.addAll(_getAllDescendants(person));
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ArtboardColors.warmWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Delete ${_selectedPersonIds.length} Selected?',
          style: GoogleFonts.playfairDisplay(
            color: ArtboardColors.charcoal,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will delete the selected members and all their descendants.',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 15,
                color: ArtboardColors.warmGray,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ArtboardColors.rust.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Total to delete: ${personsToDelete.length} family member${personsToDelete.length > 1 ? 's' : ''}',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: ArtboardColors.rust,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.cormorantGaramond(color: ArtboardColors.warmGray),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ArtboardColors.rust,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              try {
                // Sort by generation (deepest first) to avoid orphan issues
                final sortedList = personsToDelete.toList()
                  ..sort((a, b) => _getGenerationNumber(b).compareTo(_getGenerationNumber(a)));
                
                for (final person in sortedList) {
                  await _adminRepo.deletePerson(person.id);
                }
                
                setState(() {
                  _selectedPersonIds.clear();
                  _isMultiSelectMode = false;
                  _selectedPerson = null;
                  _focusStack.clear();
                });
                _loadData();
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Deleted ${personsToDelete.length} family members'),
                    backgroundColor: ArtboardColors.sage,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: Text(
              'Delete All (${personsToDelete.length})',
              style: GoogleFonts.cormorantGaramond(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, [IconData? icon, int maxLines = 1, bool isNumber = false]) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: GoogleFonts.cormorantGaramond(
        fontSize: 16,
        color: ArtboardColors.charcoal,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.cormorantGaramond(
          color: ArtboardColors.warmGray,
        ),
        prefixIcon: icon != null ? Icon(icon, color: ArtboardColors.warmGray, size: 20) : null,
        filled: true,
        fillColor: ArtboardColors.cream,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ArtboardColors.champagne),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ArtboardColors.champagne),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ArtboardColors.terracotta, width: 2),
        ),
      ),
    );
  }

  Widget _buildGenderSelector(String selected, Function(String) onChanged) {
    return Row(
      children: [
        Text(
          'Gender:',
          style: GoogleFonts.cormorantGaramond(
            color: ArtboardColors.warmGray,
          ),
        ),
        const SizedBox(width: 16),
        ChoiceChip(
          label: Text('Male', style: GoogleFonts.cormorantGaramond()),
          selected: selected == 'male',
          onSelected: (_) => onChanged('male'),
          selectedColor: ArtboardColors.terracotta.withOpacity(0.2),
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: Text('Female', style: GoogleFonts.cormorantGaramond()),
          selected: selected == 'female',
          onSelected: (_) => onChanged('female'),
          selectedColor: ArtboardColors.dustyRose.withOpacity(0.3),
        ),
      ],
    );
  }
}

/// Custom painter for subtle background pattern
class _PatternPainter extends CustomPainter {
  final bool isDark;
  
  _PatternPainter({this.isDark = false});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (isDark 
          ? Colors.white.withOpacity(0.03) 
          : ArtboardColors.champagne.withOpacity(0.3))
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const spacing = 40.0;
    
    // Draw subtle diagonal lines
    for (double i = -size.height; i < size.width + size.height; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
