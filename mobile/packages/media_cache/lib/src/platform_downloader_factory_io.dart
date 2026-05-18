import 'dart:io';

import 'package:cronet_http/cronet_http.dart';
import 'package:cupertino_http/cupertino_http.dart';
import 'package:http/io_client.dart';
import 'package:media_cache/src/cancellable_downloader.dart';
import 'package:unified_logger/unified_logger.dart';

/// `dart:io` implementation that selects the best native HTTP stack.
///
/// Prefers `cupertino_http` on Apple platforms and `cronet_http` on Android,
/// with `dart:io` `HttpClient` as a fallback.
CancellableDownloader createPlatformDownloaderImpl({
  required Duration connectionTimeout,
  required Duration idleTimeout,
  required int maxConnectionsPerHost,
  required bool allowBadCertificatesInDebug,
  required bool isDebugMode,
  required bool isWeb,
}) {
  if (isWeb) {
    return HttpCancellableDownloader(IOClient(HttpClient()));
  }

  // Prefer the platform-native HTTP stack:
  //   * Apple (iOS, macOS): NSURLSession via cupertino_http — gives us
  //     HTTP/2 + HTTP/3 (QUIC), shared OS-level connection pool, warm
  //     TLS sessions, and 0-RTT resumption. Materially faster on lossy
  //     links than dart:io's HTTP/1.1-only stack with a per-isolate
  //     pool, and on iOS/macOS shares the pool with AVPlayer.
  //   * Android: Cronet (Chromium net stack) via cronet_http — same
  //     story (HTTP/2 + HTTP/3, native pool). Falls back to dart:io
  //     when Cronet cannot be initialised (e.g. AOSP build without
  //     Google Play Services and no embedded Cronet asset bundled).
  // macOS in debug stays on the dart:io path so the bad-cert hook for
  // self-signed local relays keeps working; release/profile macOS
  // builds use NSURLSession.
  // Windows and Linux keep the dart:io / IOClient path.
  // coverage:ignore-start
  final useCupertino = Platform.isIOS || (Platform.isMacOS && !isDebugMode);
  if (useCupertino) {
    try {
      final cfg = URLSessionConfiguration.defaultSessionConfiguration()
        ..timeoutIntervalForRequest = connectionTimeout
        ..httpMaximumConnectionsPerHost = maxConnectionsPerHost;
      return HttpCancellableDownloader(
        CupertinoClient.fromSessionConfiguration(cfg),
      );
    } on Object catch (e, st) {
      Log.warning(
        'MediaCache: cupertino_http init failed, '
        'falling back to dart:io HttpClient: $e\n$st',
        name: 'MediaCache',
        category: LogCategory.video,
      );
    }
  } else if (Platform.isAndroid) {
    try {
      // `cronet_http` does not expose per-client connect/idle timeout knobs.
      // On Android, `connectionTimeout` and `idleTimeout` therefore do not
      // apply while Cronet is active.
      return HttpCancellableDownloader(CronetClient.defaultCronetEngine());
    } on Object catch (e, st) {
      Log.warning(
        'MediaCache: cronet_http init failed, '
        'falling back to dart:io HttpClient: $e\n$st',
        name: 'MediaCache',
        category: LogCategory.video,
      );
    }
  }
  // coverage:ignore-end

  final httpClient = HttpClient()
    ..connectionTimeout = connectionTimeout
    ..idleTimeout = idleTimeout
    ..maxConnectionsPerHost = maxConnectionsPerHost;

  if (allowBadCertificatesInDebug &&
      isDebugMode &&
      (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
    httpClient.badCertificateCallback = (cert, host, port) => true;
  }

  return HttpCancellableDownloader(IOClient(httpClient));
}
