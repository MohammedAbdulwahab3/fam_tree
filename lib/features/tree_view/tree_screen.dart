import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/core/theme/elegant_theme.dart';
import 'package:family_tree/data/models/person.dart';
import 'package:family_tree/features/tree_view/controllers/tree_controller.dart';
import 'package:family_tree/features/tree_view/tree_canvas.dart';
import 'package:family_tree/features/tree_view/widgets/person_details_dialog.dart';
import 'package:family_tree/features/auth/providers/auth_provider.dart';
import 'package:family_tree/providers/admin_provider.dart';
import 'package:family_tree/core/widgets/theme_toggle_button.dart';
import 'package:image_picker/image_picker.dart';
import 'package:family_tree/data/services/storage_service.dart';
import 'package:family_tree/data/services/family_export_service.dart';
import 'package:family_tree/data/services/web_download_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// View mode for family tree
enum FamilyViewMode {
  descendants, // My family - me and all my children/grandchildren
  ancestors,   // My lineage - me and all my parents/grandparents
  all,         // Full tree (demo mode)
}

/// Main screen for the family tree view
class TreeScreen extends ConsumerStatefulWidget {
  final String familyTreeId;
  final bool isDemo;

  const TreeScreen({
    Key? key,
    required this.familyTreeId,
    this.isDemo = false,
  }) : super(key: key);

  @override
  ConsumerState<TreeScreen> createState() => _TreeScreenState();
}

