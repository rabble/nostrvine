import 'package:flutter_test/flutter_test.dart';
import 'package:media_cache/src/cancellable_downloader.dart';
import 'package:media_cache/src/platform_downloader_factory_io.dart';

void main() {
  group('createPlatformDownloaderImpl', () {
    setUp(resetPlatformDownloaderFallbackStateForTesting);

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

    test('latches cupertino init failure for the process', () {
      var nativeAttempts = 0;

      final firstDownloader = createPlatformDownloaderImpl(
        connectionTimeout: const Duration(seconds: 2),
        idleTimeout: const Duration(seconds: 2),
        maxConnectionsPerHost: 2,
        allowBadCertificatesInDebug: false,
        isDebugMode: false,
        isWeb: false,
        isIOSOverride: true,
        isMacOSOverride: false,
        isAndroidOverride: false,
        cupertinoDownloaderFactory: () {
          nativeAttempts++;
          throw StateError('cupertino unavailable');
        },
      );

      final secondDownloader = createPlatformDownloaderImpl(
        connectionTimeout: const Duration(seconds: 2),
        idleTimeout: const Duration(seconds: 2),
        maxConnectionsPerHost: 2,
        allowBadCertificatesInDebug: false,
        isDebugMode: false,
        isWeb: false,
        isIOSOverride: true,
        isMacOSOverride: false,
        isAndroidOverride: false,
        cupertinoDownloaderFactory: () {
          nativeAttempts++;
          throw StateError('cupertino should be latched off');
        },
      );

      expect(firstDownloader, isA<HttpCancellableDownloader>());
      expect(secondDownloader, isA<HttpCancellableDownloader>());
      expect(nativeAttempts, 1);
    });

    test('latches cronet init failure for the process', () {
      var nativeAttempts = 0;

      final firstDownloader = createPlatformDownloaderImpl(
        connectionTimeout: const Duration(seconds: 2),
        idleTimeout: const Duration(seconds: 2),
        maxConnectionsPerHost: 2,
        allowBadCertificatesInDebug: false,
        isDebugMode: false,
        isWeb: false,
        isIOSOverride: false,
        isMacOSOverride: false,
        isAndroidOverride: true,
        cronetDownloaderFactory: () {
          nativeAttempts++;
          throw StateError('cronet unavailable');
        },
      );

      final secondDownloader = createPlatformDownloaderImpl(
        connectionTimeout: const Duration(seconds: 2),
        idleTimeout: const Duration(seconds: 2),
        maxConnectionsPerHost: 2,
        allowBadCertificatesInDebug: false,
        isDebugMode: false,
        isWeb: false,
        isIOSOverride: false,
        isMacOSOverride: false,
        isAndroidOverride: true,
        cronetDownloaderFactory: () {
          nativeAttempts++;
          throw StateError('cronet should be latched off');
        },
      );

      expect(firstDownloader, isA<HttpCancellableDownloader>());
      expect(secondDownloader, isA<HttpCancellableDownloader>());
      expect(nativeAttempts, 1);
    });

    test(
      'builds the cronet engine eagerly, falls back to dart:io when the '
      'build throws, and latches the failure for the process',
      () {
        var buildAttempts = 0;

        CancellableDownloader build() => createPlatformDownloaderImpl(
          connectionTimeout: const Duration(seconds: 2),
          idleTimeout: const Duration(seconds: 2),
          maxConnectionsPerHost: 2,
          allowBadCertificatesInDebug: false,
          isDebugMode: false,
          isWeb: false,
          isIOSOverride: false,
          isMacOSOverride: false,
          isAndroidOverride: true,
          cronetEngineFactory: () {
            buildAttempts++;
            throw StateError('All available Cronet providers are disabled');
          },
        );

        final firstDownloader = build();
        final secondDownloader = build();

        // The engine is built during creation (not deferred to the first
        // request), so the throw lands in the factory's try/catch and the
        // dart:io fallback engages. Guards against reverting to the lazy
        // `CronetClient.defaultCronetEngine()`, where the build — and its
        // throw — would never run at creation time. The first failure trips
        // the per-process `cronetUnavailable` latch via the engine-factory
        // path, so the second creation skips Cronet entirely — a single
        // build attempt across both.
        expect(buildAttempts, 1);
        expect(firstDownloader, isA<HttpCancellableDownloader>());
        expect(secondDownloader, isA<HttpCancellableDownloader>());
      },
    );
  });
}
