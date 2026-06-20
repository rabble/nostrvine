import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_video_feed/src/services/disk_prefetcher.dart';
import 'package:media_cache/media_cache.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';

class _MockMediaCacheManager extends Mock implements MediaCacheManager {}

class _MockFile extends Mock implements File {}

VideoEvent _makeVideo(String id, {String? url}) => VideoEvent(
  id: id,
  pubkey: 'pk',
  createdAt: 0,
  content: '',
  timestamp: DateTime(2024),
  videoUrl: url,
);

void main() {
  late _MockMediaCacheManager cache;
  late List<String> logs;
  late DiskPrefetcher prefetcher;

  setUp(() {
    cache = _MockMediaCacheManager();
    logs = [];
    prefetcher = DiskPrefetcher(cache: cache, log: logs.add);
  });

  tearDown(() => prefetcher.dispose());

  group(DiskPrefetcher, () {
    group('run', () {
      test('skips already-cached entries', () async {
        final mockFile = _MockFile();
        when(() => cache.getCachedFileSync('id1')).thenReturn(mockFile);

        final videos = [_makeVideo('id1', url: 'http://example.com/1.m3u8')];

        await prefetcher.run(
          startIndex: 0,
          endIndex: 0,
          videos: videos,
          resolveUrls: (v) => [if (v.videoUrl != null) v.videoUrl!],
        );

        verifyNever(
          () => cache.cacheFileCancellable(any(), key: any(named: 'key')),
        );
        expect(logs.any((l) => l.contains('already cached')), isTrue);
      });

      test('skips entries with empty URL list from resolver', () async {
        when(() => cache.getCachedFileSync(any())).thenReturn(null);

        final videos = [_makeVideo('id2')];

        await prefetcher.run(
          startIndex: 0,
          endIndex: 0,
          videos: videos,
          resolveUrls: (_) => [],
        );

        verifyNever(
          () => cache.cacheFileCancellable(any(), key: any(named: 'key')),
        );
        expect(logs.any((l) => l.contains('no URLs')), isTrue);
      });

      test('downloads uncached entries', () async {
        final mockFile = _MockFile();
        const url = 'http://example.com/video.m3u8';

        when(() => cache.getCachedFileSync('id3')).thenReturn(null);
        when(
          () => cache.cacheFileCancellable(
            url,
            key: 'id3',
          ),
        ).thenReturn(
          CancellableCacheOperation.completed(mockFile),
        );

        final videos = [_makeVideo('id3', url: url)];

        await prefetcher.run(
          startIndex: 0,
          endIndex: 0,
          videos: videos,
          resolveUrls: (v) => [if (v.videoUrl != null) v.videoUrl!],
        );

        verify(
          () => cache.cacheFileCancellable(
            url,
            key: 'id3',
          ),
        ).called(1);
        expect(logs.any((l) => l.contains('completed')), isTrue);
      });

      test('ignores indices outside videos list bounds', () async {
        final videos = [_makeVideo('id4', url: 'http://example.com/4.m3u8')];

        // endIndex 5 is out of bounds; should not throw.
        when(() => cache.getCachedFileSync(any())).thenReturn(null);
        when(
          () => cache.cacheFileCancellable(
            any(),
            key: any(named: 'key'),
          ),
        ).thenReturn(CancellableCacheOperation.completed(_MockFile()));

        await prefetcher.run(
          startIndex: 0,
          endIndex: 5,
          videos: videos,
          resolveUrls: (v) => [if (v.videoUrl != null) v.videoUrl!],
        );

        // Only id4 at index 0 is valid; no exception thrown.
        verify(
          () => cache.cacheFileCancellable(
            any(),
            key: any(named: 'key'),
          ),
        ).called(1);
      });

      test(
        'new run cancels in-flight previous cycle (stale generation)',
        () async {
          when(() => cache.getCachedFileSync(any())).thenReturn(null);

          var secondRunStarted = false;
          late final DiskPrefetcher slowPrefetcher;

          final slowCache = _MockMediaCacheManager();
          final logs2 = <String>[];
          slowPrefetcher = DiskPrefetcher(cache: slowCache, log: logs2.add);

          // Slow download that completes after a future.
          final downloadCompleter = _ManualCompleter<File?>();
          when(() => slowCache.getCachedFileSync(any())).thenReturn(null);
          when(
            () => slowCache.cacheFileCancellable(
              any(),
              key: any(named: 'key'),
            ),
          ).thenAnswer((_) {
            secondRunStarted = true;
            return _PendingOperation(downloadCompleter.future);
          });

          final videos = List.generate(
            5,
            (i) => _makeVideo('v$i', url: 'http://example.com/$i.m3u8'),
          );

          // Start first run (will stall on the slow operation at index 0).
          final firstRun = slowPrefetcher.run(
            startIndex: 0,
            endIndex: 0,
            videos: videos,
            resolveUrls: (v) => [if (v.videoUrl != null) v.videoUrl!],
          );

          // Allow first run to start.
          await Future<void>.delayed(Duration.zero);
          expect(secondRunStarted, isTrue);

          // Second run with a range far from index 0 — should cancel.
          unawaited(
            slowPrefetcher.run(
              startIndex: 3,
              endIndex: 4,
              videos: videos,
              resolveUrls: (v) => [if (v.videoUrl != null) v.videoUrl!],
            ),
          );

          // Unblock the slow download — but the first run is stale, should
          // detect cancellation and exit early.
          downloadCompleter.complete(null);
          await firstRun;

          expect(
            logs2.any((l) => l.contains('aborted') || l.contains('cancelled')),
            isTrue,
          );
          slowPrefetcher.dispose();
        },
      );

      test(
        'skips restart when active download index is within new range',
        () async {
          final slowCache = _MockMediaCacheManager();
          final logs2 = <String>[];
          final slowPrefetcher = DiskPrefetcher(
            cache: slowCache,
            log: logs2.add,
          );

          final downloadCompleter = _ManualCompleter<File?>();
          when(() => slowCache.getCachedFileSync(any())).thenReturn(null);
          when(
            () => slowCache.cacheFileCancellable(
              any(),
              key: any(named: 'key'),
            ),
          ).thenAnswer(
            (_) => _PendingOperation(downloadCompleter.future),
          );

          final videos = List.generate(
            10,
            (i) => _makeVideo('v$i', url: 'http://example.com/$i.m3u8'),
          );

          // Start cycle downloading index 3..8.
          unawaited(
            slowPrefetcher.run(
              startIndex: 3,
              endIndex: 8,
              videos: videos,
              resolveUrls: (v) => [if (v.videoUrl != null) v.videoUrl!],
            ),
          );

          // Let the first download start (index 3).
          await Future<void>.delayed(Duration.zero);

          // Second run with overlapping range — active index 3 is within
          // [2..7], so the cycle should NOT restart.
          unawaited(
            slowPrefetcher.run(
              startIndex: 2,
              endIndex: 7,
              videos: videos,
              resolveUrls: (v) => [if (v.videoUrl != null) v.videoUrl!],
            ),
          );

          expect(
            logs2.any((l) => l.contains('still active')),
            isTrue,
          );

          // Only one cacheFileCancellable call — the second run skipped.
          verify(
            () => slowCache.cacheFileCancellable(
              any(),
              key: any(named: 'key'),
            ),
          ).called(1);

          downloadCompleter.complete(null);
          slowPrefetcher.dispose();
        },
      );

      test('logs failure when download returns null', () async {
        const url = 'http://example.com/video.m3u8';
        final failCompleter = _ManualCompleter<File?>();

        when(() => cache.getCachedFileSync('id_fail')).thenReturn(null);
        when(
          () => cache.cacheFileCancellable(
            url,
            key: 'id_fail',
          ),
        ).thenAnswer((_) => _PendingOperation(failCompleter.future));

        final videos = [_makeVideo('id_fail', url: url)];

        final runFuture = prefetcher.run(
          startIndex: 0,
          endIndex: 0,
          videos: videos,
          resolveUrls: (v) => [if (v.videoUrl != null) v.videoUrl!],
        );

        failCompleter.complete(null);
        await runFuture;

        expect(logs.any((l) => l.contains('failed')), isTrue);
      });

      test(
        'cancels stalled download after stallTimeout and tries next URL',
        () async {
          final stallCache = _MockMediaCacheManager();
          final logs2 = <String>[];
          final stallPrefetcher = DiskPrefetcher(
            cache: stallCache,
            log: logs2.add,
            stallTimeout: const Duration(milliseconds: 50),
          );

          // First URL: never completes (simulates a silently-stalled
          // HTTP stream — no FileInfo, no error event).
          final stalledOp = _PendingOperation(Completer<File?>().future);
          // Second URL: completes successfully.
          final mockFile = _MockFile();
          final completedOp = CancellableCacheOperation.completed(mockFile);

          when(() => stallCache.getCachedFileSync(any())).thenReturn(null);
          when(
            () => stallCache.cacheFileCancellable(
              'http://example.com/dead',
              key: any(named: 'key'),
              aliasKey: any(named: 'aliasKey'),
            ),
          ).thenReturn(stalledOp);
          when(
            () => stallCache.cacheFileCancellable(
              'http://example.com/ok',
              key: any(named: 'key'),
              aliasKey: any(named: 'aliasKey'),
            ),
          ).thenReturn(completedOp);

          final videos = [_makeVideo('id_stall')];

          await stallPrefetcher.run(
            startIndex: 0,
            endIndex: 0,
            videos: videos,
            resolveUrls: (_) => const [
              'http://example.com/dead',
              'http://example.com/ok',
            ],
          );

          expect(stalledOp.isCancelled, isTrue);
          expect(logs2.any((l) => l.contains('stalled')), isTrue);
          expect(logs2.any((l) => l.contains('completed')), isTrue);
          stallPrefetcher.dispose();
        },
      );
    });

    group('cancelActive', () {
      test('can be called when no operation is active', () {
        expect(() => prefetcher.cancelActive(), returnsNormally);
      });
    });

    group('cancelCycle', () {
      test('can be called when no operation is active', () {
        expect(() => prefetcher.cancelCycle(), returnsNormally);
      });

      test(
        'halts the running cycle so it does not advance to the next index',
        () async {
          final slowCache = _MockMediaCacheManager();
          final logs2 = <String>[];
          final slowPrefetcher = DiskPrefetcher(
            cache: slowCache,
            log: logs2.add,
          );

          final downloadCompleter = _ManualCompleter<File?>();
          var downloadCalls = 0;
          when(() => slowCache.getCachedFileSync(any())).thenReturn(null);
          when(
            () => slowCache.cacheFileCancellable(any(), key: any(named: 'key')),
          ).thenAnswer((_) {
            downloadCalls++;
            return _PendingOperation(downloadCompleter.future);
          });

          final videos = List.generate(
            5,
            (i) => _makeVideo('v$i', url: 'http://example.com/$i.m3u8'),
          );

          final run = slowPrefetcher.run(
            startIndex: 0,
            endIndex: 4,
            videos: videos,
            resolveUrls: (v) => [if (v.videoUrl != null) v.videoUrl!],
          );

          // Let the cycle start the first download and park on it.
          await Future<void>.delayed(Duration.zero);
          expect(downloadCalls, equals(1));

          // Pause the whole cycle, then release the in-flight download.
          slowPrefetcher.cancelCycle();
          downloadCompleter.complete(null);
          await run;

          // The loop exited instead of advancing to index 1+.
          expect(downloadCalls, equals(1));
          slowPrefetcher.dispose();
        },
      );
    });

    group('dispose', () {
      test('cancels active operation without throwing', () {
        expect(() => prefetcher.dispose(), returnsNormally);
      });
    });
  });
}

/// Simple completer wrapper to satisfy the [Future] in our fake operation.
class _ManualCompleter<T> {
  final _completer = Completer<T>();
  Future<T> get future => _completer.future;
  void complete(T value) => _completer.complete(value);
}

/// A [CancellableCacheOperation] whose [file] future is controlled manually.
class _PendingOperation implements CancellableCacheOperation {
  _PendingOperation(this._fileFuture);

  final Future<File?> _fileFuture;

  @override
  Future<File?> get file => _fileFuture;

  @override
  bool get isCancelled => _cancelled;
  bool _cancelled = false;

  @override
  void cancel() => _cancelled = true;
}
