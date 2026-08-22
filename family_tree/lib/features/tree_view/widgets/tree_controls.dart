import 'package:flutter/material.dart';
import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/data/models/person.dart';
import 'package:google_fonts/google_fonts.dart';

/// Control panel for tree navigation with zoom, search, and filters
class TreeControls extends StatefulWidget {
  final List<Person> persons;
  final double currentZoom;
  final int? selectedGeneration;
  final String? searchQuery;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomFit;
  final VoidCallback onZoomReset;
  final Function(int?) onGenerationFilter;
  final Function(String) onSearch;
  final Function(String) onPersonSelect;
  final bool isMinimapVisible;
  final VoidCallback onToggleMinimap;

  const TreeControls({
    super.key,
    required this.persons,
    required this.currentZoom,
    this.selectedGeneration,
    this.searchQuery,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onZoomFit,
    required this.onZoomReset,
    required this.onGenerationFilter,
    required this.onSearch,
    required this.onPersonSelect,
    required this.isMinimapVisible,
    required this.onToggleMinimap,
  });

  @override
  State<TreeControls> createState() => _TreeControlsState();
}

class _TreeControlsState extends State<TreeControls> {
  bool _isSearchExpanded = false;
  bool _isPanelExpanded = true; // For mobile collapse
  final _searchController = TextEditingController();
  List<Person> _searchResults = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    
    final lowercaseQuery = query.toLowerCase();
    setState(() {
      _searchResults = widget.persons.where((p) {
        return p.fullName.toLowerCase().contains(lowercaseQuery) ||
               (p.birthDate?.year.toString() ?? '').contains(lowercaseQuery);
      }).take(5).toList();
    });
    
    widget.onSearch(query);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxGeneration = _getMaxGeneration();
    final isMobile = MediaQuery.of(context).size.width < 600;

