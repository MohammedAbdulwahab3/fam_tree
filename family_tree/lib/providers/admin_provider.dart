import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_tree/data/models/app_user.dart';
import 'package:family_tree/data/services/api_service.dart';
import 'package:family_tree/features/auth/providers/auth_provider.dart';

/// State for admin provider
class AdminState {
  final AppUser? appUser;
  final bool isLoading;
  final String? error;

  const AdminState({
    this.appUser,
    this.isLoading = false,
    this.error,
  });

  bool get isAdmin => appUser?.isAdmin ?? false;
  bool get isMember => appUser?.isMember ?? true;

  AdminState copyWith({
    AppUser? appUser,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return AdminState(
      appUser: appUser ?? this.appUser,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Controller for admin/role management
class AdminController extends StateNotifier<AdminState> {
  final ApiService _api;
  final Ref _ref;

  AdminController(this._api, this._ref) : super(const AdminState());

  /// Fetch current user info from backend (includes role)
  Future<void> fetchCurrentUser() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await _api.get('/api/me');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final appUser = AppUser.fromJson(data);
        state = state.copyWith(appUser: appUser, isLoading: false);
      } else if (response.statusCode == 401) {
        // Not authenticated - clear state
        state = const AdminState();
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to fetch user info',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Clear user state (on logout)
  void clear() {
    state = const AdminState();
  }
}

/// Provider for ApiService
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

/// Provider for AdminController
final adminControllerProvider = StateNotifierProvider<AdminController, AdminState>((ref) {
  final api = ref.watch(apiServiceProvider);
  return AdminController(api, ref);
});

/// Simple provider to check if current user is admin
final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(adminControllerProvider).isAdmin;
});

/// Provider that auto-fetches user when auth state changes
final userRoleProvider = FutureProvider<AppUser?>((ref) async {
  final authState = ref.watch(authStateProvider);
  
  // Wait for auth state to load
  if (authState.isLoading) return null;
  
  // If no user is logged in, return null
  if (authState.value == null) return null;
  
  // Fetch user from backend
  final api = ref.watch(apiServiceProvider);
  try {
    final response = await api.get('/api/me');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return AppUser.fromJson(data);
    }
  } catch (e) {
    print('Error fetching user role: $e');
  }
  
  return null;
});
