// ignore_for_file: unnecessary_lambdas

import 'package:flutter_test/flutter_test.dart';
import 'package:media_cache/media_cache.dart';
import 'package:mocktail/mocktail.dart';

import 'helpers/mocks.dart';
import 'helpers/test_helpers.dart';

void main() {
  setUpTestEnvironment();

  group('MediaCacheManager with mocks', () {
    late List<String> logMessages;
    late TestableMediaCacheManager cacheManager;

    setUpAll(() async {
      await setUpTestDirectories();
    });

    tearDownAll(() async {
      await tearDownTestDirectories();
    });

    setUp(() {
      logMessages = [];
    });

    tearDown(() {
      cacheManager.resetForTesting();
    });

    group('cacheFile', () {
      test('returns existing file when already cached', () async {
        final mockFile = MockFile();
        final mockFileInfo = MockFileInfo();

        when(() => mockFile.existsSync()).thenReturn(true);
        when(() => mockFile.path).thenReturn('/test/path/video.mp4');
        when(() => mockFileInfo.file).thenReturn(mockFile);

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        cacheManager = TestableMediaCacheManager(
          config: MediaCacheConfig(
            cacheKey: 'cache_test_$timestamp',
            enableSyncManifest: true,
            onDebug: logMessages.add,
            onInfo: logMessages.add,
          ),
          mockGetFileFromCache: (key) async => mockFileInfo,
        );

        final result = await cacheManager.cacheFile(
          'https://example.com/video.mp4',
          key: 'test_key',
        );

        expect(result, isNotNull);
        expect(result!.path, '/test/path/video.mp4');
        expect(
          logMessages.any((m) => m.contains('already cached')),
          true,
        );
      });

      test('downloads and caches new file', () async {
        final mockFile = MockFile();
        final mockFileInfo = MockFileInfo();

        when(() => mockFile.existsSync()).thenReturn(true);
        when(() => mockFile.path).thenReturn('/test/path/new_video.mp4');
        when(() => mockFileInfo.file).thenReturn(mockFile);

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        cacheManager = TestableMediaCacheManager(
          config: MediaCacheConfig(
            cacheKey: 'download_test_$timestamp',
            enableSyncManifest: true,
            onDebug: logMessages.add,
            onInfo: logMessages.add,
          ),
          mockGetFileFromCache: (key) async => null,
          mockDownloadFile: (url, {key, authHeaders}) async => mockFileInfo,
        );

        final result = await cacheManager.cacheFile(
          'https://example.com/new_video.mp4',
          key: 'new_key',
        );

        expect(result, isNotNull);
        expect(result!.path, '/test/path/new_video.mp4');
        expect(
          logMessages.any((m) => m.contains('Caching new_key')),
          true,
        );
        expect(
          logMessages.any((m) => m.contains('Successfully cached')),
          true,
        );
      });

      test('handles download error gracefully', () async {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        cacheManager = TestableMediaCacheManager(
          config: MediaCacheConfig(
            cacheKey: 'error_test_$timestamp',
            enableSyncManifest: true,
            onDebug: logMessages.add,
            onInfo: logMessages.add,
            onError: logMessages.add,
          ),
          mockGetFileFromCache: (key) async => null,
          mockDownloadFile: (url, {key, authHeaders}) async {
            throw Exception('Network error');
          },
        );

        final result = await cacheManager.cacheFile(
          'https://example.com/fail.mp4',
          key: 'fail_key',
        );

        expect(result, isNull);
        expect(
          logMessages.any((m) => m.contains('Failed to cache')),
          true,
        );
      });

      test('deduplicates concurrent requests for same key', () async {
        final mockFile = MockFile();
        final mockFileInfo = MockFileInfo();
        var downloadCount = 0;

        when(() => mockFile.existsSync()).thenReturn(true);
        when(() => mockFile.path).thenReturn('/test/path/video.mp4');
        when(() => mockFileInfo.file).thenReturn(mockFile);

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        cacheManager = TestableMediaCacheManager(
          config: MediaCacheConfig(
            cacheKey: 'dedup_test_$timestamp',
            enableSyncManifest: true,
            onDebug: logMessages.add,
            onInfo: logMessages.add,
          ),
          mockGetFileFromCache: (key) async => null,
          mockDownloadFile: (url, {key, authHeaders}) async {
            downloadCount++;
            // Simulate slow download
            await Future<void>.delayed(const Duration(milliseconds: 100));
            return mockFileInfo;
          },
        );

        // Start two concurrent requests for same key
        final futures = await Future.wait([
          cacheManager.cacheFile(
            'https://example.com/video.mp4',
            key: 'same_key',
          ),
          cacheManager.cacheFile(
            'https://example.com/video.mp4',
            key: 'same_key',
          ),
        ]);

        // Both should return the same file
        expect(futures[0], isNotNull);
        expect(futures[1], isNotNull);

        // But download should only happen once
        expect(downloadCount, 1);
        expect(
          logMessages.any((m) => m.contains('Waiting for ongoing')),
          true,
        );
      });

      test('passes auth headers to download', () async {
        final mockFile = MockFile();
        final mockFileInfo = MockFileInfo();
        Map<String, String>? capturedHeaders;

        when(() => mockFile.existsSync()).thenReturn(true);
        when(() => mockFile.path).thenReturn('/test/path/video.mp4');
        when(() => mockFileInfo.file).thenReturn(mockFile);

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        cacheManager = TestableMediaCacheManager(
          config: MediaCacheConfig(
            cacheKey: 'auth_test_$timestamp',
            enableSyncManifest: true,
          ),
          mockGetFileFromCache: (key) async => null,
          mockDownloadFile: (url, {key, authHeaders}) async {
            capturedHeaders = authHeaders;
            return mockFileInfo;
          },
        );

        await cacheManager.cacheFile(
          'https://example.com/video.mp4',
          key: 'auth_key',
          authHeaders: {'Authorization': 'Bearer token123'},
        );

        expect(capturedHeaders, {'Authorization': 'Bearer token123'});
      });
    });

    group('isFileCached', () {
      test('returns true when file exists in cache', () async {
        final mockFile = MockFile();
        final mockFileInfo = MockFileInfo();

        when(() => mockFile.existsSync()).thenReturn(true);
        when(() => mockFile.path).thenReturn('/test/path/video.mp4');
        when(() => mockFileInfo.file).thenReturn(mockFile);

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        cacheManager = TestableMediaCacheManager(
          config: MediaCacheConfig(
            cacheKey: 'is_cached_test_$timestamp',
            enableSyncManifest: true,
          ),
          mockGetFileFromCache: (key) async => mockFileInfo,
        );

        final isCached = await cacheManager.isFileCached('test_key');
        expect(isCached, true);
      });

      test('returns false when file does not exist', () async {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        cacheManager = TestableMediaCacheManager(
          config: MediaCacheConfig(
            cacheKey: 'not_cached_test_$timestamp',
            enableSyncManifest: true,
          ),
          mockGetFileFromCache: (key) async => null,
        );

        final isCached = await cacheManager.isFileCached('missing_key');
        expect(isCached, false);
      });

      test('handles error and returns false', () async {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        cacheManager = TestableMediaCacheManager(
          config: MediaCacheConfig(
            cacheKey: 'error_cached_test_$timestamp',
            onWarning: logMessages.add,
          ),
          mockGetFileFromCache: (key) async {
            throw Exception('Cache error');
          },
        );

        final isCached = await cacheManager.isFileCached('error_key');
        expect(isCached, false);
        expect(
          logMessages.any((m) => m.contains('Error checking cache')),
          true,
        );
      });
    });

    group('removeCachedFile', () {
      test('removes file and updates manifest', () async {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        var removeFileCalled = false;

        cacheManager = TestableMediaCacheManager(
          config: MediaCacheConfig(
            cacheKey: 'remove_test_$timestamp',
            enableSyncManifest: true,
            onInfo: logMessages.add,
          ),
          mockRemoveFile: (key) async {
            removeFileCalled = true;
          },
        );

        await cacheManager.removeCachedFile('remove_key');

        expect(removeFileCalled, true);
        expect(
          logMessages.any((m) => m.contains('Removing cached file')),
          true,
        );
        expect(
          logMessages.any((m) => m.contains('Successfully removed')),
          true,
        );
      });

      test('handles removal error gracefully', () async {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        cacheManager = TestableMediaCacheManager(
          config: MediaCacheConfig(
            cacheKey: 'remove_error_test_$timestamp',
            onInfo: logMessages.add,
            onError: logMessages.add,
          ),
          mockRemoveFile: (key) async {
            throw Exception('Removal failed');
          },
        );

        // Should not throw
        await cacheManager.removeCachedFile('error_key');

        expect(
          logMessages.any((m) => m.contains('Error removing')),
          true,
        );
      });
    });

    group('clearCache', () {
      test('clears all cached files', () async {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        var emptyCacheCalled = false;

        cacheManager = TestableMediaCacheManager(
          config: MediaCacheConfig(
            cacheKey: 'clear_test_$timestamp',
            enableSyncManifest: true,
            onInfo: logMessages.add,
          ),
          mockEmptyCache: () async {
            emptyCacheCalled = true;
          },
        );

        await cacheManager.clearCache();

        expect(emptyCacheCalled, true);
        expect(
          logMessages.any((m) => m.contains('Clearing all cached files')),
          true,
        );
        expect(
          logMessages.any((m) => m.contains('Cache cleared successfully')),
          true,
        );
      });

      test('handles clear error gracefully', () async {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        cacheManager = TestableMediaCacheManager(
          config: MediaCacheConfig(
            cacheKey: 'clear_error_test_$timestamp',
            onInfo: logMessages.add,
            onError: logMessages.add,
          ),
          mockEmptyCache: () async {
            throw Exception('Clear failed');
          },
        );

        // Should not throw
        await cacheManager.clearCache();

        expect(
          logMessages.any((m) => m.contains('Error clearing cache')),
          true,
        );
      });
    });

    group('preCacheFiles with mocks', () {
      test('skips already cached files', () async {
        final mockFile = MockFile();
        final mockFileInfo = MockFileInfo();
        var downloadCount = 0;

        when(() => mockFile.existsSync()).thenReturn(true);
        when(() => mockFile.path).thenReturn('/test/path/video.mp4');
        when(() => mockFileInfo.file).thenReturn(mockFile);

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        cacheManager = TestableMediaCacheManager(
          config: MediaCacheConfig(
            cacheKey: 'precache_skip_$timestamp',
            enableSyncManifest: true,
            onDebug: logMessages.add,
            onInfo: logMessages.add,
          ),
          mockGetFileFromCache: (key) async => mockFileInfo,
          mockDownloadFile: (url, {key, authHeaders}) async {
            downloadCount++;
            return mockFileInfo;
          },
        );

        await cacheManager.preCacheFiles([
          (url: 'https://example.com/v1.mp4', key: 'v1'),
          (url: 'https://example.com/v2.mp4', key: 'v2'),
        ]);

        // Should skip downloads since files are cached
        expect(downloadCount, 0);
        expect(
          logMessages.any((m) => m.contains('Skipping already cached')),
          true,
        );
      });

      test('uses auth headers provider', () async {
        final mockFile = MockFile();
        final mockFileInfo = MockFileInfo();
        final capturedHeaders = <String, Map<String, String>?>{};

        when(() => mockFile.existsSync()).thenReturn(true);
        when(() => mockFile.path).thenReturn('/test/path/video.mp4');
        when(() => mockFileInfo.file).thenReturn(mockFile);

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        cacheManager = TestableMediaCacheManager(
          config: MediaCacheConfig(
            cacheKey: 'precache_auth_$timestamp',
            enableSyncManifest: true,
            onInfo: logMessages.add,
          ),
          mockGetFileFromCache: (key) async => null,
          mockDownloadFile: (url, {key, authHeaders}) async {
            capturedHeaders[key!] = authHeaders;
            return mockFileInfo;
          },
        );

        await cacheManager.preCacheFiles(
          [
            (url: 'https://example.com/v1.mp4', key: 'v1'),
            (url: 'https://example.com/v2.mp4', key: 'v2'),
          ],
          authHeadersProvider: (key) => {'X-Key': key},
        );

        expect(capturedHeaders['v1'], {'X-Key': 'v1'});
        expect(capturedHeaders['v2'], {'X-Key': 'v2'});
      });
    });
  });
}
