import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// The outcome of preparing an image for upload.
class PreparedImage {
  const PreparedImage({
    required this.bytes,
    required this.fileName,
    required this.originalBytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final String fileName;

  /// Size of what the user picked, for reporting how much was saved.
  final int originalBytes;
  final int width;
  final int height;

  int get sizeBytes => bytes.length;
  bool get wasReduced => originalBytes > sizeBytes;

  /// e.g. "4.2 MB → 180 KB"
  String get savingSummary => '${_human(originalBytes)} → ${_human(sizeBytes)}';

  static String _human(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Shrinks a picked photo before it goes anywhere near the network.
///
/// A photo straight off a phone is 8–15 MB and several thousand pixels wide.
/// Uploading that raw meant a minute of blank spinner on a slow connection, a
/// server disk filling with images nothing ever displays at full size, and
/// every viewer paying to download it again. Nothing in this app shows a photo
/// larger than a full-screen viewer, so [maxEdge] is all anyone will ever see.
class ImagePreparer {
  /// Longest edge of the stored image. Comfortably above any display size in
  /// the app, including a full-screen viewer on a high-density tablet.
  static const int maxEdge = 1600;

  /// Longest edge for a profile photo, which is only ever shown small.
  static const int maxAvatarEdge = 512;

  /// JPEG quality. 82 is the point where artefacts stop being visible on
  /// photographs while the file is a fraction of the size.
  static const int quality = 82;

  /// Prepare a picked image. Falls back to the original bytes if the image
  /// cannot be decoded — an upload that works is better than one that refuses
  /// a format the `image` package does not know.
  static Future<PreparedImage> prepare(
    Uint8List bytes,
    String fileName, {
    int? maxDimension,
  }) async {
    final limit = maxDimension ?? maxEdge;

    try {
      // Off the UI thread: decoding a 12-megapixel JPEG takes long enough to
      // drop frames. (On web `compute` runs inline, which is the platform's
      // limitation rather than a choice here.)
      final result = await compute(
        _resizeInIsolate,
        _ResizeRequest(bytes: bytes, maxEdge: limit, quality: quality),
      );

      if (result == null) {
        return PreparedImage(
          bytes: bytes,
          fileName: fileName,
          originalBytes: bytes.length,
          width: 0,
          height: 0,
        );
      }

      return PreparedImage(
        bytes: result.bytes,
        fileName: _asJpegName(fileName),
        originalBytes: bytes.length,
        width: result.width,
        height: result.height,
      );
    } catch (_) {
      // Never block an upload because the shrink failed.
      return PreparedImage(
        bytes: bytes,
        fileName: fileName,
        originalBytes: bytes.length,
        width: 0,
        height: 0,
      );
    }
  }

  /// Prepare a profile photo, which needs far fewer pixels than a feed photo.
  static Future<PreparedImage> prepareAvatar(
          Uint8List bytes, String fileName) =>
      prepare(bytes, fileName, maxDimension: maxAvatarEdge);

  static String _asJpegName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    final stem = dot > 0 ? fileName.substring(0, dot) : fileName;
    return '$stem.jpg';
  }
}

class _ResizeRequest {
  const _ResizeRequest({
    required this.bytes,
    required this.maxEdge,
    required this.quality,
  });

  final Uint8List bytes;
  final int maxEdge;
  final int quality;
}

class _ResizeResult {
  const _ResizeResult({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;
}

/// Runs on a background isolate. Top-level by necessity — `compute` cannot
/// take a closure.
_ResizeResult? _resizeInIsolate(_ResizeRequest request) {
  final decoded = img.decodeImage(request.bytes);
  if (decoded == null) return null;

  // Phone photos carry an orientation tag rather than rotated pixels; without
  // baking it in, portrait shots upload sideways.
  final oriented = img.bakeOrientation(decoded);

  final longest =
      oriented.width > oriented.height ? oriented.width : oriented.height;

  final resized = longest <= request.maxEdge
      ? oriented
      : img.copyResize(
          oriented,
          width: oriented.width >= oriented.height ? request.maxEdge : null,
          height: oriented.height > oriented.width ? request.maxEdge : null,
          interpolation: img.Interpolation.average,
        );

  final encoded = img.encodeJpg(resized, quality: request.quality);

  return _ResizeResult(
    bytes: Uint8List.fromList(encoded),
    width: resized.width,
    height: resized.height,
  );
}
