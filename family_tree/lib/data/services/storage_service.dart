import 'dart:typed_data';
import 'package:family_tree/data/services/api_service.dart';
import 'package:family_tree/data/services/image_preparer.dart';

/// Uploads files to the Go backend.
///
/// Images are shrunk before they leave the device — see [ImagePreparer]. The
/// app never displays a photo larger than about 1600px, so sending a raw
/// 12-megapixel phone photo cost the user upload time and everyone who later
/// viewed it download time, for pixels nothing would ever show.
class StorageService {
  final ApiService _api = ApiService();

  /// Upload raw bytes with no processing. Use [uploadImage] for photos.
  Future<String?> uploadFile(
    String fileName,
    Uint8List bytes, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      return await _api.uploadFile(fileName, bytes, onProgress: onProgress);
    } on ApiException {
      rethrow;
    } catch (e) {
      print('Storage upload failed: $e');
      return null;
    }
  }

  /// Shrink and upload a photo. [onProgress] runs from 0.0 to 1.0.
  Future<String?> uploadImage(
    String fileName,
    Uint8List bytes, {
    void Function(double progress)? onProgress,
  }) async {
    final prepared = await ImagePreparer.prepare(bytes, fileName);
    return uploadFile(
      prepared.fileName,
      prepared.bytes,
      onProgress: onProgress,
    );
  }

  /// Same as [uploadImage] but sized for an avatar, which is never shown large.
  Future<String?> uploadAvatar(
    String fileName,
    Uint8List bytes, {
    void Function(double progress)? onProgress,
  }) async {
    final prepared = await ImagePreparer.prepareAvatar(bytes, fileName);
    return uploadFile(
      prepared.fileName,
      prepared.bytes,
      onProgress: onProgress,
    );
  }

  /// Videos are uploaded as-is: re-encoding one on-device is far slower than
  /// sending it, and the `image` package cannot help here.
  Future<String?> uploadVideo(
    String fileName,
    Uint8List bytes, {
    void Function(double progress)? onProgress,
  }) {
    return uploadFile(fileName, bytes, onProgress: onProgress);
  }

  /// Upload a profile photo and return the URL.
  Future<String> uploadProfilePhoto(Uint8List bytes, String fileName) async {
    final url = await uploadAvatar('profile_$fileName', bytes);
    if (url == null) {
      throw Exception('Failed to upload profile photo');
    }
    return url;
  }
}
