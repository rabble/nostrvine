import 'package:media_cache/src/cancellable_downloader.dart';
import 'package:media_cache/src/platform_downloader_factory_stub.dart'
    if (dart.library.io) 'package:media_cache/src/platform_downloader_factory_io.dart';

/// Creates a platform-appropriate cancellable HTTP downloader.
///
/// Uses conditional imports so web builds never load `dart:io`/FFI-backed
/// implementations.
CancellableDownloader createPlatformDownloader({
  required Duration connectionTimeout,
  required Duration idleTimeout,
  required int maxConnectionsPerHost,
  required bool allowBadCertificatesInDebug,
  required bool isDebugMode,
  required bool isWeb,
}) => createPlatformDownloaderImpl(
  connectionTimeout: connectionTimeout,
  idleTimeout: idleTimeout,
  maxConnectionsPerHost: maxConnectionsPerHost,
  allowBadCertificatesInDebug: allowBadCertificatesInDebug,
  isDebugMode: isDebugMode,
  isWeb: isWeb,
);
