import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/core/theme/elegant_theme.dart';
import 'package:family_tree/data/models/app_user.dart';
import 'package:family_tree/data/services/api_service.dart';
import 'package:family_tree/features/auth/providers/auth_provider.dart';
import 'package:google_fonts/google_fonts.dart';

/// Provider for all registered users
final registeredUsersProvider = FutureProvider<List<AppUser>>((ref) async {
  final api = ApiService();
  final response = await api.get('/api/users');
  
  if (response.statusCode == 200) {
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((json) => AppUser.fromJson(json)).toList();
  }
  return [];
});

/// Members tab showing all registered app users with search and beautiful UI
class MembersTab extends ConsumerStatefulWidget {
  final bool isDark;
  
  const MembersTab({Key? key, this.isDark = true}) : super(key: key);

  @override
  ConsumerState<MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends ConsumerState<MembersTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authStateProvider).value;
    final usersAsync = ref.watch(registeredUsersProvider);

    return usersAsync.when(
      data: (users) {
        // Filter users based on search query
        final filteredUsers = users.where((user) {
          final query = _searchQuery.toLowerCase();
          return user.name.toLowerCase().contains(query) ||
                 user.email.toLowerCase().contains(query);
        }).toList()
          ..sort((a, b) => a.name.compareTo(b.name)); // Sort alphabetically

        return Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildSearchBar(),
            ),

            // Members Grid
            Expanded(
              child: filteredUsers.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(registeredUsersProvider);
                      },
                      child: GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 200,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = filteredUsers[index];
                          final isYou = user.id == currentUser?.uid;
                          return _buildMemberCard(user, isYou);
                        },
                      ),
                    ),
            ),
          ],
        );
      },
      loading: () => Center(
        child: CircularProgressIndicator(
          color: widget.isDark ? AppTheme.primaryLight : ElegantColors.terracotta,
        ),
      ),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppTheme.error),
            const SizedBox(height: 16),
            Text(
              'Error loading members',
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                color: widget.isDark ? AppTheme.textPrimary : ElegantColors.charcoal,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => ref.invalidate(registeredUsersProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: widget.isDark ? AppTheme.surfaceDark : ElegantColors.warmWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isDark ? Colors.white10 : ElegantColors.champagne,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        style: TextStyle(
          color: widget.isDark ? AppTheme.textPrimary : ElegantColors.charcoal,
        ),
        decoration: InputDecoration(
          hintText: 'Search members...',
          hintStyle: TextStyle(
            color: widget.isDark ? AppTheme.textMuted : ElegantColors.warmGray,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: widget.isDark ? AppTheme.textMuted : ElegantColors.warmGray,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: widget.isDark ? AppTheme.textMuted : ElegantColors.warmGray),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildMemberCard(AppUser user, bool isYou) {
    return Container(
      decoration: BoxDecoration(
        color: widget.isDark ? AppTheme.surfaceDark.withOpacity(0.8) : ElegantColors.warmWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isYou 
              ? (widget.isDark ? AppTheme.primaryLight : ElegantColors.terracotta)
              : (widget.isDark ? Colors.white10 : ElegantColors.champagne),
          width: isYou ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: widget.isDark ? AppTheme.primaryGradient : ElegantColors.warmGradient,
              boxShadow: [
                BoxShadow(
                  color: (widget.isDark ? AppTheme.primaryLight : ElegantColors.terracotta).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(3), // Border width
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: ClipOval(
                child: _buildInitials(user),
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Name - use cleaned name or email prefix as fallback
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              _getDisplayName(user),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.playfairDisplay(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: widget.isDark ? AppTheme.textPrimary : ElegantColors.charcoal,
              ),
            ),
          ),
          
          const SizedBox(height: 4),
          
          // Role / Status badges
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 4,
            children: [
              if (isYou)
                _buildBadge('You', widget.isDark ? AppTheme.primaryLight : ElegantColors.terracotta),
              if (user.isAdmin)
                _buildBadge('Admin', Colors.amber.shade700),
            ],
          ),
          
          // Email hint
          if (!isYou && !user.isAdmin)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                user.email.split('@').first,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: widget.isDark ? AppTheme.textMuted : ElegantColors.warmGray,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  /// Get clean display name - filters out Firebase UIDs and technical names
  String _getDisplayName(AppUser user) {
    final name = user.name.trim();
    
    // Check if name looks like a Firebase UID or technical string
    final isOddName = name.isEmpty ||
        name.length > 30 ||
        RegExp(r'^[a-zA-Z0-9]{20,}$').hasMatch(name) || // Long alphanumeric (UID)
        name.startsWith('firebase') ||
        name.contains('user') && name.length < 6 ||
        name == 'Anonymous';
    
    if (isOddName && user.email.isNotEmpty) {
      // Use email prefix as name (capitalize first letter of each word)
      final emailPrefix = user.email.split('@').first;
      // Handle common separators: dots, underscores, hyphens
      final parts = emailPrefix.split(RegExp(r'[._-]'));
      return parts.map((part) => 
        part.isNotEmpty ? '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}' : ''
      ).join(' ').trim();
    }
    
    return name.isNotEmpty ? name : 'User';
  }

  Widget _buildInitials(AppUser user) {
    final displayName = _getDisplayName(user);
    String initials = '?';
    
    if (displayName.isNotEmpty && displayName != 'User') {
      final parts = displayName.split(' ');
      if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
        initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else if (displayName.isNotEmpty) {
        initials = displayName[0].toUpperCase();
      }
    } else if (user.email.isNotEmpty) {
      initials = user.email[0].toUpperCase();
    }
    
    return Container(
      color: widget.isDark ? AppTheme.surfaceDark : ElegantColors.cream,
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.playfairDisplay(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: widget.isDark ? AppTheme.primaryLight : ElegantColors.terracotta,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isNotEmpty ? Icons.search_off : Icons.people_outline,
            size: 64,
            color: widget.isDark ? Colors.white24 : ElegantColors.warmGray.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? 'No members found' : 'No members yet',
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              color: widget.isDark ? AppTheme.textSecondary : ElegantColors.warmGray,
            ),
          ),
          if (_searchQuery.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Invite family members to join!',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: widget.isDark ? AppTheme.textMuted : ElegantColors.warmGray,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
