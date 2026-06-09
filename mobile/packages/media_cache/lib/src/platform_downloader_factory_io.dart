import 'dart:io';

import 'package:cronet_http/cronet_http.dart';
import 'package:cupertino_http/cupertino_http.dart';
import 'package:flutter/foundation.dart';
import 'package:http/io_client.dart';
import 'package:media_cache/src/cancellable_downloader.dart';
import 'package:unified_logger/unified_logger.dart';

/// Factory for a platform-native [CancellableDownloader].
typedef NativeDownloaderFactory = CancellableDownloader Function();

final _nativeFallbackState = _NativeDownloaderFallbackState();

final class _NativeDownloaderFallbackState {
  bool cupertinoUnavailable = false;
  bool cronetUnavailable = false;

  void reset() {
    cupertinoUnavailable = false;
    cronetUnavailable = false;
  }
}

/// Clears the per-process native downloader fallback latches.
@visibleForTesting
void resetPlatformDownloaderFallbackStateForTesting() {
  _nativeFallbackState.reset();
}

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
  @visibleForTesting bool? isIOSOverride,
  @visibleForTesting bool? isMacOSOverride,
  @visibleForTesting bool? isAndroidOverride,
  @visibleForTesting NativeDownloaderFactory? cupertinoDownloaderFactory,
  @visibleForTesting NativeDownloaderFactory? cronetDownloaderFactory,
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
  final isIOS = isIOSOverride ?? Platform.isIOS;
  final isMacOS = isMacOSOverride ?? Platform.isMacOS;
  final isAndroid = isAndroidOverride ?? Platform.isAndroid;
  // coverage:ignore-start
  final useCupertino = isIOS || (isMacOS && !isDebugMode);
  if (useCupertino && !_nativeFallbackState.cupertinoUnavailable) {
    try {
      return cupertinoDownloaderFactory?.call() ??
          _createCupertinoDownloader(
            connectionTimeout: connectionTimeout,
            maxConnectionsPerHost: maxConnectionsPerHost,
          );
    } on Object catch (e, st) {
      _nativeFallbackState.cupertinoUnavailable = true;
      Log.warning(
        'MediaCache: cupertino_http init failed, '
        'using dart:io HttpClient for the rest of this process: $e',
        name: 'MediaCache',
        category: LogCategory.video,
      );
      Log.debug(
        'MediaCache: cupertino_http init stack trace: $st',
        name: 'MediaCache',
        category: LogCategory.video,
      );
    }
  } else if (isAndroid && !_nativeFallbackState.cronetUnavailable) {
    try {
      // `cronet_http` does not expose per-client connect/idle timeout knobs.
      // On Android, `connectionTimeout` and `idleTimeout` therefore do not
      // apply while Cronet is active.
      return cronetDownloaderFactory?.call() ?? _createCronetDownloader();
    } on Object catch (e, st) {
      _nativeFallbackState.cronetUnavailable = true;
      Log.warning(
        'MediaCache: cronet_http init failed, '
        'using dart:io HttpClient for the rest of this process: $e',
        name: 'MediaCache',
        category: LogCategory.video,
      );
      Log.debug(
        'MediaCache: cronet_http init stack trace: $st',
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

// coverage:ignore-start
CancellableDownloader _createCupertinoDownloader({
  required Duration connectionTimeout,
  required int maxConnectionsPerHost,
}) {
  final cfg = URLSessionConfiguration.defaultSessionConfiguration()
    ..timeoutIntervalForRequest = connectionTimeout
    ..httpMaximumConnectionsPerHost = maxConnectionsPerHost;
  return HttpCancellableDownloader(
    CupertinoClient.fromSessionConfiguration(cfg),
  );
}
// coverage:ignore-end

// coverage:ignore-start
CancellableDownloader _createCronetDownloader() {
  return HttpCancellableDownloader(CronetClient.defaultCronetEngine());
}

// coverage:ignore-end
