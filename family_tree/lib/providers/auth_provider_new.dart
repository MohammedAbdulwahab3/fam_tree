import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_tree/data/services/auth_service_new.dart';

// Auth Service Provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// Auth State Provider - returns current user
final authStateProvider = StreamProvider<Map<String, dynamic>?>((ref) async* {
  final authService = ref.watch(authServiceProvider);
  await authService.init();
  
  // Since we don't have real-time auth state changes like Firebase,
  // we'll just emit the current user once
  yield authService.currentUser;
  
  // In a real app, you might want to periodically check token validity
  // or listen to changes via a StateNotifier
});

// Auth Controller for login/logout actions
final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController(ref);
});

class AuthController {
  final Ref ref;
  AuthController(this.ref);

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String name,
  }) async {
    final authService = ref.read(authServiceProvider);
    final result = await authService.register(
      email: email,
      password: password,
      name: name,
    );
    
    // Refresh auth state
    ref.invalidate(authStateProvider);
    
    return result;
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final authService = ref.read(authServiceProvider);
    final result = await authService.login(
      email: email,
      password: password,
    );
    
    // Refresh auth state
    ref.invalidate(authStateProvider);
    
    return result;
  }

  Future<void> logout() async {
    final authService = ref.read(authServiceProvider);
    await authService.logout();
    
    // Refresh auth state
    ref.invalidate(authStateProvider);
  }
}
