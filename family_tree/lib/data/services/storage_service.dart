import 'dart:typed_data';
import 'package:family_tree/data/services/api_service.dart';

/// Storage service that uploads files to the Go backend
class StorageService {
  final ApiService _api = ApiService();

  /// Upload a file to the Go backend and return the full URL
  Future<String?> uploadFile(String fileName, Uint8List bytes) async {
    try {
      final url = await _api.uploadFile(fileName, bytes);
      return url;
    } catch (e) {
      print('Storage upload failed: $e');
      return null;
    }
  }

  /// Upload an image
  Future<String?> uploadImage(String fileName, Uint8List bytes) async {
    return uploadFile(fileName, bytes);
  }

  /// Upload a video
  Future<String?> uploadVideo(String fileName, Uint8List bytes) async {
    return uploadFile(fileName, bytes);
  }

  /// Upload a profile photo and return the URL
  Future<String> uploadProfilePhoto(Uint8List bytes, String fileName) async {
    final url = await uploadFile('profile_$fileName', bytes);
    if (url == null) {
      throw Exception('Failed to upload profile photo');
    }
    return url;
  }
}
