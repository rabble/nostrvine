import 'package:flutter_test/flutter_test.dart';
import 'package:media_cache/src/cancellable_downloader.dart';
import 'package:media_cache/src/platform_downloader_factory_io.dart';

void main() {
  group('createPlatformDownloaderImpl', () {
    test('returns HttpCancellableDownloader when isWeb is true', () {
      final downloader = createPlatformDownloaderImpl(
        connectionTimeout: const Duration(seconds: 1),
        idleTimeout: const Duration(seconds: 1),
        maxConnectionsPerHost: 1,
        allowBadCertificatesInDebug: false,
        isDebugMode: true,
        isWeb: true,
      );

      expect(downloader, isA<HttpCancellableDownloader>());
    });

    test('returns fallback HttpCancellableDownloader in debug mode', () {
      final downloader = createPlatformDownloaderImpl(
        connectionTimeout: const Duration(seconds: 2),
        idleTimeout: const Duration(seconds: 2),
        maxConnectionsPerHost: 2,
        allowBadCertificatesInDebug: true,
        isDebugMode: true,
        isWeb: false,
      );

      expect(downloader, isA<HttpCancellableDownloader>());
    });
  });
}
