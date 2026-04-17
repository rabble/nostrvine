import 'dart:typed_data';

import 'package:openvine/services/web_video_object_url_factory_stub.dart'
    if (dart.library.html) 'package:openvine/services/web_video_object_url_factory_web.dart'
    as object_url_factory;

String createWebVideoObjectUrl(
  Uint8List bytes, {
  String mimeType = 'application/octet-stream',
}) => object_url_factory.createWebVideoObjectUrl(
  bytes,
  mimeType: mimeType,
);

void revokeWebVideoObjectUrl(String url) =>
    object_url_factory.revokeWebVideoObjectUrl(url);
