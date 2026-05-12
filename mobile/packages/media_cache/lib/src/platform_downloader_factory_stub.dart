import 'package:http/http.dart' as http;
import 'package:media_cache/src/cancellable_downloader.dart';

/// Fallback implementation used on platforms without `dart:io`.
///
/// Returns a plain `http.Client` based downloader.
CancellableDownloader createPlatformDownloaderImpl({
  required Duration connectionTimeout,
  required Duration idleTimeout,
  required int maxConnectionsPerHost,
  required bool allowBadCertificatesInDebug,
  required bool isDebugMode,
  required bool isWeb,
}) {
  return HttpCancellableDownloader(http.Client());
}
