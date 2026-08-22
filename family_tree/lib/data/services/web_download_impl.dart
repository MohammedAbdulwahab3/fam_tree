import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Web implementation for file download
void downloadFileWeb(String content, String filename, String mimeType) {
  final bytes = utf8.encode(content);
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}

/// Opens HTML in new window and triggers print dialog for PDF save
void openAndPrintWeb(String htmlContent) {
  // Add print script to HTML to auto-trigger print dialog
  final htmlWithPrint = htmlContent.replaceFirst(
    '</body>',
    '<script>window.onload = function() { setTimeout(function() { window.print(); }, 500); }</script></body>'
  );
  
  final blob = html.Blob([htmlWithPrint], 'text/html');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.window.open(url, '_blank');
}

/// Downloads an image from URL
void downloadImageFromUrlWeb(String imageUrl) {
  final anchor = html.AnchorElement(href: imageUrl)
    ..setAttribute('download', 'image_${DateTime.now().millisecondsSinceEpoch}.jpg')
    ..setAttribute('target', '_blank');
  anchor.click();
}
