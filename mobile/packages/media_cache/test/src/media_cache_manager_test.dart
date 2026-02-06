import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_cache/media_cache.dart';
import 'package:mocktail/mocktail.dart';

import 'helpers/mocks.dart';
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
        // Use test paths so sqflite doesn't need to be initialized
        databasePathProvider: () async => testTempPath,
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
          databasePathProvider: () async =>
              throw Exception('Database path unavailable'),
        );

        // Should not throw - graceful degradation
        await failingCache.initialize();
        expect(failingCache.isInitialized, true);

        failingCache.resetForTesting();
      });

      test('completes successfully when no database exists', () async {
        // With the sqflite-based manifest, if no database exists,
        // initialization still succeeds (graceful degradation)
        await cacheManager.initialize();

        expect(cacheManager.isInitialized, true);
        // Manifest should be empty since no database was found
        expect(cacheManager.getCacheStats()['manifestSize'], 0);
      });

      test('loads cache entries from database into manifest', () async {
        // Create a database file so the code doesn't early-return
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final cacheKey = 'db_test_$timestamp';
        final dbFile = File('$testTempPath/$cacheKey.db')..createSync();

        // Create cache directory with actual files
        final cacheDir = Directory('$testTempPath/$cacheKey')
          ..createSync(recursive: true);
        final testFile = await createTestFile(cacheDir, 'test_video.mp4');

        // Mock database that returns cache entries
        final mockDb = MockDatabase();
        when(() => mockDb.query('cacheObject')).thenAnswer(
          (_) async => [
            {
              'key': 'video_key_1',
              'relativePath': 'test_video.mp4',
            },
          ],
        );
        when(mockDb.close).thenAnswer((_) async {});

        final dbCache = MediaCacheManager(
          config: MediaCacheConfig(
            cacheKey: cacheKey,
            enableSyncManifest: true,
          ),
          tempDirectoryProvider: () async => Directory(testTempPath),
          databasePathProvider: () async => testTempPath,
          databaseOpener: (path, {readOnly = false}) async => mockDb,
        );

        await dbCache.initialize();

        expect(dbCache.isInitialized, true);
        expect(dbCache.getCacheStats()['manifestSize'], 1);

        // Should be able to get the cached file synchronously
        final cachedFile = dbCache.getCachedFileSync('video_key_1');
        expect(cachedFile, isNotNull);
        expect(cachedFile!.path, testFile.path);

        // Clean up
        dbCache.resetForTesting();
        if (dbFile.existsSync()) dbFile.deleteSync();
        if (cacheDir.existsSync()) cacheDir.deleteSync(recursive: true);
      });

      test('skips entries with missing files', () async {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final cacheKey = 'missing_file_test_$timestamp';
        final dbFile = File('$testTempPath/$cacheKey.db')..createSync();

        // Create cache directory but NOT the actual file
        Directory('$testTempPath/$cacheKey').createSync(recursive: true);

        final mockDb = MockDatabase();
        when(() => mockDb.query('cacheObject')).thenAnswer(
          (_) async => [
            {
              'key': 'missing_video',
              'relativePath': 'nonexistent.mp4',
            },
          ],
        );
        when(mockDb.close).thenAnswer((_) async {});

        final dbCache = MediaCacheManager(
          config: MediaCacheConfig(
            cacheKey: cacheKey,
            enableSyncManifest: true,
          ),
          tempDirectoryProvider: () async => Directory(testTempPath),
          databasePathProvider: () async => testTempPath,
          databaseOpener: (path, {readOnly = false}) async => mockDb,
        );

        await dbCache.initialize();

        expect(dbCache.isInitialized, true);
        // Entry should not be added since file doesn't exist
        expect(dbCache.getCacheStats()['manifestSize'], 0);

        // Clean up
        dbCache.resetForTesting();
        if (dbFile.existsSync()) dbFile.deleteSync();
        Directory('$testTempPath/$cacheKey').deleteSync(recursive: true);
      });

      test('skips entries with null key or relativePath', () async {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final cacheKey = 'null_entries_test_$timestamp';
        final dbFile = File('$testTempPath/$cacheKey.db')..createSync();

        Directory('$testTempPath/$cacheKey').createSync(recursive: true);

        final mockDb = MockDatabase();
        when(() => mockDb.query('cacheObject')).thenAnswer(
          (_) async => [
            {'key': null, 'relativePath': 'video.mp4'},
            {'key': 'valid_key', 'relativePath': null},
            <String, Object?>{}, // Empty map
          ],
        );
        when(mockDb.close).thenAnswer((_) async {});

        final dbCache = MediaCacheManager(
          config: MediaCacheConfig(
            cacheKey: cacheKey,
            enableSyncManifest: true,
          ),
          tempDirectoryProvider: () async => Directory(testTempPath),
          databasePathProvider: () async => testTempPath,
          databaseOpener: (path, {readOnly = false}) async => mockDb,
        );

        await dbCache.initialize();

        expect(dbCache.isInitialized, true);
        expect(dbCache.getCacheStats()['manifestSize'], 0);

        // Clean up
        dbCache.resetForTesting();
        if (dbFile.existsSync()) dbFile.deleteSync();
        Directory('$testTempPath/$cacheKey').deleteSync(recursive: true);
      });

      test('handles database query error gracefully', () async {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final cacheKey = 'db_error_test_$timestamp';
        final dbFile = File('$testTempPath/$cacheKey.db')..createSync();

        final mockDb = MockDatabase();
        when(() => mockDb.query('cacheObject')).thenThrow(
          Exception('Database corrupted'),
        );
        when(mockDb.close).thenAnswer((_) async {});

        final dbCache = MediaCacheManager(
          config: MediaCacheConfig(
            cacheKey: cacheKey,
            enableSyncManifest: true,
          ),
          tempDirectoryProvider: () async => Directory(testTempPath),
          databasePathProvider: () async => testTempPath,
          databaseOpener: (path, {readOnly = false}) async => mockDb,
        );

        // Should not throw - graceful degradation
        await dbCache.initialize();
        expect(dbCache.isInitialized, true);

        // Clean up
        dbCache.resetForTesting();
        if (dbFile.existsSync()) dbFile.deleteSync();
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
          ' not in database', () async {
        // With sqflite-based manifest, files must be registered in the database
        // to appear in the manifest. Files on disk alone are not discovered.
        final cacheDir = Directory(
          '$testTempPath/${cacheManager.mediaConfig.cacheKey}',
        )..createSync(recursive: true);
        await createTestFile(cacheDir, 'orphan_file.mp4');

        await cacheManager.initialize();

        // File exists on disk but not in database, so returns null
        final file = cacheManager.getCachedFileSync('orphan_file');
        expect(file, isNull);

        // Clean up
        cacheDir.deleteSync(recursive: true);
      });

      test('removes stale entry when file no longer exists', () async {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final cacheKey = 'stale_test_$timestamp';
        final dbFile = File('$testTempPath/$cacheKey.db')..createSync();

        // Create cache directory with a file
        final cacheDir = Directory('$testTempPath/$cacheKey')
          ..createSync(recursive: true);
        final testFile = await createTestFile(cacheDir, 'will_be_deleted.mp4');

        final mockDb = MockDatabase();
        when(() => mockDb.query('cacheObject')).thenAnswer(
          (_) async => [
            {'key': 'stale_key', 'relativePath': 'will_be_deleted.mp4'},
          ],
        );
        when(mockDb.close).thenAnswer((_) async {});

        final staleCache = MediaCacheManager(
          config: MediaCacheConfig(
            cacheKey: cacheKey,
            enableSyncManifest: true,
          ),
          tempDirectoryProvider: () async => Directory(testTempPath),
          databasePathProvider: () async => testTempPath,
          databaseOpener: (path, {readOnly = false}) async => mockDb,
        );

        await staleCache.initialize();

        // Verify file is in manifest
        expect(staleCache.getCacheStats()['manifestSize'], 1);
        var file = staleCache.getCachedFileSync('stale_key');
        expect(file, isNotNull);

        // Delete the file externally
        testFile.deleteSync();

        // Should return null and remove stale entry from manifest
        file = staleCache.getCachedFileSync('stale_key');
        expect(file, isNull);
        expect(staleCache.getCacheStats()['manifestSize'], 0);

        // Clean up
        staleCache.resetForTesting();
        if (dbFile.existsSync()) dbFile.deleteSync();
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
  });
}
