import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// The web half of [WebDownloadHelper].
///
/// This used to be written against `dart:html`, which is deprecated and is not
/// compiled by `dart2wasm` at all — so the app could not have been built for
/// WebAssembly while it was here. `package:web` is the supported replacement
/// and works under both the JavaScript and WebAssembly backends.

/// Hands the browser a file to save.
void downloadFileWeb(String content, String filename, String mimeType) {
  final bytes = utf8.encode(content);
  final blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);

  (web.document.createElement('a') as web.HTMLAnchorElement)
    ..href = url
    ..download = filename
    ..click();

  web.URL.revokeObjectURL(url);
}

/// Opens HTML in a new window and triggers the print dialog, which is how the
/// browser offers "save as PDF".
void openAndPrintWeb(String htmlContent) {
  final htmlWithPrint = htmlContent.replaceFirst('</body>',
      '<script>window.onload = function() { setTimeout(function() { window.print(); }, 500); }</script></body>');

  final blob = web.Blob(
    <JSAny>[htmlWithPrint.toJS].toJS,
    web.BlobPropertyBag(type: 'text/html'),
  );
  web.window.open(web.URL.createObjectURL(blob), '_blank');
}

/// Downloads an image straight from its URL.
void downloadImageFromUrlWeb(String imageUrl) {
  (web.document.createElement('a') as web.HTMLAnchorElement)
    ..href = imageUrl
    ..download = 'image_${DateTime.now().millisecondsSinceEpoch}.jpg'
    ..target = '_blank'
    ..click();
}
