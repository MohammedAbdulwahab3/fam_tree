import 'dart:convert';
import 'package:family_tree/data/services/api_service.dart';

class AuthService {
  final ApiService _apiService = ApiService();

  // Current user data
  Map<String, dynamic>? _currentUser;
  String? _currentToken;

  Map<String, dynamic>? get currentUser => _currentUser;
  String? get currentUserId => _currentUser?['id'];
  bool get isAuthenticated => _currentToken != null;

  // Initialize - load token and validate
  Future<void> init() async {
    await _apiService.init();
    // TODO: Optionally verify token with a /me endpoint
  }

  // Register
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final response = await _apiService.post(
        '/register',
        body: {
          'email': email,
          'password': password,
          'name': name,
        },
        includeAuth: false,
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        _currentToken = data['token'];
        _currentUser = data['user'];
        await _apiService.setToken(_currentToken!);
        return {'success': true};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['error'] ?? 'Registration failed'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Login
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiService.post(
        '/login',
        body: {
          'email': email,
          'password': password,
        },
        includeAuth: false,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _currentToken = data['token'];
        _currentUser = data['user'];
        await _apiService.setToken(_currentToken!);
        return {'success': true};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['error'] ?? 'Login failed'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Logout
  Future<void> logout() async {
    _currentToken = null;
    _currentUser = null;
    await _apiService.clearToken();
  }

  // Get current user (for compatibility with existing code)
  dynamic getCurrentUser() {
    return _currentUser;
  }
}
