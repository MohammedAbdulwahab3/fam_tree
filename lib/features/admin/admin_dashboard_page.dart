import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/core/theme/elegant_theme.dart';
import 'package:family_tree/data/models/person.dart';
import 'package:family_tree/data/models/post.dart';
import 'package:family_tree/data/models/appointment.dart';
import 'package:family_tree/data/models/app_user.dart';
import 'package:family_tree/data/repositories/person_repository.dart';
import 'package:family_tree/data/repositories/group_repository.dart';
import 'package:family_tree/data/repositories/admin_repository.dart';
import 'package:family_tree/features/auth/providers/auth_provider.dart';
import 'package:family_tree/providers/admin_provider.dart';
import 'package:family_tree/features/edit/add_person_dialog.dart';
import 'package:family_tree/features/maps/location_picker_dialog.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:family_tree/data/services/storage_service.dart';
import 'dart:typed_data';
import 'package:url_launcher/url_launcher.dart';

import 'package:family_tree/features/admin/admin_family_artboard.dart';

/// Admin Dashboard with full management capabilities
class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({Key? key}) : super(key: key);

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage>
    with TickerProviderStateMixin {
  final PersonRepository _personRepo = PersonRepository();
  final GroupRepository _groupRepo = GroupRepository();
  final AdminRepository _adminRepo = AdminRepository();

  late TabController _tabController;
  
  List<Person> _persons = [];
  List<Post> _posts = [];
  List<Appointment> _events = [];
  List<AppUser> _users = [];
  
  bool _isLoading = true;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      setState(() => _selectedTab = _tabController.index);
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final persons = await _personRepo.getFamilyMembers('main-family-tree');
      final posts = await _groupRepo.getPosts();
      final events = await _groupRepo.getEvents();
      final users = await _adminRepo.getUsers();

      setState(() {
        _persons = persons;
        _posts = posts;
        _events = events;
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: isDark ? null : ElegantColors.cream,
              gradient: isDark
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF0D1117),
                        const Color(0xFF161B22),
                        AppTheme.primaryDeep.withOpacity(0.2),
                      ],
                    )
                  : null,
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Header
                  _buildHeader(user, isDark),
                  
                  // Stats Row
                  if (!_isLoading) _buildStatsRow(isDark),
                  
                  // Tab Bar
                  _buildTabBar(isDark),
                  
                  // Content
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : TabBarView(
                            controller: _tabController,
                            children: [
                              _buildOverviewTab(isDark),
                              _buildTreeManagementTab(isDark),
                              _buildFeedManagementTab(isDark),
                              _buildEventsManagementTab(isDark),
                              _buildUsersManagementTab(isDark),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(dynamic user, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Back button
          Container(
            decoration: BoxDecoration(
              color: isDark 
                  ? Colors.white.withOpacity(0.1) 
                  : ElegantColors.warmWhite,
              borderRadius: BorderRadius.circular(12),
              border: isDark ? null : Border.all(color: ElegantColors.champagne),
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
                color: isDark ? Colors.white : ElegantColors.charcoal,
                size: 20,
              ),
              onPressed: () => context.go('/dashboard'),
            ),
          ),
          const SizedBox(width: 16),
          
          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'ADMIN',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Dashboard',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : ElegantColors.charcoal,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Manage your family tree application',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 14,
                    color: isDark ? Colors.white60 : ElegantColors.warmGray,
                  ),
                ),
              ],
            ),
          ),
          
          // Family Artboard button
          Container(
            decoration: BoxDecoration(
              gradient: isDark 
                  ? const LinearGradient(colors: [Color(0xFFCD5C45), Color(0xFFB7472A)])
                  : ElegantColors.warmGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: ElegantColors.terracotta.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.dashboard_customize_rounded, color: Colors.white),
              onPressed: () => context.go('/admin/artboard'),
              tooltip: 'Family Artboard',
            ),
          ),
          const SizedBox(width: 8),
          
          // Refresh button
          Container(
            decoration: BoxDecoration(
              gradient: isDark ? AppTheme.primaryGradient : ElegantColors.sageGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: isDark 
                      ? AppTheme.primaryLight.withOpacity(0.3)
                      : ElegantColors.sage.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _loadData,
              tooltip: 'Refresh Data',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildStatCard(
            icon: Icons.people_alt_rounded,
            value: '${_persons.length}',
            label: 'Members',
            color: AppTheme.accentTeal,
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _buildStatCard(
            icon: Icons.article_rounded,
            value: '${_posts.length}',
            label: 'Posts',
            color: AppTheme.primaryLight,
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _buildStatCard(
            icon: Icons.event_rounded,
            value: '${_events.length}',
            label: 'Events',
            color: AppTheme.accentGold,
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _buildStatCard(
            icon: Icons.person_rounded,
            value: '${_users.length}',
            label: 'Users',
            color: Colors.purple,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark 
              ? Colors.white.withOpacity(0.05) 
              : ElegantColors.warmWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? color.withOpacity(0.3) : ElegantColors.champagne,
          ),
          boxShadow: isDark ? null : [
            BoxShadow(
              color: ElegantColors.sienna.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : ElegantColors.charcoal,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 11,
                color: isDark ? Colors.white60 : ElegantColors.warmGray,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark 
            ? Colors.white.withOpacity(0.05) 
            : ElegantColors.warmWhite,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? null : Border.all(color: ElegantColors.champagne),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicator: BoxDecoration(
          gradient: isDark ? AppTheme.primaryGradient : ElegantColors.warmGradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: isDark 
                  ? AppTheme.primaryLight.withOpacity(0.3)
                  : ElegantColors.terracotta.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: isDark ? Colors.white60 : ElegantColors.warmGray,
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.all(4),
        tabs: const [
          Tab(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(Icons.dashboard_rounded, size: 18),
                  SizedBox(width: 6),
                  Text('Overview'),
                ],
              ),
            ),
          ),
          Tab(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(Icons.account_tree_rounded, size: 18),
                  SizedBox(width: 6),
                  Text('Tree'),
                ],
              ),
            ),
          ),
          Tab(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(Icons.dynamic_feed_rounded, size: 18),
                  SizedBox(width: 6),
                  Text('Feed'),
                ],
              ),
            ),
          ),
          Tab(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(Icons.event_rounded, size: 18),
                  SizedBox(width: 6),
                  Text('Events'),
                ],
              ),
            ),
          ),
          Tab(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(Icons.admin_panel_settings_rounded, size: 18),
                  SizedBox(width: 6),
                  Text('Users'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== OVERVIEW TAB =====
  Widget _buildOverviewTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Actions
          Text(
            'Quick Actions',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildQuickAction(
                icon: Icons.person_add_alt_1_rounded,
                label: 'Add Member',
                color: AppTheme.accentTeal,
                isDark: isDark,
                onTap: () => _showAddPersonDialog(),
              ),
              const SizedBox(width: 12),
              _buildQuickAction(
                icon: Icons.post_add_rounded,
                label: 'New Post',
                color: AppTheme.primaryLight,
                isDark: isDark,
                onTap: () => _showAddPostDialog(),
              ),
              const SizedBox(width: 12),
              _buildQuickAction(
                icon: Icons.event_available_rounded,
                label: 'New Event',
                color: AppTheme.accentGold,
                isDark: isDark,
                onTap: () => _showAddEventDialog(),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Second row of quick actions
          Row(
            children: [
              _buildQuickAction(
                icon: Icons.verified_user_rounded,
                label: 'Link Verification',
                color: Colors.purple,
                isDark: isDark,
                onTap: () => context.go('/admin/link-requests'),
              ),
              const SizedBox(width: 12),
              _buildQuickAction(
                icon: Icons.campaign_rounded,
                label: 'Announcement',
                color: Colors.orange,
                isDark: isDark,
                onTap: () => _showAnnouncementDialog(),
              ),
              const SizedBox(width: 12),
              _buildQuickAction(
                icon: Icons.download_rounded,
                label: 'Export Data',
                color: Colors.teal,
                isDark: isDark,
                onTap: () => _showExportDialog(isDark),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Recent Members
          _buildSectionHeader('Recent Members', isDark),
          const SizedBox(height: 12),
          ..._persons.take(5).map((p) => _buildPersonTile(p, isDark)),
        ],
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark 
                ? Colors.white.withOpacity(0.05) 
                : ElegantColors.warmWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? color.withOpacity(0.3) : ElegantColors.champagne),
            boxShadow: isDark ? null : [
              BoxShadow(
                color: ElegantColors.sienna.withOpacity(0.06),
                blurRadius: 10,
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : ElegantColors.charcoal,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : Colors.black87,
      ),
    );
  }

  Widget _buildPersonTile(Person person, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark 
            ? Colors.white.withOpacity(0.05) 
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark 
              ? Colors.white.withOpacity(0.1) 
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: person.gender == 'male'
                    ? [Colors.blue.shade300, Colors.blue.shade500]
                    : [Colors.pink.shade300, Colors.pink.shade500],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              person.gender == 'male' ? Icons.person : Icons.person_2,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  person.fullName,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                if (person.birthDate != null)
                  Text(
                    'Born ${person.birthDate!.year}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  Icons.edit_rounded,
                  color: AppTheme.primaryLight,
                  size: 20,
                ),
                onPressed: () => _showEditPersonDialog(person),
                tooltip: 'Edit',
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red.shade400,
                  size: 20,
                ),
                onPressed: () => _confirmDeletePerson(person),
                tooltip: 'Delete',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.8)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== TREE MANAGEMENT TAB =====
  Widget _buildTreeManagementTab(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: isDark 
                  ? AppTheme.primaryGradient
                  : ElegantColors.warmGradient,
              borderRadius: BorderRadius.circular(100),
              boxShadow: [
                BoxShadow(
                  color: ElegantColors.terracotta.withOpacity(0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.account_tree_rounded,
              size: 64,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Family Artboard',
            style: GoogleFonts.playfairDisplay(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : ElegantColors.charcoal,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Visual management for your family tree',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 16,
              color: isDark ? Colors.white60 : ElegantColors.warmGray,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.primaryLight.withOpacity(0.15) : ElegantColors.terracotta.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_persons.length} family members',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.primaryLight : ElegantColors.terracotta,
              ),
            ),
          ),
          const SizedBox(height: 36),
          
          // Open Artboard Button
          ElevatedButton.icon(
            onPressed: () => context.go('/admin/artboard'),
            icon: const Icon(Icons.dashboard_customize_rounded, size: 22),
            label: Text(
              'Open Artboard',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppTheme.primaryLight : ElegantColors.terracotta,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Features
          Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.symmetric(horizontal: 32),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : ElegantColors.cream,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white10 : ElegantColors.champagne,
              ),
            ),
            child: Column(
              children: [
                _buildFeatureRow(Icons.person_add_rounded, 'Add & edit family members', isDark),
                const SizedBox(height: 12),
                _buildFeatureRow(Icons.delete_sweep_rounded, 'Delete with cascade (removes descendants)', isDark),
                const SizedBox(height: 12),
                _buildFeatureRow(Icons.checklist_rounded, 'Multi-select for batch operations', isDark),
                const SizedBox(height: 12),
                _buildFeatureRow(Icons.center_focus_strong_rounded, 'Focus mode drill-down view', isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  
  Widget _buildFeatureRow(IconData icon, String text, bool isDark) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isDark ? AppTheme.primaryLight : ElegantColors.terracotta,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 14,
              color: isDark ? Colors.white70 : ElegantColors.charcoal,
            ),
          ),
        ),
      ],
    );
  }

  // ===== FEED MANAGEMENT TAB =====
  Widget _buildFeedManagementTab(bool isDark) {
    return Column(
      children: [
        // Add Post Button
        Padding(
          padding: const EdgeInsets.all(16),
          child: _buildActionButton(
            label: 'Create New Post',
            icon: Icons.post_add_rounded,
            color: AppTheme.primaryLight,
            onTap: () => _showAddPostDialog(),
          ),
        ),
        
        // Post List
        Expanded(
          child: _posts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.article_outlined,
                        size: 64,
                        color: isDark ? Colors.white30 : Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No posts yet',
                        style: GoogleFonts.inter(
                          color: isDark ? Colors.white60 : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _posts.length,
                  itemBuilder: (context, index) {
                    return _buildPostTile(_posts[index], isDark);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPostTile(Post post, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark 
            ? Colors.white.withOpacity(0.05) 
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark 
              ? Colors.white.withOpacity(0.1) 
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.primaryLight,
                child: Text(
                  post.userName.isNotEmpty ? post.userName[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.userName,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      _formatDate(post.createdAt),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.edit_outlined,
                  color: isDark ? Colors.white60 : Colors.grey,
                ),
                onPressed: () => _showEditPostDialog(post),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red.shade400,
                ),
                onPressed: () => _confirmDeletePost(post),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            post.content,
            style: GoogleFonts.inter(
              color: isDark ? Colors.white : Colors.black87,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ===== EVENTS MANAGEMENT TAB =====
  Widget _buildEventsManagementTab(bool isDark) {
    return Column(
      children: [
        // Add Event Button
        Padding(
          padding: const EdgeInsets.all(16),
          child: _buildActionButton(
            label: 'Create New Event',
            icon: Icons.event_available_rounded,
            color: AppTheme.accentGold,
            onTap: () => _showAddEventDialog(),
          ),
        ),
        
        // Event List
        Expanded(
          child: _events.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.event_outlined,
                        size: 64,
                        color: isDark ? Colors.white30 : Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No events yet',
                        style: GoogleFonts.inter(
                          color: isDark ? Colors.white60 : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _events.length,
                  itemBuilder: (context, index) {
                    return _buildEventTile(_events[index], isDark);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEventTile(Appointment event, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark 
            ? Colors.white.withOpacity(0.05) 
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.accentGold.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.accentGold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  '${event.dateTime.day}',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accentGold,
                  ),
                ),
                Text(
                  _getMonthAbbrev(event.dateTime.month),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.accentGold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                if ((event.location ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: isDark ? Colors.white60 : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        event.location ?? '',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  '${event.attendees.length} attending',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.accentTeal,
                  ),
                ),
               ],
            ),
          ),
          // Maps button (if mapLink exists)
          if (event.mapLink != null && event.mapLink!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.map, color: AppTheme.accentTeal),
              tooltip: 'Open in Maps',
              onPressed: () async {
                final uri = Uri.parse(event.mapLink!);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not open map link')),
                    );
                  }
                }
              },
            ),

          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppTheme.accentTeal),
            onPressed: () => _showEditEventDialog(event),
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline_rounded,
              color: Colors.red.shade400,
            ),
            onPressed: () => _confirmDeleteEvent(event),
          ),
        ],
      ),
    );
  }

  // ===== USERS MANAGEMENT TAB =====
  Widget _buildUsersManagementTab(bool isDark) {
    return _users.isEmpty
        ? Center(
            child: Text(
              'No users found',
              style: GoogleFonts.inter(
                color: isDark ? Colors.white60 : Colors.grey,
              ),
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _users.length,
            itemBuilder: (context, index) {
              return _buildUserTile(_users[index], isDark);
            },
          );
  }

  Widget _buildUserTile(AppUser user, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark 
            ? Colors.white.withOpacity(0.05) 
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: user.isAdmin 
              ? Colors.orange.withOpacity(0.5) 
              : (isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: user.isAdmin ? Colors.orange : AppTheme.primaryLight,
            child: Icon(
              user.isAdmin ? Icons.admin_panel_settings : Icons.person,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      user.name.isNotEmpty ? user.name : 'Unknown User',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: user.isAdmin 
                            ? Colors.orange.withOpacity(0.2)
                            : Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        user.role.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: user.isAdmin ? Colors.orange : Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  user.email.isNotEmpty ? user.email : user.id,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              color: isDark ? Colors.white60 : Colors.grey,
            ),
            onSelected: (value) {
              if (value == 'admin' || value == 'member') {
                _updateUserRole(user, value);
              } else if (value == 'delete') {
                _confirmDeleteUser(user);
              } else if (value == 'ban') {
                _banUser(user);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'admin',
                enabled: !user.isAdmin,
                child: const Row(
                  children: [
                    Icon(Icons.admin_panel_settings, size: 20),
                    SizedBox(width: 8),
                    Text('Make Admin'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'member',
                enabled: user.isAdmin,
                child: const Row(
                  children: [
                    Icon(Icons.person_outline, size: 20),
                    SizedBox(width: 8),
                    Text('Make Member'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'ban',
                child: Row(
                  children: [
                    Icon(Icons.block, size: 20, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Ban User', style: TextStyle(color: Colors.orange)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete User', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===== DIALOG METHODS =====
  
  void _showAddPersonDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => AddPersonDialog(
        familyTreeId: 'main-family-tree',
        onSave: (person) async {
          try {
            await _adminRepo.addPerson(person);
            _loadData();
            if (mounted) {
              ScaffoldMessenger.of(this.context).showSnackBar(
                const SnackBar(content: Text('Person added successfully')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(content: Text('Error: $e')),
              );
            }
          }
        },
      ),
    );
  }

  void _showEditPersonDialog(Person person) {
    final firstNameController = TextEditingController(text: person.firstName);
    final lastNameController = TextEditingController(text: person.lastName);
    final bioController = TextEditingController(text: person.bio ?? '');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${person.fullName}', style: GoogleFonts.playfairDisplay()),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: firstNameController,
                decoration: const InputDecoration(
                  labelText: 'First Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Last Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: bioController,
                decoration: const InputDecoration(
                  labelText: 'Bio',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final updated = person.copyWith(
                firstName: firstNameController.text,
                lastName: lastNameController.text,
                bio: bioController.text,
              );
              
              try {
                await _adminRepo.updatePerson(updated);
                Navigator.pop(context);
                _loadData();
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Person updated successfully')),
                );
              } catch (e) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeletePerson(Person person) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Person'),
        content: Text('Are you sure you want to delete ${person.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await _adminRepo.deletePerson(person.id);
                Navigator.pop(context);
                _loadData();
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Person deleted')),
                );
              } catch (e) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showEditPostDialog(Post post) {
    final contentController = TextEditingController(text: post.content);
    final user = ref.read(authStateProvider).value;
    
    // Existing media
    List<String> existingPhotos = List.from(post.photos);
    List<String> existingVideos = List.from(post.videos);
    List<String> existingFiles = List.from(post.files);
    
    // New media
    List<XFile> newImages = [];
    List<XFile> newVideos = [];
    List<PlatformFile> newFiles = [];
    
    bool isUploading = false;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit Post', style: GoogleFonts.playfairDisplay()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: contentController,
                  decoration: const InputDecoration(
                    labelText: 'What\'s on your mind?',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 5,
                ),
                const SizedBox(height: 16),
                
                // Media/File buttons
                Wrap(
                  spacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        final ImagePicker picker = ImagePicker();
                        final images = await picker.pickMultiImage();
                        setDialogState(() => newImages.addAll(images));
                      },
                      icon: const Icon(Icons.image, size: 18),
                      label: const Text('Photos'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentTeal,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final ImagePicker picker = ImagePicker();
                        final video = await picker.pickVideo(source: ImageSource.gallery);
                        if (video != null) {
                          setDialogState(() => newVideos.add(video));
                        }
                      },
                      icon: const Icon(Icons.video_library, size: 18),
                      label: const Text('Video'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentCyan,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          allowMultiple: true,
                          type: FileType.custom,
                          allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'xlsx', 'pptx'],
                        );
                        if (result != null) {
                          setDialogState(() => newFiles.addAll(result.files));
                        }
                      },
                      icon: const Icon(Icons.attach_file, size: 18),
                      label: const Text('Files'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentGold,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                
                // Existing Media Preview
                if (existingPhotos.isNotEmpty || existingVideos.isNotEmpty || existingFiles.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Existing Attachments:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (existingPhotos.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      children: existingPhotos.asMap().entries.map((entry) => Chip(
                        label: Text('Photo ${entry.key + 1}'),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () => setDialogState(() => existingPhotos.removeAt(entry.key)),
                      )).toList(),
                    ),
                  if (existingVideos.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      children: existingVideos.asMap().entries.map((entry) => Chip(
                        avatar: const Icon(Icons.video_library, size: 16),
                        label: Text('Video ${entry.key + 1}'),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () => setDialogState(() => existingVideos.removeAt(entry.key)),
                      )).toList(),
                    ),
                  if (existingFiles.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      children: existingFiles.asMap().entries.map((entry) => Chip(
                        avatar: const Icon(Icons.attach_file, size: 16),
                        label: Text('File ${entry.key + 1}'),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () => setDialogState(() => existingFiles.removeAt(entry.key)),
                      )).toList(),
                    ),
                ],

                // New Media Preview
                if (newImages.isNotEmpty || newVideos.isNotEmpty || newFiles.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('New Attachments:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (newImages.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      children: newImages.map((img) => Chip(
                        label: Text(img.name),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () => setDialogState(() => newImages.remove(img)),
                      )).toList(),
                    ),
                  if (newVideos.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      children: newVideos.map((vid) => Chip(
                        avatar: const Icon(Icons.video_library, size: 16),
                        label: Text(vid.name),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () => setDialogState(() => newVideos.remove(vid)),
                      )).toList(),
                    ),
                  if (newFiles.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      children: newFiles.map((file) => Chip(
                        avatar: const Icon(Icons.attach_file, size: 16),
                        label: Text(file.name),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () => setDialogState(() => newFiles.remove(file)),
                      )).toList(),
                    ),
                ],
                
                if (isUploading) ...[
                  const SizedBox(height: 16),
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 8),
                  const Center(child: Text('Updating post...')),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isUploading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isUploading ? null : () async {
                if (contentController.text.isEmpty) return;
                
                setDialogState(() => isUploading = true);
                
                try {
                  final storageService = StorageService();
                  
                  // Upload new media
                  for (final image in newImages) {
                    final bytes = await image.readAsBytes();
                    final url = await storageService.uploadImage(image.name, Uint8List.fromList(bytes));
                    if (url != null) existingPhotos.add(url);
                  }
                  
                  for (final video in newVideos) {
                    final bytes = await video.readAsBytes();
                    final url = await storageService.uploadVideo(video.name, Uint8List.fromList(bytes));
                    if (url != null) existingVideos.add(url);
                  }
                  
                  for (final file in newFiles) {
                    if (file.bytes != null) {
                      final url = await storageService.uploadFile(file.name, file.bytes!);
                      if (url != null) existingFiles.add(url);
                    }
                  }
                  
                  final updatedPost = post.copyWith(
                    content: contentController.text,
                    photos: existingPhotos,
                    videos: existingVideos,
                    files: existingFiles,
                  );
                  
                  // We need to implement updatePost in AdminRepository
                  // For now, let's assume it exists or we'll add it
                  await _adminRepo.updatePost(updatedPost);
                  
                  Navigator.pop(context);
                  _loadData();
                  if (mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(content: Text('Post updated successfully')),
                    );
                  }
                } catch (e) {
                  setDialogState(() => isUploading = false);
                  if (mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddPostDialog() {
    final contentController = TextEditingController();
    final user = ref.read(authStateProvider).value;
    List<XFile> selectedImages = [];
    List<XFile> selectedVideos = [];
    List<PlatformFile> selectedFiles = [];
    bool isUploading = false;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Create Post', style: GoogleFonts.playfairDisplay()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: contentController,
                  decoration: const InputDecoration(
                    labelText: 'What\'s on your mind?',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 5,
                ),
                const SizedBox(height: 16),
                
                // Media/File buttons
                Wrap(
                  spacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        final ImagePicker picker = ImagePicker();
                        final images = await picker.pickMultiImage();
                        setDialogState(() => selectedImages.addAll(images));
                      },
                      icon: const Icon(Icons.image, size: 18),
                      label: const Text('Photos'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentTeal,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final ImagePicker picker = ImagePicker();
                        final video = await picker.pickVideo(source: ImageSource.gallery);
                        if (video != null) {
                          setDialogState(() => selectedVideos.add(video));
                        }
                      },
                      icon: const Icon(Icons.video_library, size: 18),
                      label: const Text('Video'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentCyan,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          allowMultiple: true,
                          type: FileType.custom,
                          allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'xlsx', 'pptx'],
                        );
                        if (result != null) {
                          setDialogState(() => selectedFiles.addAll(result.files));
                        }
                      },
                      icon: const Icon(Icons.attach_file, size: 18),
                      label: const Text('Files'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentGold,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                
                // Selected media preview
                if (selectedImages.isNotEmpty || selectedVideos.isNotEmpty || selectedFiles.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Attachments:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (selectedImages.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      children: selectedImages.map((img) => Chip(
                        label: Text(img.name),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () => setDialogState(() => selectedImages.remove(img)),
                      )).toList(),
                    ),
                  if (selectedVideos.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      children: selectedVideos.map((vid) => Chip(
                        avatar: const Icon(Icons.video_library, size: 16),
                        label: Text(vid.name),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () => setDialogState(() => selectedVideos.remove(vid)),
                      )).toList(),
                    ),
                  if (selectedFiles.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      children: selectedFiles.map((file) => Chip(
                        avatar: const Icon(Icons.attach_file, size: 16),
                        label: Text(file.name),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () => setDialogState(() => selectedFiles.remove(file)),
                      )).toList(),
                    ),
                ],
                
                if (isUploading) ...[
                  const SizedBox(height: 16),
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 8),
                  const Center(child: Text('Uploading media...')),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isUploading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isUploading ? null : () async {
                if (contentController.text.isEmpty) return;
                
                setDialogState(() => isUploading = true);
                
                try {
                  final storageService = StorageService();
                  List<String> photoUrls = [];
                  List<String> videoUrls = [];
                  List<String> fileUrls = [];
                  
                  // Upload images
                  for (final image in selectedImages) {
                    final bytes = await image.readAsBytes();
                    final url = await storageService.uploadImage(image.name, Uint8List.fromList(bytes));
                    if (url != null) photoUrls.add(url);
                  }
                  
                  // Upload videos
                  for (final video in selectedVideos) {
                    final bytes = await video.readAsBytes();
                    final url = await storageService.uploadVideo(video.name, Uint8List.fromList(bytes));
                    if (url != null) videoUrls.add(url);
                  }
                  
                  // Upload files
                  for (final file in selectedFiles) {
                    if (file.bytes != null) {
                      final url = await storageService.uploadFile(file.name, file.bytes!);
                      if (url != null) fileUrls.add(url);
                    }
                  }
                  
                  final post = Post(
                    id: '',
                    familyTreeId: 'main-family-tree',
                    userId: user?.uid ?? '',
                    userName: user?.displayName ?? 'Admin',
                    userPhoto: user?.photoURL ?? '',
                    content: contentController.text,
                    photos: photoUrls,
                    videos: videoUrls,
                    files: fileUrls,
                    createdAt: DateTime.now(),
                  );
                  
                  await _adminRepo.createPost(post);
                  Navigator.pop(context);
                  _loadData();
                  if (mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(content: Text('Post created successfully')),
                    );
                  }
                } catch (e) {
                  setDialogState(() => isUploading = false);
                  if (mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: const Text('Post'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeletePost(Post post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await _adminRepo.deletePost(post.id);
                Navigator.pop(context);
                _loadData();
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Post deleted')),
                );
              } catch (e) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddEventDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final locationController = TextEditingController();
    final mapLinkController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));
    TimeOfDay selectedTime = const TimeOfDay(hour: 10, minute: 0);
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Create Event', style: GoogleFonts.playfairDisplay()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Event Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: mapLinkController,
                  decoration: InputDecoration(
                    labelText: 'Google Maps Link (Optional)',
                    hintText: 'https://maps.google.com/...',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.map),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.location_on),
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
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Date'),
                  subtitle: Text('${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setDialogState(() => selectedDate = date);
                    }
                  },
                ),
                ListTile(
                  title: const Text('Time'),
                  subtitle: Text('${selectedTime.hour}:${selectedTime.minute.toString().padLeft(2, '0')}'),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: selectedTime,
                    );
                    if (time != null) {
                      setDialogState(() => selectedTime = time);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty) return;
                
                final user = ref.read(authStateProvider).value;
                final dateTime = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  selectedTime.hour,
                  selectedTime.minute,
                );
                
                final event = Appointment(
                  id: '',
                  familyTreeId: 'main-family-tree',
                  title: titleController.text,
                  description: descriptionController.text,
                  location: locationController.text,
                  mapLink: mapLinkController.text.isEmpty ? null : mapLinkController.text,
                  dateTime: dateTime,
                  createdBy: user?.uid ?? '',
                  attendees: [],
                );
                
                try {
                  await _adminRepo.createEvent(event);
                  Navigator.pop(context);
                  _loadData();
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('Event created successfully')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteEvent(Appointment event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text('Are you sure you want to delete "${event.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await _adminRepo.deleteEvent(event.id);
                Navigator.pop(context);
                _loadData();
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Event deleted')),
                );
              } catch (e) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showEditEventDialog(Appointment event) {
    final titleController = TextEditingController(text: event.title);
    final descriptionController = TextEditingController(text: event.description);
    final locationController = TextEditingController(text: event.location);
    final mapLinkController = TextEditingController(text: event.mapLink);
    DateTime selectedDateTime = event.dateTime;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Edit Event', style: GoogleFonts.playfairDisplay()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: mapLinkController,
                  decoration: InputDecoration(
                    labelText: 'Google Maps Link',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.map),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.location_on),
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
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Date & Time'),
                  subtitle: Text(_formatDate(selectedDateTime)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDateTime,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
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
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty) return;

                final updatedEvent = event.copyWith(
                  title: titleController.text,
                  description: descriptionController.text,
                  location: locationController.text,
                  mapLink: mapLinkController.text,
                  dateTime: selectedDateTime,
                );

                try {
                  await _adminRepo.updateEvent(updatedEvent);
                  Navigator.pop(context);
                  _loadData();
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('Event updated successfully')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateUserRole(AppUser user, String role) async {
    try {
      await _adminRepo.updateUserRole(user.id, role);
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user.name} is now ${role}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // ===== HELPER METHODS =====
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getMonthAbbrev(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  // ===== ANNOUNCEMENT DIALOG =====
  void _showAnnouncementDialog() {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
        title: Row(
          children: [
            const Icon(Icons.campaign_rounded, color: Colors.orange),
            const SizedBox(width: 8),
            Text(
              'Send Announcement',
              style: GoogleFonts.playfairDisplay(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Enter announcement title',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: messageController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Message',
                hintText: 'Enter announcement message',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              if (titleController.text.isEmpty || messageController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill in all fields')),
                );
                return;
              }
              try {
                await _adminRepo.sendAnnouncement(
                  title: titleController.text,
                  message: messageController.text,
                );
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Announcement sent to all users!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            icon: const Icon(Icons.send),
            label: const Text('Send'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          ),
        ],
      ),
    );
  }

  // ===== EXPORT DIALOG =====
  void _showExportDialog(bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
        title: Row(
          children: [
            const Icon(Icons.download_rounded, color: Colors.teal),
            const SizedBox(width: 8),
            Text(
              'Export Family Tree',
              style: GoogleFonts.playfairDisplay(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Export your family tree data for backup or transfer.',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 16),
            _buildExportOption(
              'JSON Format',
              'Complete data with all fields',
              Icons.code,
              isDark,
              () => _exportData('json'),
            ),
            const SizedBox(height: 8),
            _buildExportOption(
              'CSV Format',
              'Spreadsheet-friendly format',
              Icons.table_chart,
              isDark,
              () => _exportData('csv'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildExportOption(String title, String subtitle, IconData icon, bool isDark, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.teal.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.teal),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  )),
                  Text(subtitle, style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.grey,
                  )),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.teal),
          ],
        ),
      ),
    );
  }

  Future<void> _exportData(String format) async {
    Navigator.pop(context);
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exporting data...')),
      );
      final data = await _adminRepo.exportFamilyTreeData('main-family-tree');
      
      // For web, we'd use a download link; for mobile, we'd save to file
      // For now, show success
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported ${data['persons']?.length ?? 0} persons as $format'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  // ===== USER DELETE/BAN =====
  Future<void> _confirmDeleteUser(AppUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete ${user.name}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _adminRepo.deleteUser(user.id);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${user.name} has been deleted')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _banUser(AppUser user) async {
    final reasonController = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ban User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to ban ${user.name}?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'Why is this user being banned?',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Ban User'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _adminRepo.banUser(user.id, reason: reasonController.text);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${user.name} has been banned')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
