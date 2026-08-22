import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

/// Platform-aware image picker that handles web vs mobile properly
class PlatformImagePicker {
  final ImagePicker _imagePicker = ImagePicker();

  /// Pick multiple images - uses file_picker on web to avoid mouse_tracker issues
  Future<List<PickedFile>> pickMultipleImages({int imageQuality = 70}) async {
    if (kIsWeb) {
      // Use file_picker on web to avoid mouse_tracker assertion errors
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        withData: true, // Get bytes for web
      );

      if (result == null || result.files.isEmpty) {
        return [];
      }

      return result.files
          .where((file) => file.bytes != null)
          .map((file) => PickedFile(
                name: file.name,
                bytes: file.bytes!,
                path: '', // Path not available on web
              ))
          .toList();
    } else {
      // Use image_picker on mobile
      final images = await _imagePicker.pickMultiImage(imageQuality: imageQuality);
      
      final List<PickedFile> pickedFiles = [];
      for (final image in images) {
        final bytes = await image.readAsBytes();
        pickedFiles.add(PickedFile(
          name: image.name,
          bytes: bytes,
          path: image.path,
        ));
      }
      return pickedFiles;
    }
  }

  /// Pick single video
  Future<PickedFile?> pickVideo() async {
    if (kIsWeb) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty || result.files.first.bytes == null) {
        return null;
      }

      final file = result.files.first;
      return PickedFile(
        name: file.name,
        bytes: file.bytes!,
        path: '', // Path not available on web
      );
    } else {
      final video = await _imagePicker.pickVideo(source: ImageSource.gallery);
      if (video == null) return null;

      final bytes = await video.readAsBytes();
      return PickedFile(
        name: video.name,
        bytes: bytes,
        path: video.path,
      );
    }
  }

  /// Pick single image from camera (mobile only)
  Future<PickedFile?> pickImageFromCamera({int imageQuality = 70}) async {
    if (kIsWeb) return null; // Camera not available on web

    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: imageQuality,
    );
    
    if (image == null) return null;

    final bytes = await image.readAsBytes();
    return PickedFile(
      name: image.name,
      bytes: bytes,
      path: image.path,
    );
  }
}

/// Simple data class for picked files
class PickedFile {
  final String name;
  final Uint8List bytes;
  final String path;

  PickedFile({
    required this.name,
    required this.bytes,
    required this.path,
  });
}
