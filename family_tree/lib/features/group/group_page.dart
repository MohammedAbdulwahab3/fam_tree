
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/core/theme/elegant_theme.dart';
import 'package:family_tree/core/utils/platform_image_picker.dart';
import 'package:family_tree/data/models/post.dart';
import 'package:family_tree/data/models/appointment.dart';
import 'package:family_tree/data/repositories/group_repository.dart';
import 'package:family_tree/data/services/storage_service.dart';
import 'package:family_tree/features/auth/providers/auth_provider.dart';
import 'package:family_tree/features/group/tabs/feed_tab.dart';
import 'package:family_tree/features/group/tabs/chat_tab.dart';
import 'package:family_tree/features/group/tabs/events_tab.dart';
import 'package:family_tree/features/group/tabs/members_tab.dart';
import 'package:family_tree/core/widgets/theme_toggle_button.dart';
import 'package:family_tree/providers/admin_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:family_tree/features/maps/location_picker_dialog.dart';

/// Main family group page with tabs for feed, chat, and events
class GroupPage extends ConsumerStatefulWidget {
  const GroupPage({Key? key}) : super(key: key);

  @override
  ConsumerState<GroupPage> createState() => _GroupPageState();
}

class _GroupPageState extends ConsumerState<GroupPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentIndex = 0;
  int _webCenterView = 0; // 0 = Feed, 1 = Chat for web layout

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentIndex = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : ElegantColors.cream,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: isDark ? null : ElegantColors.cream,
              gradient: isDark
                  ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppTheme.backgroundDark,
                        AppTheme.primaryDeep.withOpacity(0.15),
                        AppTheme.backgroundDark,
                      ],
                    )
                  : null,
            ),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 900;
                  
                  if (isWide) {
                    return _buildWebLayout(user, isDark, constraints);
                  } else {
                    return _buildMobileLayout(user, isDark);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Beautiful web layout with sidebar panels
  Widget _buildWebLayout(dynamic user, bool isDark, BoxConstraints constraints) {
    return Row(
      children: [
        // Left Sidebar - Members & Navigation
        Container(
          width: 280,
          decoration: BoxDecoration(
            color: isDark ? AppTheme.surfaceDark : ElegantColors.warmWhite,
            border: Border(
              right: BorderSide(
                color: isDark ? Colors.white10 : ElegantColors.champagne,
              ),
            ),
          ),
          child: Column(
            children: [
              // Left Sidebar Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? Colors.white10 : ElegantColors.champagne,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: isDark ? AppTheme.primaryGradient : ElegantColors.warmGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.people_alt_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Family Members',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : ElegantColors.charcoal,
                            ),
                          ),
                          Text(
                            'Your loved ones',
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: 13,
                              color: isDark ? Colors.white60 : ElegantColors.warmGray,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Members List
              Expanded(
                child: MembersTab(isDark: isDark),
              ),
            ],
          ),
        ),
        
        // Center - Main Content (Feed)
        Expanded(
          flex: 2,
          child: Column(
            children: [
              // Center Header
              _buildWebCenterHeader(user, isDark),
              
              // Main Content - Feed or Chat
              Expanded(
                child: _webCenterView == 0 
                    ? FeedTab(isDark: isDark)
                    : ChatTab(isDark: isDark),
              ),
            ],
          ),
        ),
        
        // Right Sidebar - Events & Chat
        Container(
          width: 320,
          decoration: BoxDecoration(
            color: isDark ? AppTheme.surfaceDark : ElegantColors.warmWhite,
            border: Border(
              left: BorderSide(
                color: isDark ? Colors.white10 : ElegantColors.champagne,
              ),
            ),
          ),
          child: Column(
            children: [
              // Events Section Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? Colors.white10 : ElegantColors.champagne,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: isDark 
                            ? const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)])
                            : ElegantColors.sageGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.event_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Upcoming Events',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : ElegantColors.charcoal,
                            ),
                          ),
                          Text(
                            'Family gatherings',
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: 13,
                              color: isDark ? Colors.white60 : ElegantColors.warmGray,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Events List
              Expanded(
                child: EventsTab(isDark: isDark),
              ),
              
              // Chat Section
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: isDark ? Colors.white10 : ElegantColors.champagne,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    // Chat Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark 
                                  ? AppTheme.primaryLight.withOpacity(0.2)
                                  : ElegantColors.softBlue.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.chat_bubble_rounded, 
                              color: isDark ? AppTheme.primaryLight : ElegantColors.softBlue,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Family Chat',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : ElegantColors.charcoal,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _webCenterView = _webCenterView == 1 ? 0 : 1;
                              });
                            },
                            child: Text(
                              _webCenterView == 1 ? 'Feed' : 'Open',
                              style: GoogleFonts.cormorantGaramond(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppTheme.primaryLight : ElegantColors.terracotta,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Chat Preview
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.forum_rounded,
                                size: 40,
                                color: isDark ? Colors.white24 : ElegantColors.champagne,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Click "Open" to join chat',
                                style: GoogleFonts.cormorantGaramond(
                                  fontSize: 13,
                                  color: isDark ? Colors.white38 : ElegantColors.warmGray,
                                ),
                              ),
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
        ),
      ],
    );
  }
  
  /// Web center header with title and user avatar
  Widget _buildWebCenterHeader(dynamic user, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white10 : ElegantColors.champagne,
          ),
        ),
      ),
      child: Row(
        children: [
          // Back button
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: isDark 
                  ? Colors.white.withOpacity(0.1)
                  : ElegantColors.cream,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white10 : ElegantColors.champagne,
              ),
            ),
            child: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new,
                color: isDark ? Colors.white : ElegantColors.charcoal,
                size: 18,
              ),
              onPressed: () => context.go('/tree'),
            ),
          ),
          
          // Title section
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: isDark ? AppTheme.primaryGradient : ElegantColors.warmGradient,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'FAMILY',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Group Feed',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : ElegantColors.charcoal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Share moments, celebrate milestones, stay connected',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 15,
                    color: isDark ? Colors.white60 : ElegantColors.warmGray,
                  ),
                ),
              ],
            ),
          ),
          
          // Navigation menu
          PopupMenuButton<String>(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark 
                    ? Colors.white.withOpacity(0.1)
                    : ElegantColors.cream,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.menu,
                color: isDark ? Colors.white : ElegantColors.charcoal,
                size: 20,
              ),
            ),
            tooltip: 'Navigate',
            color: isDark ? AppTheme.surfaceDark : ElegantColors.warmWhite,
            onSelected: (route) => context.go(route),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: '/dashboard',
                child: Row(
                  children: [
                    Icon(Icons.dashboard, color: isDark ? Colors.white : ElegantColors.charcoal),
                    const SizedBox(width: 8),
                    Text('Dashboard', style: TextStyle(color: isDark ? Colors.white : ElegantColors.charcoal)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: '/tree',
                child: Row(
                  children: [
                    Icon(Icons.account_tree, color: isDark ? Colors.white : ElegantColors.charcoal),
                    const SizedBox(width: 8),
                    Text('Family Tree', style: TextStyle(color: isDark ? Colors.white : ElegantColors.charcoal)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: '/',
                child: Row(
                  children: [
                    Icon(Icons.explore, color: isDark ? Colors.white : ElegantColors.charcoal),
                    const SizedBox(width: 8),
                    Text('Landing Page', style: TextStyle(color: isDark ? Colors.white : ElegantColors.charcoal)),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(width: 12),
          
          // Theme Toggle
          ThemeToggleIcon(
            color: isDark ? Colors.white : ElegantColors.charcoal,
          ),
          const SizedBox(width: 12),
          
          // User avatar
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: isDark ? AppTheme.primaryGradient : ElegantColors.warmGradient,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: isDark 
                      ? AppTheme.primaryLight.withOpacity(0.3)
                      : ElegantColors.terracotta.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: user?.photoURL != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: Image.network(user!.photoURL!, fit: BoxFit.cover),
                  )
                : Center(
                    child: Text(
                      user?.displayName?.isNotEmpty == true 
                          ? user!.displayName![0].toUpperCase() 
                          : '?',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
  
  /// Mobile layout with tabs
  Widget _buildMobileLayout(dynamic user, bool isDark) {
    return Column(
      children: [
        // Beautiful Header
        _buildHeader(user, isDark),

        // Beautiful Tab Bar
        _buildTabBar(isDark),

        const SizedBox(height: 12),

        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              FeedTab(isDark: isDark),
              ChatTab(isDark: isDark),
              EventsTab(isDark: isDark),
              MembersTab(isDark: isDark),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildHeader(dynamic user, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 16, 16),
      child: Row(
        children: [
          // Back button
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: isDark 
                  ? AppTheme.surfaceDark.withOpacity(0.5)
                  : ElegantColors.warmWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark 
                    ? AppTheme.primaryLight.withOpacity(0.2)
                    : ElegantColors.champagne,
              ),
              boxShadow: isDark ? null : [
                BoxShadow(
                  color: ElegantColors.sienna.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new, 
                color: isDark ? AppTheme.textPrimary : ElegantColors.charcoal, 
                size: 20,
              ),
              onPressed: () => context.go('/tree'),
            ),
          ),
          
          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Family Group',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : ElegantColors.charcoal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Stay connected with your loved ones',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 14,
                    color: isDark ? AppTheme.textMuted : ElegantColors.warmGray,
                  ),
                ),
              ],
            ),
          ),
          
          // User avatar
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: isDark ? AppTheme.primaryGradient : ElegantColors.warmGradient,
              borderRadius: BorderRadius.circular(23),
              boxShadow: [
                BoxShadow(
                  color: isDark 
                      ? AppTheme.primaryLight.withOpacity(0.3)
                      : ElegantColors.terracotta.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: user?.photoURL != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(23),
                    child: Image.network(user!.photoURL!, fit: BoxFit.cover),
                  )
                : Center(
                    child: Text(
                      user?.displayName?.isNotEmpty == true 
                          ? user!.displayName![0].toUpperCase() 
                          : '?',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTabBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark 
            ? AppTheme.surfaceDark.withOpacity(0.6)
            : ElegantColors.warmWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark 
              ? AppTheme.primaryLight.withOpacity(0.1)
              : ElegantColors.champagne,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark 
                ? Colors.black.withOpacity(0.2)
                : ElegantColors.sienna.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: isDark ? AppTheme.primaryGradient : ElegantColors.warmGradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: isDark 
                  ? AppTheme.primaryLight.withOpacity(0.4)
                  : ElegantColors.terracotta.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: isDark ? AppTheme.textMuted : ElegantColors.warmGray,
        labelStyle: GoogleFonts.cormorantGaramond(
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: GoogleFonts.cormorantGaramond(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        tabs: [
          _buildTab(Icons.dynamic_feed_rounded, 'Feed', 0, isDark),
          _buildTab(Icons.chat_bubble_rounded, 'Chat', 1, isDark),
          _buildTab(Icons.event_rounded, 'Events', 2, isDark),
          // Members tab - commented out for now
          // _buildTab(Icons.people_rounded, 'Members', 3, isDark),
        ],
      ),
    );
  }

  Widget _buildTab(IconData icon, String label, int index, bool isDark) {
    final isSelected = _currentIndex == index;
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          if (isSelected) ...[
            const SizedBox(width: 6),
            Text(label),
          ],
        ],
      ),
    );
  }

  Widget _buildFAB(bool isDark) {
    // Check if user is admin - only admins can create posts and events
    final userRole = ref.watch(userRoleProvider);
    final isAdmin = userRole.value?.isAdmin ?? false;

    // Non-admins don't see create buttons for posts and events
    if (!isAdmin && (_currentIndex == 0 || _currentIndex == 2)) {
      return const SizedBox.shrink();
    }

    IconData icon;
    String tooltip;
    VoidCallback onPressed;

    switch (_currentIndex) {
      case 0: // Feed - Admin only
        icon = Icons.add;
        tooltip = 'New Post';
        onPressed = () => _showAddPostDialog(isDark);
        break;
      case 1: // Chat
        return const SizedBox.shrink(); // No FAB for chat
      case 2: // Events - Admin only
        icon = Icons.event;
        tooltip = 'New Event';
        onPressed = () => _showAddEventDialog(isDark);
        break;
      case 3: // Members
        return const SizedBox.shrink(); // No FAB for members
      default:
        return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        gradient: isDark ? AppTheme.primaryGradient : ElegantColors.warmGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: isDark 
                ? AppTheme.primaryLight.withOpacity(0.4)
                : ElegantColors.terracotta.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: onPressed,
        tooltip: tooltip,
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Icon(icon, color: Colors.white),
      ),
    );
  }

  void _showAddPostDialog(bool isDark) {
    final TextEditingController contentController = TextEditingController();
    final PlatformImagePicker picker = PlatformImagePicker();
    final StorageService storageService = StorageService();
    
    List<PickedFile> selectedImages = [];
    List<PickedFile> selectedVideos = [];
    bool isUploading = false;
    bool isPickingMedia = false;

    showDialog(
      context: context,
      barrierDismissible: !isUploading, // Prevent dismissing during upload
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (builderContext, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? AppTheme.surfaceDark : ElegantColors.warmWhite,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                'New Post',
                style: GoogleFonts.playfairDisplay(
                  color: isDark ? AppTheme.textPrimary : ElegantColors.charcoal,
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    TextField(
                      controller: contentController,
                      maxLines: 5,
                      enabled: !isUploading && !isPickingMedia,
                      decoration: InputDecoration(
                        hintText: 'What\'s on your mind?',
                        hintStyle: GoogleFonts.cormorantGaramond(
                          color: isDark ? AppTheme.textMuted : ElegantColors.warmGray,
                        ),
                        filled: true,
                        fillColor: isDark ? AppTheme.backgroundDark : ElegantColors.cream,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 16,
                        color: isDark ? AppTheme.textPrimary : ElegantColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceMd),
                    
                    // Media Previews
                    if (selectedImages.isNotEmpty || selectedVideos.isNotEmpty)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 120),
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          shrinkWrap: true,
                          children: [
                            ...selectedImages.map((file) => Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(
                                      file.bytes,
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          width: 100,
                                          height: 100,
                                          color: AppTheme.surfaceDark,
                                          child: const Icon(Icons.error, color: AppTheme.error),
                                        );
                                      },
                                    ),
                                  ),
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: GestureDetector(
                                      onTap: isUploading || isPickingMedia ? null : () {
                                        if (builderContext.mounted) {
                                          setDialogState(() => selectedImages.remove(file));
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(Icons.close, color: Colors.white, size: 18),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                            ...selectedVideos.map((file) => Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Stack(
                                children: [
                                  Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Center(child: Icon(Icons.videocam, color: Colors.white)),
                                  ),
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: GestureDetector(
                                      onTap: isUploading || isPickingMedia ? null : () {
                                        if (builderContext.mounted) {
                                          setDialogState(() => selectedVideos.remove(file));
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(Icons.close, color: Colors.white, size: 18),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                          ],
                        ),
                      ),
                    
                    const SizedBox(height: AppTheme.spaceSm),
                    
                    // Media Buttons
                    Row(
                      children: [
                        IconButton(
                          icon: isPickingMedia 
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryLight),
                                )
                              : const Icon(Icons.photo_library, color: AppTheme.primaryLight),
                          onPressed: (isUploading || isPickingMedia) ? null : () async {
                            try {
                              if (builderContext.mounted) {
                                setDialogState(() => isPickingMedia = true);
                              }
                              
                              await Future.delayed(const Duration(milliseconds: 50));
                              
                              final List<PickedFile> images = await picker.pickMultipleImages(imageQuality: 70);
                              
                              if (builderContext.mounted) {
                                setDialogState(() {
                                  isPickingMedia = false;
                                  if (images.isNotEmpty) {
                                    selectedImages.addAll(images);
                                  }
                                });
                              }
                            } catch (e) {
                              print('Error picking images: $e');
                              if (builderContext.mounted) {
                                setDialogState(() => isPickingMedia = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to pick images: ${e.toString()}'),
                                    backgroundColor: AppTheme.error,
                                  ),
                                );
                              }
                            }
                          },
                          tooltip: isPickingMedia ? 'Selecting...' : 'Add Photos',
                        ),
                        IconButton(
                          icon: const Icon(Icons.video_library, color: AppTheme.primaryLight),
                          onPressed: (isUploading || isPickingMedia) ? null : () async {
                            try {
                              if (builderContext.mounted) {
                                setDialogState(() => isPickingMedia = true);
                              }
                              
                              await Future.delayed(const Duration(milliseconds: 50));
                              
                              final PickedFile? video = await picker.pickVideo();
                              
                              if (builderContext.mounted) {
                                setDialogState(() {
                                  isPickingMedia = false;
                                  if (video != null) {
                                    selectedVideos.add(video);
                                  }
                                });
                              }
                            } catch (e) {
                              print('Error picking video: $e');
                              if (builderContext.mounted) {
                                setDialogState(() => isPickingMedia = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to pick video: ${e.toString()}'),
                                    backgroundColor: AppTheme.error,
                                  ),
                                );
                              }
                            }
                          },
                          tooltip: 'Add Video',
                        ),
                        IconButton(
                          icon: const Icon(Icons.camera_alt, color: AppTheme.primaryLight),
                          onPressed: (kIsWeb || isUploading || isPickingMedia) ? null : () async {
                            try {
                              if (builderContext.mounted) {
                                setDialogState(() => isPickingMedia = true);
                              }
                              
                              await Future.delayed(const Duration(milliseconds: 50));
                              
                              final PickedFile? photo = await picker.pickImageFromCamera(imageQuality: 70);
                              
                              if (builderContext.mounted) {
                                setDialogState(() {
                                  isPickingMedia = false;
                                  if (photo != null) {
                                    selectedImages.add(photo);
                                  }
                                });
                              }
                            } catch (e) {
                              print('Error taking photo: $e');
                              if (builderContext.mounted) {
                                setDialogState(() => isPickingMedia = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to take photo: ${e.toString()}'),
                                    backgroundColor: AppTheme.error,
                                  ),
                                );
                              }
                            }
                          },
                          tooltip: kIsWeb ? 'Not available on web' : 'Take Photo',
                        ),
                      ],
                    ),
                    
                    if (isPickingMedia)
                      Padding(
                        padding: const EdgeInsets.only(top: AppTheme.spaceSm),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Selecting media...',
                              style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    
                    if (isUploading)
                      Padding(
                        padding: const EdgeInsets.only(top: AppTheme.spaceSm),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const LinearProgressIndicator(),
                            const SizedBox(height: 4),
                            Text(
                              'Uploading media and creating post...',
                              style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: (isUploading || isPickingMedia) ? null : () => Navigator.pop(dialogContext),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(color: AppTheme.textMuted),
                  ),
                ),
                ElevatedButton(
                  onPressed: (isUploading || isPickingMedia) ? null : () async {
                    final content = contentController.text.trim();
                    if (content.isEmpty && selectedImages.isEmpty && selectedVideos.isEmpty) return;

                    if (builderContext.mounted) {
                      setDialogState(() => isUploading = true);
                    }

                    try {
                      final user = ref.read(authStateProvider).value;
                      if (user == null) {
                        throw Exception('Not logged in');
                      }

                      // Upload media
                      List<String> photoUrls = [];
                      List<String> videoUrls = [];

                      for (var image in selectedImages) {
                        final url = await storageService.uploadImage(image.name, image.bytes);
                        if (url != null) {
                          photoUrls.add(url);
                        } else {
                          print('Failed to upload image: ${image.name}');
                        }
                      }

                      for (var video in selectedVideos) {
                        final url = await storageService.uploadVideo(video.name, video.bytes);
                        if (url != null) {
                          videoUrls.add(url);
                        } else {
                          print('Failed to upload video: ${video.name}');
                        }
                      }

                      final post = Post(
                        id: '',
                        familyTreeId: 'main-family-tree',
                        userId: user.uid,
                        userName: user.displayName ?? 'Anonymous',
                        userPhoto: user.photoURL,
                        content: content,
                        photos: photoUrls,
                        videos: videoUrls,
                        createdAt: DateTime.now(),
                      );

                      final repository = GroupRepository();
                      await repository.addPost(post);

                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                      
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Post created successfully!'),
                            backgroundColor: AppTheme.success,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    } catch (e) {
                      print('Error creating post: $e');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error creating post: ${e.toString()}'),
                            backgroundColor: AppTheme.error,
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      }
                    } finally {
                      if (builderContext.mounted) {
                        setDialogState(() => isUploading = false);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryLight,
                  ),
                  child: isUploading 
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Post'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddEventDialog(bool isDark) {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    final TextEditingController locationController = TextEditingController();
    final TextEditingController mapLinkController = TextEditingController();
    DateTime selectedDateTime = DateTime.now().add(const Duration(days: 1));

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: isDark ? AppTheme.surfaceDark : ElegantColors.warmWhite,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                'New Event',
                style: GoogleFonts.playfairDisplay(
                  color: isDark ? AppTheme.textPrimary : ElegantColors.charcoal,
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Title',
                        labelStyle: GoogleFonts.cormorantGaramond(
                          color: isDark ? AppTheme.textSecondary : ElegantColors.warmGray,
                        ),
                        hintText: 'Family Reunion',
                        hintStyle: GoogleFonts.cormorantGaramond(
                          color: isDark ? AppTheme.textMuted : ElegantColors.warmGray,
                        ),
                        filled: true,
                        fillColor: isDark ? AppTheme.backgroundDark : ElegantColors.cream,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 16,
                        color: isDark ? AppTheme.textPrimary : ElegantColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceMd),

                    // Description
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Description (optional)',
                        labelStyle: GoogleFonts.cormorantGaramond(
                          color: isDark ? AppTheme.textSecondary : ElegantColors.warmGray,
                        ),
                        hintText: 'Event details...',
                        hintStyle: GoogleFonts.cormorantGaramond(
                          color: isDark ? AppTheme.textMuted : ElegantColors.warmGray,
                        ),
                        filled: true,
                        fillColor: isDark ? AppTheme.backgroundDark : ElegantColors.cream,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 16,
                        color: isDark ? AppTheme.textPrimary : ElegantColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceMd),

                    // Location
                    TextField(
                      controller: locationController,
                      decoration: InputDecoration(
                        labelText: 'Location (optional)',
                        labelStyle: GoogleFonts.cormorantGaramond(
                          color: isDark ? AppTheme.textSecondary : ElegantColors.warmGray,
                        ),
                        hintText: 'Grandma\'s house',
                        hintStyle: GoogleFonts.cormorantGaramond(
                          color: isDark ? AppTheme.textMuted : ElegantColors.warmGray,
                        ),
                        filled: true,
                        fillColor: isDark ? AppTheme.backgroundDark : ElegantColors.cream,
                        prefixIcon: Icon(
                          Icons.location_on, 
                          color: isDark ? AppTheme.accentCyan : ElegantColors.terracotta,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 16,
                        color: isDark ? AppTheme.textPrimary : ElegantColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceMd),

                    // Map Link
                    TextField(
                      controller: mapLinkController,
                      decoration: InputDecoration(
                        labelText: 'Google Maps Link (Optional)',
                        labelStyle: GoogleFonts.cormorantGaramond(
                          color: isDark ? AppTheme.textSecondary : ElegantColors.warmGray,
                        ),
                        hintText: 'https://maps.google.com/...',
                        hintStyle: GoogleFonts.cormorantGaramond(
                          color: isDark ? AppTheme.textMuted : ElegantColors.warmGray,
                        ),
                        filled: true,
                        fillColor: isDark ? AppTheme.backgroundDark : ElegantColors.cream,
                        prefixIcon: Icon(
                          Icons.map, 
                          color: isDark ? AppTheme.accentCyan : ElegantColors.terracotta,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            Icons.location_on,
                            color: isDark ? AppTheme.accentCyan : ElegantColors.terracotta,
                          ),
                          tooltip: 'Pick on Map',
                          onPressed: () async {
                            final link = await showDialog<String>(
                              context: context,
                              builder: (context) => const LocationPickerDialog(),
                            );
                            if (link != null) {
                              mapLinkController.text = link;
                            }
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 16,
                        color: isDark ? AppTheme.textPrimary : ElegantColors.charcoal,
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: AppTheme.spaceMd),

                    // Date/Time Picker
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedDateTime,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(selectedDateTime),
                            );
                            if (time != null) {
                              setState(() {
                                selectedDateTime = DateTime(
                                  date.year,
                                  date.month,
                                  date.day,
                                  time.hour,
                                  time.minute,
                                );
                              });
                            }
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.backgroundDark : ElegantColors.cream,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today, 
                                color: isDark ? AppTheme.primaryLight : ElegantColors.terracotta,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '${selectedDateTime.day}/${selectedDateTime.month}/${selectedDateTime.year} at ${selectedDateTime.hour}:${selectedDateTime.minute.toString().padLeft(2, '0')}',
                                  style: GoogleFonts.cormorantGaramond(
                                    fontSize: 16,
                                    color: isDark ? AppTheme.textPrimary : ElegantColors.charcoal,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.edit, 
                                color: isDark ? AppTheme.textMuted : ElegantColors.warmGray, 
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.cormorantGaramond(
                      color: isDark ? AppTheme.textMuted : ElegantColors.warmGray,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    if (title.isEmpty) return;

                    final user = ref.read(authStateProvider).value;
                    if (user == null) return;

                    final appointment = Appointment(
                      id: '',
                      familyTreeId: 'main-family-tree',
                      title: title,
                      description: descriptionController.text.trim().isNotEmpty
                          ? descriptionController.text.trim()
                          : null,
                      location: locationController.text.trim(),
                      mapLink: mapLinkController.text.isEmpty ? null : mapLinkController.text.trim(),
                      dateTime: selectedDateTime,
                      createdBy: user.uid,
                      attendees: [user.uid], // Creator auto-joins
                    );

                    final repository = GroupRepository();
                    await repository.addAppointment(appointment);

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Event created!'),
                          backgroundColor: isDark ? AppTheme.success : ElegantColors.sage,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppTheme.primaryLight : ElegantColors.terracotta,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    'Create',
                    style: GoogleFonts.cormorantGaramond(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
