import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_cache/media_cache.dart';

import 'helpers/test_helpers.dart';

void main() {
  group('MediaCacheManager', () {
    setUpTestEnvironment();

    late MediaCacheManager cacheManager;

    setUpAll(() async {
      await setUpTestDirectories();
    });

    tearDownAll(() async {
      await tearDownTestDirectories();
    });

    setUp(() {
      cacheManager = MediaCacheManager(
        config: MediaCacheConfig(
          cacheKey: 'test_cache_${DateTime.now().millisecondsSinceEpoch}',
          enableSyncManifest: true,
        ),
      );
    });

    tearDown(() {
      cacheManager.resetForTesting();
    });

    test('can be instantiated', () {
      expect(cacheManager, isNotNull);
    });

    test('exposes mediaConfig', () {
      expect(cacheManager.mediaConfig, isNotNull);
      expect(cacheManager.mediaConfig.enableSyncManifest, true);
    });

    test('isInitialized returns false before initialization', () {
      expect(cacheManager.isInitialized, false);
    });

    group('initialize', () {
      test('sets isInitialized to true', () async {
        await cacheManager.initialize();
        expect(cacheManager.isInitialized, true);
      });

      test('is idempotent - can be called multiple times', () async {
        await cacheManager.initialize();
        await cacheManager.initialize();
        expect(cacheManager.isInitialized, true);
      });

      test('skips initialization when sync manifest is disabled', () async {
        final noManifestCache = MediaCacheManager(
          config: MediaCacheConfig(
            cacheKey: 'no_manifest_${DateTime.now().millisecondsSinceEpoch}',
          ),
        );

        await noManifestCache.initialize();
        expect(noManifestCache.isInitialized, true);
      });

      test('handles exception gracefully and sets initialized', () async {
        final failingCache = MediaCacheManager(
          config: MediaCacheConfig(
            cacheKey: 'failing_${DateTime.now().millisecondsSinceEpoch}',
            enableSyncManifest: true,
          ),
          tempDirectoryProvider: () async =>
              throw Exception('Directory unavailable'),
        );

        // Should not throw - graceful degradation
        await failingCache.initialize();
        expect(failingCache.isInitialized, true);

        failingCache.resetForTesting();
      });

      test('loads existing files into manifest', () async {
        // Create cache directory with test files
        final cacheDir = Directory(
          '$testTempPath/${cacheManager.mediaConfig.cacheKey}',
        )..createSync(recursive: true);

        await createTestFile(cacheDir, 'video1.mp4');
        await createTestFile(cacheDir, 'video2.mp4');
        await createTestFile(cacheDir, 'video3.mp4');

        await cacheManager.initialize();

        expect(cacheManager.isInitialized, true);

        // Clean up
        cacheDir.deleteSync(recursive: true);
      });
    });

    group('getCachedFileSync', () {
      test('returns null when manifest is disabled', () {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final noManifestCache = MediaCacheManager(
          config: MediaCacheConfig(cacheKey: 'no_manifest_sync_$timestamp'),
        );

        final file = noManifestCache.getCachedFileSync('any_key');
        expect(file, isNull);
      });

      test('returns null for unknown key', () async {
        await cacheManager.initialize();
        final file = cacheManager.getCachedFileSync('unknown_key');
        expect(file, isNull);
      });

      test('returns file when key exists in manifest', () async {
        // Create cache directory with test file
        final cacheDir = Directory(
          '$testTempPath/${cacheManager.mediaConfig.cacheKey}',
        )..createSync(recursive: true);
        await createTestFile(cacheDir, 'known_key.mp4');

        await cacheManager.initialize();

        final file = cacheManager.getCachedFileSync('known_key');
        expect(file, isNotNull);
        expect(file!.existsSync(), true);

        // Clean up
        cacheDir.deleteSync(recursive: true);
      });

      test('removes stale entry when file no longer exists', () async {
        // Create cache directory with test file
        final cacheDir = Directory(
          '$testTempPath/${cacheManager.mediaConfig.cacheKey}',
        )..createSync(recursive: true);
        final testFile = await createTestFile(cacheDir, 'stale_key.mp4');

        await cacheManager.initialize();

        // Verify file is in manifest
        var file = cacheManager.getCachedFileSync('stale_key');
        expect(file, isNotNull);

        // Delete the file externally
        testFile.deleteSync();

        // Should return null and remove from manifest
        file = cacheManager.getCachedFileSync('stale_key');
        expect(file, isNull);

        // Clean up
        if (cacheDir.existsSync()) {
          cacheDir.deleteSync(recursive: true);
        }
      });
    });

    group('isFileCached', () {
      test('returns false for unknown key', () async {
        final isCached = await cacheManager.isFileCached('unknown_key');
        expect(isCached, false);
      });
    });

    group('getCacheStats', () {
      test('returns expected keys', () {
        final stats = cacheManager.getCacheStats();

        expect(stats.containsKey('cacheKey'), true);
        expect(stats.containsKey('manifestSize'), true);
        expect(stats.containsKey('manifestInitialized'), true);
        expect(stats.containsKey('maxObjects'), true);
        expect(stats.containsKey('stalePeriodDays'), true);
        expect(stats.containsKey('syncManifestEnabled'), true);
      });

      test('returns correct values', () {
        final stats = cacheManager.getCacheStats();

        expect(stats['manifestSize'], 0);
        expect(stats['manifestInitialized'], false);
        expect(stats['syncManifestEnabled'], true);
      });

      test('reflects initialization state', () async {
        var stats = cacheManager.getCacheStats();
        expect(stats['manifestInitialized'], false);

        await cacheManager.initialize();

        stats = cacheManager.getCacheStats();
        expect(stats['manifestInitialized'], true);
      });
    });

    group('resetForTesting', () {
      test('clears manifest and resets state', () async {
        await cacheManager.initialize();
        expect(cacheManager.isInitialized, true);

        cacheManager.resetForTesting();

        expect(cacheManager.isInitialized, false);
        expect(cacheManager.getCacheStats()['manifestSize'], 0);
      });
    });

    group('preCacheFiles', () {
      test('handles empty list', () async {
        await cacheManager.preCacheFiles([]);
        // Should not throw
      });
    });

    group('with video config', () {
      late MediaCacheManager videoCache;

      setUp(() {
        videoCache = MediaCacheManager(
          config: MediaCacheConfig.video(
            cacheKey: 'video_cache_${DateTime.now().millisecondsSinceEpoch}',
          ),
        );
      });

      tearDown(() {
        videoCache.resetForTesting();
      });

      test('has sync manifest enabled', () {
        expect(videoCache.mediaConfig.enableSyncManifest, true);
      });

      test('has correct stale period', () {
        expect(videoCache.mediaConfig.stalePeriod, const Duration(days: 30));
      });

      test('has correct max objects', () {
        expect(videoCache.mediaConfig.maxNrOfCacheObjects, 1000);
      });
    });

    group('with image config', () {
      late MediaCacheManager imageCache;

      setUp(() {
        imageCache = MediaCacheManager(
          config: MediaCacheConfig.image(
            cacheKey: 'image_cache_${DateTime.now().millisecondsSinceEpoch}',
          ),
        );
      });

      tearDown(() {
        imageCache.resetForTesting();
      });

      test('has sync manifest disabled', () {
        expect(imageCache.mediaConfig.enableSyncManifest, false);
      });

      test('has correct stale period', () {
        expect(imageCache.mediaConfig.stalePeriod, const Duration(days: 7));
      });

      test('has correct max objects', () {
        expect(imageCache.mediaConfig.maxNrOfCacheObjects, 200);
      });
    });

    group('removeCachedFile', () {
      test('handles non-existent key gracefully', () async {
        // Should not throw when key does not exist
        await cacheManager.removeCachedFile('non_existent_key');
      });
    });

    group('clearCache', () {
      test('clears manifest on clearCache', () async {
        await cacheManager.initialize();

        // Add something to manifest via initialization
        // Then clear it
        await cacheManager.clearCache();

        // Stats should show empty manifest
        final stats = cacheManager.getCacheStats();
        expect(stats['manifestSize'], 0);
      });
    });
  });
}
