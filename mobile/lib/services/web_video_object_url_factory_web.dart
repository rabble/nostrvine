// ignore: deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

String createWebVideoObjectUrl(
  Uint8List bytes, {
  String mimeType = 'application/octet-stream',
}) {
  final blob = html.Blob([bytes], mimeType);
  return html.Url.createObjectUrlFromBlob(blob);
}

void revokeWebVideoObjectUrl(String url) {
  html.Url.revokeObjectUrl(url);
}
