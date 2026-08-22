import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_tree/data/models/person.dart';
import 'package:family_tree/data/repositories/person_repository.dart';
import 'package:family_tree/features/tree_view/tree_canvas.dart';

/// State for the tree view
class TreeState {
  final List<Person> persons;
  final String? selectedPersonId;
  final String? focusedSubtreeRoot;  // Root of focused subtree
  final List<String> focusedPersonIds;
  final LayoutMode layoutMode;
  final bool isLoading;
  final String? error;

  const TreeState({
    this.persons = const [],
    this.selectedPersonId,
    this.focusedSubtreeRoot,
    this.focusedPersonIds = const [],
    this.layoutMode = LayoutMode.focus,
    this.isLoading = false,
    this.error,
  });

  TreeState copyWith({
    List<Person>? persons,
    String? selectedPersonId,
    Object? focusedSubtreeRoot = _sentinel,
    List<String>? focusedPersonIds,
    LayoutMode? layoutMode,
    bool? isLoading,
    String? error,
  }) {
    return TreeState(
      persons: persons ?? this.persons,
      selectedPersonId: selectedPersonId ?? this.selectedPersonId,
      focusedSubtreeRoot: focusedSubtreeRoot == _sentinel 
          ? this.focusedSubtreeRoot 
          : focusedSubtreeRoot as String?,
      focusedPersonIds: focusedPersonIds ?? this.focusedPersonIds,
      layoutMode: layoutMode ?? this.layoutMode,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

// Sentinel value to distinguish between "not provided" and "explicitly null"
const _sentinel = Object();

/// Tree view controller
class TreeController extends StateNotifier<TreeState> {
  final PersonRepository _repository;
  final String familyTreeId;

  TreeController({
    required PersonRepository repository,
    required this.familyTreeId,
  })  : _repository = repository,
        super(const TreeState(isLoading: true)) {
    _init();
  }

  void _init() {
    // Watch for person changes from Go backend
    _repository.watchFamilyMembers(familyTreeId).listen((persons) {
      // The repository hands back the very same list when a poll found nothing
      // new. Skipping the state write there means no rebuild at all, rather
      // than a rebuild that happens to change nothing.
      if (identical(persons, state.persons) && !state.isLoading) return;
      state = state.copyWith(persons: persons, isLoading: false);
    }, onError: (error) {
      String errorMessage = error.toString();
      if (errorMessage.contains('403') || errorMessage.contains('PERMISSION_DENIED')) {
        errorMessage = 'Permission denied. Please update Firestore security rules.';
      }
      
      state = state.copyWith(error: errorMessage, isLoading: false);
    });
  }

  void selectPerson(String? personId) {
    state = state.copyWith(selectedPersonId: personId);
  }

  /// Refresh the tree data from the repository
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    try {
      // An explicit refresh means "ignore what you think you know".
      PersonRepository.invalidate();
      final persons = await _repository.getFamilyMembers(familyTreeId);
      state = state.copyWith(persons: persons, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  void setLayoutMode(LayoutMode mode) {
    state = state.copyWith(layoutMode: mode);
  }

  Future<void> focusOnAncestors(String personId) async {
    final ancestors = await _repository.getAncestors(personId);
    final ancestorIds = {...ancestors.map((p) => p.id), personId};
    state = state.copyWith(focusedPersonIds: ancestorIds.toList());
  }

  Future<void> focusOnDescendants(String personId) async {
    final descendants = await _repository.getDescendants(personId);
    final descendantIds = {...descendants.map((p) => p.id), personId};
    state = state.copyWith(focusedPersonIds: descendantIds.toList());
  }

  void clearFocus() {
    state = state.copyWith(focusedPersonIds: []);
  }

  void focusOnSubtree(String personId) {
    state = state.copyWith(focusedSubtreeRoot: personId);
  }

  void clearSubtreeFocus() {
    state = state.copyWith(focusedSubtreeRoot: null);
  }

  Future<void> addPerson(Person person) async {
    try {
      await _repository.addPerson(person);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Persists an edited person and rethrows on failure.
  ///
  /// The error also lands in state for anything rendering the tree, but a
  /// caller that owns a form needs to know the save failed so it can keep the
  /// user's input on screen instead of closing over lost work.
  Future<void> updatePerson(Person person) async {
    try {
      await _repository.updatePerson(person);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> deletePerson(String personId) async {
    try {
      await _repository.deletePerson(personId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

/// Provider for the tree controller
final treeControllerProvider =
    StateNotifierProvider.family<TreeController, TreeState, String>(
  (ref, familyTreeId) => TreeController(
    repository: PersonRepository(),
    familyTreeId: familyTreeId,
  ),
);
