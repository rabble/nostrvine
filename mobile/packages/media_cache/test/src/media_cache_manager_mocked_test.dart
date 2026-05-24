import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_cache/media_cache.dart';
import 'package:mocktail/mocktail.dart';

import 'helpers/mocks.dart';
import 'helpers/test_helpers.dart';

class _ThrowingCancellableDownloader implements CancellableDownloader {
  @override
  CancellableDownload download({
    required String url,
    required File targetFile,
    Map<String, String>? headers,
  }) {
    throw Exception('download setup failed');
  }

  @override
  Future<void> close() async {}
}

Future<File?> _cancelAndWait(CancellableCacheOperation operation) async {
  operation.cancel();
  return operation.file;
}

void main() {
  setUpTestEnvironment();

  group('MediaCacheManager with mocks', () {
    late TestableMediaCacheManager cacheManager;

    setUpAll(() async {
      await setUpTestDirectories();
    });

    tearDownAll(() async {
      await tearDownTestDirectories();
    });

    tearDown(() {
      cacheManager.resetForTesting();
    });

    group('cacheFile', () {
      test('returns existing file when already cached', () async {
        final mockFile = MockFile();
        final mockFileInfo = MockFileInfo();

        when(mockFile.existsSync).thenReturn(true);
        when(() => mockFile.path).thenReturn('/test/path/video.mp4');
        when(() => mockFileInfo.file).thenReturn(mockFile);

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        cacheManager = TestableMediaCacheManager(
          config: MediaCacheConfig(
            cacheKey: 'cache_test_$timestamp',
            enableSyncManifest: true,
          ),
          mockGetFileFromCache: (key) async => mockFileInfo,
        );

        final result = await cacheManager.cacheFile(
          'https://example.com/video.mp4',
          key: 'test_key',
        );

        expect(result, isNotNull);
        expect(result!.path, '/test/path/video.mp4');
      });

      test('downloads and caches new file', () async {
        final mockFile = MockFile();
        final mockFileInfo = MockFileInfo();

        when(mockFile.existsSync).thenReturn(true);
        when(() => mockFile.path).thenReturn('/test/path/new_video.mp4');
        when(() => mockFileInfo.file).thenReturn(mockFile);

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        cacheManager = TestableMediaCacheManager(
          config: MediaCacheConfig(
            cacheKey: 'download_test_$timestamp',
            enableSyncManifest: true,
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
      });

      test('handles download error gracefully', () async {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        cacheManager = TestableMediaCacheManager(
          config: MediaCacheConfig(
            cacheKey: 'error_test_$timestamp',
            enableSyncManifest: true,
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
      });

      test('deduplicates concurrent requests for same key', () async {
        final mockFile = MockFile();
        final mockFileInfo = MockFileInfo();
        var downloadCount = 0;

        when(mockFile.existsSync).thenReturn(true);
        when(() => mockFile.path).thenReturn('/test/path/video.mp4');
        when(() => mockFileInfo.file).thenReturn(mockFile);

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        cacheManager = TestableMediaCacheManager(
          config: MediaCacheConfig(
            cacheKey: 'dedup_test_$timestamp',
            enableSyncManifest: true,
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
      });

      test('close completes pending cacheFile operations with null', () async {
        final mockFile = MockFile();
        final mockFileInfo = MockFileInfo();
        final repo = MockCacheInfoRepository();
        final downloadCompleter = Completer<FileInfo>();

        when(mockFile.existsSync).thenReturn(true);
        when(() => mockFile.path).thenReturn('/test/path/late_video.mp4');
        when(() => mockFileInfo.file).thenReturn(mockFile);
        when(repo.open).thenAnswer((_) async => true);
        when(repo.getAllObjects).thenAnswer((_) async => []);
        when(repo.close).thenAnswer((_) async => true);

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        cacheManager = TestableMediaCacheManager(
          config: MediaCacheConfig(
            cacheKey: 'close_pending_cache_file_$timestamp',
            enableSyncManifest: true,
          ),
          repoOverride: repo,
          mockGetFileFromCache: (key) async => null,
          mockDownloadFile: (url, {key, authHeaders}) =>
              downloadCompleter.future,
        );

        final cacheFuture = cacheManager.cacheFile(
          'https://example.com/video.mp4',
          key: 'pending_close_key',
        );
        await Future<void>.delayed(const Duration(milliseconds: 1));

        await cacheManager.close();

        expect(await cacheFuture, isNull);
        expect(
          await cacheManager.cacheFile(
            'https://example.com/after-close.mp4',
            key: 'after_close_key',
          ),
          isNull,
        );

        downloadCompleter.complete(mockFileInfo);
        await Future<void>.delayed(const Duration(milliseconds: 1));
      });

      test('passes auth headers to download', () async {
        final mockFile = MockFile();
        final mockFileInfo = MockFileInfo();
        Map<String, String>? capturedHeaders;

        when(mockFile.existsSync).thenReturn(true);
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

        when(mockFile.existsSync).thenReturn(true);
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
          ),
          mockGetFileFromCache: (key) async {
            throw Exception('Cache error');
          },
        );

        final isCached = await cacheManager.isFileCached('error_key');
        expect(isCached, false);
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
          ),
          mockRemoveFile: (key) async {
            removeFileCalled = true;
          },
        );

        await cacheManager.removeCachedFile('remove_key');

        expect(removeFileCalled, true);
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
          ),
          mockEmptyCache: () async {
            emptyCacheCalled = true;
          },
        );

        await cacheManager.clearCache();

        expect(emptyCacheCalled, true);
      });
    });

    group('preCacheFiles with mocks', () {
      Future<void> pumpDownloads(
        FakeCancellableDownloader downloader, {
        int expected = 1,
      }) async {
        for (var i = 0; i < 50 && downloader.downloads.length < expected; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
      }

      test('skips already cached files', () async {
        final mockFile = MockFile();
        final mockFileInfo = MockFileInfo();
        final downloader = FakeCancellableDownloader();

        when(mockFile.existsSync).thenReturn(true);
        when(() => mockFile.path).thenReturn('/test/path/video.mp4');
        when(() => mockFileInfo.file).thenReturn(mockFile);

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        cacheManager = TestableMediaCacheManager(
          config: MediaCacheConfig(
            cacheKey: 'precache_skip_$timestamp',
            enableSyncManifest: true,
          ),
          mockGetFileFromCache: (key) async => mockFileInfo,
          downloaderOverride: downloader,
        );

        await cacheManager.preCacheFiles([
          (url: 'https://example.com/v1.mp4', key: 'v1'),
          (url: 'https://example.com/v2.mp4', key: 'v2'),
        ]);

        // Should skip downloads since files are cached
        expect(downloader.downloads, isEmpty);
      });

      test(
        'uses native cancellable downloader with auth headers provider',
        () async {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final cacheKey = 'precache_auth_$timestamp';
          final sourceDir = Directory.systemTemp.createTempSync(
            'precache_auth_src_',
          );
          final v1File = await createTestFile(sourceDir, 'v1.mp4');
          final v2File = await createTestFile(sourceDir, 'v2.mp4');
          final downloader = FakeCancellableDownloader();

          cacheManager = TestableMediaCacheManager(
            config: MediaCacheConfig(
              cacheKey: cacheKey,
              enableSyncManifest: true,
            ),
            mockGetFileFromCache: (key) async => null,
            downloaderOverride: downloader,
          );

          final preCacheFuture = cacheManager.preCacheFiles(
            [
              (url: 'https://example.com/v1.mp4', key: 'v1'),
              (url: 'https://example.com/v2.mp4', key: 'v2'),
            ],
            authHeadersProvider: (key) => {'X-Key': key},
          );

          await pumpDownloads(downloader, expected: 2);
          expect(downloader.downloads, hasLength(2));
          downloader.downloads[0].completeWith(v1File);
          downloader.downloads[1].completeWith(v2File);
          await preCacheFuture;

          expect(
            downloader.downloads.map((download) => download.url),
            unorderedEquals([
              'https://example.com/v1.mp4',
              'https://example.com/v2.mp4',
            ]),
          );
          expect(
            downloader.downloads.map((download) => download.headers),
            unorderedEquals([
              {'X-Key': 'v1'},
              {'X-Key': 'v2'},
            ]),
          );

          final cacheDir = Directory('$testTempPath/$cacheKey');
          if (cacheDir.existsSync()) cacheDir.deleteSync(recursive: true);
          if (sourceDir.existsSync()) sourceDir.deleteSync(recursive: true);
        },
      );

      test('reuses in-flight download for duplicate keys in a batch', () async {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final cacheKey = 'precache_duplicate_inflight_$timestamp';
        final sourceDir = Directory.systemTemp.createTempSync(
          'precache_duplicate_src_',
        );
        final videoFile = await createTestFile(sourceDir, 'duplicate.mp4');
        final downloader = FakeCancellableDownloader();

        cacheManager = TestableMediaCacheManager(
          config: MediaCacheConfig(
            cacheKey: cacheKey,
            enableSyncManifest: true,
          ),
          mockGetFileFromCache: (key) async => null,
          downloaderOverride: downloader,
        );

        final preCacheFuture = cacheManager.preCacheFiles(
          [
            (url: 'https://example.com/duplicate.mp4', key: 'dup'),
            (url: 'https://example.com/duplicate-again.mp4', key: 'dup'),
          ],
          batchSize: 2,
        );

        await pumpDownloads(downloader);
        expect(downloader.downloads, hasLength(1));

        downloader.downloads.single.completeWith(videoFile);
        await preCacheFuture;

        final cacheDir = Directory('$testTempPath/$cacheKey');
        if (cacheDir.existsSync()) cacheDir.deleteSync(recursive: true);
        if (sourceDir.existsSync()) sourceDir.deleteSync(recursive: true);
      });

      test('tracks prefetched files when later used synchronously', () async {
        final mockFile = MockFile();
        final mockFileInfo = MockFileInfo();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final cacheKey = 'precache_metrics_$timestamp';
        final cacheDir = Directory('$testTempPath/$cacheKey')
          ..createSync(recursive: true);
        final prefetchedFile = await createTestFile(cacheDir, 'prefetched.mp4');

        when(mockFile.existsSync).thenReturn(true);
        when(() => mockFile.path).thenReturn(prefetchedFile.path);
        when(() => mockFileInfo.file).thenReturn(mockFile);

        cacheManager = TestableMediaCacheManager(
          config: MediaCacheConfig(
            cacheKey: cacheKey,
            enableSyncManifest: true,
          ),
          mockGetFileFromCache: (key) async => mockFileInfo,
        );

        await cacheManager.preCacheFiles([
          (url: 'https://example.com/prefetched.mp4', key: 'prefetched_key'),
        ]);

        final cachedFile = cacheManager.getCachedFileSync('prefetched_key');
        final stats = cacheManager.getCacheStats();

        expect(cachedFile, isNotNull);
        expect(cachedFile!.path, prefetchedFile.path);
        expect(stats['prefetched_total'], 1);
        expect(stats['prefetched_used'], 1);

        if (cacheDir.existsSync()) {
          cacheDir.deleteSync(recursive: true);
        }
      });
    });

    group('cacheFileCancellable', () {
      // Drains the microtask + event queue until the manager's deferred
      // [_resolveBaseCacheDir] -> [_downloader.download] step has run and
      // [downloader.downloads] contains the expected number of entries.
      Future<void> pumpDownloads(
        FakeCancellableDownloader downloader, {
        int expected = 1,
      }) async {
        for (var i = 0; i < 50 && downloader.downloads.length < expected; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
      }

      test(
        'returns completed operation when file is already in manifest',
        () async {
          final mockFile = MockFile();
          final mockFileInfo = MockFileInfo();
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final cacheKey = 'cancellable_fast_path_$timestamp';
          final cacheDir = Directory('$testTempPath/$cacheKey')
            ..createSync(recursive: true);
          final cachedFile = await createTestFile(cacheDir, 'video_fast.mp4');

          when(mockFile.existsSync).thenReturn(true);
          when(() => mockFile.path).thenReturn(cachedFile.path);
          when(() => mockFileInfo.file).thenReturn(mockFile);

          cacheManager = TestableMediaCacheManager(
            config: MediaCacheConfig(
              cacheKey: cacheKey,
              enableSyncManifest: true,
            ),
            mockGetFileFromCache: (key) async => null,
            mockDownloadFile: (url, {key, authHeaders}) async => mockFileInfo,
          );

          // Populate the manifest via cacheFile.
          await cacheManager.cacheFile(
            'https://example.com/video.mp4',
            key: 'fast_path_key',
          );

          final op = cacheManager.cacheFileCancellable(
            'https://example.com/video.mp4',
            key: 'fast_path_key',
          );

          expect(await op.file, isNotNull);

          if (cacheDir.existsSync()) {
            cacheDir.deleteSync(recursive: true);
          }
        },
      );

      test(
        'returns pending operation and increments prefetchedTotal',
        () async {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final downloader = FakeCancellableDownloader();

          cacheManager = TestableMediaCacheManager(
            config: MediaCacheConfig(
              cacheKey: 'cancellable_pending_$timestamp',
              enableSyncManifest: true,
            ),
            downloaderOverride: downloader,
          );

          final op = cacheManager.cacheFileCancellable(
            'https://example.com/video.mp4',
            key: 'pending_key',
          );

          expect(cacheManager.metrics.prefetchedTotal, equals(1));
          expect(op.isCancelled, isFalse);

          // Let the deferred download dispatch, then close it cleanly.
          await pumpDownloads(downloader);
          downloader.downloads.single.completeNull();
          await op.file;
        },
      );

      test(
        'returns completed null operation after manager is closed',
        () async {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final downloader = FakeCancellableDownloader();

          cacheManager = TestableMediaCacheManager(
            config: MediaCacheConfig(
              cacheKey: 'cancellable_closed_$timestamp',
              enableSyncManifest: true,
            ),
            downloaderOverride: downloader,
          );

          final activeOp = cacheManager.cacheFileCancellable(
            'https://example.com/active-before-close.mp4',
            key: 'active_before_close_key',
          );
          await pumpDownloads(downloader);
          await cacheManager.close();
          expect(await activeOp.file, isNull);

          final op = cacheManager.cacheFileCancellable(
            'https://example.com/video.mp4',
            key: 'closed_cancellable_key',
          );

          expect(await op.file, isNull);
          expect(op.isCancelled, isFalse);
          op.cancel();
          expect(op.isCancelled, isTrue);
          expect(downloader.downloads, hasLength(1));
        },
      );

      test('manifest is updated after download completes', () async {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final cacheKey = 'cancellable_manifest_$timestamp';
        final cacheDir = Directory('$testTempPath/$cacheKey')
          ..createSync(recursive: true);
        final cachedFile = await createTestFile(cacheDir, 'video.mp4');

        final downloader = FakeCancellableDownloader();
        cacheManager = TestableMediaCacheManager(
          config: MediaCacheConfig(
            cacheKey: cacheKey,
            enableSyncManifest: true,
          ),
          downloaderOverride: downloader,
        );

        final op = cacheManager.cacheFileCancellable(
          'https://example.com/video.mp4',
          key: 'manifest_key',
        );

        await pumpDownloads(downloader);
        downloader.downloads.single.completeWith(cachedFile);
        await op.file;

        final synced = cacheManager.getCachedFileSync('manifest_key');
        expect(synced, isNotNull);
        expect(synced!.path, equals(cachedFile.path));

        if (cacheDir.existsSync()) cacheDir.deleteSync(recursive: true);
      });

      test(
        'manifest is NOT updated when enableSyncManifest is false',
        () async {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final cacheKey = 'cancellable_no_manifest_$timestamp';
          final cacheDir = Directory('$testTempPath/$cacheKey')
            ..createSync(recursive: true);
          final cachedFile = await createTestFile(cacheDir, 'video.mp4');

          final downloader = FakeCancellableDownloader();
          cacheManager = TestableMediaCacheManager(
            config: MediaCacheConfig(
              cacheKey: cacheKey,
              // enableSyncManifest defaults to false
            ),
            downloaderOverride: downloader,
          );

          final op = cacheManager.cacheFileCancellable(
            'https://example.com/video.mp4',
            key: 'no_manifest_key',
          );

          await pumpDownloads(downloader);
          downloader.downloads.single.completeWith(cachedFile);
          await op.file;

          expect(cacheManager.getCachedFileSync('no_manifest_key'), isNull);

          if (cacheDir.existsSync()) cacheDir.deleteSync(recursive: true);
        },
      );

      test('passes auth headers to the downloader', () async {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final downloader = FakeCancellableDownloader();

        cacheManager = TestableMediaCacheManager(
          config: MediaCacheConfig(
            cacheKey: 'cancellable_auth_$timestamp',
          ),
          downloaderOverride: downloader,
        );

        final op = cacheManager.cacheFileCancellable(
          'https://example.com/video.mp4',
          key: 'auth_key',
          authHeaders: {'Authorization': 'Bearer token123'},
        );

        await pumpDownloads(downloader);
        expect(
          downloader.downloads.single.headers,
          equals({'Authorization': 'Bearer token123'}),
        );

        downloader.downloads.single.completeNull();
        await op.file;
      });

      test(
        'file future completes with null when download yields no file',
        () async {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final downloader = FakeCancellableDownloader();

          cacheManager = TestableMediaCacheManager(
            config: MediaCacheConfig(
              cacheKey: 'cancellable_no_info_$timestamp',
            ),
            downloaderOverride: downloader,
          );

          final op = cacheManager.cacheFileCancellable(
            'https://example.com/video.mp4',
            key: 'no_info_key',
          );

          await pumpDownloads(downloader);
          downloader.downloads.single.completeNull();

          expect(await op.file, isNull);
        },
      );

      test(
        'prefetchedUsed increments when prefetched key is hit via '
        'getCachedFileSync',
        () async {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final cacheKey = 'prefetched_used_$timestamp';
          final cacheDir = Directory('$testTempPath/$cacheKey')
            ..createSync(recursive: true);
          final cachedFile = await createTestFile(cacheDir, 'video.mp4');

          final downloader = FakeCancellableDownloader();
          cacheManager = TestableMediaCacheManager(
            config: MediaCacheConfig(
              cacheKey: cacheKey,
              enableSyncManifest: true,
            ),
            downloaderOverride: downloader,
          );

          final op = cacheManager.cacheFileCancellable(
            'https://example.com/video.mp4',
            key: 'prefetched_key',
          );

          await pumpDownloads(downloader);
          downloader.downloads.single.completeWith(cachedFile);
          await op.file;

          final file = cacheManager.getCachedFileSync('prefetched_key');
          expect(file, isNotNull);
          expect(cacheManager.metrics.prefetchedUsed, equals(1));

          if (cacheDir.existsSync()) cacheDir.deleteSync(recursive: true);
        },
      );

      test(
        'aliasKey: also records cached path under the alias on success',
        () async {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final cacheKey = 'cancellable_alias_$timestamp';
          final cacheDir = Directory('$testTempPath/$cacheKey')
            ..createSync(recursive: true);
          final cachedFile = await createTestFile(cacheDir, 'video.mp4');

          final downloader = FakeCancellableDownloader();
          cacheManager = TestableMediaCacheManager(
            config: MediaCacheConfig(
              cacheKey: cacheKey,
              enableSyncManifest: true,
            ),
            downloaderOverride: downloader,
          );

          final op = cacheManager.cacheFileCancellable(
            'https://example.com/video.mp4',
            key: 'video_id__fb1',
            aliasKey: 'video_id',
          );

          await pumpDownloads(downloader);
          downloader.downloads.single.completeWith(cachedFile);
          await op.file;

          final viaDownloadKey = cacheManager.getCachedFileSync(
            'video_id__fb1',
          );
          final viaAlias = cacheManager.getCachedFileSync('video_id');
          expect(viaDownloadKey, isNotNull);
          expect(viaAlias, isNotNull);
          expect(viaAlias!.path, equals(cachedFile.path));
          expect(viaDownloadKey!.path, equals(cachedFile.path));
        },
      );

      test(
        'aliasKey: fast-path returns the file when only the alias is cached',
        () async {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final cacheKey = 'cancellable_alias_fastpath_$timestamp';
          final cacheDir = Directory('$testTempPath/$cacheKey')
            ..createSync(recursive: true);
          final cachedFile = await createTestFile(cacheDir, 'video.mp4');

          final downloader = FakeCancellableDownloader();
          cacheManager = TestableMediaCacheManager(
            config: MediaCacheConfig(
              cacheKey: cacheKey,
              enableSyncManifest: true,
            ),
            downloaderOverride: downloader,
          );

          // Seed the manifest under the alias key.
          final firstOp = cacheManager.cacheFileCancellable(
            'https://example.com/video.mp4',
            key: 'video_id',
          );
          await pumpDownloads(downloader);
          downloader.downloads.single.completeWith(cachedFile);
          await firstOp.file;

          // Second attempt under a different download key but with the same
          // alias must hit the fast path instead of starting a new download.
          final secondOp = cacheManager.cacheFileCancellable(
            'https://example.com/video.mp4',
            key: 'video_id__fb2',
            aliasKey: 'video_id',
          );
          expect(await secondOp.file, isNotNull);
          // No second download was issued.
          expect(downloader.downloads, hasLength(1));

          if (cacheDir.existsSync()) cacheDir.deleteSync(recursive: true);
        },
      );

      test(
        'aliasKey: alias persists across manager restart via aliases.json',
        () async {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final cacheKey = 'cancellable_alias_persist_$timestamp';
          final cacheDir = Directory('$testTempPath/$cacheKey')
            ..createSync(recursive: true);
          final cachedFile = await createTestFile(cacheDir, 'video.mp4');
          final relativePath = cachedFile.uri.pathSegments.last;

          final downloader = FakeCancellableDownloader();
          cacheManager = TestableMediaCacheManager(
            config: MediaCacheConfig(
              cacheKey: cacheKey,
              enableSyncManifest: true,
            ),
            downloaderOverride: downloader,
          );

          final op = cacheManager.cacheFileCancellable(
            'https://example.com/video.mp4',
            key: 'video_id__fb1',
            aliasKey: 'video_id',
          );
          await pumpDownloads(downloader);
          downloader.downloads.single.completeWith(cachedFile);
          await op.file;

          // Allow the queued alias-persist write to flush.
          await Future<void>.delayed(const Duration(milliseconds: 50));

          final aliasFile = File('${cacheDir.path}/aliases.json');
          expect(aliasFile.existsSync(), isTrue);

          // Second "session": fresh manager with same cacheKey. Stub the
          // repo so initialize() sees the previously-cached fb1 object.
          final repo = MockCacheInfoRepository();
          final cacheObject = CacheObject(
            'https://example.com/video.mp4',
            key: 'video_id__fb1',
            relativePath: relativePath,
            validTill: DateTime.now().add(const Duration(days: 30)),
            id: 1,
          );
          when(repo.open).thenAnswer((_) async => true);
          when(repo.getAllObjects).thenAnswer((_) async => [cacheObject]);

          cacheManager.resetForTesting();
          cacheManager = TestableMediaCacheManager(
            config: MediaCacheConfig(
              cacheKey: cacheKey,
              enableSyncManifest: true,
            ),
            repoOverride: repo,
          );

          await cacheManager.initialize();

          final viaAlias = cacheManager.getCachedFileSync('video_id');
          final viaActual = cacheManager.getCachedFileSync('video_id__fb1');
          expect(viaAlias, isNotNull);
          expect(viaActual, isNotNull);
          expect(viaActual!.path, equals(cachedFile.path));
          expect(viaAlias!.path, equals(cachedFile.path));

          if (cacheDir.existsSync()) cacheDir.deleteSync(recursive: true);
        },
      );

      test('initialize ignores corrupt aliases.json gracefully', () async {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final cacheKey = 'alias_corrupt_$timestamp';
        final cacheDir = Directory('$testTempPath/$cacheKey')
          ..createSync(recursive: true);
        final cachedFile = await createTestFile(cacheDir, 'video.mp4');
        final aliasFile = File('${cacheDir.path}/aliases.json')
          ..writeAsStringSync('{not-valid-json');

        final repo = MockCacheInfoRepository();
        final cacheObject = CacheObject(
          'https://example.com/video.mp4',
          key: 'actual_key',
          relativePath: 'video.mp4',
          validTill: DateTime.now().add(const Duration(days: 30)),
          id: 1,
        );
        when(repo.open).thenAnswer((_) async => true);
        when(repo.getAllObjects).thenAnswer((_) async => [cacheObject]);

        cacheManager = TestableMediaCacheManager(
          config: MediaCacheConfig(
            cacheKey: cacheKey,
            enableSyncManifest: true,
          ),
          repoOverride: repo,
          tempDirectoryProvider: () async => Directory(testTempPath),
        );

        await cacheManager.initialize();

        expect(cacheManager.isInitialized, isTrue);
        expect(
          cacheManager.getCachedFileSync('actual_key')?.path,
          cachedFile.path,
        );
        // Corrupt alias file is ignored instead of crashing init.
        expect(aliasFile.existsSync(), isTrue);

        if (cacheDir.existsSync()) cacheDir.deleteSync(recursive: true);
      });

      test(
        'cancel before deferred download starts sets operation cancelled',
        () async {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final downloader = FakeCancellableDownloader();

          cacheManager = TestableMediaCacheManager(
            config: MediaCacheConfig(
              cacheKey: 'cancellable_cancel_early_$timestamp',
              enableSyncManifest: true,
            ),
            downloaderOverride: downloader,
          );

          final op = cacheManager.cacheFileCancellable(
            'https://example.com/video.mp4',
            key: 'cancel_early_key',
          )..cancel();
          expect(op.isCancelled, isTrue);
          expect(await op.file, isNull);
        },
      );

      test(
        'cancel after deferred download starts forwards cancel state',
        () async {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final downloader = FakeCancellableDownloader();

          cacheManager = TestableMediaCacheManager(
            config: MediaCacheConfig(
              cacheKey: 'cancellable_cancel_started_$timestamp',
              enableSyncManifest: true,
            ),
            downloaderOverride: downloader,
          );

          final op = cacheManager.cacheFileCancellable(
            'https://example.com/video.mp4',
            key: 'cancel_started_key',
          );

          await pumpDownloads(downloader);
          expect(op.isCancelled, isFalse);

          op.cancel();
          expect(op.isCancelled, isTrue);
          expect(downloader.downloads.single.isCancelled, isTrue);
          expect(await op.file, isNull);
        },
      );

      test('isCancelled forwards active downloader state', () async {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final downloader = FakeCancellableDownloader();

        cacheManager = TestableMediaCacheManager(
          config: MediaCacheConfig(
            cacheKey: 'cancellable_active_state_$timestamp',
            enableSyncManifest: true,
          ),
          downloaderOverride: downloader,
        );

        final op = cacheManager.cacheFileCancellable(
          'https://example.com/video.mp4',
          key: 'active_state_key',
        );

        await pumpDownloads(downloader);

        expect(op.isCancelled, isFalse);
        downloader.downloads.single.completeNull();
        await op.file;
      });

      test('completes with null when downloader throws during start', () async {
        final timestamp = DateTime.now().millisecondsSinceEpoch;

        cacheManager = TestableMediaCacheManager(
          config: MediaCacheConfig(
            cacheKey: 'cancellable_throw_start_$timestamp',
            enableSyncManifest: true,
          ),
          downloaderOverride: _ThrowingCancellableDownloader(),
        );

        final op = cacheManager.cacheFileCancellable(
          'https://example.com/video.mp4',
          key: 'throwing_key',
        );

        expect(await op.file, isNull);
      });

      test('uses default extension when URL has no extension', () async {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final downloader = FakeCancellableDownloader();

        cacheManager = TestableMediaCacheManager(
          config: MediaCacheConfig(
            cacheKey: 'default_ext_$timestamp',
            enableSyncManifest: true,
          ),
          downloaderOverride: downloader,
        );

        final op = cacheManager.cacheFileCancellable(
          'https://example.com/video_without_ext',
          key: 'no_ext_key',
        );

        await pumpDownloads(downloader);
        expect(downloader.downloads.single.targetFile.path, endsWith('.bin'));

        downloader.downloads.single.completeNull();
        await op.file;
      });

      test('preserves long extension from URL path', () async {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final downloader = FakeCancellableDownloader();

        cacheManager = TestableMediaCacheManager(
          config: MediaCacheConfig(
            cacheKey: 'long_ext_$timestamp',
            enableSyncManifest: true,
          ),
          downloaderOverride: downloader,
        );

        final op = cacheManager.cacheFileCancellable(
          'https://example.com/video.jpeg2000',
          key: 'long_ext_key',
        );

        await pumpDownloads(downloader);
        expect(
          downloader.downloads.single.targetFile.path,
          endsWith('.jpeg2000'),
        );

        downloader.downloads.single.completeNull();
        await op.file;
      });

      test('close cancels active operations and closes downloader', () async {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final downloader = FakeCancellableDownloader();

        cacheManager = TestableMediaCacheManager(
          config: MediaCacheConfig(
            cacheKey: 'close_ops_$timestamp',
            enableSyncManifest: true,
          ),
          downloaderOverride: downloader,
        );

        final op = cacheManager.cacheFileCancellable(
          'https://example.com/video.mp4',
          key: 'close_key',
        );

        await pumpDownloads(downloader);
        await cacheManager.close();

        expect(op.isCancelled, isTrue);
        expect(await op.file, isNull);
        expect(downloader.closed, isTrue);
      });

      test(
        'recreates base cache dir before writing aliases.json when deleted',
        () async {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final cacheKey = 'alias_recreate_dir_$timestamp';
          final cacheDir = Directory('$testTempPath/$cacheKey');
          final cachedFile = await createTestFile(
            Directory.systemTemp.createTempSync('alias_source_'),
            'video.mp4',
          );

          final downloader = FakeCancellableDownloader();
          cacheManager = TestableMediaCacheManager(
            config: MediaCacheConfig(
              cacheKey: cacheKey,
              enableSyncManifest: true,
            ),
            downloaderOverride: downloader,
            tempDirectoryProvider: () async => Directory(testTempPath),
          );

          final op = cacheManager.cacheFileCancellable(
            'https://example.com/video.mp4',
            key: 'video_id__fb1',
            aliasKey: 'video_id',
          );

          await pumpDownloads(downloader);
          if (cacheDir.existsSync()) cacheDir.deleteSync(recursive: true);
          downloader.downloads.single.completeWith(cachedFile);
          await op.file;

          await Future<void>.delayed(const Duration(milliseconds: 50));
          expect(File('${cacheDir.path}/aliases.json').existsSync(), isTrue);

          if (cacheDir.existsSync()) cacheDir.deleteSync(recursive: true);
          final sourceDir = cachedFile.parent;
          if (sourceDir.existsSync()) sourceDir.deleteSync(recursive: true);
        },
      );

      test('ignores alias persistence write errors', () async {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final cacheKey = 'alias_write_error_$timestamp';
        final cacheDir = Directory('$testTempPath/$cacheKey');
        final cachedFile = await createTestFile(
          Directory.systemTemp.createTempSync('alias_err_src_'),
          'video.mp4',
        );

        final downloader = FakeCancellableDownloader();
        cacheManager = TestableMediaCacheManager(
          config: MediaCacheConfig(
            cacheKey: cacheKey,
            enableSyncManifest: true,
          ),
          downloaderOverride: downloader,
          tempDirectoryProvider: () async => Directory(testTempPath),
        );

        final op = cacheManager.cacheFileCancellable(
          'https://example.com/video.mp4',
          key: 'video_id__fb1',
          aliasKey: 'video_id',
        );

        await pumpDownloads(downloader);
        cacheDir.createSync(recursive: true);
        // Force File.writeAsString to throw by occupying the file path
        // with a directory.
        Directory('${cacheDir.path}/aliases.json').createSync(recursive: true);

        downloader.downloads.single.completeWith(cachedFile);
        final result = await op.file;
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(result, isNotNull);
        // In-memory alias still resolves even if persistence failed.
        expect(cacheManager.getCachedFileSync('video_id')?.path, result!.path);

        if (cacheDir.existsSync()) cacheDir.deleteSync(recursive: true);
        final sourceDir = cachedFile.parent;
        if (sourceDir.existsSync()) sourceDir.deleteSync(recursive: true);
      });

      test('removeCachedFile removes alias mapping and persists it', () async {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final cacheKey = 'alias_remove_$timestamp';
        final cacheDir = Directory('$testTempPath/$cacheKey');
        final cachedFile = await createTestFile(
          Directory.systemTemp.createTempSync('alias_remove_src_'),
          'video.mp4',
        );

        final downloader = FakeCancellableDownloader();
        cacheManager = TestableMediaCacheManager(
          config: MediaCacheConfig(
            cacheKey: cacheKey,
            enableSyncManifest: true,
          ),
          downloaderOverride: downloader,
          tempDirectoryProvider: () async => Directory(testTempPath),
        );

        final op = cacheManager.cacheFileCancellable(
          'https://example.com/video.mp4',
          key: 'video_id__fb1',
          aliasKey: 'video_id',
        );

        await pumpDownloads(downloader);
        downloader.downloads.single.completeWith(cachedFile);
        final result = await op.file;

        expect(result, isNotNull);
        expect(cacheManager.getCachedFileSync('video_id')?.path, result!.path);

        await cacheManager.removeCachedFile('video_id__fb1');

        expect(cacheManager.getCachedFileSync('video_id'), isNull);

        final aliasFile = File('${cacheDir.path}/aliases.json');
        expect(aliasFile.existsSync(), isTrue);
        final decoded = jsonDecode(aliasFile.readAsStringSync());
        expect(decoded, isA<Map<String, dynamic>>());
        expect(
          (decoded as Map<String, dynamic>).containsKey('video_id'),
          isFalse,
        );

        if (cacheDir.existsSync()) cacheDir.deleteSync(recursive: true);
        final sourceDir = cachedFile.parent;
        if (sourceDir.existsSync()) sourceDir.deleteSync(recursive: true);
      });

      test('clearCache clears alias mapping and persists it', () async {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final cacheKey = 'alias_clear_$timestamp';
        final cacheDir = Directory('$testTempPath/$cacheKey');
        final cachedFile = await createTestFile(
          Directory.systemTemp.createTempSync('alias_clear_src_'),
          'video.mp4',
        );

        final downloader = FakeCancellableDownloader();
        cacheManager = TestableMediaCacheManager(
          config: MediaCacheConfig(
            cacheKey: cacheKey,
            enableSyncManifest: true,
          ),
          downloaderOverride: downloader,
          tempDirectoryProvider: () async => Directory(testTempPath),
        );

        final op = cacheManager.cacheFileCancellable(
          'https://example.com/video.mp4',
          key: 'video_id__fb1',
          aliasKey: 'video_id',
        );

        await pumpDownloads(downloader);
        downloader.downloads.single.completeWith(cachedFile);
        await op.file;

        await cacheManager.clearCache();

        expect(cacheManager.getCachedFileSync('video_id'), isNull);

        final aliasFile = File('${cacheDir.path}/aliases.json');
        expect(aliasFile.existsSync(), isTrue);
        final decoded = jsonDecode(aliasFile.readAsStringSync());
        expect(decoded, isA<Map<String, dynamic>>());
        expect((decoded as Map<String, dynamic>).isEmpty, isTrue);

        if (cacheDir.existsSync()) cacheDir.deleteSync(recursive: true);
        final sourceDir = cachedFile.parent;
        if (sourceDir.existsSync()) sourceDir.deleteSync(recursive: true);
      });

      test(
        'cacheFile in-flight: cacheFileCancellable joins without '
        'starting a second download',
        () async {
          final mockFile = MockFile();
          final mockFileInfo = MockFileInfo();
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final downloadCompleter = Completer<FileInfo>();
          var downloadCallCount = 0;

          when(mockFile.existsSync).thenReturn(true);
          when(() => mockFile.path).thenReturn('/test/path/shared.mp4');
          when(() => mockFileInfo.file).thenReturn(mockFile);

          final fakeDownloader = FakeCancellableDownloader();
          cacheManager = TestableMediaCacheManager(
            config: MediaCacheConfig(
              cacheKey: 'cross_dedup_cf_first_$timestamp',
              enableSyncManifest: true,
            ),
            downloaderOverride: fakeDownloader,
            mockGetFileFromCache: (key) async => null,
            mockDownloadFile: (url, {key, authHeaders}) {
              downloadCallCount++;
              return downloadCompleter.future;
            },
          );

          // Start cacheFile first so it registers in _pendingCacheOperations.
          final cacheFileFuture = cacheManager.cacheFile(
            'https://example.com/shared.mp4',
            key: 'shared_key',
          );
          // Yield so cacheFile's async getFileFromCache check finishes and
          // the pending op is registered before cacheFileCancellable runs.
          await Future<void>.delayed(const Duration(milliseconds: 1));

          // cacheFileCancellable for the same key must join the in-flight
          // operation rather than starting its own download.
          final op = cacheManager.cacheFileCancellable(
            'https://example.com/shared.mp4',
            key: 'shared_key',
          );

          // No separate cancellable download was issued.
          expect(fakeDownloader.downloads, isEmpty);

          // Resolve the original cacheFile download.
          downloadCompleter.complete(mockFileInfo);

          final cfFile = await cacheFileFuture;
          final opFile = await op.file;
          expect(cfFile, isNotNull);
          expect(opFile, isNotNull);
          expect(cfFile!.path, equals(opFile!.path));
          expect(downloadCallCount, equals(1));
        },
      );

      test(
        'cacheFile in-flight: cancelling the joined cancellable op '
        'completes it locally without cancelling the shared download',
        () async {
          final mockFile = MockFile();
          final mockFileInfo = MockFileInfo();
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final downloadCompleter = Completer<FileInfo>();
          var downloadCallCount = 0;

          when(mockFile.existsSync).thenReturn(true);
          when(() => mockFile.path).thenReturn('/test/path/shared_cancel.mp4');
          when(() => mockFileInfo.file).thenReturn(mockFile);

          final fakeDownloader = FakeCancellableDownloader();
          cacheManager = TestableMediaCacheManager(
            config: MediaCacheConfig(
              cacheKey: 'cross_dedup_cf_cancel_$timestamp',
              enableSyncManifest: true,
            ),
            downloaderOverride: fakeDownloader,
            mockGetFileFromCache: (key) async => null,
            mockDownloadFile: (url, {key, authHeaders}) {
              downloadCallCount++;
              return downloadCompleter.future;
            },
          );

          final cacheFileFuture = cacheManager.cacheFile(
            'https://example.com/shared_cancel.mp4',
            key: 'shared_cancel_key',
          );
          await Future<void>.delayed(const Duration(milliseconds: 1));

          final op = cacheManager.cacheFileCancellable(
            'https://example.com/shared_cancel.mp4',
            key: 'shared_cancel_key',
          );
          final joinedFile = await _cancelAndWait(op);
          expect(joinedFile, isNull);

          downloadCompleter.complete(mockFileInfo);
          final cacheFileResult = await cacheFileFuture;

          expect(cacheFileResult, isNotNull);
          expect(cacheFileResult!.path, equals(mockFile.path));
          expect(downloadCallCount, equals(1));
          expect(fakeDownloader.downloads, isEmpty);
        },
      );

      test(
        'cacheFileCancellable in-flight: cacheFile joins without '
        'starting a second download',
        () async {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final cacheKey = 'cross_dedup_ccf_first_$timestamp';
          final cacheDir = Directory('$testTempPath/$cacheKey')
            ..createSync(recursive: true);
          final cachedFile = await createTestFile(cacheDir, 'shared.mp4');

          final fakeDownloader = FakeCancellableDownloader();
          var downloadFileCallCount = 0;

          cacheManager = TestableMediaCacheManager(
            config: MediaCacheConfig(
              cacheKey: cacheKey,
              enableSyncManifest: true,
            ),
            downloaderOverride: fakeDownloader,
            mockGetFileFromCache: (key) async => null,
            mockDownloadFile: (url, {key, authHeaders}) async {
              downloadFileCallCount++;
              throw Exception('should not be called');
            },
          );

          // Start cacheFileCancellable first; it registers the pending op
          // synchronously before the async download begins.
          final op = cacheManager.cacheFileCancellable(
            'https://example.com/shared.mp4',
            key: 'shared_key',
          );
          // Yield so cacheFile's getFileFromCache check resolves and sees
          // the pending op that cacheFileCancellable registered.
          await Future<void>.delayed(const Duration(milliseconds: 1));

          // cacheFile for the same key should join the in-flight op.
          final cacheFileFuture = cacheManager.cacheFile(
            'https://example.com/shared.mp4',
            key: 'shared_key',
          );

          // Complete the single cancellable download.
          await pumpDownloads(fakeDownloader);
          fakeDownloader.downloads.single.completeWith(cachedFile);
          final opFile = await op.file;
          final cfFile = await cacheFileFuture;

          expect(opFile, isNotNull);
          expect(cfFile, isNotNull);
          expect(opFile!.path, equals(cfFile!.path));
          // downloadFile was never invoked — cacheFile joined the op.
          expect(downloadFileCallCount, equals(0));
          expect(fakeDownloader.downloads, hasLength(1));

          if (cacheDir.existsSync()) cacheDir.deleteSync(recursive: true);
        },
      );
    });
  });
}
