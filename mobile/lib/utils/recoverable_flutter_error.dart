import 'package:flutter/material.dart';

const _recoverableMediaLoadReason = 'Recoverable media load failure';
const _recoverableMediaHosts = <String>{
  'media.divine.video',
  'cdn.divine.video',
  'divine.video',
  'v.cdn.vine.co',
  'cdn.vine.co',
};

/// Returns a non-fatal reporting reason when a Flutter error represents a
/// recoverable media or image loading failure.
String? classifyRecoverableFlutterError(FlutterErrorDetails details) {
  final error = details.exception.toString();
  final library = details.library ?? '';
  final context = details.context?.toDescription() ?? '';

  final isImage404 =
      error.contains('HTTP request failed, statusCode: 404') &&
      (library.contains('_network_image_io') ||
          context.contains('image codec') ||
          context.contains('image resource'));

  final isMediaHostLookup =
      error.contains('SocketException') && _containsRecoverableMediaHost(error);

  final isInterruptedMediaDownload =
      error.contains('Connection closed while receiving data') &&
      _containsRecoverableMediaHost(error);

  final isInvalidImageData =
      error.contains('Invalid image data') &&
      (library == 'dart:ui' ||
          context.contains('image codec') ||
          context.contains('instantiateImageCodecWithSize'));

  if (isImage404 ||
      isMediaHostLookup ||
      isInterruptedMediaDownload ||
      isInvalidImageData) {
    return _recoverableMediaLoadReason;
  }

  return null;
}

bool _containsRecoverableMediaHost(String value) {
  for (final host in _recoverableMediaHosts) {
    if (value.contains(host)) {
      return true;
    }
  }
  return false;
}