    // On mobile, show a toggle button when collapsed
    if (isMobile && !_isPanelExpanded) {
      return _buildCollapseToggle(isDark);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Collapse toggle for mobile
        if (isMobile) _buildCollapseToggle(isDark),
        if (isMobile) const SizedBox(height: 8),
        
        // Search bar (expandable)
        _isSearchExpanded
            ? _buildExpandedSearch(isDark)
            : _buildCollapsedSearch(isDark),

        const SizedBox(height: 8),

        // Main controls panel
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark
                ? AppTheme.surfaceDark.withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Zoom controls
              _buildControlButton(
                icon: Icons.add,
                tooltip: 'Zoom In',
                onTap: widget.onZoomIn,
                isDark: isDark,
              ),
              const SizedBox(height: 4),
              
              // Zoom indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  '${(widget.currentZoom * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppTheme.textSecondaryDark
                        : AppTheme.textSecondaryLight,
                  ),
                ),
              ),
              
              _buildControlButton(
                icon: Icons.remove,
                tooltip: 'Zoom Out',
                onTap: widget.onZoomOut,
                isDark: isDark,
              ),
              
              const Divider(height: 16),
              
              _buildControlButton(
                icon: Icons.fit_screen,
                tooltip: 'Fit All',
                onTap: widget.onZoomFit,
                isDark: isDark,
              ),
              
              const SizedBox(height: 4),
              
              _buildControlButton(
                icon: Icons.restart_alt,
                tooltip: 'Reset View',
                onTap: widget.onZoomReset,
                isDark: isDark,
              ),
              
              const Divider(height: 16),
              
              // Minimap toggle
              _buildControlButton(
                icon: widget.isMinimapVisible ? Icons.map : Icons.map_outlined,
                tooltip: 'Toggle Minimap',
                onTap: widget.onToggleMinimap,
                isDark: isDark,
                isActive: widget.isMinimapVisible,
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Generation filter
        if (maxGeneration > 0)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.surfaceDark.withValues(alpha: 0.95)
                  : Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Generations',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppTheme.textMutedDark
                          : AppTheme.textMutedLight,
                    ),
                  ),
                ),
                
                // All generations button
                _buildGenerationButton(
                  label: 'All',
                  generation: null,
                  isSelected: widget.selectedGeneration == null,
                  isDark: isDark,
                ),
                
                const SizedBox(height: 4),
                
                // Generation buttons
                ...List.generate(maxGeneration + 1, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _buildGenerationButton(
                      label: 'G${index + 1}',
                      generation: index,
                      isSelected: widget.selectedGeneration == index,
                      isDark: isDark,
                      color: AppTheme.getGenerationColor(index),
                    ),
                  );
                }),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required bool isDark,
    bool isActive = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isActive
                  ? AppTheme.primaryLight.withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: isActive
                  ? AppTheme.primaryLight
                  : isDark
                      ? AppTheme.textSecondaryDark
                      : AppTheme.textSecondaryLight,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGenerationButton({
    required String label,
    required int? generation,
    required bool isSelected,
    required bool isDark,
    Color? color,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => widget.onGenerationFilter(generation),
        child: Container(
          width: 36,
          height: 28,
          decoration: BoxDecoration(
            color: isSelected
                ? (color ?? AppTheme.primaryLight).withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected
                  ? (color ?? AppTheme.primaryLight)
                  : isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.1),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? (color ?? AppTheme.primaryLight)
                    : isDark
                        ? AppTheme.textSecondaryDark
                        : AppTheme.textSecondaryLight,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsedSearch(bool isDark) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() => _isSearchExpanded = true),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isDark
                ? AppTheme.surfaceDark.withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.search,
            color: isDark
                ? AppTheme.textSecondaryDark
                : AppTheme.textSecondaryLight,
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedSearch(bool isDark) {
    return Container(
      constraints: const BoxConstraints(minWidth: 280),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.surfaceDark.withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search input
          SizedBox(
            width: 280,
            child: Row(
              children: [
                const SizedBox(width: 12),
                Icon(
                  Icons.search,
                  size: 20,
                  color: isDark
                      ? AppTheme.textMutedDark
                      : AppTheme.textMutedLight,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    onChanged: _performSearch,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: isDark
                          ? AppTheme.textPrimaryDark
                          : AppTheme.textPrimaryLight,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search family...',
                      hintStyle: TextStyle(
                        color: isDark
                            ? AppTheme.textMutedDark
                            : AppTheme.textMutedLight,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    _performSearch('');
                    setState(() => _isSearchExpanded = false);
                  },
                  color: isDark
                      ? AppTheme.textMutedDark
                      : AppTheme.textMutedLight,
                ),
              ],
            ),
          ),
          
          // Search results
          if (_searchResults.isNotEmpty) ...[
            Divider(
              height: 1,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.1),
            ),
            ...List.generate(_searchResults.length, (index) {
              final person = _searchResults[index];
              return InkWell(
                onTap: () {
                  widget.onPersonSelect(person.id);
                  _searchController.clear();
                  setState(() {
                    _searchResults = [];
                    _isSearchExpanded = false;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppTheme.getGenerationColor(
                            _getPersonGeneration(person),
                          ).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            person.firstName.isNotEmpty
                                ? person.firstName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.getGenerationColor(
                                _getPersonGeneration(person),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              person.fullName,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? AppTheme.textPrimaryDark
                                    : AppTheme.textPrimaryLight,
                              ),
                            ),
                            if (person.lifespan.isNotEmpty)
                              Text(
                                person.lifespan,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: isDark
                                      ? AppTheme.textMutedDark
                                      : AppTheme.textMutedLight,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  int _getMaxGeneration() {
    int max = 0;
    for (final person in widget.persons) {
      final gen = _getPersonGeneration(person);
      if (gen > max) max = gen;
    }
    return max;
  }

  int _getPersonGeneration(Person person) {
    // Simple generation calculation based on parent hierarchy
    if (person.relationships.parentIds.isEmpty) return 0;
    
    int maxParentGen = -1;
    for (final parentId in person.relationships.parentIds) {
      final parent = widget.persons.firstWhere(
        (p) => p.id == parentId,
        orElse: () => person,
      );
      if (parent.id != person.id) {
        final parentGen = _getPersonGeneration(parent);
        if (parentGen > maxParentGen) maxParentGen = parentGen;
      }
    }
    return maxParentGen + 1;
  }

  Widget _buildCollapseToggle(bool isDark) {
    return GestureDetector(
      onTap: () => setState(() => _isPanelExpanded = !_isPanelExpanded),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isDark
              ? AppTheme.surfaceDark.withValues(alpha: 0.95)
              : Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          _isPanelExpanded ? Icons.chevron_right : Icons.tune,
          color: isDark
              ? AppTheme.textSecondaryDark
              : AppTheme.textSecondaryLight,
        ),
      ),
    );
  }
}
