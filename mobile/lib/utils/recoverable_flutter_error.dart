import 'dart:io'
    if (dart.library.js_interop) 'package:openvine/utils/platform_io_web.dart'
    as io;

import 'package:flutter/material.dart';
import 'package:media_cache/media_cache.dart';
import 'package:openvine/utils/expected_network_error.dart';

const _recoverableMediaLoadReason = 'Recoverable media load failure';
const _recoverableHeroFlightReason = 'Recoverable hero flight layout failure';
const _expectedNetworkFailureReason = 'Expected network failure';
const _recoverableMediaHosts = <String>{
  'media.divine.video',
  'cdn.divine.video',
  'divine.video',
  // Legacy Vine CDN hosts have no DNS records, the old Fastly edge certificate
  // expired on 2025-07-10, and cleartext HTTP is blocked by transport policy.
  // These media loads should fail honestly and fall back to placeholders.
  'v.cdn.vine.co',
  'cdn.vine.co',
};

/// How the app should treat a Flutter error it recovers from on its own.
typedef RecoverableFlutterError = ({
  /// The Crashlytics reason describing the recovery.
  String reason,

  /// Whether the error is still worth a non-fatal Crashlytics report.
  ///
  /// `false` where the error carries nothing actionable. The currently
  /// silenced branches are the download-without-file media-cache failure
  /// (#7298) and expected DNS failures (#7290). Other recoverable IO
  /// signatures still report, and widening that is a separate call. The error
  /// is logged and presented either way.
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

  if (isExpectedNetworkFailure(details.exception)) {
    return (reason: _expectedNetworkFailureReason, report: false);
  }

  // DNS failures are handled above by the typed expected-network predicate.
  // This string fallback stays intentionally reportable so non-DNS media-host
  // socket failures, including descriptor-lifecycle bugs, keep their signal.
  final isMediaHostLookup =
      error.contains('SocketException') && hasRecoverableMediaHost;

  // A media download the transport tears down mid-flight is recoverable — the
  // widget falls back to a placeholder. dart:io words these differently per
  // platform and per abort point ('Connection closed while receiving data'
  // when the parser runs dry, 'Software caused connection abort' when the OS
  // kills the socket), so gate on the HttpException type rather than
  // enumerating messages that keep arriving one Crashlytics issue at a time.
  // The string arm stays because a codec-wrapped load arrives already
  // stringified, with the typed exception no longer reachable. Being an `is`
  // check it also takes flutter_cache_manager's HttpExceptionWithStatus, so a
  // non-2xx CachedNetworkImage thumbnail ('Invalid statusCode: 404', which no
  // string arm matches) is recoverable here rather than fatal.
  final isInterruptedMediaDownload =
      hasRecoverableMediaHost &&
      (details.exception is io.HttpException ||
          error.contains('Connection closed while receiving data'));

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
