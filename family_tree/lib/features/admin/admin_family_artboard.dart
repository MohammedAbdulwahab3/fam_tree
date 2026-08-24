import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:family_tree/data/models/person.dart';
import 'package:family_tree/data/repositories/person_repository.dart';
import 'package:family_tree/data/repositories/admin_repository.dart';
import 'package:family_tree/core/theme/elegant_theme.dart';
import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/core/theme/app_colors.dart';
import 'package:family_tree/core/widgets/aurora_background.dart';
import 'package:family_tree/data/models/post.dart';
import 'package:family_tree/features/admin/admin_tools_sheet.dart';
import 'package:family_tree/features/admin/person_editor.dart';
import 'package:family_tree/features/admin/relationships_sheet.dart';
import 'package:family_tree/features/auth/session.dart';
import 'package:family_tree/features/linking/link_status.dart';
import 'package:family_tree/features/linking/review_claims_page.dart';
import 'package:family_tree/features/admin/post_composer_sheet.dart';
import 'package:family_tree/data/services/family_export_service.dart';
import 'package:family_tree/data/services/web_download_helper.dart';
import 'package:family_tree/core/config.dart';
import 'package:family_tree/core/design/typography.dart';

/// Alias for backward compatibility
typedef ArtboardColors = ElegantColors;

/// Beautiful Admin Family Artboard
/// An elegant, high-fidelity view for managing the family tree
class AdminFamilyArtboard extends ConsumerStatefulWidget {
  final bool showBackButton;

  const AdminFamilyArtboard({
    super.key,
    this.showBackButton = true,
  });

  @override
  ConsumerState<AdminFamilyArtboard> createState() =>
      _AdminFamilyArtboardState();
}

