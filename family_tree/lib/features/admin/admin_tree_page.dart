import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/data/models/person.dart';
import 'package:family_tree/data/repositories/admin_repository.dart';
import 'package:family_tree/features/tree_view/controllers/tree_controller.dart';
import 'package:family_tree/features/tree_view/tree_canvas.dart';
import 'package:family_tree/features/edit/add_person_dialog.dart';

/// Admin Tree Page with full editing capabilities
class AdminTreePage extends ConsumerStatefulWidget {
  const AdminTreePage({super.key});

  @override
  ConsumerState<AdminTreePage> createState() => _AdminTreePageState();
}

class _AdminTreePageState extends ConsumerState<AdminTreePage> {
  final AdminRepository _adminRepo = AdminRepository();
  Person? _selectedPerson;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(treeControllerProvider('main-family-tree'));
    final controller = ref.read(treeControllerProvider('main-family-tree').notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF0D1117),
                    const Color(0xFF161B22),
                    AppTheme.primaryDeep.withOpacity(0.2),
                  ]
                : [
                    Colors.grey.shade50,
                    Colors.white,
                    AppTheme.primaryLight.withOpacity(0.05),
                  ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(isDark),
              
              // Tree Canvas
              Expanded(
                child: state.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : state.persons.isEmpty
                        ? _buildEmptyState(controller)
                        : Stack(
                            children: [
                              TreeCanvas(
                                persons: state.persons,
                                selectedPersonId: state.selectedPersonId,
                                focusedSubtreeRoot: state.focusedSubtreeRoot,
                                focusedPersonIds: state.focusedPersonIds,
                                layoutMode: state.layoutMode,
                                onPersonTapped: (id) {
                                  controller.selectPerson(id);
                                  final person = state.persons.firstWhere((p) => p.id == id);
                                  setState(() => _selectedPerson = person);
                                },
                                onPersonDoubleTapped: (id) {
                                  final person = state.persons.firstWhere((p) => p.id == id);
                                  _showEditPersonDialog(person, controller);
                                },
                                onPersonLongPressed: (id) {
                                  final person = state.persons.firstWhere((p) => p.id == id);
                                  _showPersonOptions(context, person, controller);
                                },
                                onClearSubtreeFocus: () => controller.clearSubtreeFocus(),
                                onBackgroundTapped: () {
                                  controller.selectPerson(null);
                                  setState(() => _selectedPerson = null);
                                },
                              ),
                              
                              // Selected Person Panel
                              if (_selectedPerson != null)
                                Positioned(
                                  bottom: 16,
                                  left: 16,
                                  right: 16,
                                  child: _buildSelectedPersonPanel(
                                    _selectedPerson!,
                                    controller,
                                    isDark,
                                  ),
                                ),
                            ],
                          ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Layout Toggle
          FloatingActionButton.small(
            heroTag: 'layout',
            backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
            onPressed: () => _showLayoutOptions(controller),
            child: Icon(
              Icons.view_module,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          // Add Person
          FloatingActionButton.extended(
            heroTag: 'add',
            onPressed: () => _showAddPersonDialog(controller),
            icon: const Icon(Icons.person_add),
            label: const Text('Add Member'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Back button
          Container(
            decoration: BoxDecoration(
              color: isDark 
                  ? Colors.white.withOpacity(0.1) 
                  : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new,
                color: isDark ? Colors.white : Colors.black87,
                size: 20,
              ),
              onPressed: () => context.go('/admin'),
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
                      'Tree Editor',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Double-tap to edit, long-press for options',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(TreeController controller) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.family_restroom,
            size: 80,
            color: AppTheme.textMuted,
          ),
          const SizedBox(height: 24),
          Text(
            'No family members yet',
            style: GoogleFonts.playfairDisplay(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start building your family tree',
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddPersonDialog(controller),
            icon: const Icon(Icons.person_add),
            label: const Text('Add First Person'),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedPersonPanel(
    Person person,
    TreeController controller,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark 
            ? const Color(0xFF1C2128).withOpacity(0.95) 
            : Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryLight.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: person.gender == 'male'
                    ? [Colors.blue.shade300, Colors.blue.shade600]
                    : [Colors.pink.shade300, Colors.pink.shade600],
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Center(
              child: Text(
                person.firstName[0].toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  person.fullName,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                if (person.lifespan.isNotEmpty)
                  Text(
                    person.lifespan,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
              ],
            ),
          ),
          
          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildActionIcon(
                icon: Icons.person_add_alt,
                color: AppTheme.accentTeal,
                tooltip: 'Add Child',
                onTap: () => _showAddChildDialog(person, controller),
              ),
              const SizedBox(width: 8),
              _buildActionIcon(
                icon: Icons.edit,
                color: AppTheme.primaryLight,
                tooltip: 'Edit',
                onTap: () => _showEditPersonDialog(person, controller),
              ),
              const SizedBox(width: 8),
              _buildActionIcon(
                icon: Icons.delete_outline,
                color: Colors.red.shade400,
                tooltip: 'Delete',
                onTap: () => _confirmDeletePerson(person, controller),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionIcon({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }

  void _showLayoutOptions(TreeController controller) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.account_tree),
              title: const Text('Tree View'),
              onTap: () {
                controller.setLayoutMode(LayoutMode.tree);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.radio_button_checked),
              title: const Text('Radial View'),
              onTap: () {
                controller.setLayoutMode(LayoutMode.radial);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.timeline),
              title: const Text('Timeline View'),
              onTap: () {
                controller.setLayoutMode(LayoutMode.timeline);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.list),
              title: const Text('List View'),
              onTap: () {
                controller.setLayoutMode(LayoutMode.list);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddPersonDialog(TreeController controller) {
    showDialog(
      context: context,
      builder: (context) => AddPersonDialog(
        familyTreeId: 'main-family-tree',
        onSave: (person) async {
          try {
            await _adminRepo.addPerson(person);
            controller.refresh();
          } catch (e) {
            ScaffoldMessenger.of(this.context).showSnackBar(
              SnackBar(content: Text('Error: $e')),
            );
          }
        },
      ),
    );
  }

  void _showAddChildDialog(Person parent, TreeController controller) {
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController(text: parent.lastName);
    String gender = 'male';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'Add Child of ${parent.firstName}',
            style: GoogleFonts.playfairDisplay(),
          ),
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
                DropdownButtonFormField<String>(
                  initialValue: gender,
                  decoration: const InputDecoration(
                    labelText: 'Gender',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('Male')),
                    DropdownMenuItem(value: 'female', child: Text('Female')),
                  ],
                  onChanged: (value) {
                    setDialogState(() => gender = value ?? 'male');
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
                if (firstNameController.text.isEmpty) return;

                final child = Person(
                  id: '',
                  familyTreeId: 'main-family-tree',
                  firstName: firstNameController.text,
                  lastName: lastNameController.text,
                  gender: gender,
                  relationships: Relationships(
                    parentIds: [parent.id],
                  ),
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );

                try {
                  final childId = await _adminRepo.addPerson(child);
                  
                  // Update parent with new child
                  final updatedParent = parent.copyWith(
                    relationships: parent.relationships.copyWith(
                      childrenIds: [...parent.relationships.childrenIds, childId],
                    ),
                  );
                  await _adminRepo.updatePerson(updatedParent);
                  
                  Navigator.pop(context);
                  controller.refresh();
                  setState(() => _selectedPerson = null);
                  
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('Child added successfully')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditPersonDialog(Person person, TreeController controller) {
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
                controller.refresh();
                setState(() => _selectedPerson = null);
                
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

  void _confirmDeletePerson(Person person, TreeController controller) {
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
                controller.refresh();
                setState(() => _selectedPerson = null);
                
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

  void _showPersonOptions(
    BuildContext context,
    Person person,
    TreeController controller,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1C2128)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: person.gender == 'male'
                              ? [Colors.blue.shade300, Colors.blue.shade600]
                              : [Colors.pink.shade300, Colors.pink.shade600],
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Center(
                        child: Text(
                          person.firstName[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        person.fullName,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 24),
              
              // Options
              ListTile(
                leading: const Icon(Icons.edit, color: AppTheme.primaryLight),
                title: const Text('Edit Person'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditPersonDialog(person, controller);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_add, color: AppTheme.accentTeal),
                title: const Text('Add Child'),
                onTap: () {
                  Navigator.pop(context);
                  _showAddChildDialog(person, controller);
                },
              ),
              ListTile(
                leading: Icon(Icons.account_tree, color: AppTheme.accentGold),
                title: const Text('Focus on Subtree'),
                onTap: () {
                  Navigator.pop(context);
                  controller.focusOnSubtree(person.id);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red.shade400),
                title: Text(
                  'Delete Person',
                  style: TextStyle(color: Colors.red.shade400),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeletePerson(person, controller);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
