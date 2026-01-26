import 'package:flutter_test/flutter_test.dart';
import 'package:media_cache/media_cache.dart';

void main() {
  group('MediaCacheConfig', () {
    test('can be instantiated with required parameters', () {
      const config = MediaCacheConfig(cacheKey: 'test_cache');
      expect(config.cacheKey, 'test_cache');
    });

    test('has sensible defaults', () {
      const config = MediaCacheConfig(cacheKey: 'test_cache');

      expect(config.stalePeriod, const Duration(days: 14));
      expect(config.maxNrOfCacheObjects, 200);
      expect(config.connectionTimeout, const Duration(seconds: 15));
      expect(config.idleTimeout, const Duration(seconds: 30));
      expect(config.maxConnectionsPerHost, 6);
      expect(config.enableSyncManifest, false);
      expect(config.allowBadCertificatesInDebug, true);
    });

    test('accepts custom values', () {
      const config = MediaCacheConfig(
        cacheKey: 'custom_cache',
        stalePeriod: Duration(days: 7),
        maxNrOfCacheObjects: 100,
        connectionTimeout: Duration(seconds: 20),
        idleTimeout: Duration(seconds: 45),
        maxConnectionsPerHost: 8,
        enableSyncManifest: true,
        allowBadCertificatesInDebug: false,
      );

      expect(config.cacheKey, 'custom_cache');
      expect(config.stalePeriod, const Duration(days: 7));
      expect(config.maxNrOfCacheObjects, 100);
      expect(config.connectionTimeout, const Duration(seconds: 20));
      expect(config.idleTimeout, const Duration(seconds: 45));
      expect(config.maxConnectionsPerHost, 8);
      expect(config.enableSyncManifest, true);
      expect(config.allowBadCertificatesInDebug, false);
    });

    group('video preset', () {
      test('has optimized settings for videos', () {
        const config = MediaCacheConfig.video(cacheKey: 'video_cache');

        expect(config.cacheKey, 'video_cache');
        expect(config.stalePeriod, const Duration(days: 30));
        expect(config.maxNrOfCacheObjects, 1000);
        expect(config.connectionTimeout, const Duration(seconds: 30));
        expect(config.idleTimeout, const Duration(minutes: 2));
        expect(config.maxConnectionsPerHost, 4);
        expect(config.enableSyncManifest, true);
        expect(config.allowBadCertificatesInDebug, true);
      });
    });

    group('image preset', () {
      test('has optimized settings for images', () {
        const config = MediaCacheConfig.image(cacheKey: 'image_cache');

        expect(config.cacheKey, 'image_cache');
        expect(config.stalePeriod, const Duration(days: 7));
        expect(config.maxNrOfCacheObjects, 200);
        expect(config.connectionTimeout, const Duration(seconds: 10));
        expect(config.idleTimeout, const Duration(seconds: 30));
        expect(config.maxConnectionsPerHost, 6);
        expect(config.enableSyncManifest, false);
        expect(config.allowBadCertificatesInDebug, true);
      });
    });

    group('presets comparison', () {
      test('video has longer stale period than image', () {
        const videoConfig = MediaCacheConfig.video(cacheKey: 'v');
        const imageConfig = MediaCacheConfig.image(cacheKey: 'i');

        expect(
          videoConfig.stalePeriod.inDays,
          greaterThan(imageConfig.stalePeriod.inDays),
        );
      });

      test('video has more cache objects than image', () {
        const videoConfig = MediaCacheConfig.video(cacheKey: 'v');
        const imageConfig = MediaCacheConfig.image(cacheKey: 'i');

        expect(
          videoConfig.maxNrOfCacheObjects,
          greaterThan(imageConfig.maxNrOfCacheObjects),
        );
      });

      test('video has longer timeouts than image', () {
        const videoConfig = MediaCacheConfig.video(cacheKey: 'v');
        const imageConfig = MediaCacheConfig.image(cacheKey: 'i');

        expect(
          videoConfig.connectionTimeout.inSeconds,
          greaterThan(imageConfig.connectionTimeout.inSeconds),
        );
        expect(
          videoConfig.idleTimeout.inSeconds,
          greaterThan(imageConfig.idleTimeout.inSeconds),
        );
      });

      test('video enables sync manifest, image does not', () {
        const videoConfig = MediaCacheConfig.video(cacheKey: 'v');
        const imageConfig = MediaCacheConfig.image(cacheKey: 'i');

        expect(videoConfig.enableSyncManifest, true);
        expect(imageConfig.enableSyncManifest, false);
      });
    });
  });
}
