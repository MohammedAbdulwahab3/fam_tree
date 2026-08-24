import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:family_tree/core/layout/breakpoints.dart';
import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/core/theme/app_colors.dart';
import 'package:family_tree/core/theme/elegant_theme.dart';
import 'package:family_tree/data/models/person.dart';
import 'package:family_tree/features/tree_view/controllers/tree_controller.dart';
import 'package:family_tree/features/tree_view/tree_canvas.dart';
import 'package:family_tree/features/tree_view/widgets/person_details_dialog.dart';
import 'package:family_tree/features/tree_view/widgets/profile_drawer.dart';
import 'package:family_tree/features/linking/find_myself_sheet.dart';
import 'package:family_tree/features/linking/link_status.dart';
import 'package:family_tree/features/profile/my_profile_editor.dart';
import 'package:family_tree/features/auth/session.dart';
import 'package:family_tree/core/widgets/theme_toggle_button.dart';
import 'package:family_tree/core/widgets/locale_menu_button.dart';
import 'package:image_picker/image_picker.dart';
import 'package:family_tree/data/services/storage_service.dart';
import 'package:family_tree/data/services/family_export_service.dart';
import 'package:family_tree/data/services/web_download_helper.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:family_tree/core/design/typography.dart';

/// Which slice of the tree the canvas draws.
enum FamilyViewMode {
  /// Everyone — what a signed-out visitor sees, and the default for everyone.
  all,

  /// The signed-in member's own line: every ancestor above them and every
  /// descendant below, drawn together on one canvas.
  lineage,
}

/// Main screen for the family tree view
class TreeScreen extends ConsumerStatefulWidget {
  final String familyTreeId;
  final bool isDemo;

  /// Set on the first visit after signing up. Opens the "find yourself in the
  /// tree" sheet once the tree has loaded.
  final bool promptToLink;

  const TreeScreen({
    super.key,
    required this.familyTreeId,
    this.isDemo = false,
    this.promptToLink = false,
  });

  @override
  ConsumerState<TreeScreen> createState() => _TreeScreenState();
}

