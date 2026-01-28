import 'package:flutter/foundation.dart' show kIsWeb;

// Conditional import for web
// ignore: avoid_web_libraries_in_flutter
import 'web_download_stub.dart' if (dart.library.html) 'web_download_impl.dart' as download;

/// Platform-safe file download utility
class WebDownloadHelper {
  static void downloadFile(String content, String filename, String mimeType) {
    if (kIsWeb) {
      download.downloadFileWeb(content, filename, mimeType);
    } else {
      // For mobile, we could use path_provider and share_plus
      // For now, just log
      print('Mobile download not yet implemented for: $filename');
    }
  }
  
  /// Opens HTML content in a new window and triggers print dialog for PDF save
  static void openAndPrint(String htmlContent) {
    if (kIsWeb) {
      download.openAndPrintWeb(htmlContent);
    } else {
      print('Print to PDF not implemented for mobile');
    }
  }
  
  /// Downloads an image from URL (web only)
  static void downloadImageFromUrl(String imageUrl) {
    if (kIsWeb) {
      download.downloadImageFromUrlWeb(imageUrl);
    } else {
      print('Image download not implemented for mobile');
    }
  }
}
