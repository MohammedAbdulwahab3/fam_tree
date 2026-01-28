import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/data/models/person.dart';
import 'package:family_tree/data/repositories/person_repository.dart';

/// Provider for search query
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Provider for search results
final searchResultsProvider = FutureProvider.family<List<Person>, String>(
  (ref, familyTreeId) async {
    final query = ref.watch(searchQueryProvider);
    if (query.isEmpty) return [];
    
    final repository = PersonRepository();
    return repository.searchPersons(familyTreeId, query);
  },
);

/// Search bar widget
class SearchBarWidget extends ConsumerWidget {
  final String familyTreeId;
  final Function(String)? onPersonSelected;

  const SearchBarWidget({
    super.key,
    required this.familyTreeId,
    this.onPersonSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = ref.watch(searchQueryProvider);
    final searchResults = ref.watch(searchResultsProvider(familyTreeId));

    return Container(
      width: 400,
      margin: const EdgeInsets.all(AppTheme.spaceMd),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search input
          TextField(
            decoration: InputDecoration(
              hintText: 'Search family members...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () =>
                          ref.read(searchQueryProvider.notifier).state = '',
                    )
                  : null,
            ),
            onChanged: (value) {
              ref.read(searchQueryProvider.notifier).state = value;
            },
          ),
          
          // Search results
          if (searchQuery.isNotEmpty)
            searchResults.when(
              data: (persons) {
                if (persons.isEmpty) {
                  return Container(
                    margin: const EdgeInsets.only(top: AppTheme.spaceSm),
                    padding: const EdgeInsets.all(AppTheme.spaceMd),
                    decoration: AppTheme.glassDecoration(),
                    child: Text(
                      'No results found',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                }
                
                return Container(
                  margin: const EdgeInsets.only(top: AppTheme.spaceSm),
                  constraints: const BoxConstraints(maxHeight: 300),
                  decoration: AppTheme.glassDecoration(),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: persons.length,
                    itemBuilder: (context, index) {
                      final person = persons[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: person.profilePhotoUrl != null
                              ? NetworkImage(person.profilePhotoUrl!)
                              : null,
                          child: person.profilePhotoUrl == null
                              ? Text(person.firstName[0])
                              : null,
                        ),
                        title: Text(person.fullName),
                        subtitle: Text(person.lifespan),
                        onTap: () {
                          if (onPersonSelected != null) {
                            onPersonSelected!(person.id);
                          }
                          ref.read(searchQueryProvider.notifier).state = '';
                        },
                      );
                    },
                  ),
                );
              },
              loading: () => Container(
                margin: const EdgeInsets.only(top: AppTheme.spaceSm),
                padding: const EdgeInsets.all(AppTheme.spaceMd),
                decoration: AppTheme.glassDecoration(),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, stack) => Container(
                margin: const EdgeInsets.only(top: AppTheme.spaceSm),
                padding: const EdgeInsets.all(AppTheme.spaceMd),
                decoration: AppTheme.glassDecoration(),
                child: Text(
                  'Error: $error',
                  style: const TextStyle(color: AppTheme.error),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
