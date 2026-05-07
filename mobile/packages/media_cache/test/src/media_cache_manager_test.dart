import 'dart:async';
import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:media_cache/media_cache.dart';
import 'package:mocktail/mocktail.dart';

import 'helpers/mocks.dart';
import 'helpers/test_helpers.dart';

class _TrackingIOClient extends IOClient {
  _TrackingIOClient() : super(HttpClient());

  int closeCount = 0;

  @override
  void close() {
    closeCount++;
    super.close();
  }
}

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
        );

        // Should not throw - graceful degradation
        await failingCache.initialize();
        expect(failingCache.isInitialized, true);

        failingCache.resetForTesting();
      });

      test('completes successfully when no existing cache entries', () async {
        // JsonCacheInfoRepository starts empty on first use, so the manifest
        // stays empty — initialization still succeeds.
        await cacheManager.initialize();

        expect(cacheManager.isInitialized, true);
        expect(cacheManager.getCacheStats()['manifestSize'], 0);
      });

      test('loads cache entries from repository into manifest', () async {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final cacheKey = 'db_test_$timestamp';

        // Create cache directory with an actual file on disk.
        final cacheDir = Directory('$testTempPath/$cacheKey')
          ..createSync(recursive: true);
        final testFile = await createTestFile(cacheDir, 'test_video.mp4');

        final mockRepo = MockCacheInfoRepository();
        when(mockRepo.open).thenAnswer((_) async => true);
        when(mockRepo.getAllObjects).thenAnswer(
          (_) async => [
            CacheObject(
              'https://example.com/test_video.mp4',
              relativePath: 'test_video.mp4',
              validTill: DateTime(2099),
              key: 'video_key_1',
            ),
          ],
        );

        final dbCache = MediaCacheManager(
          config: MediaCacheConfig(
            cacheKey: cacheKey,
            enableSyncManifest: true,
          ),
          tempDirectoryProvider: () async => Directory(testTempPath),
          repoOverride: mockRepo,
        );

        await dbCache.initialize();

        expect(dbCache.isInitialized, true);
        expect(dbCache.getCacheStats()['manifestSize'], 1);

        final cachedFile = dbCache.getCachedFileSync('video_key_1');
        expect(cachedFile, isNotNull);
        expect(cachedFile!.path, testFile.path);

        dbCache.resetForTesting();
        if (cacheDir.existsSync()) cacheDir.deleteSync(recursive: true);
      });

      test('skips entries with missing files', () async {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final cacheKey = 'missing_file_test_$timestamp';

        // Create cache directory but NOT the actual file.
        final cacheDir = Directory('$testTempPath/$cacheKey')
          ..createSync(recursive: true);

        final mockRepo = MockCacheInfoRepository();
        when(mockRepo.open).thenAnswer((_) async => true);
        when(mockRepo.getAllObjects).thenAnswer(
          (_) async => [
            CacheObject(
              'https://example.com/nonexistent.mp4',
              relativePath: 'nonexistent.mp4',
              validTill: DateTime(2099),
              key: 'missing_video',
            ),
          ],
        );

        final dbCache = MediaCacheManager(
          config: MediaCacheConfig(
            cacheKey: cacheKey,
            enableSyncManifest: true,
          ),
          tempDirectoryProvider: () async => Directory(testTempPath),
          repoOverride: mockRepo,
        );

        await dbCache.initialize();

        expect(dbCache.isInitialized, true);
        expect(dbCache.getCacheStats()['manifestSize'], 0);

        dbCache.resetForTesting();
        if (cacheDir.existsSync()) cacheDir.deleteSync(recursive: true);
      });

      test('skips initialization when repository.open returns false', () async {
        final mockRepo = MockCacheInfoRepository();
        when(mockRepo.open).thenAnswer((_) async => false);

        final dbCache = MediaCacheManager(
          config: MediaCacheConfig(
            cacheKey: 'open_false_${DateTime.now().millisecondsSinceEpoch}',
            enableSyncManifest: true,
          ),
          repoOverride: mockRepo,
        );

        await dbCache.initialize();

        expect(dbCache.isInitialized, true);
        expect(dbCache.getCacheStats()['manifestSize'], 0);
        verifyNever(mockRepo.getAllObjects);

        dbCache.resetForTesting();
      });

      test('handles repository query error gracefully', () async {
        final mockRepo = MockCacheInfoRepository();
        when(mockRepo.open).thenAnswer((_) async => true);
        when(mockRepo.getAllObjects).thenThrow(
          Exception('Repository corrupted'),
        );

        final dbCache = MediaCacheManager(
          config: MediaCacheConfig(
            cacheKey: 'error_test_${DateTime.now().millisecondsSinceEpoch}',
            enableSyncManifest: true,
          ),
          repoOverride: mockRepo,
        );

        await dbCache.initialize();
        expect(dbCache.isInitialized, true);

        dbCache.resetForTesting();
      });

      test('uses config.repo when no repoOverride is provided', () async {
        // Without repoOverride the manager uses SafeCacheInfoRepository
        // (wrapping JsonCacheInfoRepository). On first use that repo is empty,
        // so the manifest stays empty but initialization still succeeds.
        await cacheManager.initialize();

        expect(cacheManager.isInitialized, true);
        expect(cacheManager.getCacheStats()['manifestSize'], 0);
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

      test('returns null when file exists on disk but'
          ' not in manifest', () async {
        // Files on disk are not automatically discovered — they must be
        // registered in the repository before initialize() is called.
        final cacheDir = Directory(
          '$testTempPath/${cacheManager.mediaConfig.cacheKey}',
        )..createSync(recursive: true);
        await createTestFile(cacheDir, 'orphan_file.mp4');

        await cacheManager.initialize();

        // File exists on disk but not in manifest, so returns null.
        final file = cacheManager.getCachedFileSync('orphan_file');
        expect(file, isNull);

        // Clean up
        cacheDir.deleteSync(recursive: true);
      });

      test('removes stale entry when file no longer exists', () async {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final cacheKey = 'stale_test_$timestamp';

        final cacheDir = Directory('$testTempPath/$cacheKey')
          ..createSync(recursive: true);
        final testFile = await createTestFile(
          cacheDir,
          'will_be_deleted.mp4',
        );

        final mockRepo = MockCacheInfoRepository();
        when(mockRepo.open).thenAnswer((_) async => true);
        when(mockRepo.getAllObjects).thenAnswer(
          (_) async => [
            CacheObject(
              'https://example.com/will_be_deleted.mp4',
              relativePath: 'will_be_deleted.mp4',
              validTill: DateTime(2099),
              key: 'stale_key',
            ),
          ],
        );

        final staleCache = MediaCacheManager(
          config: MediaCacheConfig(
            cacheKey: cacheKey,
            enableSyncManifest: true,
          ),
          tempDirectoryProvider: () async => Directory(testTempPath),
          repoOverride: mockRepo,
        );

        await staleCache.initialize();

        expect(staleCache.getCacheStats()['manifestSize'], 1);
        var file = staleCache.getCachedFileSync('stale_key');
        expect(file, isNotNull);

        testFile.deleteSync();

        // getCachedFileSync detects the file is gone and evicts the stale
        // entry.
        file = staleCache.getCachedFileSync('stale_key');
        expect(file, isNull);
        expect(staleCache.getCacheStats()['manifestSize'], 0);

        staleCache.resetForTesting();
        if (cacheDir.existsSync()) cacheDir.deleteSync(recursive: true);
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

    group('close', () {
      test('closes the legacy file-service HTTP client', () async {
        final tracker = _TrackingIOClient();

        // Construction kicks off an async open() on the parent
        // CacheManager's repo store; that pipeline is unrelated to the
        // leak we're pinning. Swallow any sync/async errors it emits
        // so the assertion below is what determines pass/fail.
        await runZonedGuarded(
          () async {
            final manager = MediaCacheManager(
              config: MediaCacheConfig(
                cacheKey:
                    'close_test_${DateTime.now().millisecondsSinceEpoch}',
              ),
              repoOverride: MockCacheInfoRepository(),
              fileServiceClientOverride: tracker,
            );

            expect(tracker.closeCount, 0);

            try {
              await manager.close();
            } on Object catch (_) {}
          },
          (_, _) {},
        );

        expect(
          tracker.closeCount,
          equals(1),
          reason:
              'MediaCacheManager.close() must dispose the IOClient '
              'backing HttpFileService to avoid leaking the connection '
              'pool on every close.',
        );
      });
    });
  });
}