class _AdminFamilyArtboardState extends ConsumerState<AdminFamilyArtboard>
    with TickerProviderStateMixin {
  final PersonRepository _personRepo = PersonRepository();
  final AdminRepository _adminRepo = AdminRepository();
  late final AnimationController _auroraController;

  List<Person> _persons = [];
  List<Person> _filteredPersons = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String _selectedGeneration = 'All';
  Person? _selectedPerson;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  /// Derived from the loaded tree — a hardcoded list silently hid Gen 6.
  List<String> get _generations => [
        'All',
        for (var i = 1; i <= _generationCount; i++) 'Gen $i',
      ];

  int get _generationCount {
    if (_persons.isEmpty) return 0;
    return _persons.map(_generationOf).fold<int>(0, (a, b) => a > b ? a : b) +
        1;
  }

  // Map to cache branch colors for each person
  Map<String, Color> _branchColorMap = {};

  // Rebuilt whenever the roster changes; see _generationOf.
  Map<String, Person> _personById = {};
  final Map<String, int> _generationCache = {};

  // Stack of focused persons for drill-down navigation
  List<String> _focusStack = [];

  final ScrollController _verticalScrollController =
      ScrollController(initialScrollOffset: 500);
  final ScrollController _horizontalScrollController =
      ScrollController(initialScrollOffset: 500);

  @override
  void initState() {
    super.initState();
    _auroraController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();
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
    _searchController.dispose();
    _auroraController.dispose();
    _fadeController.dispose();
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final persons =
          await _personRepo.getFamilyMembers(AppConfig.familyTreeId);
      setState(() {
        _persons = persons;
        _filteredPersons = persons;
        // Caches derived from the roster must be rebuilt with it.
        _personById = {for (final p in persons) p.id: p};
        _generationCache.clear();
        _isLoading = false;
        _buildBranchColorMap();
      });
      _fadeController.forward();

      // Auto-assign displayOrder to members that don't have one
      await _initializeDisplayOrders();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  /// Auto-assign displayOrder to all family members who have order 0
  Future<void> _initializeDisplayOrders() async {
    // Group persons by parent
    final Map<String, List<Person>> siblingGroups = {};

    // Roots group
    final roots =
        _persons.where((p) => p.relationships.parentIds.isEmpty).toList();
    siblingGroups['_roots'] = roots;

    // Children of each parent
    for (final person in _persons) {
      for (final parentId in person.relationships.parentIds) {
        siblingGroups.putIfAbsent(parentId, () => []);
        siblingGroups[parentId]!.add(person);
      }
    }

    // For each group, assign order based on createdAt if everyone has order 0
    for (final entry in siblingGroups.entries) {
      final siblings = entry.value;

      // Check if any sibling has a valid order (non-zero)
      final hasOrders = siblings.any((s) => s.displayOrder > 0);
      if (hasOrders) continue; // Skip if already has orders

      // Sort by createdAt and assign order numbers
      siblings.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      for (int i = 0; i < siblings.length; i++) {
        final person = siblings[i];
        final newOrder = i + 1;

        // Update in backend
        await _adminRepo.updatePerson(person.copyWith(displayOrder: newOrder));

        // Update local state
        final idx = _persons.indexWhere((p) => p.id == person.id);
        if (idx >= 0) {
          _persons[idx] = person.copyWith(displayOrder: newOrder);
        }
      }
    }

    // Refresh filtered list
    setState(() {
      _filteredPersons = List.from(_persons);
    });
  }

  /// Build a map of person ID to their family branch color
  void _buildBranchColorMap() {
    _branchColorMap = {};

    // Find root (Gen 1 - Mohammed)
    final roots =
        _persons.where((p) => p.relationships.parentIds.isEmpty).toList();

    // Assign gold color to roots
    for (final root in roots) {
      _branchColorMap[root.id] = ArtboardColors.gold;
    }

    // Find Gen 2 (children of root) and assign each a unique branch color
    final gen2 = _persons
        .where((p) =>
            roots.any((root) => p.relationships.parentIds.contains(root.id)))
        .toList();

    for (int i = 0; i < gen2.length; i++) {
      final branchColor =
          ArtboardColors.branchColors[i % ArtboardColors.branchColors.length];
      _branchColorMap[gen2[i].id] = branchColor;
      // Propagate this color to all descendants
      _assignBranchColorToDescendants(gen2[i].id, branchColor);
    }
  }

  /// Recursively assign branch color to all descendants
  void _assignBranchColorToDescendants(String parentId, Color color) {
    final children = _persons
        .where((p) => p.relationships.parentIds.contains(parentId))
        .toList();

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
        final genNum =
            int.tryParse(_selectedGeneration.replaceAll('Gen ', '')) ?? 0;
        final personGen = _getGenerationNumber(p);
        return matchesSearch && personGen == genNum;
      }).toList();
    });
  }

  int _getGenerationNumber(Person person) {
    if (person.relationships.parentIds.isEmpty) return 1;

    // Find parent and get their generation
    final parent = _persons
        .where((p) => person.relationships.parentIds.contains(p.id))
        .firstOrNull;
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
          // Ambient light, shared with the app's other entry screens.
          AuroraBackground(
            animation: _auroraController,
            isDark: isDark,
            intensity: 0.5,
          ),
          // Fine engraved pattern on top of it, for the paper feel.
          _buildPatternBackground(),

          // Main content
          SafeArea(
            child: Column(
              children: [
                _buildArtboardHeader(isDark),
                Expanded(
                  child: _isLoading ? _buildLoadingState() : _buildFamilyGrid(),
                ),
              ],
            ),
          ),

          // Selected person detail panel
          if (_selectedPerson != null) _buildDetailPanel(),
        ],
      ),
    );
  }

  /// One minimal bar, so the board gets the height.
  ///
  /// This was briefly three stacked bands — title, stats, controls — which ate
  /// roughly a third of the viewport and started the tree halfway down the
  /// screen. Everything now shares a single row.
  Widget _buildArtboardHeader(bool isDark) {
    final fg = context.colors.ink;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        return ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: compact ? 10 : 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white.withValues(alpha: 0.6),
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.10)
                        : ArtboardColors.champagne,
                  ),
                ),
              ),
              child: Row(
                children: [
                  _roundIcon(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back to the tree',
                    isDark: isDark,
                    onTap: () => context.go('/tree'),
                  ),
                  const SizedBox(width: 6),
                  _roundIcon(
                    icon: Icons.refresh_rounded,
                    tooltip: 'Reload',
                    isDark: isDark,
                    onTap: _loadData,
                  ),
                  const SizedBox(width: 6),
                  _toolsMenu(isDark),
                  const SizedBox(width: 12),
                  // Flexible rather than fixed: on a narrow phone the title
                  // ellipsises instead of pushing the controls off the edge.
                  Flexible(
                    child: Text(
                      'Family Artboard',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: AppType.sans(
                        fontSize: compact ? 16 : 19,
                        fontWeight: FontWeight.bold,
                        color: fg,
                      ),
                    ),
                  ),
                  SizedBox(width: compact ? 8 : 14),
                  Expanded(
                    flex: compact ? 3 : 4,
                    child: _buildInlineSearch(isDark),
                  ),
                  const SizedBox(width: 8),
                  _buildGenerationFilter(isDark, compact: compact),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// A soft circular button. The bare [IconButton]s read as unfinished next to
  /// the rest of the app's rounded, tinted controls.
  Widget _roundIcon({
    required IconData icon,
    required String tooltip,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isDark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.white.withValues(alpha: 0.8),
        shape: CircleBorder(
          side: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : ArtboardColors.champagne,
          ),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(
              icon,
              size: 19,
              color: context.colors.inkSoft,
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolsMenu(bool isDark) {
    // Somebody waiting to be linked has no way to hurry an admin along, and an
    // admin has no reason to go and look. The count is the only thing that
    // closes that gap.
    final waiting = ref.watch(pendingLinkCountProvider);

    PopupMenuItem<String> item(
      String value,
      IconData icon,
      String label, {
      int badge = 0,
    }) {
      return PopupMenuItem(
        value: value,
        child: ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, size: 20),
          title: Text(label, style: AppType.sans(fontSize: 13.5)),
          trailing: badge == 0 ? null : _CountBadge(count: badge),
        ),
      );
    }

    return PopupMenuButton<String>(
      tooltip: 'Admin tools',
      onSelected: _onToolSelected,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: context.colors.surface,
      itemBuilder: (context) => [
        item('add-person', Icons.person_add_alt_1_rounded, 'Add member'),
        item('add-post', Icons.post_add_rounded, 'Add post'),
        const PopupMenuDivider(),
        item('members', Icons.people_outline_rounded, 'Members'),
        item('posts', Icons.forum_outlined, 'Posts'),
        const PopupMenuDivider(),
        item('announce', Icons.campaign_outlined, 'Send announcement'),
        item('links', Icons.verified_user_outlined, 'Who is who',
            badge: waiting),
        item('export', Icons.download_outlined, 'Export tree'),
      ],
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (waiting > 0)
            Positioned(
              right: -2,
              top: -2,
              child: _CountBadge(count: waiting),
            ),
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.white.withValues(alpha: 0.8),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : ArtboardColors.champagne,
              ),
            ),
            child: Icon(
              Icons.tune_rounded,
              size: 19,
              color: context.colors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }

  void _artboardToast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppTheme.error : AppTheme.primaryDeep,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  /// Compose and publish a family post.
  ///
  /// The old dialog was a lone textarea and hardcoded photos, videos and files
  /// to empty, so the feed could only ever receive plain text even though
  /// [Post] has always carried attachments.
  Future<void> _showAddPostDialog() async {
    final user = ref.read(currentUserProvider);

    final composed = await PostComposerSheet.show(
      context,
      authorName: user?.displayName ?? 'Admin',
    );
    if (composed == null) return;

    try {
      await _adminRepo.createPost(
        Post(
          id: '',
          familyTreeId: AppConfig.familyTreeId,
          userId: user?.uid ?? '',
          userName: user?.displayName ?? 'Admin',
          userPhoto: user?.photoURL,
          content: composed.content,
          photos: composed.photos,
          videos: composed.videos,
          files: composed.files,
          createdAt: DateTime.now(),
          reactions: const {},
        ),
      );
      final count = composed.photos.length +
          composed.videos.length +
          composed.files.length;
      _artboardToast(
        count == 0
            ? 'Posted to the family feed'
            : 'Posted with $count attachment${count == 1 ? '' : 's'}',
      );
      await _loadData();
    } catch (e) {
      _artboardToast(readableError(e), isError: true);
    }
  }

  Future<void> _showAnnouncementDialog() async {
    final titleController = TextEditingController();
    final messageController = TextEditingController();

    final send = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Send announcement',
            style: AppType.sans(fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'Title', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageController,
                maxLines: 4,
                decoration: const InputDecoration(
                    labelText: 'Message', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              Text(
                'Every member receives this as a notification.',
                style: AppType.sans(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Send')),
        ],
      ),
    );

    if (send != true) return;
    if (titleController.text.trim().isEmpty ||
        messageController.text.trim().isEmpty) {
      _artboardToast('A title and a message are both required', isError: true);
      return;
    }

    try {
      await _adminRepo.sendAnnouncement(
        title: titleController.text.trim(),
        message: messageController.text.trim(),
      );
      _artboardToast('Announcement sent to the family');
    } catch (e) {
      _artboardToast(readableError(e), isError: true);
    }
  }

  /// Download the whole tree. JSON keeps every field; CSV opens in a
  /// spreadsheet.
  Future<void> _exportTree() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Export tree',
            style: AppType.sans(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.data_object_rounded),
              title: const Text('JSON'),
              subtitle: const Text('Every field, for backup or re-import'),
              onTap: () => Navigator.pop(dialogContext, 'json'),
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_rounded),
              title: const Text('CSV'),
              subtitle: const Text('Opens in a spreadsheet'),
              onTap: () => Navigator.pop(dialogContext, 'csv'),
            ),
            ListTile(
              leading: const Icon(Icons.description_rounded),
              title: const Text('Member list'),
              subtitle: const Text('A readable roster'),
              onTap: () => Navigator.pop(dialogContext, 'list'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (choice == null) return;

    if (_persons.isEmpty) {
      _artboardToast('There is nobody in the tree to export', isError: true);
      return;
    }

    try {
      final stamp = DateTime.now().toIso8601String().split('T').first;
      switch (choice) {
        case 'json':
          WebDownloadHelper.downloadFile(
            FamilyExportService.exportAsJson(_persons),
            'family-tree-$stamp.json',
            'application/json',
          );
        case 'csv':
          WebDownloadHelper.downloadFile(
            FamilyExportService.exportAsCsv(_persons),
            'family-tree-$stamp.csv',
            'text/csv',
          );
        case 'list':
          WebDownloadHelper.downloadFile(
            FamilyExportService.exportAsMemberList(_persons, 'Family'),
            'family-members-$stamp.txt',
            'text/plain',
          );
      }
      _artboardToast('Export downloaded');
    } catch (e) {
      _artboardToast(readableError(e), isError: true);
    }
  }

  /// Depth of a person below the roots, memoised in [_generationCache].
  ///
  /// Zero-based, unlike [_getGenerationNumber] which is the one-based label
  /// shown in the filter — [_generationCount] adds the one back.
  int _generationOf(Person person) {
    final cached = _generationCache[person.id];
    if (cached != null) return cached;

    // Guard against a record that lists itself among its own ancestors.
    _generationCache[person.id] = 0;

    var depth = 0;
    for (final parentId in person.relationships.parentIds) {
      final parent = _personById[parentId];
      if (parent == null) continue;
      final parentDepth = _generationOf(parent) + 1;
      if (parentDepth > depth) depth = parentDepth;
    }

    return _generationCache[person.id] = depth;
  }

  /// Routes a choice from the admin tools menu.
  void _onToolSelected(String value) {
    switch (value) {
      case 'add-person':
        _showUnifiedAddDialog();
      case 'add-post':
        _showAddPostDialog();
      case 'members':
        AdminToolsSheet.open(context, AdminTool.members);
      case 'posts':
        AdminToolsSheet.open(context, AdminTool.posts);
      case 'announce':
        _showAnnouncementDialog();
      case 'links':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ReviewClaimsPage()),
        );
      case 'export':
        _exportTree();
    }
  }

  Widget _buildInlineSearch(bool isDark) {
    return TextField(
      controller: _searchController,
      onChanged: (v) {
        setState(() => _searchQuery = v.trim());
        _filterPersons();
      },
      style: AppType.sans(
        fontSize: 14,
        color: context.colors.ink,
      ),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Search relatives…',
        hintStyle: AppType.sans(
          fontSize: 13.5,
          color: context.colors.inkMuted,
        ),
        prefixIcon: Icon(
          Icons.search_rounded,
          size: 19,
          color: context.colors.inkMuted,
        ),
        suffixIcon: _searchQuery.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                icon: const Icon(Icons.close_rounded, size: 17),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                  _filterPersons();
                },
              ),
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.9),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        // A visible resting border, so the field reads as a control rather
        // than a slightly lighter patch of the header.
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : ArtboardColors.champagne,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : ArtboardColors.champagne,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: context.colors.accent,
            width: 1.6,
          ),
        ),
      ),
    );
  }

  /// Generation picker. The list comes from the data, so every generation that
  /// exists is selectable.
  Widget _buildGenerationFilter(bool isDark, {bool compact = false}) {
    final selected = _selectedGeneration != 'All';
    final accent = context.colors.accent;
    return Container(
      // Matches the search field so the two read as one control bar, and kept
      // short because every pixel here is a pixel the tree does not get.
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: selected
            ? accent.withValues(alpha: isDark ? 0.2 : 0.12)
            : (isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.9)),
        border: Border.all(
          color: selected
              ? accent
              : (isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : ArtboardColors.champagne),
          width: selected ? 1.5 : 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedGeneration,
          isDense: true,
          borderRadius: BorderRadius.circular(14),
          dropdownColor:
              isDark ? const Color(0xFF1B2430) : ArtboardColors.warmWhite,
          icon: Icon(
            Icons.expand_more_rounded,
            size: 19,
            color: selected
                ? accent
                : (isDark ? Colors.white70 : ArtboardColors.warmGray),
          ),
          style: AppType.sans(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: selected ? accent : (context.colors.ink),
          ),
          selectedItemBuilder: (context) => _generations
              .map((g) => Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      g == 'All' ? (compact ? 'All' : 'All generations') : g,
                      style: AppType.sans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? accent
                            : (isDark ? Colors.white : ArtboardColors.charcoal),
                      ),
                    ),
                  ))
              .toList(),
          items: _generations
              .map((g) => DropdownMenuItem(
                    value: g,
                    child: Text(g == 'All' ? 'All generations' : g),
                  ))
              .toList(),
          onChanged: (v) {
            setState(() => _selectedGeneration = v ?? 'All');
            _filterPersons();
          },
        ),
      ),
    );
  }

  /// Card surface shared by every person card, so the board matches the glass
  /// used on the feed and the admin sheets instead of an opaque warm panel.
  Color _cardSurface(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.white.withValues(alpha: 0.88);
  }

  Widget _buildPatternBackground() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Positioned.fill(
      child: Opacity(
        opacity: 0.5,
        child: CustomPaint(
          painter: _PatternPainter(isDark: isDark),
        ),
      ),
    );
  }

  // Helper method to get color based on theme

  Widget _buildFamilyGrid() {
    // Find root person (no parents = generation 1)
    final roots = _filteredPersons
        .where((p) => p.relationships.parentIds.isEmpty)
        .toList();

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
    final children = _persons
        .where((p) => p.relationships.parentIds.contains(currentPerson!.id))
        .toList();

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
        child: _buildDrillDownView(currentPerson, children),
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
      siblings = _persons
          .where((p) => p.relationships.parentIds.contains(parentId))
          .toList();
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
            // Tight at the top so the first card sits just under the bar.
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Current person - large card
                _buildLargeFocusCard(
                    person, color, generation, isRoot, childCount),

                if (children.isNotEmpty) ...[
                  const SizedBox(height: 20),

                  // Connecting line
                  Container(
                    width: 3,
                    height: 26,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          color.withValues(alpha: 0.55),
                          color.withValues(alpha: 0.12),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Children label
                  Builder(builder: (context) {
                    final dark =
                        Theme.of(context).brightness == Brightness.dark;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: dark ? 0.18 : 0.1),
                        borderRadius: BorderRadius.circular(30),
                        border:
                            Border.all(color: color.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.child_care_rounded,
                              size: 14, color: color),
                          const SizedBox(width: 7),
                          Text(
                            '${children.length} '
                            '${children.length == 1 ? "child" : "children"}',
                            style: AppType.sans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: dark ? Colors.white : color,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 18),

                  // Children cards - dynamic spacing
                  Wrap(
                    spacing: _getCardSpacing(childCount),
                    runSpacing: _getCardSpacing(childCount),
                    alignment: WrapAlignment.center,
                    children: children
                        .asMap()
                        .entries
                        .map((entry) =>
                            _buildChildCard(entry.value, entry.key, childCount))
                        .toList(),
                  ),

                  const SizedBox(height: 32),

                  // Hint
                  if (children.any((c) => _persons
                      .any((p) => p.relationships.parentIds.contains(c.id))))
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.touch_app_rounded,
                            size: 18, color: ArtboardColors.warmGray),
                        const SizedBox(width: 8),
                        Text(
                          'Tap to explore descendants',
                          style: AppType.sans(
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
                      color: ArtboardColors.cream.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.family_restroom_rounded,
                            size: 40,
                            color:
                                ArtboardColors.warmGray.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        Text(
                          'No children recorded',
                          style: AppType.sans(
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
      ],
    );
  }

  /// One slim strip carrying everything drill-down needs: step back, the trail
  /// you took, and sibling paging. The old design split this across a header
  /// bar and a second footer bar that repeated the same "back" action.
  Widget _buildDrillDownNav(
      Person person, Color color, List<Person> siblings, int currentIndex) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = context.colors.ink;
    final muted = context.colors.inkMuted;
    final hasPrev = currentIndex > 0;
    final hasNext = currentIndex < siblings.length - 1;

    Widget crumb(String label, VoidCallback onTap, {bool current = false}) {
      return InkWell(
        onTap: current ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Text(
            label,
            style: AppType.sans(
              fontSize: 13,
              fontWeight: current ? FontWeight.w700 : FontWeight.w500,
              color: current ? fg : muted,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.white.withValues(alpha: 0.6),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : ArtboardColors.champagne,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_rounded, size: 20, color: fg),
            tooltip: 'Back',
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() {
              if (_focusStack.isNotEmpty) _focusStack.removeLast();
            }),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(
                children: [
                  crumb('Family', () => setState(() => _focusStack.clear())),
                  for (final id in _focusStack) ...[
                    Icon(Icons.chevron_right_rounded, size: 15, color: muted),
                    crumb(
                      _personById[id]?.firstName ?? '…',
                      () {
                        final idx = _focusStack.indexOf(id);
                        setState(() =>
                            _focusStack = _focusStack.sublist(0, idx + 1));
                      },
                      current: id == _focusStack.last,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (siblings.length > 1) ...[
            Text(
              '${currentIndex + 1}/${siblings.length}',
              style: AppType.sans(fontSize: 11.5, color: muted),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded, size: 20),
              tooltip: hasPrev ? 'Previous sibling' : null,
              visualDensity: VisualDensity.compact,
              color: fg,
              onPressed: hasPrev
                  ? () => setState(() {
                        _focusStack[_focusStack.length - 1] =
                            siblings[currentIndex - 1].id;
                      })
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded, size: 20),
              tooltip: hasNext ? 'Next sibling' : null,
              visualDensity: VisualDensity.compact,
              color: fg,
              onPressed: hasNext
                  ? () => setState(() {
                        _focusStack[_focusStack.length - 1] =
                            siblings[currentIndex + 1].id;
                      })
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  // Dynamic sizing helpers
  double _getCardSpacing(int count) => count <= 4 ? 16 : 12;

  /// Card width never drops below a readable size.
  ///
  /// The previous scale shrank cards to 95px once a parent had ten or more
  /// children — Muzeyen has 28 — which made the names unreadable. Cards now
  /// hold a comfortable width and the Wrap simply flows onto more rows.
  double _getChildCardWidth(int count) {
    if (count == 1) return 200;
    if (count <= 3) return 180;
    return 160;
  }

  // Avatar and label stay legible however many siblings share the row; the
  // layout gains rows instead of shrinking type.
  double _getChildAvatarSize(int count) => count <= 3 ? 52 : 44;

  double _getChildFontSize(int count) => count <= 3 ? 14.5 : 13.5;

  Widget _buildLargeFocusCard(
      Person person, Color color, int generation, bool isRoot, int childCount) {
    final avatarSize = childCount > 6 ? 55.0 : 70.0;
    final nameFontSize = childCount > 6 ? 18.0 : 22.0;
    final maxWidth = childCount > 6 ? 380.0 : 420.0;

    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: _cardSurface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 8)),
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
                colors: [color.withValues(alpha: 0.85), color],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Center(
              child: Text(
                person.firstName[0].toUpperCase(),
                style: AppType.sans(
                    fontSize: avatarSize * 0.4,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isRoot) ...[
                        const Icon(Icons.star_rounded,
                            size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        isRoot ? 'PATRIARCH' : 'GEN $generation',
                        style: AppType.sans(
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
                  style: AppType.sans(
                      fontSize: nameFontSize,
                      fontWeight: FontWeight.w700,
                      color: ArtboardColors.charcoal),
                ),

                if (person.lifespan.isNotEmpty)
                  Text(
                    person.lifespan,
                    style: AppType.sans(
                        fontSize: 12, color: ArtboardColors.warmGray),
                  ),

                const SizedBox(height: 4),

                // Stats
                Text(
                  '${_getDescendantCount(person)} descendants',
                  style: AppType.sans(
                      fontSize: 12, fontWeight: FontWeight.w600, color: color),
                ),
              ],
            ),
          ),

          // Actions
          Column(
            children: [
              _buildMiniAction(Icons.edit_rounded, ArtboardColors.sage,
                  () => _showEditDialog(person)),
              const SizedBox(height: 6),
              _buildMiniAction(Icons.person_add_alt_rounded, color,
                  () => _showUnifiedAddDialog(preSelectedParent: person)),
              const SizedBox(height: 6),
              // Moving somebody between branches, and recording a marriage.
              // Without this the only way to correct a relative filed under
              // the wrong parent was to delete them and everything below.
              _buildMiniAction(Icons.account_tree_rounded,
                  ArtboardColors.softBlue, () => _editRelationships(person)),
              if (!isRoot) ...[
                const SizedBox(height: 6),
                _buildMiniAction(Icons.delete_outline_rounded,
                    ArtboardColors.rust, () => _confirmDelete(person)),
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

    // Dynamic sizing based on total children
    final cardWidth = _getChildCardWidth(totalChildren);
    final avatarSize = _getChildAvatarSize(totalChildren);
    final fontSize = _getChildFontSize(totalChildren);

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
              color: _cardSurface(context),
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
                        colors: [color.withValues(alpha: 0.8), color],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        person.firstName[0].toUpperCase(),
                        style: AppType.sans(
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
                    style: AppType.sans(
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
        onWillAcceptWithDetails: (details) => details.data.id != person.id,
        onAcceptWithDetails: (details) => _swapPersons(details.data, person),
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
                  return Transform.scale(
                      scale: value,
                      child: Opacity(opacity: value, child: child));
                },
                child: Container(
                  width: cardWidth,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _cardSurface(context),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color:
                            isHovering ? color : color.withValues(alpha: 0.3),
                        width: isHovering ? 2 : 1),
                    boxShadow: [
                      BoxShadow(
                          color:
                              color.withValues(alpha: isHovering ? 0.2 : 0.08),
                          blurRadius: isHovering ? 16 : 10,
                          offset: const Offset(0, 4)),
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
                            colors: [color.withValues(alpha: 0.85), color],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: color.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 2))
                          ],
                        ),
                        child: Center(
                          child: Text(
                            person.firstName[0].toUpperCase(),
                            style: AppType.sans(
                                fontSize: avatarSize * 0.44,
                                fontWeight: FontWeight.w700,
                                color: Colors.white),
                          ),
                        ),
                      ),

                      SizedBox(height: 10),

                      // Name
                      Text(
                        person.firstName,
                        style: AppType.sans(
                            fontSize: fontSize,
                            fontWeight: FontWeight.w700,
                            color: ArtboardColors.charcoal),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Text(
                        person.lastName,
                        style: AppType.sans(
                            fontSize: fontSize - 2,
                            color: ArtboardColors.warmGray),
                        overflow: TextOverflow.ellipsis,
                      ),

                      SizedBox(height: 8),

                      // Descendants or explore
                      Text(
                        hasChildren ? '$descendantCount desc.' : 'No children',
                        style: AppType.sans(
                          fontSize: 11,
                          fontWeight:
                              hasChildren ? FontWeight.w600 : FontWeight.w400,
                          color: hasChildren ? color : ArtboardColors.warmGray,
                        ),
                      ),

                      SizedBox(height: 8),

                      // Admin Actions Row - Edit/Delete
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Edit button
                            GestureDetector(
                              onTap: () => _showEditDialog(person),
                              child: Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: ArtboardColors.sage
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.edit_rounded,
                                  size: 18,
                                  color: ArtboardColors.sage,
                                ),
                              ),
                            ),
                            SizedBox(width: 10),
                            // Explore/View button
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _focusStack.add(person.id)),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  color: hasChildren
                                      ? color
                                      : ArtboardColors.warmGray
                                          .withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  hasChildren ? 'Explore' : 'View',
                                  style: AppType.sans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white),
                                ),
                              ),
                            ),
                            SizedBox(width: 10),
                            // Delete button
                            GestureDetector(
                              onTap: () => _confirmDelete(person),
                              child: Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.delete_rounded,
                                  size: 18,
                                  color: Colors.red,
                                ),
                              ),
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
        },
      ),
    );
  }

  /// Compact vertical list layout

  /// Horizontal tree layout

  /// Horizontal tree node (original tree layout)

  /// Special large card for root/patriarch (tree view)

  /// Compact vertical tree - much easier to read

  int _getDescendantCount(Person person) {
    final children = _persons
        .where((p) => p.relationships.parentIds.contains(person.id))
        .toList();
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

  Widget _buildMiniAction(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
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
              color: _cardSurface(context),
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
                        colors: [
                          branchColor.withValues(alpha: 0.8),
                          branchColor
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        person.firstName[0].toUpperCase(),
                        style: AppType.sans(
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
                    style: AppType.sans(
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
        child: _buildCardContent(
            person, index, generation, branchColor, isSelected),
      ),
      onDragStarted: () {
        setState(() => _selectedPerson = person);
      },
      child: DragTarget<Person>(
        onWillAcceptWithDetails: (details) => details.data.id != person.id,
        onAcceptWithDetails: (details) {
          _swapPersons(details.data, person);
        },
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;
          final lift = isHovering ? 1.05 : (isSelected ? 1.02 : 1.0);
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            transform: Matrix4.identity()..scaleByDouble(lift, lift, lift, 1),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: isHovering
                  ? [
                      BoxShadow(
                        color: branchColor.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : [],
            ),
            child: _buildCardContent(
                person, index, generation, branchColor, isSelected),
          );
        },
      ),
    );
  }

  Widget _buildCardContent(Person person, int index, int generation,
      Color branchColor, bool isSelected) {
    final lift = isSelected ? 1.02 : 1.0;
    return GestureDetector(
      onTap: () => setState(() => _selectedPerson = person),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()..scaleByDouble(lift, lift, lift, 1),
        decoration: BoxDecoration(
          color: _cardSurface(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? branchColor : ArtboardColors.champagne,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? branchColor.withValues(alpha: 0.2)
                  : ArtboardColors.sienna.withValues(alpha: 0.08),
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
                  color: branchColor.withValues(alpha: 0.1),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: branchColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Gen $generation',
                      style: AppType.sans(
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
                            branchColor.withValues(alpha: 0.8),
                            branchColor,
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: branchColor.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          person.firstName[0].toUpperCase(),
                          style: AppType.sans(
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
                    style: AppType.sans(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: ArtboardColors.charcoal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    person.lastName,
                    style: AppType.sans(
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
                          color: ArtboardColors.warmGray.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          person.lifespan,
                          style: AppType.sans(
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
          color: color.withValues(alpha: 0.1),
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
            color: _cardSurface(context),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(32),
              bottomLeft: Radius.circular(32),
            ),
            boxShadow: [
              BoxShadow(
                color: ArtboardColors.charcoal.withValues(alpha: 0.15),
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
                      branchColor.withValues(alpha: 0.1),
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: branchColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Generation $generation',
                            style: AppType.sans(
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
                          colors: [
                            branchColor.withValues(alpha: 0.8),
                            branchColor
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: branchColor.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          person.firstName[0].toUpperCase(),
                          style: AppType.sans(
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
                      style: AppType.sans(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: ArtboardColors.charcoal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (person.lifespan.isNotEmpty)
                      Text(
                        person.lifespan,
                        style: AppType.sans(
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
                      _buildDetailSection(
                          'Bio', person.bio ?? 'No biography added yet.'),
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
          style: AppType.sans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: ArtboardColors.terracotta,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: AppType.sans(
            fontSize: 15,
            color: ArtboardColors.charcoal,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildRelationshipSection(Person person) {
    final parents = _persons
        .where((p) => person.relationships.parentIds.contains(p.id))
        .toList();
    final children = _persons
        .where((p) => person.relationships.childrenIds.contains(p.id))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RELATIONSHIPS',
          style: AppType.sans(
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
            style: AppType.sans(
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
            style: AppType.sans(
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
                color: ArtboardColors.terracotta.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  person.firstName[0],
                  style: AppType.sans(
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
              style: AppType.sans(
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

  Widget _buildPanelButton(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
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
              style: AppType.sans(
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
              valueColor:
                  AlwaysStoppedAnimation<Color>(ArtboardColors.terracotta),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading family tree...',
            style: AppType.sans(
              fontSize: 18,
              color: ArtboardColors.warmGray,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UNIFIED ADD MEMBER DIALOG - Clean, Single Dialog for All Cases
  // ═══════════════════════════════════════════════════════════════════════════

  /// The look every box in the add-member form shares, so the form reads as
  /// one thing rather than as fields added at different times.
  /// Adding somebody uses the same form as editing them, so the two cannot
  /// drift apart again.
  Future<void> _showUnifiedAddDialog({Person? preSelectedParent}) async {
    final created = await showPersonEditor(
      context: context,
      people: _persons,
      preSelectedParent: preSelectedParent,
    );
    if (created == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final parentIds = created.relationships.parentIds;

    try {
      var displayOrder = created.displayOrder;

      if (parentIds.isEmpty) {
        // A root's position is after the roots that already exist rather than
        // whatever the form happened to be showing.
        final roots =
            _persons.where((p) => p.relationships.parentIds.isEmpty).toList();
        displayOrder = roots.isEmpty
            ? 1
            : roots.map((r) => r.displayOrder).reduce((a, b) => a > b ? a : b) +
                1;
      } else {
        // Everyone at or below the chosen position shifts down to make room,
        // highest first so no two siblings collide on the way.
        final siblings = _persons
            .where((p) =>
                p.relationships.parentIds.any(parentIds.contains) &&
                p.displayOrder >= displayOrder)
            .toList()
          ..sort((a, b) => b.displayOrder.compareTo(a.displayOrder));

        for (final sibling in siblings) {
          await _adminRepo.updatePerson(
              sibling.copyWith(displayOrder: sibling.displayOrder + 1));
        }
      }

      // One request. The parent's side of the link is derived by the server
      // from the child's parentIds, so the second call that used to append to
      // the parent's childrenIds — and left the tree inconsistent whenever it
      // failed — is gone.
      await _adminRepo.addPerson(created.copyWith(displayOrder: displayOrder));

      if (!mounted) return;
      _loadData();

      messenger.showSnackBar(
        SnackBar(
          content: Text('${created.firstName} added'),
          backgroundColor: ArtboardColors.sage,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(readableError(e)),
          backgroundColor: ArtboardColors.rust,
        ),
      );
    }
  }

  // Drag-drop swap method - swaps displayOrder to change sibling order
  void _swapPersons(Person draggedPerson, Person targetPerson) async {
    final tempOrder = draggedPerson.displayOrder;

    // Create updated persons with swapped displayOrder
    final updatedDragged =
        draggedPerson.copyWith(displayOrder: targetPerson.displayOrder);
    final updatedTarget = targetPerson.copyWith(displayOrder: tempOrder);

    // Immediately update local state for instant visual feedback
    setState(() {
      final draggedIndex = _persons.indexWhere((p) => p.id == draggedPerson.id);
      final targetIndex = _persons.indexWhere((p) => p.id == targetPerson.id);

      if (draggedIndex >= 0) {
        _persons[draggedIndex] = updatedDragged;
      }
      if (targetIndex >= 0) {
        _persons[targetIndex] = updatedTarget;
      }

      // Also update filtered list
      final draggedFilteredIndex =
          _filteredPersons.indexWhere((p) => p.id == draggedPerson.id);
      final targetFilteredIndex =
          _filteredPersons.indexWhere((p) => p.id == targetPerson.id);

      if (draggedFilteredIndex >= 0) {
        _filteredPersons[draggedFilteredIndex] = updatedDragged;
      }
      if (targetFilteredIndex >= 0) {
        _filteredPersons[targetFilteredIndex] = updatedTarget;
      }
    });

    // Persist to backend (async, no await needed for UI)
    try {
      await _personRepo.updatePerson(updatedDragged);
      await _personRepo.updatePerson(updatedTarget);
    } catch (e) {
      // If backend fails, reload data to restore correct state
      _loadData();
    }
  }

  /// Change who a person's parents are, and who they married.
  Future<void> _editRelationships(Person person) async {
    final saved = await showRelationshipsSheet(
      context,
      person: person,
      people: _persons,
      onSave: (updated) => _adminRepo.updatePerson(updated),
    );
    if (saved == true) _loadData();
  }

  /// Editing uses the same form as adding, so every field an admin can fill
  /// in when creating somebody stays editable afterwards. The two used to be
  /// separate dialogs and had drifted badly: this one offered a name, a birth
  /// year and a biography, and nothing else on the record could be changed
  /// through the app at all.
  Future<void> _showEditDialog(Person person) async {
    final updated = await showPersonEditor(
      context: context,
      people: _persons,
      existing: person,
    );
    if (updated == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    try {
      // Birth order is a position among siblings, so taking one means giving
      // the sibling who held it the position being vacated.
      if (updated.displayOrder != person.displayOrder &&
          updated.relationships.parentIds.isNotEmpty) {
        final siblings = _persons
            .where((p) =>
                p.id != person.id &&
                p.relationships.parentIds.any(
                    (pid) => updated.relationships.parentIds.contains(pid)))
            .toList();

        for (final sibling in siblings) {
          if (sibling.displayOrder == updated.displayOrder) {
            await _adminRepo.updatePerson(
                sibling.copyWith(displayOrder: person.displayOrder));
            break;
          }
        }
      }

      await _adminRepo.updatePerson(updated);

      if (!mounted) return;
      _loadData();
      setState(() => _selectedPerson = null);

      messenger.showSnackBar(
        SnackBar(
          content: Text('${updated.firstName} updated'),
          backgroundColor: ArtboardColors.sage,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(readableError(e)),
          backgroundColor: ArtboardColors.rust,
        ),
      );
    }
  }

  // Get ancestry chain for a person

  /// Everyone below this person — children, grandchildren, and so on.
  ///
  /// Breadth-first and visited-guarded. The recursive version rescanned the
  /// whole list per node and would not terminate if anyone ended up as their
  /// own ancestor, which this screen can produce.
  List<Person> _getAllDescendants(Person person) {
    final index = FamilyIndex(_persons);
    final found = <Person>[];
    final seen = <String>{person.id};
    final queue = <Person>[person];

    while (queue.isNotEmpty) {
      for (final child in index.childrenOf(queue.removeAt(0))) {
        if (seen.add(child.id)) {
          found.add(child);
          queue.add(child);
        }
      }
    }
    return found;
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
          style: AppType.sans(
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
              style: AppType.sans(
                fontSize: 15,
                color: ArtboardColors.warmGray,
              ),
            ),
            if (descendants.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ArtboardColors.rust.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: ArtboardColors.rust.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_rounded,
                        color: ArtboardColors.rust, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This will also delete ${descendants.length} descendant${descendants.length > 1 ? 's' : ''} (children, grandchildren, etc.)',
                        style: AppType.sans(
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
              style: AppType.sans(color: ArtboardColors.warmGray),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ArtboardColors.rust,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              // Resolved before the await: see the add-person handler above.
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(this.context);

              try {
                // One request for the whole subtree. This used to send one
                // delete per descendant, so a failure partway left half a
                // family gone with no way to tell which half.
                await _adminRepo.deletePerson(
                  person.id,
                  cascade: descendants.isNotEmpty,
                );

                if (!mounted) return;
                navigator.pop();
                _loadData();
                setState(() {
                  _selectedPerson = null;
                  _focusStack.clear();
                });
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                        'Deleted $totalToDelete family member${totalToDelete > 1 ? 's' : ''}'),
                    backgroundColor: ArtboardColors.sage,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(content: Text(readableError(e))),
                );
              }
            },
            child: Text(
              'Delete ${totalToDelete > 1 ? 'All ($totalToDelete)' : ''}',
              style: AppType.sans(
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

  /// Batch delete selected persons with cascade
}

/// Custom painter for subtle background pattern
class _PatternPainter extends CustomPainter {
  final bool isDark;

  _PatternPainter({this.isDark = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (isDark
          ? Colors.white.withValues(alpha: 0.03)
          : ArtboardColors.champagne.withValues(alpha: 0.3))
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

/// A small count on an admin control. Reads as "there is work here" without
/// having to open the menu to find out.
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.error,
        shape: BoxShape.circle,
        border: Border.all(color: context.colors.surface, width: 1.5),
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        style: AppType.sans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1,
        ),
      ),
    );
  }
}
