import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/data/models/person.dart';
import 'package:family_tree/data/repositories/person_repository.dart';
import 'package:family_tree/features/auth/providers/auth_provider.dart';
import 'package:google_fonts/google_fonts.dart';

/// Dialog shown for first-time users to set up their Person profile
class UserSetupDialog extends ConsumerStatefulWidget {
  const UserSetupDialog({super.key});

  @override
  ConsumerState<UserSetupDialog> createState() => _UserSetupDialogState();
}

class _UserSetupDialogState extends ConsumerState<UserSetupDialog> {
  final PersonRepository _repository = PersonRepository();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  
  List<Person> _searchResults = [];
  bool _isSearching = false;
  bool _isCreatingNew = false;
  Person? _selectedPerson;

  @override
  void dispose() {
    _searchController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _searchPersons() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isSearching = true);

    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) return;

      // Search in the demo tree for now
      final results = await _repository.searchPersons('main-family-tree', query);
      
      // Filter out persons already linked to users
      final availableResults = results.where((p) => p.authUserId == null).toList();
      
      setState(() {
        _searchResults = availableResults;
        _isSearching = false;
      });

      // If no results, show helpful message
      if (availableResults.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(results.isEmpty 
                ? 'No persons found. Try seeding data first by going to the Tree view and clicking the cloud upload icon.' 
                : 'All matching persons are already linked to accounts.'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSearching = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching: $e')),
        );
      }
    }
  }

  Future<void> _linkToPerson(Person person) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

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
              Text('Linking profile...'),
            ],
          ),
          duration: Duration(seconds: 30),
        ),
      );
    }

    try {
      print('Attempting to link person ${person.id} to user ${user.uid}');
      
      // Add timeout to prevent hanging forever
      await _repository.linkPersonToUser(person.id, user.uid).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Operation timed out. This is likely a Firestore permissions issue. Please update your Firestore security rules.');
        },
      );
      
      print('Link successful!');
      
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        Navigator.pop(context, person);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully linked to your profile!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      print('Link error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error linking profile: $e\n\nThis is likely a Firestore permissions issue. Check the console for details.'),
            backgroundColor: AppTheme.error,
            duration: const Duration(seconds: 7),
          ),
        );
      }
    }
  }

  Future<void> _createNewPerson() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    
    if (firstName.isEmpty || lastName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }

    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    try {
      final newPerson = Person(
        id: '',
        familyTreeId: 'main-family-tree',
        authUserId: user.uid,
        firstName: firstName,
        lastName: lastName,
        relationships: Relationships(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      print('Creating new person: $firstName $lastName for user ${user.uid}');
      
      // Add timeout
      final personId = await _repository.addPerson(newPerson).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Operation timed out. This is likely a Firestore permissions issue. Please update your Firestore security rules.');
        },
      );
      
      final createdPerson = await _repository.getPerson(personId);
      print('Person created successfully with ID: $personId');
      
      if (mounted && createdPerson != null) {
        Navigator.pop(context, createdPerson);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile created successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating profile: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surfaceDark,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set Up Your Profile',
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            Text(
              'Link your account to your person in the family tree',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: AppTheme.spaceLg),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => setState(() => _isCreatingNew = false),
                    icon: const Icon(Icons.search),
                    label: const Text('Find Existing'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !_isCreatingNew ? AppTheme.primaryLight : AppTheme.surfaceDark,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spaceSm),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => setState(() => _isCreatingNew = true),
                    icon: const Icon(Icons.add),
                    label: const Text('Create New'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isCreatingNew ? AppTheme.primaryLight : AppTheme.surfaceDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceMd),

            Expanded(
                child: _isCreatingNew ? _buildCreateForm() : _buildSearchForm(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchForm() {
    return Column(
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search by name...',
            hintStyle: GoogleFonts.inter(color: AppTheme.textMuted),
            filled: true,
            fillColor: AppTheme.backgroundDark,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: BorderSide.none,
            ),
            suffixIcon: IconButton(
              icon: const Icon(Icons.search, color: AppTheme.primaryLight),
              onPressed: _searchPersons,
            ),
          ),
          style: GoogleFonts.inter(color: AppTheme.textPrimary),
          onSubmitted: (_) => _searchPersons(),
        ),
        const SizedBox(height: AppTheme.spaceMd),

        Expanded(
          child: _isSearching
              ? const Center(child: CircularProgressIndicator())
              : _searchResults.isEmpty
                  ? Center(
                      child: Text(
                        'Search for your name in the family tree',
                        style: GoogleFonts.inter(color: AppTheme.textMuted),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final person = _searchResults[index];
                        return Card(
                          color: AppTheme.surfaceDark,
                          margin: const EdgeInsets.only(bottom: AppTheme.spaceSm),
                          child: ListTile(
                            title: Text(
                              person.fullName,
                              style: GoogleFonts.inter(color: AppTheme.textPrimary),
                            ),
                            subtitle: person.lifespan.isNotEmpty
                                ? Text(
                                    person.lifespan,
                                    style: GoogleFonts.inter(color: AppTheme.textSecondary),
                                  )
                                : null,
                            trailing: ElevatedButton(
                              onPressed: () => _linkToPerson(person),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryLight,
                              ),
                              child: const Text('Link'),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildCreateForm() {
    return Column(
      children: [
        TextField(
          controller: _firstNameController,
          decoration: InputDecoration(
            labelText: 'First Name',
            labelStyle: GoogleFonts.inter(color: AppTheme.textSecondary),
            filled: true,
            fillColor: AppTheme.backgroundDark,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: BorderSide.none,
            ),
          ),
          style: GoogleFonts.inter(color: AppTheme.textPrimary),
        ),
        const SizedBox(height: AppTheme.spaceMd),
        TextField(
          controller: _lastNameController,
          decoration: InputDecoration(
            labelText: 'Last Name',
            labelStyle: GoogleFonts.inter(color: AppTheme.textSecondary),
            filled: true,
            fillColor: AppTheme.backgroundDark,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: BorderSide.none,
            ),
          ),
          style: GoogleFonts.inter(color: AppTheme.textPrimary),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _createNewPerson,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryLight,
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceMd),
            ),
            child: const Text('Create Profile'),
          ),
        ),
      ],
    );
  }
}
