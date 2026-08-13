import 'package:flutter/material.dart';
import 'package:media_cache/media_cache.dart';

const _recoverableMediaLoadReason = 'Recoverable media load failure';
const _recoverableHeroFlightReason = 'Recoverable hero flight layout failure';
const _recoverableMediaHosts = <String>{
  'media.divine.video',
  'cdn.divine.video',
  'divine.video',
  'v.cdn.vine.co',
  'cdn.vine.co',
};

/// How the app should treat a Flutter error it recovers from on its own.
typedef RecoverableFlutterError = ({
  /// The Crashlytics reason describing the recovery.
  String reason,

  /// Whether the error is still worth a non-fatal Crashlytics report.
  ///
  /// `false` for expected IO conditions: per the decision matrix in
  /// `.claude/rules/error_handling.md`, network and IO failures are not
  /// reportable, so recording them only drowns real bugs in the dashboard.
  /// The error is still logged and still presented.
  bool report,
});

/// Returns how to handle a Flutter error the app recovers from on its own, or
/// `null` when it must stay fatal.
///
/// The signature checks below match against Flutter/Dart SDK internals:
/// library paths, context descriptions (for example `_network_image_io` and
/// `image codec`), and stack frame symbols (`HeroController`). None are part
/// of Flutter's public API and they may change silently on a major SDK
/// upgrade — re-verify them when bumping Flutter to a new major version. The
/// stack frame match additionally assumes release builds keep Dart symbols in
/// `StackTrace.toString()`: building with `--obfuscate` *or*
/// `--split-debug-info` (which implies `--dwarf-stack-traces`) strips them and
/// silently sends those errors back to the fatal path.
RecoverableFlutterError? classifyRecoverableFlutterError(
  FlutterErrorDetails details,
) {
  final error = details.exception.toString();
  final library = details.library ?? '';
  final context = details.context?.toDescription() ?? '';
  final hasRecoverableMediaHost = _containsRecoverableMediaHost(error);

  // A raw NetworkImage load that fails with any non-200 HTTP status is
  // recoverable — the widget falls back to a placeholder. Flutter throws the
  // same NetworkImageLoadException ("HTTP request failed, statusCode: <code>")
  // for every response where statusCode != 200 — 404 (missing), 401/403
  // (unauthorized), and 5xx (server error) alike — so match the
  // status-agnostic prefix rather than a single code. Classified by Flutter's
  // image-loading library/context rather than host, because a failed image
  // from any source is recoverable.
  final isImageHttpFailure =
      error.contains('HTTP request failed, statusCode: ') &&
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
  //
  // Reported as a plain IO failure and therefore never sent to Crashlytics
  // (#7298): the exception carries no information beyond "this URL is dead",
  // which the avatar/thumbnail negative caches already act on. It accounted
  // for 13 events across 10 users in a week with nothing actionable in any
  // of them.
  if (details.exception is MediaCacheImageLoadException) {
    return (reason: _recoverableMediaLoadReason, report: false);
  }

  if (isImageHttpFailure ||
      isMediaHostLookup ||
      isInterruptedMediaDownload ||
      isMissingHttpHost ||
      isInvalidImageData) {
    return (reason: _recoverableMediaLoadReason, report: true);
  }

  // A hero flight measures its destination hero in a post-frame callback, and
  // a route added to the pages stack under an opaque cover was never laid out
  // — release's RenderBox.size throws where debug would assert. The scheduler
  // catches it and skips the flight, so nothing actually crashes
  // (flutter/flutter#136356, closed unfixed; only the swipe-back variant is
  // guarded upstream). The stack gate is what keeps a genuine app layout bug
  // fatal, and is read lazily so the common path never stringifies a stack.
  final isHeroFlightLayoutFailure =
      error.contains('RenderBox was not laid out') &&
      (details.stack?.toString().contains('HeroController') ?? false);

  if (isHeroFlightLayoutFailure) {
    return (reason: _recoverableHeroFlightReason, report: true);
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
