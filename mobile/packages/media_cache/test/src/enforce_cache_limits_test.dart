import 'dart:async';
import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_cache/media_cache.dart';
import 'package:mocktail/mocktail.dart';

import 'helpers/mocks.dart';
import 'helpers/test_helpers.dart';

void main() {
  setUpTestEnvironment();

  group('MediaCacheManager.enforceCacheLimits', () {
    late MockCacheInfoRepository repo;

    setUpAll(() async {
      await setUpTestDirectories();
      registerFallbackValue(<int>[]);
      registerFallbackValue(
        CacheObject('u', relativePath: 'r', validTill: DateTime(2099)),
      );
    });

    tearDownAll(() async {
      await tearDownTestDirectories();
    });

    setUp(() {
      repo = MockCacheInfoRepository();
      when(repo.open).thenAnswer((_) async => true);
      when(repo.close).thenAnswer((_) async => true);
      when(() => repo.deleteAll(any())).thenAnswer((_) async => 0);
    });

    (MediaCacheManager, Directory) build({int? maxCacheSizeBytes}) {
      final cacheKey = 'enforce_${DateTime.now().microsecondsSinceEpoch}';
      final dir = Directory('$testTempPath/$cacheKey')
        ..createSync(recursive: true);
      final manager = MediaCacheManager(
        config: MediaCacheConfig(
          cacheKey: cacheKey,
          enableSyncManifest: true,
          maxCacheSizeBytes: maxCacheSizeBytes,
        ),
        repoOverride: repo,
      );
      return (manager, dir);
    }

    File writeFile(Directory dir, String name, int bytes) {
      return File('${dir.path}/$name')
        ..writeAsBytesSync(List<int>.filled(bytes, 0));
    }

    CacheObject obj(String relativePath, {int? id, DateTime? touched}) {
      return CacheObject(
        'https://example.com/$relativePath',
        key: 'key_$relativePath',
        relativePath: relativePath,
        validTill: DateTime(2099),
        id: id,
        touched: touched,
      );
    }

    test('reclaims untracked managed-pattern files, keeps everything '
        'else', () async {
      final (manager, dir) = build();
      final tracked = writeFile(dir, 'vid_key_100_1.mp4', 10);
      final orphan = writeFile(dir, 'vid_key_200_2.mp4', 10);
      final seedVideo = writeFile(dir, 'a1b2c3d4e5f6', 10);
      final seedThumb = writeFile(dir, 'thumbnail_a1b2c3.jpg', 10);
      final aliases = writeFile(dir, 'aliases.json', 10);
      final nested = Directory('${dir.path}/nested')..createSync();

      when(repo.getAllObjects).thenAnswer(
        (_) async => [obj('vid_key_100_1.mp4', id: 1)],
      );

      await manager.enforceCacheLimits();

      expect(orphan.existsSync(), isFalse, reason: 'untracked orphan removed');
      expect(tracked.existsSync(), isTrue, reason: 'tracked file kept');
      expect(seedVideo.existsSync(), isTrue, reason: 'seed video kept');
      expect(seedThumb.existsSync(), isTrue, reason: 'seed thumbnail kept');
      expect(aliases.existsSync(), isTrue, reason: 'alias manifest kept');
      expect(nested.existsSync(), isTrue, reason: 'subdirectory kept');
    });

    test('evicts least-recently-used tracked files until under '
        'budget', () async {
      final (manager, dir) = build(maxCacheSizeBytes: 100);
      final oldest = writeFile(dir, 'a_1_1.mp4', 60);
      final middle = writeFile(dir, 'b_2_2.mp4', 60);
      final newest = writeFile(dir, 'c_3_3.mp4', 60);

      when(repo.getAllObjects).thenAnswer(
        (_) async => [
          obj('a_1_1.mp4', id: 1, touched: DateTime(2020)),
          obj('b_2_2.mp4', id: 2, touched: DateTime(2020, 1, 2)),
          obj('c_3_3.mp4', id: 3, touched: DateTime(2020, 1, 3)),
        ],
      );

      await manager.enforceCacheLimits();

      // 180 bytes > 100: drop oldest (→120), still over, drop middle (→60).
      expect(oldest.existsSync(), isFalse);
      expect(middle.existsSync(), isFalse);
      expect(newest.existsSync(), isTrue);

      final captured =
          verify(() => repo.deleteAll(captureAny())).captured.single as List;
      expect(captured, containsAll(<int>[1, 2]));
      expect(captured, isNot(contains(3)));
    });

    test('does not evict when total size is within budget', () async {
      final (manager, dir) = build(maxCacheSizeBytes: 1000);
      final file = writeFile(dir, 'a_1_1.mp4', 60);

      when(repo.getAllObjects).thenAnswer(
        (_) async => [obj('a_1_1.mp4', id: 1, touched: DateTime(2020))],
      );

      await manager.enforceCacheLimits();

      expect(file.existsSync(), isTrue);
      verifyNever(() => repo.deleteAll(any()));
    });

    test('skips tracked objects whose file is missing on disk', () async {
      final (manager, dir) = build(maxCacheSizeBytes: 50);
      final present = writeFile(dir, 'present_2_2.mp4', 60);

      when(repo.getAllObjects).thenAnswer(
        (_) async => [
          obj('missing_9_9.mp4', id: 1, touched: DateTime(2020)),
          obj('present_2_2.mp4', id: 2, touched: DateTime(2020, 1, 2)),
        ],
      );

      await manager.enforceCacheLimits();

      expect(present.existsSync(), isFalse);
      final captured =
          verify(() => repo.deleteAll(captureAny())).captured.single as List;
      expect(captured, equals(<int>[2]));
    });

    test('evicts files whose object has no id without calling '
        'deleteAll', () async {
      final (manager, dir) = build(maxCacheSizeBytes: 50);
      final file = writeFile(dir, 'a_1_1.mp4', 60);

      when(repo.getAllObjects).thenAnswer(
        (_) async => [obj('a_1_1.mp4', touched: DateTime(2020))],
      );

      await manager.enforceCacheLimits();

      expect(file.existsSync(), isFalse);
      verifyNever(() => repo.deleteAll(any()));
    });

    test('does nothing when the repository fails to open', () async {
      when(repo.open).thenAnswer((_) async => false);
      final (manager, dir) = build();
      final orphan = writeFile(dir, 'x_1_1.mp4', 10);

      await manager.enforceCacheLimits();

      expect(orphan.existsSync(), isTrue);
      verifyNever(repo.getAllObjects);
    });

    test('swallows repository errors without throwing', () async {
      final (manager, _) = build();
      when(repo.getAllObjects).thenThrow(Exception('boom'));

      await expectLater(manager.enforceCacheLimits(), completes);
    });

    test('is a no-op after the manager is closed', () async {
      when(repo.getAllObjects).thenAnswer((_) async => []);
      final (manager, dir) = build();
      await runZonedGuarded(() async {
        try {
          await manager.close();
        } on Object catch (_) {}
      }, (_, _) {});
      final orphan = writeFile(dir, 'x_1_1.mp4', 10);

      await manager.enforceCacheLimits();

      expect(orphan.existsSync(), isTrue);
      verifyNever(repo.getAllObjects);
    });

    test('ignores an overlapping call while a sweep is in progress', () async {
      final gate = Completer<List<CacheObject>>();
      when(repo.getAllObjects).thenAnswer((_) => gate.future);
      final (manager, dir) = build();
      final orphan = writeFile(dir, 'x_1_1.mp4', 10);

      final first = manager.enforceCacheLimits();
      // Second call sees _sweepInProgress and returns immediately.
      await manager.enforceCacheLimits();
      expect(orphan.existsSync(), isTrue, reason: 'first sweep still parked');

      gate.complete([]);
      await first;

      expect(orphan.existsSync(), isFalse);
      verify(repo.getAllObjects).called(1);
    });

    test('skips a second pass within the throttle window', () async {
      when(repo.getAllObjects).thenAnswer((_) async => []);
      final (manager, dir) = build();
      final firstOrphan = writeFile(dir, 'a_1_1.mp4', 10);

      await manager.enforceCacheLimits();
      expect(firstOrphan.existsSync(), isFalse, reason: 'first pass ran');

      final secondOrphan = writeFile(dir, 'b_2_2.mp4', 10);
      await manager.enforceCacheLimits();

      expect(
        secondOrphan.existsSync(),
        isTrue,
        reason: 'second pass throttled within the interval',
      );
      verify(repo.getAllObjects).called(1);
    });

    test('runs a throttled sweep after enough downloads', () async {
      final downloader = FakeCancellableDownloader();
      final cacheKey = 'throttle_${DateTime.now().microsecondsSinceEpoch}';
      Directory('$testTempPath/$cacheKey').createSync(recursive: true);
      when(repo.getAllObjects).thenAnswer((_) async => []);
      when(() => repo.updateOrInsert(any())).thenAnswer((_) async => 0);

      final manager = MediaCacheManager(
        config: MediaCacheConfig(cacheKey: cacheKey, enableSyncManifest: true),
        repoOverride: repo,
        downloaderOverride: downloader,
      );

      final sourceDir = Directory.systemTemp.createTempSync('throttle_src_');
      final file = File('${sourceDir.path}/v.mp4')
        ..writeAsBytesSync(const [1, 2, 3]);

      final ops = [
        for (var i = 0; i < 25; i++)
          manager.cacheFileCancellable(
            'https://example.com/v$i.mp4',
            key: 'k$i',
          ),
      ];

      for (var i = 0; i < 400 && downloader.downloads.length < 25; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      for (final download in downloader.downloads) {
        download.completeWith(file);
      }
      await Future.wait(ops.map((op) => op.file));
      await Future<void>.delayed(const Duration(milliseconds: 5));

      verify(repo.getAllObjects).called(greaterThanOrEqualTo(1));
      sourceDir.deleteSync(recursive: true);
    });

    test('reports the byte budget via getCacheStats', () {
      final (manager, _) = build(maxCacheSizeBytes: 4096);
      expect(manager.getCacheStats()['maxCacheSizeBytes'], 4096);
    });
  });
}
