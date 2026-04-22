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
          resolveUrl: (v) => v.videoUrl,
        );

        verifyNever(
          () => cache.cacheFileCancellable(any(), key: any(named: 'key')),
        );
        expect(logs.any((l) => l.contains('already cached')), isTrue);
      });

      test('skips entries with null URL from resolver', () async {
        when(() => cache.getCachedFileSync(any())).thenReturn(null);

        final videos = [_makeVideo('id2')];

        await prefetcher.run(
          startIndex: 0,
          endIndex: 0,
          videos: videos,
          resolveUrl: (_) => null,
        );

        verifyNever(
          () => cache.cacheFileCancellable(any(), key: any(named: 'key')),
        );
        expect(logs.any((l) => l.contains('no URL')), isTrue);
      });

      test('downloads uncached entries', () async {
        final mockFile = _MockFile();
        const url = 'http://example.com/video.m3u8';

        when(() => cache.getCachedFileSync('id3')).thenReturn(null);
        when(() => cache.cacheFileCancellable(url, key: 'id3')).thenReturn(
          CancellableCacheOperation.completed(mockFile),
        );

        final videos = [_makeVideo('id3', url: url)];

        await prefetcher.run(
          startIndex: 0,
          endIndex: 0,
          videos: videos,
          resolveUrl: (v) => v.videoUrl,
        );

        verify(() => cache.cacheFileCancellable(url, key: 'id3')).called(1);
        expect(logs.any((l) => l.contains('completed')), isTrue);
      });

      test('ignores indices outside videos list bounds', () async {
        final videos = [_makeVideo('id4', url: 'http://example.com/4.m3u8')];

        // endIndex 5 is out of bounds; should not throw.
        when(() => cache.getCachedFileSync(any())).thenReturn(null);
        when(
          () => cache.cacheFileCancellable(any(), key: any(named: 'key')),
        ).thenReturn(CancellableCacheOperation.completed(_MockFile()));

        await prefetcher.run(
          startIndex: 0,
          endIndex: 5,
          videos: videos,
          resolveUrl: (v) => v.videoUrl,
        );

        // Only id4 at index 0 is valid; no exception thrown.
        verify(
          () => cache.cacheFileCancellable(any(), key: any(named: 'key')),
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
            () => slowCache.cacheFileCancellable(any(), key: any(named: 'key')),
          ).thenAnswer((_) {
            secondRunStarted = true;
            return _PendingOperation(downloadCompleter.future);
          });

          final videos = [
            _makeVideo('slow', url: 'http://example.com/slow.m3u8'),
            _makeVideo('fast', url: 'http://example.com/fast.m3u8'),
          ];

          // Start first run (will stall on the slow operation).
          final firstRun = slowPrefetcher.run(
            startIndex: 0,
            endIndex: 0,
            videos: videos,
            resolveUrl: (v) => v.videoUrl,
          );

          // Allow first run to start.
          await Future<void>.delayed(Duration.zero);
          expect(secondRunStarted, isTrue);

          // Second run cancels first.
          unawaited(
            slowPrefetcher.run(
              startIndex: 1,
              endIndex: 1,
              videos: videos,
              resolveUrl: (v) => v.videoUrl,
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
    });

    group('cancelActive', () {
      test('can be called when no operation is active', () {
        expect(() => prefetcher.cancelActive(), returnsNormally);
      });
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