class _TreeScreenState extends ConsumerState<TreeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<TreeCanvasState> _treeCanvasKey =
      GlobalKey<TreeCanvasState>();

  /// Signing in used to drop you into your own descendants in a drill-down
  /// view. The tree is the point of the app, so it now opens the same way for
  /// everyone and "My lineage" is an opt-in.
  final FamilyViewMode _viewMode = FamilyViewMode.all;
  bool _initialized = false;

  /// Guards the welcome prompt so it opens once per arrival, not on every
  /// rebuild the polling tree triggers.
  bool _linkPromptShown = false;

  /// Get the logged-in user's linked person
  Person? _getLinkedPerson(List<Person> allPersons, String? authUserId) {
    if (authUserId == null || widget.isDemo) return null;
    return allPersons.where((p) => p.authUserId == authUserId).firstOrNull;
  }

  /// The people the canvas should draw for the current view mode.
  ///
  /// Lineage means the member's whole vertical line in one go — every
  /// generation above them and every generation below — plus the spouses of
  /// everyone on it, so couples still render as couples instead of a single
  /// parent appearing to have children alone.
  List<Person> _getFilteredPersons(
      List<Person> allPersons, String? authUserId) {
    if (_viewMode == FamilyViewMode.all || widget.isDemo) {
      return allPersons;
    }

    final linkedPerson = _getLinkedPerson(allPersons, authUserId);
    if (linkedPerson == null) return allPersons;

    final byId = {for (final p in allPersons) p.id: p};
    final childrenOf = <String, List<String>>{};
    for (final person in allPersons) {
      for (final parentId in person.relationships.parentIds) {
        (childrenOf[parentId] ??= <String>[]).add(person.id);
      }
    }

    final included = <String>{linkedPerson.id};

    void walkUp(String id) {
      for (final parentId in byId[id]?.relationships.parentIds ?? const []) {
        if (included.add(parentId)) walkUp(parentId);
      }
    }

    void walkDown(String id) {
      for (final childId in childrenOf[id] ?? const <String>[]) {
        if (included.add(childId)) walkDown(childId);
      }
    }

    walkUp(linkedPerson.id);
    walkDown(linkedPerson.id);

    // Spouses come last so marrying into the line does not drag their whole
    // family in with them.
    for (final id in included.toList()) {
      included.addAll(byId[id]?.relationships.spouseIds ?? const []);
    }

    return allPersons.where((p) => included.contains(p.id)).toList();
  }

  /// Show photo upload options (camera or gallery)
  void _showPhotoUploadOptions(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Change Profile Photo',
              style: AppType.sans(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: context.colors.ink,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (context.colors.accent).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.camera_alt_rounded,
                  color: context.colors.accent,
                ),
              ),
              title: Text(
                'Take Photo',
                style: AppType.sans(
                  color: context.colors.ink,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (context.colors.secondary).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.photo_library_rounded,
                  color: context.colors.secondary,
                ),
              ),
              title: Text(
                'Choose from Gallery',
                style: AppType.sans(
                  color: context.colors.ink,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadPhoto(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// Pick and upload photo
  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                ),
                SizedBox(width: 16),
                Text('Uploading photo...'),
              ],
            ),
            duration: Duration(seconds: 10),
          ),
        );
      }

      // Read file bytes
      final bytes = await pickedFile.readAsBytes();

      // Upload to storage
      final storageService = StorageService();
      final downloadUrl =
          await storageService.uploadProfilePhoto(bytes, pickedFile.name);

      // Persist the new photo on the backend user record
      await ref.read(authServiceProvider).updatePhotoUrl(downloadUrl);

      // Hide loading and show success
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated!'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh the auth state to get updated photo
        ref.read(sessionProvider.notifier).refresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update photo: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  /// Show edit profile dialog for linked users
  /// Open the full self-profile editor for the record this account owns.
  ///
  /// Replaces the old three-field dialog, which stored the spouse's name in
  /// the `bio` column — so a member's biography and their marriage were the
  /// same field and neither could be shown properly.
  void _showEditProfileDialog(
      BuildContext context, Person person, bool isDark) {
    final controller =
        ref.read(treeControllerProvider(widget.familyTreeId).notifier);
    final all = ref.read(treeControllerProvider(widget.familyTreeId)).persons;
    final spouses = all
        .where((p) => person.relationships.spouseIds.contains(p.id))
        .toList();

    // Resolved before the sheet is awaited: the callback runs once the sheet
    // has closed, by which point this context may be gone.
    final messenger = ScaffoldMessenger.of(context);

    MyProfileEditor.show(
      context,
      person: person,
      spouses: spouses,
      isAdmin: ref.read(isAdminProvider),
      onSave: (updated) async {
        await controller.updatePerson(updated);
        await controller.refresh();
      },
    ).then((saved) {
      if (saved == true && mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Your profile is updated'),
            backgroundColor: ElegantColors.sage,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(treeControllerProvider(widget.familyTreeId));
    final controller =
        ref.read(treeControllerProvider(widget.familyTreeId).notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 768;

    // Get current user for filtering
    final authUser = ref.watch(currentUserProvider);
    final authUserId = authUser?.uid;
    final isSignedIn = authUser != null;

    final isAdmin = ref.watch(isAdminProvider);

    // Get linked person for display
    final linkedPerson = _getLinkedPerson(state.persons, authUserId);

    // A new member who has not claimed a record yet: show them how, once the
    // tree has actually loaded so the sheet has people to search.
    if (widget.promptToLink &&
        !_linkPromptShown &&
        isSignedIn &&
        !widget.isDemo &&
        linkedPerson == null &&
        state.persons.isNotEmpty) {
      _linkPromptShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _maybePromptToLink(state.persons);
      });
    }

    // Auto-select linked person and set focus mode on first load
    if (!_initialized && linkedPerson != null && !widget.isDemo) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(sessionProvider.notifier).refresh();
        controller.selectPerson(linkedPerson.id);
        controller.setLayoutMode(LayoutMode.focus);
        setState(() {
          _initialized = true;
        });
      });
    }

    // Filter persons based on view mode
    final filteredPersons = _getFilteredPersons(state.persons, authUserId);

    return Scaffold(
      key: _scaffoldKey,
      endDrawer: _buildProfileSidebar(context, isDark),
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        AppTheme.backgroundDark,
                        const Color(0xFF0D1F2D),
                        AppTheme.primaryDeep.withValues(alpha: 0.2),
                      ]
                    : [
                        const Color(0xFFF8FAFC),
                        const Color(0xFFECFDF5),
                        AppTheme.accentTeal.withValues(alpha: 0.05),
                      ],
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Custom Top Bar with navigation buttons
                _buildTopBar(context, isDark, isMobile, isSignedIn, isAdmin,
                    linkedPerson != null),

                // Tree Canvas
                Expanded(
                  child: state.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : state.error != null
                          ? _buildErrorState(context, state.error!)
                          : filteredPersons.isEmpty
                              ? _buildEmptyState(context, controller, ref)
                              : TreeCanvas(
                                  key: _treeCanvasKey,
                                  persons: filteredPersons,
                                  selectedPersonId: state.selectedPersonId,
                                  focusedSubtreeRoot: state.focusedSubtreeRoot,
                                  focusedPersonIds: state.focusedPersonIds,
                                  layoutMode: state.layoutMode,
                                  onPersonTapped: (id) {
                                    controller.selectPerson(id);
                                  },
                                  onPersonDoubleTapped: (id) {
                                    final person = filteredPersons
                                        .firstWhere((p) => p.id == id);
                                    final spouses = filteredPersons
                                        .where((p) => person
                                            .relationships.spouseIds
                                            .contains(p.id))
                                        .toList();
                                    final children = filteredPersons
                                        .where((p) => person
                                            .relationships.childrenIds
                                            .contains(p.id))
                                        .toList();

                                    showDialog(
                                      context: context,
                                      barrierColor:
                                          Colors.black.withValues(alpha: 0.5),
                                      builder: (context) => PersonDetailsDialog(
                                        person: person,
                                        spouses: spouses,
                                        children: children,
                                        onPersonTapped: (relativeId) {
                                          Navigator.of(context).pop();
                                          controller.selectPerson(relativeId);
                                        },
                                      ),
                                    );
                                  },
                                  onPersonLongPressed: (id) {
                                    controller.focusOnSubtree(id);
                                  },
                                  onClearSubtreeFocus: () {
                                    controller.clearSubtreeFocus();
                                  },
                                  onBackgroundTapped: () {
                                    controller.selectPerson(null);
                                  },
                                ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Opens the claim sheet for a member who has never asked to be linked.
  ///
  /// Someone with a claim already pending or previously rejected is left alone
  /// — they know about the flow, and reopening it would only let them file a
  /// duplicate the backend would refuse.
  Future<void> _maybePromptToLink(List<Person> members) async {
    final status = await ref.read(linkStatusProvider.future).catchError(
          (_) => LinkStatus(isVerified: false, status: 'unknown'),
        );
    if (!mounted || !status.canClaim || status.isRejected) return;

    await showFindMyselfSheet(context, people: members);
    if (mounted) ref.invalidate(linkStatusProvider);
  }

  Widget _buildTopBar(BuildContext context, bool isDark, bool isMobile,
      bool isSignedIn, bool isAdmin, bool hasLineage) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 20,
        vertical: 12,
      ),
      child: Row(
        children: [
          // Back button
          _buildIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => context.go('/'),
            isDark: isDark,
            tooltip: 'Home',
          ),

          const SizedBox(width: 12),

          // Title
          Expanded(
            child: Text(
              widget.isDemo ? 'Family Tree Demo' : _getViewTitle(),
              style: AppType.sans(
                fontSize: isMobile ? 20 : 24,
                fontWeight: FontWeight.bold,
                color: context.colors.ink,
              ),
            ),
          ),

          // Language (EN / አማ) toggle — switches the tree to Amharic names
          const LocaleMenuButton(),

          const SizedBox(width: 8),

          // Theme Toggle
          ThemeToggleIcon(
            color: context.colors.ink,
          ),

          const SizedBox(width: 8),

          // Download/Export button
          _buildIconButton(
            icon: Icons.download_rounded,
            onTap: () => _showExportDialog(context, isDark),
            isDark: isDark,
            tooltip: 'Download Family Tree',
          ),

          const SizedBox(width: 8),

          // Focus/Full Tree Toggle Button - responsive
          Builder(
            builder: (context) {
              final state =
                  ref.watch(treeControllerProvider(widget.familyTreeId));
              final controller = ref
                  .read(treeControllerProvider(widget.familyTreeId).notifier);
              final isFocusMode = state.layoutMode == LayoutMode.focus;

              return GestureDetector(
                onTap: () {
                  // Toggle between focus and tree modes
                  controller.setLayoutMode(
                      isFocusMode ? LayoutMode.tree : LayoutMode.focus);
                },
                child: Tooltip(
                  message: isFocusMode ? 'Focus Mode' : 'Full Tree',
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 10 : 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isFocusMode
                          ? (context.colors.accent)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : ElegantColors.warmWhite),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isFocusMode
                            ? Colors.transparent
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : ElegantColors.champagne),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isFocusMode
                              ? Icons.center_focus_strong_rounded
                              : Icons.account_tree_rounded,
                          color: isFocusMode
                              ? Colors.white
                              : (context.colors.inkSoft),
                          size: 18,
                        ),
                        // Only show text on larger screens
                        if (!isMobile) ...[
                          const SizedBox(width: 6),
                          Text(
                            isFocusMode ? 'Focus' : 'Full Tree',
                            style: AppType.sans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isFocusMode
                                  ? Colors.white
                                  : (context.colors.inkSoft),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(width: 8),

          // Sign In / Profile button - icon-only for cleaner mobile UI
          if (!isSignedIn)
            _buildIconButton(
              icon: Icons.account_circle_rounded,
              onTap: () => context.go('/login'),
              isDark: isDark,
              tooltip: 'Sign In',
              isPrimary: true,
            )
          else
            _buildIconButton(
              icon: Icons.person_rounded,
              onTap: () => _showProfileDialog(context, isDark),
              isDark: isDark,
              tooltip: 'Profile',
              isPrimary: true,
            ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
    required String tooltip,
    bool isPrimary = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: isPrimary ? AppTheme.primaryGradient : null,
              color: isPrimary
                  ? null
                  : isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : ElegantColors.warmWhite,
              borderRadius: BorderRadius.circular(14),
              border: isPrimary
                  ? null
                  : Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : ElegantColors.champagne,
                    ),
              boxShadow: isPrimary
                  ? [
                      BoxShadow(
                        color: AppTheme.primaryLight.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              icon,
              color: isPrimary
                  ? Colors.white
                  : isDark
                      ? Colors.white70
                      : ElegantColors.charcoal,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  String _getViewTitle() {
    switch (_viewMode) {
      case FamilyViewMode.all:
        return 'Family Tree';
      case FamilyViewMode.lineage:
        return 'My Lineage';
    }
  }

  /// Show export dialog with multiple format options
  void _showExportDialog(BuildContext context, bool isDark) {
    // Get focused subtree if in focus mode, otherwise all members
    final allMembers =
        ref.read(treeControllerProvider(widget.familyTreeId)).persons;
    final canvasState = _treeCanvasKey.currentState;
    final familyMembers = canvasState?.getFocusedSubtreePersons() ?? allMembers;
    final focusedPersonName = canvasState?.getFocusedPersonName();
    final isSubtree = focusedPersonName != null;
    final exportTitle =
        isSubtree ? "$focusedPersonName's Family" : "Mamaduu's Lineage";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: ElegantColors.warmGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.download_rounded,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isSubtree ? 'Download Subtree' : 'Download Family Tree',
                    style: AppType.sans(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: context.colors.ink,
                    ),
                  ),
                  Text(
                    isSubtree
                        ? '${familyMembers.length} members ($focusedPersonName\'s branch)'
                        : '${familyMembers.length} members',
                    style: AppType.sans(
                      fontSize: 12,
                      color: context.colors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          // Was a hard 400, which is wider than a small phone's dialog once
          // insets are taken off — the content overflowed the right edge.
          width: context.dialogWidth(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildExportOption(
                context: context,
                icon: Icons.picture_as_pdf_rounded,
                title: 'Download Family Tree',
                subtitle: kIsWeb
                    ? 'Download as scrollable HTML file'
                    : 'Share or save PDF',
                color: ElegantColors.terracotta,
                isDark: isDark,
                onTap: () async {
                  Navigator.pop(context);
                  if (kIsWeb) {
                    // Web: download as HTML file (scrollable in any browser)
                    final htmlContent = FamilyExportService.exportAsHtmlTree(
                        familyMembers, exportTitle);
                    WebDownloadHelper.downloadFile(
                        htmlContent,
                        '${exportTitle.replaceAll(' ', '_')}_family_tree.html',
                        'text/html');
                    _showDownloadSuccess(context,
                        'Family Tree HTML downloaded - open in browser to scroll!');
                  } else {
                    // Mobile: use printing package to share/print PDF
                    _showDownloadSuccess(context, 'Generating PDF...');
                    await Printing.layoutPdf(
                      onLayout: (format) async {
                        final doc = pw.Document();
                        doc.addPage(
                          pw.MultiPage(
                            pageFormat: PdfPageFormat.a4.landscape,
                            margin: const pw.EdgeInsets.all(32),
                            header: (context) => pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Row(
                                  mainAxisAlignment:
                                      pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text("$exportTitle - Family Tree",
                                        style: pw.TextStyle(
                                            fontSize: 24,
                                            fontWeight: pw.FontWeight.bold)),
                                    pw.Text(
                                        'Page ${context.pageNumber} of ${context.pagesCount}',
                                        style: const pw.TextStyle(
                                            fontSize: 12,
                                            color: PdfColors.grey600)),
                                  ],
                                ),
                                pw.SizedBox(height: 4),
                                pw.Text(
                                    'Total Members: ${familyMembers.length} | Generated: ${DateTime.now().toString().split('.')[0]}',
                                    style: const pw.TextStyle(
                                        fontSize: 12,
                                        color: PdfColors.grey700)),
                                pw.Divider(
                                    thickness: 1, color: PdfColors.amber),
                                pw.SizedBox(height: 8),
                              ],
                            ),
                            footer: (context) => pw.Container(
                              alignment: pw.Alignment.centerRight,
                              margin: const pw.EdgeInsets.only(top: 10),
                              child: pw.Text('Family Tree App',
                                  style: const pw.TextStyle(
                                      fontSize: 10, color: PdfColors.grey500)),
                            ),
                            build: (context) => [
                              ...familyMembers.map((p) {
                                final spouseNames = familyMembers
                                    .where((s) => p.relationships.spouseIds
                                        .contains(s.id))
                                    .map((s) => s.fullName)
                                    .toList();
                                final childNames = familyMembers
                                    .where((c) => p.relationships.childrenIds
                                        .contains(c.id))
                                    .map((c) => c.fullName)
                                    .toList();
                                final parentNames = familyMembers
                                    .where((pr) => p.relationships.parentIds
                                        .contains(pr.id))
                                    .map((pr) => pr.fullName)
                                    .toList();

                                return pw.Container(
                                  margin: const pw.EdgeInsets.only(bottom: 10),
                                  padding: const pw.EdgeInsets.all(12),
                                  decoration: pw.BoxDecoration(
                                    border: pw.Border.all(
                                        color: PdfColors.amber200),
                                    borderRadius: pw.BorderRadius.circular(8),
                                    color: PdfColors.amber50,
                                  ),
                                  child: pw.Row(
                                    crossAxisAlignment:
                                        pw.CrossAxisAlignment.start,
                                    children: [
                                      pw.Container(
                                        width: 40,
                                        height: 40,
                                        decoration: pw.BoxDecoration(
                                          color: p.gender == 'male' ||
                                                  p.gender == 'Male'
                                              ? PdfColors.blue300
                                              : PdfColors.pink300,
                                          shape: pw.BoxShape.circle,
                                        ),
                                        child: pw.Center(
                                          child: pw.Text(
                                              p.firstName[0].toUpperCase(),
                                              style: pw.TextStyle(
                                                  color: PdfColors.white,
                                                  fontWeight:
                                                      pw.FontWeight.bold,
                                                  fontSize: 16)),
                                        ),
                                      ),
                                      pw.SizedBox(width: 15),
                                      pw.Expanded(
                                        child: pw.Column(
                                          crossAxisAlignment:
                                              pw.CrossAxisAlignment.start,
                                          children: [
                                            pw.Text(p.fullName,
                                                style: pw.TextStyle(
                                                    fontWeight:
                                                        pw.FontWeight.bold,
                                                    fontSize: 14)),
                                            pw.SizedBox(height: 2),
                                            pw.Text(
                                              '${p.gender == 'male' || p.gender == 'Male' ? '♂ Male' : '♀ Female'}'
                                              '${(p.bio ?? '').isNotEmpty ? ' • ${p.bio}' : ''}',
                                              style: const pw.TextStyle(
                                                  fontSize: 10,
                                                  color: PdfColors.grey700),
                                            ),
                                            if (parentNames.isNotEmpty) ...[
                                              pw.SizedBox(height: 2),
                                              pw.Text(
                                                  'Parents: ${parentNames.join(', ')}',
                                                  style: const pw.TextStyle(
                                                      fontSize: 10,
                                                      color:
                                                          PdfColors.grey600)),
                                            ],
                                            if (spouseNames.isNotEmpty) ...[
                                              pw.SizedBox(height: 2),
                                              pw.Text(
                                                  'Spouse: ${spouseNames.join(', ')}',
                                                  style: const pw.TextStyle(
                                                      fontSize: 10,
                                                      color:
                                                          PdfColors.grey600)),
                                            ],
                                            if (childNames.isNotEmpty) ...[
                                              pw.SizedBox(height: 2),
                                              pw.Text(
                                                  'Children: ${childNames.join(', ')}',
                                                  style: const pw.TextStyle(
                                                      fontSize: 10,
                                                      color:
                                                          PdfColors.grey600)),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                        return doc.save();
                      },
                    );
                  }
                },
              ),
              const SizedBox(height: 12),
              _buildExportOption(
                context: context,
                icon: Icons.people_rounded,
                title: 'Member Directory',
                subtitle: 'Printable list of all family members',
                color: ElegantColors.sage,
                isDark: isDark,
                onTap: () {
                  Navigator.pop(context);
                  _downloadFile(
                    FamilyExportService.exportAsMemberList(
                        familyMembers, exportTitle),
                    'family_members.html',
                    'text/html',
                  );
                  _showDownloadSuccess(context, 'Member Directory');
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.colors.inkMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportOption({
    required BuildContext context,
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
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : color.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.2 : 0.15),
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
                      style: AppType.sans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: context.colors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppType.sans(
                        fontSize: 12,
                        color: context.colors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: context.colors.inkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _downloadFile(String content, String filename, String mimeType) {
    WebDownloadHelper.downloadFile(content, filename, mimeType);
  }

  void _showDownloadSuccess(BuildContext context, String type) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Text('$type downloaded successfully!'),
          ],
        ),
        backgroundColor: ElegantColors.sage,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showProfileDialog(BuildContext context, bool isDark) {
    // Open the end drawer for the profile sidebar
    _scaffoldKey.currentState?.openEndDrawer();
  }

  /// The profile side panel. All of its presentation lives in [ProfileDrawer];
  /// this screen only supplies the tree data and the dialogs the panel opens.
  Widget _buildProfileSidebar(BuildContext context, bool isDark) {
    final state = ref.watch(treeControllerProvider(widget.familyTreeId));
    final authUserId = ref.watch(currentUserProvider)?.uid;

    return ProfileDrawer(
      familyMembers: state.persons,
      linkedPerson: _getLinkedPerson(state.persons, authUserId),
      onChangePhoto: () => _showPhotoUploadOptions(context, isDark),
      onEditLinkedProfile: () {
        final person = _getLinkedPerson(state.persons, authUserId);
        if (person != null) {
          _showEditProfileDialog(context, person, isDark);
        }
      },
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 64,
            color: Colors.red.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Error: $error',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
      BuildContext context, TreeController controller, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient.scale(0.3),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.family_restroom_rounded,
              size: 64,
              color: context.colors.inkMuted,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No family members yet',
            style: AppType.sans(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: context.colors.ink,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'The family tree is empty.\nUse the Admin Panel to add members.',
            style: AppType.sans(
              fontSize: 15,
              color: context.colors.inkMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