class _TreeScreenState extends ConsumerState<TreeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  FamilyViewMode _viewMode = FamilyViewMode.descendants;
  String? _linkedPersonId;
  bool _initialized = false;
  
  /// Get the logged-in user's linked person
  Person? _getLinkedPerson(List<Person> allPersons, String? authUserId) {
    if (authUserId == null || widget.isDemo) return null;
    return allPersons.where((p) => p.authUserId == authUserId).firstOrNull;
  }
  
  /// Get filtered persons based on view mode
  List<Person> _getFilteredPersons(List<Person> allPersons, String? authUserId) {
    if (authUserId == null || widget.isDemo) {
      return allPersons;
    }
    
    final linkedPerson = _getLinkedPerson(allPersons, authUserId);
    
    if (linkedPerson == null) {
      return allPersons;
    }
    
    final Set<String> includedIds = {linkedPerson.id};
    
    if (_viewMode == FamilyViewMode.descendants) {
      void addDescendants(String personId) {
        for (final person in allPersons) {
          if (person.relationships.parentIds.contains(personId)) {
            if (!includedIds.contains(person.id)) {
              includedIds.add(person.id);
              addDescendants(person.id);
            }
          }
        }
      }
      addDescendants(linkedPerson.id);
    } else if (_viewMode == FamilyViewMode.ancestors) {
      void addAncestors(String personId) {
        final person = allPersons.where((p) => p.id == personId).firstOrNull;
        if (person == null) return;
        
        for (final parentId in person.relationships.parentIds) {
          if (!includedIds.contains(parentId)) {
            includedIds.add(parentId);
            addAncestors(parentId);
          }
        }
      }
      addAncestors(linkedPerson.id);
    }
    
    return allPersons.where((p) => includedIds.contains(p.id)).toList();
  }

  /// Show photo upload options (camera or gallery)
  void _showPhotoUploadOptions(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppTheme.cardDark : ElegantColors.warmWhite,
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
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : ElegantColors.charcoal,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isDark ? AppTheme.primaryLight : ElegantColors.terracotta).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.camera_alt_rounded,
                  color: isDark ? AppTheme.primaryLight : ElegantColors.terracotta,
                ),
              ),
              title: Text(
                'Take Photo',
                style: GoogleFonts.inter(
                  color: isDark ? Colors.white : ElegantColors.charcoal,
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
                  color: (isDark ? AppTheme.accentTeal : ElegantColors.sage).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.photo_library_rounded,
                  color: isDark ? AppTheme.accentTeal : ElegantColors.sage,
                ),
              ),
              title: Text(
                'Choose from Gallery',
                style: GoogleFonts.inter(
                  color: isDark ? Colors.white : ElegantColors.charcoal,
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
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
      final downloadUrl = await storageService.uploadProfilePhoto(bytes, pickedFile.name);

      // Update Firebase user profile
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.updatePhotoURL(downloadUrl);
        await user.reload();
      }

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
        ref.invalidate(authStateProvider);
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
  void _showEditProfileDialog(BuildContext context, Person person, bool isDark) {
    final firstNameController = TextEditingController(text: person.firstName);
    final lastNameController = TextEditingController(text: person.lastName);
    // Store spouse in bio field (private to user)
    final spouseController = TextEditingController(text: person.bio ?? '');
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? AppTheme.cardDark : ElegantColors.warmWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              Icons.edit_rounded,
              color: isDark ? AppTheme.primaryLight : ElegantColors.terracotta,
            ),
            const SizedBox(width: 12),
            Text(
              'Edit My Profile',
              style: GoogleFonts.playfairDisplay(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : ElegantColors.charcoal,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // First Name
              TextField(
                controller: firstNameController,
                decoration: InputDecoration(
                  labelText: 'First Name',
                  labelStyle: TextStyle(color: isDark ? AppTheme.textSecondary : ElegantColors.warmGray),
                  prefixIcon: Icon(Icons.person_outline, color: isDark ? AppTheme.primaryLight : ElegantColors.terracotta),
                ),
                style: TextStyle(color: isDark ? Colors.white : ElegantColors.charcoal),
              ),
              const SizedBox(height: 16),
              
              // Last Name
              TextField(
                controller: lastNameController,
                decoration: InputDecoration(
                  labelText: 'Last Name',
                  labelStyle: TextStyle(color: isDark ? AppTheme.textSecondary : ElegantColors.warmGray),
                  prefixIcon: Icon(Icons.person_outline, color: isDark ? AppTheme.primaryLight : ElegantColors.terracotta),
                ),
                style: TextStyle(color: isDark ? Colors.white : ElegantColors.charcoal),
              ),
              const SizedBox(height: 24),
              
              // Spouse section (private - only visible to user)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isDark ? AppTheme.accentGold : ElegantColors.gold).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (isDark ? AppTheme.accentGold : ElegantColors.gold).withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.favorite_rounded,
                          size: 16,
                          color: isDark ? AppTheme.accentGold : ElegantColors.gold,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Spouse (Private)',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppTheme.accentGold : ElegantColors.gold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This is only visible to you and not shown in the family tree.',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isDark ? AppTheme.textMuted : ElegantColors.warmGray,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: spouseController,
                      decoration: InputDecoration(
                        hintText: 'Enter spouse name',
                        hintStyle: TextStyle(color: isDark ? AppTheme.textMuted : ElegantColors.warmGray),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: (isDark ? AppTheme.accentGold : ElegantColors.gold).withOpacity(0.3)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      style: TextStyle(color: isDark ? Colors.white : ElegantColors.charcoal),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancel',
              style: TextStyle(color: isDark ? AppTheme.textMuted : ElegantColors.warmGray),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              // Update person data - store spouse in bio field (private)
              final updatedPerson = person.copyWith(
                firstName: firstNameController.text.trim(),
                lastName: lastNameController.text.trim(),
                bio: spouseController.text.trim().isEmpty ? null : spouseController.text.trim(),
              );
              
              // Call API to update
              final controller = ref.read(treeControllerProvider(widget.familyTreeId).notifier);
              await controller.updatePerson(updatedPerson);
              
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Profile updated successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppTheme.primaryLight : ElegantColors.terracotta,
            ),
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(treeControllerProvider(widget.familyTreeId));
    final controller = ref.read(treeControllerProvider(widget.familyTreeId).notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 768;
    
    // Get current user for filtering
    final authUser = ref.watch(authStateProvider).value;
    final authUserId = authUser?.uid;
    final isSignedIn = authUser != null;
    final isAdmin = ref.watch(isAdminProvider);
    
    // Get linked person for display
    final linkedPerson = _getLinkedPerson(state.persons, authUserId);
    
    // Auto-select linked person and set focus mode on first load
    if (!_initialized && linkedPerson != null && !widget.isDemo) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.selectPerson(linkedPerson.id);
        controller.setLayoutMode(LayoutMode.focus);
        setState(() {
          _linkedPersonId = linkedPerson.id;
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
                        AppTheme.primaryDeep.withOpacity(0.2),
                      ]
                    : [
                        const Color(0xFFF8FAFC),
                        const Color(0xFFECFDF5),
                        AppTheme.accentTeal.withOpacity(0.05),
                      ],
              ),
            ),
          ),
          
          // Main content
          SafeArea(
            child: Column(
              children: [
                // Custom Top Bar with navigation buttons
                _buildTopBar(context, isDark, isMobile, isSignedIn, isAdmin),
                
                // View Mode Toggle (only for authenticated users)
                if (!widget.isDemo && linkedPerson != null && isSignedIn)
                  _buildViewModeToggle(isDark),
                
                // Tree Canvas
                Expanded(
                  child: state.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : state.error != null
                          ? _buildErrorState(context, state.error!)
                          : filteredPersons.isEmpty
                              ? _buildEmptyState(context, controller, ref)
                              : TreeCanvas(
                                  persons: filteredPersons,
                                  selectedPersonId: state.selectedPersonId,
                                  focusedSubtreeRoot: state.focusedSubtreeRoot,
                                  focusedPersonIds: state.focusedPersonIds,
                                  layoutMode: state.layoutMode,
                                  onPersonTapped: (id) {
                                    controller.selectPerson(id);
                                  },
                                  onPersonDoubleTapped: (id) {
                                    final person = filteredPersons.firstWhere((p) => p.id == id);
                                    final spouses = filteredPersons.where((p) => person.relationships.spouseIds.contains(p.id)).toList();
                                    final children = filteredPersons.where((p) => person.relationships.childrenIds.contains(p.id)).toList();
                                    
                                    showDialog(
                                      context: context,
                                      barrierColor: Colors.black.withOpacity(0.5),
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
          
          // Floating Action Buttons at bottom - REMOVED as per request
          // _buildFloatingButtons(context, isDark, isMobile, isSignedIn, isAdmin, controller),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, bool isDark, bool isMobile, bool isSignedIn, bool isAdmin) {
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
              style: GoogleFonts.playfairDisplay(
                fontSize: isMobile ? 20 : 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : ElegantColors.charcoal,
              ),
            ),
          ),
          
          // Theme Toggle
          ThemeToggleIcon(
            color: isDark ? Colors.white : ElegantColors.charcoal,
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

          // Layout mode dropdown
          PopupMenuButton<LayoutMode>(
            icon: Tooltip(
              message: 'Layout',
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.08) : ElegantColors.warmWhite,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.1) : ElegantColors.champagne,
                  ),
                ),
                child: Icon(
                  Icons.view_module_rounded,
                  color: isDark ? Colors.white70 : ElegantColors.charcoal,
                  size: 22,
                ),
              ),
            ),
            offset: const Offset(0, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: isDark ? AppTheme.cardDark : Colors.white,
            onSelected: (mode) {
              final controller = ref.read(treeControllerProvider(widget.familyTreeId).notifier);
              controller.setLayoutMode(mode);
            },
            itemBuilder: (context) => [
              _buildLayoutMenuItem(
                context,
                icon: Icons.account_tree_rounded,
                label: 'Tree View',
                mode: LayoutMode.tree,
                isDark: isDark,
              ),
              _buildLayoutMenuItem(
                context,
                icon: Icons.radio_button_checked_rounded,
                label: 'Radial View',
                mode: LayoutMode.radial,
                isDark: isDark,
              ),
              _buildLayoutMenuItem(
                context,
                icon: Icons.list_rounded,
                label: 'List View',
                mode: LayoutMode.list,
                isDark: isDark,
              ),
              _buildLayoutMenuItem(
                context,
                icon: Icons.center_focus_strong_rounded,
                label: 'Focus View',
                mode: LayoutMode.focus,
                isDark: isDark,
              ),
            ],
          ),
          
          const SizedBox(width: 8),
          
          // Sign In / Profile button
          if (!isSignedIn)
            _buildPillButton(
              label: 'Sign In',
              icon: Icons.login_rounded,
              onTap: () => context.go('/login'),
              isDark: isDark,
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

  Widget _buildViewModeToggle(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark 
            ? Colors.white.withOpacity(0.08) 
            : ElegantColors.warmWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark 
              ? Colors.white.withOpacity(0.1) 
              : ElegantColors.champagne,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildViewModeButton(
            icon: Icons.arrow_downward_rounded,
            label: 'Lineage Tree',
            isSelected: _viewMode == FamilyViewMode.descendants,
            onTap: () => setState(() => _viewMode = FamilyViewMode.descendants),
            isDark: isDark,
          ),
          const SizedBox(width: 4),
          _buildViewModeButton(
            icon: Icons.arrow_upward_rounded,
            label: 'My Lineage',
            isSelected: _viewMode == FamilyViewMode.ancestors,
            onTap: () => setState(() => _viewMode = FamilyViewMode.ancestors),
            isDark: isDark,
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
                      ? Colors.white.withOpacity(0.08) 
                      : ElegantColors.warmWhite,
              borderRadius: BorderRadius.circular(14),
              border: isPrimary 
                  ? null 
                  : Border.all(
                      color: isDark 
                          ? Colors.white.withOpacity(0.1) 
                          : ElegantColors.champagne,
                    ),
              boxShadow: isPrimary 
                  ? [
                      BoxShadow(
                        color: AppTheme.primaryLight.withOpacity(0.3),
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

  Widget _buildPillButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
    bool isPrimary = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: isPrimary ? AppTheme.primaryGradient : null,
            color: isPrimary 
                ? null 
                : isDark 
                    ? Colors.white.withOpacity(0.08) 
                    : ElegantColors.warmWhite,
            borderRadius: BorderRadius.circular(14),
            border: isPrimary 
                ? null 
                : Border.all(
                    color: isDark 
                        ? Colors.white.withOpacity(0.1) 
                        : ElegantColors.champagne,
                  ),
            boxShadow: isPrimary 
                ? [
                    BoxShadow(
                      color: AppTheme.primaryLight.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ] 
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isPrimary 
                    ? Colors.white 
                    : isDark 
                        ? Colors.white70 
                        : ElegantColors.charcoal,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isPrimary 
                      ? Colors.white 
                      : isDark 
                          ? Colors.white70 
                          : ElegantColors.charcoal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  String _getViewTitle() {
    switch (_viewMode) {
      case FamilyViewMode.descendants:
        return 'Lineage Tree';
      case FamilyViewMode.ancestors:
        return 'My Lineage';
      case FamilyViewMode.all:
        return 'Family Tree';
    }
  }
  
  Widget _buildViewModeButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected ? AppTheme.primaryGradient : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected 
              ? [
                  BoxShadow(
                    color: AppTheme.primaryLight.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ] 
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected 
                  ? Colors.white
                  : (isDark ? Colors.white60 : ElegantColors.warmGray),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected 
                    ? Colors.white
                    : (isDark ? Colors.white60 : ElegantColors.warmGray),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show export dialog with multiple format options
  void _showExportDialog(BuildContext context, bool isDark) {
    final familyMembers = ref.read(treeControllerProvider(widget.familyTreeId)).persons;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: ElegantColors.warmGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.download_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Download Family Tree',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : ElegantColors.charcoal,
                    ),
                  ),
                  Text(
                    '${familyMembers.length} members',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : ElegantColors.warmGray,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildExportOption(
                context: context,
                icon: Icons.picture_as_pdf_rounded,
                title: 'Save as PDF',
                subtitle: kIsWeb ? 'Opens in new tab for printing' : 'Share or save PDF',
                color: ElegantColors.terracotta,
                isDark: isDark,
                onTap: () async {
                  Navigator.pop(context);
                  if (kIsWeb) {
                    // Web: open HTML in new tab with print dialog
                    final htmlContent = FamilyExportService.exportAsHtmlTree(familyMembers, "Mamaduu's Lineage");
                    WebDownloadHelper.openAndPrint(htmlContent);
                    _showDownloadSuccess(context, 'Print dialog opened - Select "Save as PDF"');
                  } else {
                    // Mobile: use printing package to share/print PDF
                    _showDownloadSuccess(context, 'Generating PDF...');
                    // A0 landscape: 1189mm x 841mm (in points: 3370 x 2384)
                    const a0Landscape = PdfPageFormat(1189 * PdfPageFormat.mm, 841 * PdfPageFormat.mm);
                    await Printing.layoutPdf(
                      onLayout: (format) async {
                        final doc = pw.Document();
                        doc.addPage(
                          pw.MultiPage(
                            pageFormat: a0Landscape,
                            margin: const pw.EdgeInsets.all(20),
                            build: (context) => [
                              pw.Header(
                                level: 0,
                                child: pw.Text("Mamaduu's Lineage - Family Tree",
                                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                              ),
                              pw.SizedBox(height: 20),
                              pw.Text('Total Members: ${familyMembers.length}'),
                              pw.SizedBox(height: 10),
                              pw.Text('Generated: ${DateTime.now().toString().split('.')[0]}'),
                              pw.SizedBox(height: 30),
                              ...familyMembers.map((p) => pw.Container(
                                margin: const pw.EdgeInsets.only(bottom: 10),
                                padding: const pw.EdgeInsets.all(10),
                                decoration: pw.BoxDecoration(
                                  border: pw.Border.all(color: PdfColors.amber),
                                  borderRadius: pw.BorderRadius.circular(8),
                                ),
                                child: pw.Row(
                                  children: [
                                    pw.Container(
                                      width: 40,
                                      height: 40,
                                      decoration: pw.BoxDecoration(
                                        color: PdfColors.amber,
                                        shape: pw.BoxShape.circle,
                                      ),
                                      child: pw.Center(
                                        child: pw.Text(p.firstName[0].toUpperCase(),
                                          style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
                                      ),
                                    ),
                                    pw.SizedBox(width: 15),
                                    pw.Expanded(
                                      child: pw.Column(
                                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                                        children: [
                                          pw.Text(p.fullName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                                          pw.Text('${p.gender == 'male' || p.gender == 'Male' ? '♂ Male' : '♀ Female'}'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )),
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
                    FamilyExportService.exportAsMemberList(familyMembers, "Mamaduu's Lineage"),
                    'family_members.html',
                    'text/html',
                  );
                  _showDownloadSuccess(context, 'Member Directory');
                },
              ),
              const SizedBox(height: 12),
              _buildExportOption(
                context: context,
                icon: Icons.code_rounded,
                title: 'JSON Data',
                subtitle: 'Complete data for developers',
                color: AppTheme.accentTeal,
                isDark: isDark,
                onTap: () {
                  Navigator.pop(context);
                  _downloadFile(
                    FamilyExportService.exportAsJson(familyMembers),
                    'family_tree.json',
                    'application/json',
                  );
                  _showDownloadSuccess(context, 'JSON Data');
                },
              ),
              const SizedBox(height: 12),
              _buildExportOption(
                context: context,
                icon: Icons.table_chart_rounded,
                title: 'CSV Spreadsheet',
                subtitle: 'Open in Excel or Google Sheets',
                color: ElegantColors.gold,
                isDark: isDark,
                onTap: () {
                  Navigator.pop(context);
                  _downloadFile(
                    FamilyExportService.exportAsCsv(familyMembers),
                    'family_tree.csv',
                    'text/csv',
                  );
                  _showDownloadSuccess(context, 'CSV File');
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
              style: TextStyle(color: isDark ? Colors.white54 : ElegantColors.warmGray),
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
            color: isDark ? Colors.white.withOpacity(0.05) : color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.1) : color.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(isDark ? 0.2 : 0.15),
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
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : ElegantColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : ElegantColors.warmGray,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: isDark ? Colors.white38 : ElegantColors.warmGray,
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

  Widget _buildProfileSidebar(BuildContext context, bool isDark) {
    final authUser = ref.watch(authStateProvider).value;
    final isAdmin = ref.watch(userRoleProvider).value?.isAdmin ?? false;
    final familyMembers = ref.watch(treeControllerProvider(widget.familyTreeId)).persons;
    
    // Check if user is linked to a family member
    final linkedPerson = _getLinkedPerson(familyMembers, authUser?.uid);
    final isLinked = linkedPerson != null;
    
    // Calculate stats
    final generations = _calculateGenerations(familyMembers);
    final descendants = familyMembers.length;
    
    return Drawer(
      width: 320,
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.backgroundDark,
                    AppTheme.primaryDeep.withValues(alpha: 0.3),
                  ],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    ElegantColors.warmWhite,
                    ElegantColors.cream,
                  ],
                ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(-5, 0),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header with close button
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Text(
                      'Profile',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : ElegantColors.charcoal,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        color: isDark ? Colors.white70 : ElegantColors.warmGray,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Profile section
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: isDark ? AppTheme.primaryGradient : ElegantColors.warmGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: (isDark ? AppTheme.primaryLight : ElegantColors.terracotta).withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Avatar with photo upload
                    GestureDetector(
                      onTap: () => _showPhotoUploadOptions(context, isDark),
                      child: Stack(
                        children: [
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.2),
                              border: Border.all(color: Colors.white, width: 2),
                              image: authUser?.photoURL != null
                                  ? DecorationImage(
                                      image: NetworkImage(authUser!.photoURL!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: authUser?.photoURL == null
                                ? const Icon(Icons.person_rounded, color: Colors.white, size: 35)
                                : null,
                          ),
                          // Camera icon overlay
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.primaryLight : ElegantColors.terracotta,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      authUser?.displayName ?? authUser?.email?.split('@').first ?? 'User',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      authUser?.email ?? '',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Stats row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSidebarStat(
                        icon: Icons.account_tree_rounded,
                        value: '$generations',
                        label: 'Generations',
                        color: isDark ? AppTheme.primaryLight : ElegantColors.sage,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSidebarStat(
                        icon: Icons.people_alt_rounded,
                        value: '$descendants',
                        label: 'Members',
                        color: isDark ? AppTheme.accentGold : ElegantColors.gold,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Quick actions
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick Actions',
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white60 : ElegantColors.warmGray,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildSidebarAction(
                        icon: Icons.groups_rounded,
                        label: 'Family Group',
                        subtitle: 'Chat & events',
                        color: ElegantColors.sage,
                        isDark: isDark,
                        onTap: () {
                          Navigator.pop(context);
                          context.go('/group');
                        },
                      ),
                      if (isAdmin) ...[
                        const SizedBox(height: 8),
                        _buildSidebarAction(
                          icon: Icons.admin_panel_settings_rounded,
                          label: 'Admin Panel',
                          subtitle: 'Manage family tree',
                          color: ElegantColors.gold,
                          isDark: isDark,
                          onTap: () {
                            Navigator.pop(context);
                            context.go('/admin');
                          },
                        ),
                      ],
                      const SizedBox(height: 8),
                      // Show Edit Profile if linked, otherwise show Link Profile
                      if (isLinked)
                        _buildSidebarAction(
                          icon: Icons.edit_rounded,
                          label: 'Edit My Profile',
                          subtitle: 'Update your info & spouse',
                          color: isDark ? AppTheme.accentTeal : ElegantColors.sage,
                          isDark: isDark,
                          onTap: () {
                            Navigator.pop(context);
                            _showEditProfileDialog(context, linkedPerson!, isDark);
                          },
                        ),
                      // Link Profile - commented out for now
                      // else
                      //   _buildSidebarAction(
                      //     icon: Icons.link_rounded,
                      //     label: 'Link Profile',
                      //     subtitle: 'Connect to family member',
                      //     color: isDark ? AppTheme.primaryLight : ElegantColors.terracotta,
                      //     isDark: isDark,
                      //     onTap: () {
                      //       Navigator.pop(context);
                      //       context.go('/group?tab=3'); // Go to Members tab with linking
                      //     },
                      //   ),
                    ],
                  ),
                ),
              ),
              
              // Sign out button
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final authController = ref.read(authControllerProvider.notifier);
                      await authController.signOut();
                      if (context.mounted) {
                        Navigator.pop(context);
                        context.go('/');
                      }
                    },
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Sign Out'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade400,
                      side: BorderSide(color: Colors.red.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _calculateGenerations(List<Person> members) {
    if (members.isEmpty) return 0;
    final roots = members.where((p) => p.relationships.parentIds.isEmpty).toList();
    if (roots.isEmpty) return 1;
    int maxDepth = 0;
    for (final root in roots) {
      final depth = _getPersonDepth(root.id, members, {});
      if (depth > maxDepth) maxDepth = depth;
    }
    return maxDepth;
  }

  int _getPersonDepth(String personId, List<Person> members, Set<String> visited) {
    if (visited.contains(personId)) return 0;
    visited.add(personId);
    final person = members.firstWhere((p) => p.id == personId, orElse: () => members.first);
    if (person.relationships.childrenIds.isEmpty) return 1;
    int maxChildDepth = 0;
    for (final childId in person.relationships.childrenIds) {
      final childDepth = _getPersonDepth(childId, members, visited);
      if (childDepth > maxChildDepth) maxChildDepth = childDepth;
    }
    return maxChildDepth + 1;
  }

  Widget _buildSidebarStat({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : ElegantColors.warmWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : ElegantColors.champagne,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
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
              fontSize: 12,
              color: isDark ? Colors.white60 : ElegantColors.warmGray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarAction({
    required IconData icon,
    required String label,
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
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : ElegantColors.warmWhite,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.1) : ElegantColors.champagne,
            ),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : ElegantColors.charcoal,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : ElegantColors.warmGray,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? Colors.white30 : ElegantColors.warmGray,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return _buildSidebarAction(
      icon: icon,
      label: label,
      subtitle: '',
      color: AppTheme.primaryLight,
      isDark: isDark,
      onTap: onTap,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
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
              color: isDark ? Colors.white54 : ElegantColors.warmGray,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No family members yet',
            style: GoogleFonts.playfairDisplay(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : ElegantColors.charcoal,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'The family tree is empty.\nUse the Admin Panel to add members.',
            style: GoogleFonts.inter(
              fontSize: 15,
              color: isDark ? Colors.white60 : ElegantColors.warmGray,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  PopupMenuItem<LayoutMode> _buildLayoutMenuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required LayoutMode mode,
    required bool isDark,
  }) {
    return PopupMenuItem<LayoutMode>(
      value: mode,
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isDark ? Colors.white70 : ElegantColors.charcoal,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : ElegantColors.charcoal,
            ),
          ),
        ],
      ),
    );
  }
}
