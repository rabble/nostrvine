import 'dart:typed_data';

String createWebVideoObjectUrl(
  Uint8List bytes, {
  String mimeType = 'application/octet-stream',
}) {
  throw UnsupportedError('Web video object URLs are only supported on web');
}

void revokeWebVideoObjectUrl(String url) {}
