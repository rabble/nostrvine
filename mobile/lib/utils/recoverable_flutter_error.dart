import 'package:flutter/material.dart';
import 'package:media_cache/media_cache.dart';

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
///
/// The signature checks below match against Flutter/Dart SDK-internal library
/// paths and context descriptions (for example `_network_image_io` and
/// `image codec`). Those strings are not part of Flutter's public API and may
/// change silently on a major SDK upgrade — re-verify them when bumping
/// Flutter to a new major version.
String? classifyRecoverableFlutterError(FlutterErrorDetails details) {
  final error = details.exception.toString();
  final library = details.library ?? '';
  final context = details.context?.toDescription() ?? '';
  final hasRecoverableMediaHost = _containsRecoverableMediaHost(error);

  // Image 404s are classified by Flutter's image-loading context rather than
  // host, because a missing image from any source is recoverable — the app
  // falls back to a placeholder.
  final isImage404 =
      error.contains('HTTP request failed, statusCode: 404') &&
      (library.contains('_network_image_io') ||
          context.contains('image codec') ||
          context.contains('image resource'));

  final isMediaHostLookup =
      error.contains('SocketException') && hasRecoverableMediaHost;

  final isInterruptedMediaDownload =
      error.contains('Connection closed while receiving data') &&
      hasRecoverableMediaHost;

  final isMissingHttpHost =
      library == 'dart:_http' && error.contains('No host specified in URI');

  final isInvalidImageData =
      error.contains('Invalid image data') &&
      (library == 'dart:ui' ||
          context.contains('image codec') ||
          context.contains('instantiateImageCodecWithSize'));

  // A MediaCacheImageProvider download that finishes without a usable file
  // (dead legacy media, non-2xx, DNS failure) is recoverable by contract —
  // the widget falls back to a placeholder. It is host-agnostic because dead
  // Vine avatars are commonly proxied through web.archive.org, which is not a
  // recoverable-media host.
  final isMediaCacheLoadFailure =
      details.exception is MediaCacheImageLoadException;

  if (isImage404 ||
      isMediaHostLookup ||
      isInterruptedMediaDownload ||
      isMissingHttpHost ||
      isInvalidImageData ||
      isMediaCacheLoadFailure) {
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
