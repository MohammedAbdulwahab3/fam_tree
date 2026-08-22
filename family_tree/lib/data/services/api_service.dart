import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class ApiService {
  // Production backend URL (AWS ECS)
  static const String baseUrl = 'http://13.60.94.189:5000';
  
  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Initialize - no longer needed for token but kept for compatibility
  Future<void> init() async {}

  // Set token - no longer needed
  Future<void> setToken(String token) async {}

  // Clear token - no longer needed
  Future<void> clearToken() async {}

  // Get headers
  Future<Map<String, String>> _getHeaders({bool includeAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (includeAuth) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          final token = await user.getIdToken();
          if (token != null) {
            // print('ApiService: Got token: ${token.substring(0, 10)}...');
            headers['Authorization'] = 'Bearer $token';
          } else {
            print('ApiService: Token is null');
          }
        } catch (e) {
          print('ApiService: Error getting token: $e');
        }
      } else {
        // Silently handle null user - normal when not logged in
        // print('ApiService: User is null');
      }
    }
    return headers;
  }

  // POST request
  Future<http.Response> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool includeAuth = true,
  }) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders(includeAuth: includeAuth);
    final response = await http.post(
      url,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return response;
  }

  // GET request
  Future<http.Response> get(
    String endpoint, {
    bool includeAuth = true,
  }) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders(includeAuth: includeAuth);
    final response = await http.get(
      url,
      headers: headers,
    );
    return response;
  }

  // PUT request
  Future<http.Response> put(
    String endpoint, {
    Map<String, dynamic>? body,
    bool includeAuth = true,
  }) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders(includeAuth: includeAuth);
    final response = await http.put(
      url,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return response;
  }

  // DELETE request
  Future<http.Response> delete(
    String endpoint, {
    bool includeAuth = true,
  }) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders(includeAuth: includeAuth);
    final response = await http.delete(
      url,
      headers: headers,
    );
    return response;
  }

  // Upload file
  Future<String?> uploadFile(String filePath, List<int> fileBytes) async {
    try {
      final url = Uri.parse('$baseUrl/api/upload');
      final request = http.MultipartRequest('POST', url);
      
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: filePath.split('/').last,
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return '$baseUrl${data['url']}';
      }
      return null;
    } catch (e) {
      print('Upload error: $e');
      return null;
    }
  }
}
