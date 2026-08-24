import 'package:flutter/foundation.dart' show kIsWeb;

// The web implementation is selected by dart.library.js_interop rather than
// dart.library.html: the implementation is written against package:web now,
// and the html guard does not hold under the WebAssembly backend.
import 'web_download_stub.dart'
    if (dart.library.js_interop) 'web_download_impl.dart' as download;
import 'package:family_tree/core/logging.dart';

/// Platform-safe file download utility
class WebDownloadHelper {
  static void downloadFile(String content, String filename, String mimeType) {
    if (kIsWeb) {
      download.downloadFileWeb(content, filename, mimeType);
    } else {
      // For mobile, we could use path_provider and share_plus
      // For now, just log
      log('Downloads are not implemented on this platform');
    }
  }

  /// Opens HTML content in a new window and triggers print dialog for PDF save
  static void openAndPrint(String htmlContent) {
    if (kIsWeb) {
      download.openAndPrintWeb(htmlContent);
    } else {
      log('Printing is not implemented on this platform');
    }
  }

  /// Downloads an image from URL (web only)
  static void downloadImageFromUrl(String imageUrl) {
    if (kIsWeb) {
      download.downloadImageFromUrlWeb(imageUrl);
    } else {
      log('Image download is not implemented on this platform');
    }
  }
}
