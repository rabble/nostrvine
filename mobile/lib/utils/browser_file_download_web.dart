// ABOUTME: Web implementation of the browser file-download helper.
// ABOUTME: Built on package:web + dart:js_interop, so it is web-only.

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Hands [bytes] to the browser as a download named [fileName].
///
/// Wraps the bytes in an object URL and clicks a synthetic anchor, which is
/// the only way to name a downloaded file from Dart.
void downloadBytesAsFile({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) {
  final blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  try {
    web.HTMLAnchorElement()
      ..href = url
      ..download = fileName
      ..click();
  } finally {
    web.URL.revokeObjectURL(url);
  }
}
