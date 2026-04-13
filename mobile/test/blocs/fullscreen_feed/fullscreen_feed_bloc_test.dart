// ABOUTME: Tests for FullscreenFeedBloc - fullscreen video playback state
// ABOUTME: Tests stream subscription, index changes, pagination, cache resolution,
// ABOUTME: and background caching

import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_cache/media_cache.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/fullscreen_feed/fullscreen_feed_bloc.dart';

class MockFileInfo extends Mock implements FileInfo {}

class MockMediaCacheManager extends Mock implements MediaCacheManager {}

class MockBlossomAuthService extends Mock implements BlossomAuthService {}

class MockFile extends Mock implements File {}

void main() {
  group('FullscreenFeedBloc', () {
    late StreamController<List<VideoEvent>> videosController;
    late MockMediaCacheManager mockMediaCache;
    late MockBlossomAuthService mockBlossomAuth;

    setUp(() {
      videosController = StreamController<List<VideoEvent>>.broadcast();
      mockMediaCache = MockMediaCacheManager();
      mockBlossomAuth = MockBlossomAuthService();

      // Default: no cached files
      when(() => mockMediaCache.getCachedFileSync(any())).thenReturn(null);
    });

    tearDown(() {
      videosController.close();
    });

    VideoEvent createTestVideo(String id, {String? sha256}) {
      final now = DateTime.now();
      return VideoEvent(
        id: id,
        pubkey: '0' * 64,
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        content: '',
        timestamp: now,
        title: 'Test Video $id',
        videoUrl: 'https://example.com/video_$id.mp4',
        thumbnailUrl: 'https://example.com/thumb_$id.jpg',
        sha256: sha256,
      );
    }

    FullscreenFeedBloc createBloc({
      int initialIndex = 0,
      void Function()? onLoadMore,
      MediaCacheManager? mediaCache,
      BlossomAuthService? blossomAuthService,
    }) => FullscreenFeedBloc(
      videosStream: videosController.stream,
      initialIndex: initialIndex,
      onLoadMore: onLoadMore,
      mediaCache: mediaCache ?? mockMediaCache,
      blossomAuthService: blossomAuthService,
    );

    test('initial state has correct values', () {
      final bloc = createBloc(initialIndex: 2);
      expect(bloc.state.status, FullscreenFeedStatus.initial);
      expect(bloc.state.videos, isEmpty);
      expect(bloc.state.currentIndex, 2);
      expect(bloc.state.isLoadingMore, isFalse);
      bloc.close();
    });

    group('FullscreenFeedState', () {
      test('currentVideo returns video at currentIndex', () {
        final video1 = createTestVideo('video1');
        final video2 = createTestVideo('video2');
        final state = FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [video1, video2],
          currentIndex: 1,
        );

        expect(state.currentVideo, video2);
      });

      test('currentVideo returns null when index out of range', () {
        final video = createTestVideo('video1');
        final state = FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [video],
          currentIndex: 5,
        );

        expect(state.currentVideo, isNull);
      });

      test('currentVideo returns null when videos empty', () {
        const state = FullscreenFeedState(status: FullscreenFeedStatus.ready);

        expect(state.currentVideo, isNull);
      });

      test('hasVideos returns true when videos not empty', () {
        final video = createTestVideo('video1');
        final state = FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [video],
        );

        expect(state.hasVideos, isTrue);
      });

      test('hasVideos returns false when videos empty', () {
        const state = FullscreenFeedState(status: FullscreenFeedStatus.ready);

        expect(state.hasVideos, isFalse);
      });

      test('pooledVideos uses platform-aware playback URLs', () {
        final now = DateTime.now();
        const url =
            'https://media.divine.video/'
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef.mp4';
        final video = VideoEvent(
          id: 'video1',
          pubkey: '0' * 64,
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          content: '',
          timestamp: now,
          videoUrl: url,
        );

        final state = FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [video],
        );

        expect(state.pooledVideos, hasLength(1));
        expect(state.pooledVideos.single.url, url);
      });

      test('copyWith creates copy with updated values', () {
        const state = FullscreenFeedState();
        final video = createTestVideo('video1');

        final updated = state.copyWith(
          status: FullscreenFeedStatus.ready,
          videos: [video],
          currentIndex: 5,
          isLoadingMore: true,
        );

        expect(updated.status, FullscreenFeedStatus.ready);
        expect(updated.videos, [video]);
        expect(updated.currentIndex, 5);
        expect(updated.isLoadingMore, isTrue);
      });

      test('copyWith preserves values when not specified', () {
        final video = createTestVideo('video1');
        final state = FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [video],
          currentIndex: 3,
          isLoadingMore: true,
        );

        final updated = state.copyWith();

        expect(updated.status, FullscreenFeedStatus.ready);
        expect(updated.videos, [video]);
        expect(updated.currentIndex, 3);
        expect(updated.isLoadingMore, isTrue);
      });

      test('props contains all fields for Equatable', () {
        final video = createTestVideo('video1');
        final state = FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [video],
          currentIndex: 2,
          isLoadingMore: true,
        );

        expect(state.props, [
          FullscreenFeedStatus.ready,
          [video],
          2,
          true,
          false,
        ]);
      });
    });

    group('FullscreenFeedStarted', () {
      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'subscribes to videos stream and emits ready when videos arrive',
        build: createBloc,
        act: (bloc) async {
          bloc.add(const FullscreenFeedStarted());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController.add([createTestVideo('video1')]);
        },
        wait: const Duration(milliseconds: 100),
        expect: () => [
          isA<FullscreenFeedState>()
              .having((s) => s.status, 'status', FullscreenFeedStatus.ready)
              .having((s) => s.videos.length, 'videos count', 1)
              .having((s) => s.videos.first.id, 'first video id', 'video1'),
        ],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'emits multiple times when stream emits multiple values',
        build: createBloc,
        act: (bloc) async {
          bloc.add(const FullscreenFeedStarted());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController.add([createTestVideo('video1')]);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController.add([
            createTestVideo('video1'),
            createTestVideo('video2'),
          ]);
        },
        wait: const Duration(milliseconds: 200),
        expect: () => [
          isA<FullscreenFeedState>().having(
            (s) => s.videos.length,
            'videos count',
            1,
          ),
          isA<FullscreenFeedState>().having(
            (s) => s.videos.length,
            'videos count',
            2,
          ),
        ],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'cancels previous subscription when started again',
        build: createBloc,
        act: (bloc) async {
          bloc.add(const FullscreenFeedStarted());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          bloc.add(const FullscreenFeedStarted());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController.add([createTestVideo('video1')]);
        },
        wait: const Duration(milliseconds: 200),
        expect: () => [
          isA<FullscreenFeedState>().having(
            (s) => s.videos.length,
            'videos count',
            1,
          ),
        ],
      );
    });

    group('FullscreenFeedLoadMoreRequested', () {
      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'sets isLoadingMore and calls onLoadMore callback',
        build: () {
          var callCount = 0;
          return createBloc(onLoadMore: () => callCount++);
        },
        act: (bloc) => bloc.add(const FullscreenFeedLoadMoreRequested()),
        expect: () => [
          isA<FullscreenFeedState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            true,
          ),
        ],
      );

      test('calls onLoadMore callback when triggered', () async {
        var called = false;
        final bloc = FullscreenFeedBloc(
          videosStream: videosController.stream,
          initialIndex: 0,
          onLoadMore: () => called = true,
          mediaCache: mockMediaCache,
        );

        bloc.add(const FullscreenFeedLoadMoreRequested());
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(called, isTrue);
        await bloc.close();
      });

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'does nothing when onLoadMore is null',
        build: createBloc,
        act: (bloc) => bloc.add(const FullscreenFeedLoadMoreRequested()),
        expect: () => <FullscreenFeedState>[],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'does nothing when already loading more',
        build: () => createBloc(onLoadMore: () {}),
        seed: () => const FullscreenFeedState(isLoadingMore: true),
        act: (bloc) => bloc.add(const FullscreenFeedLoadMoreRequested()),
        expect: () => <FullscreenFeedState>[],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'resets isLoadingMore when onLoadMore throws synchronously',
        build: () => createBloc(
          onLoadMore: () => throw StateError('stale widget callback'),
        ),
        act: (bloc) => bloc.add(const FullscreenFeedLoadMoreRequested()),
        expect: () => [
          isA<FullscreenFeedState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            true,
          ),
          isA<FullscreenFeedState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            false,
          ),
        ],
      );
    });

    group('FullscreenFeedIndexChanged', () {
      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'updates currentIndex',
        build: createBloc,
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [
            createTestVideo('video1'),
            createTestVideo('video2'),
            createTestVideo('video3'),
          ],
        ),
        act: (bloc) => bloc.add(const FullscreenFeedIndexChanged(2)),
        expect: () => [
          isA<FullscreenFeedState>().having(
            (s) => s.currentIndex,
            'currentIndex',
            2,
          ),
        ],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'clamps index to valid range',
        build: createBloc,
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [createTestVideo('video1'), createTestVideo('video2')],
        ),
        act: (bloc) => bloc.add(const FullscreenFeedIndexChanged(10)),
        expect: () => [
          isA<FullscreenFeedState>().having(
            (s) => s.currentIndex,
            'currentIndex',
            1,
          ),
        ],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'clamps negative index to 0',
        build: createBloc,
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [createTestVideo('video1')],
        ),
        act: (bloc) => bloc.add(const FullscreenFeedIndexChanged(-5)),
        expect: () => <FullscreenFeedState>[],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'does nothing when index unchanged',
        build: createBloc,
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [createTestVideo('video1')],
        ),
        act: (bloc) => bloc.add(const FullscreenFeedIndexChanged(0)),
        expect: () => <FullscreenFeedState>[],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'sets index to 0 when videos are empty',
        build: createBloc,
        seed: () => const FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          currentIndex: 5,
        ),
        act: (bloc) => bloc.add(const FullscreenFeedIndexChanged(10)),
        expect: () => [
          isA<FullscreenFeedState>().having(
            (s) => s.currentIndex,
            'currentIndex',
            0,
          ),
        ],
      );
    });

    group('close', () {
      test('cancels videos subscription', () async {
        final bloc = createBloc();
        bloc.add(const FullscreenFeedStarted());
        await Future<void>.delayed(const Duration(milliseconds: 50));

        await bloc.close();

        // After closing, stream events should not cause errors
        expect(
          () => videosController.add([createTestVideo('video1')]),
          returnsNormally,
        );
      });
    });

    group('FullscreenFeedEvent props', () {
      test('FullscreenFeedStarted props is empty', () {
        const event = FullscreenFeedStarted();
        expect(event.props, isEmpty);
      });

      test('FullscreenFeedLoadMoreRequested props is empty', () {
        const event = FullscreenFeedLoadMoreRequested();
        expect(event.props, isEmpty);
      });

      test('FullscreenFeedIndexChanged props contains index', () {
        const event = FullscreenFeedIndexChanged(5);
        expect(event.props, [5]);
      });

      test('FullscreenFeedVideoCacheStarted props contains index', () {
        const event = FullscreenFeedVideoCacheStarted(index: 3);
        expect(event.props, [3]);
      });
    });

    group('cache resolution', () {
      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'does not replace videoUrl with cache path when videos arrive',
        setUp: () {
          final mockFile = MockFile();
          when(() => mockFile.path).thenReturn('/cached/video1.mp4');
          when(
            () => mockMediaCache.getCachedFileSync('video1'),
          ).thenReturn(mockFile);
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const FullscreenFeedStarted());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController.add([createTestVideo('video1')]);
        },
        wait: const Duration(milliseconds: 100),
        expect: () => [
          isA<FullscreenFeedState>()
              .having((s) => s.status, 'status', FullscreenFeedStatus.ready)
              .having(
                (s) => s.videos.first.videoUrl,
                'videoUrl preserved as HTTP',
                'https://example.com/video_video1.mp4',
              ),
        ],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'keeps original URL when video is not cached',
        build: createBloc,
        act: (bloc) async {
          bloc.add(const FullscreenFeedStarted());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController.add([createTestVideo('video1')]);
        },
        wait: const Duration(milliseconds: 100),
        expect: () => [
          isA<FullscreenFeedState>().having(
            (s) => s.videos.first.videoUrl,
            'original video URL',
            'https://example.com/video_video1.mp4',
          ),
        ],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'preserves HTTP videoUrl when cache hit occurs '
        '(never replaces with local file path)',
        setUp: () {
          final mockFile = MockFile();
          when(() => mockFile.path).thenReturn(
            '/data/user/0/co.openvine.app/cache/openvine_video_cache/video1.mp4',
          );
          when(
            () => mockMediaCache.getCachedFileSync('video1'),
          ).thenReturn(mockFile);
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const FullscreenFeedStarted());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController.add([createTestVideo('video1')]);
        },
        wait: const Duration(milliseconds: 100),
        expect: () => [
          isA<FullscreenFeedState>()
              .having((s) => s.status, 'status', FullscreenFeedStatus.ready)
              .having(
                (s) => s.videos.first.videoUrl,
                'videoUrl must remain HTTP',
                startsWith('https://'),
              ),
        ],
      );
    });

    group('FullscreenFeedVideoCacheStarted', () {
      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'triggers background caching for uncached video',
        setUp: () {
          when(
            () => mockMediaCache.downloadFile(
              any(),
              key: any(named: 'key'),
              authHeaders: any(named: 'authHeaders'),
            ),
          ).thenAnswer((_) async => MockFileInfo());
        },
        build: createBloc,
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [createTestVideo('video1')],
        ),
        act: (bloc) =>
            bloc.add(const FullscreenFeedVideoCacheStarted(index: 0)),
        wait: const Duration(milliseconds: 100),
        verify: (_) {
          verify(
            () => mockMediaCache.downloadFile(
              'https://example.com/video_video1.mp4',
              key: 'video1',
            ),
          ).called(1);
        },
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'skips caching when video is already cached',
        setUp: () {
          final mockFile = MockFile();
          when(() => mockFile.path).thenReturn('/cached/video1.mp4');
          when(
            () => mockMediaCache.getCachedFileSync('video1'),
          ).thenReturn(mockFile);
        },
        build: createBloc,
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [createTestVideo('video1')],
        ),
        act: (bloc) =>
            bloc.add(const FullscreenFeedVideoCacheStarted(index: 0)),
        wait: const Duration(milliseconds: 100),
        verify: (_) {
          verifyNever(
            () => mockMediaCache.downloadFile(
              any(),
              key: any(named: 'key'),
              authHeaders: any(named: 'authHeaders'),
            ),
          );
        },
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'does nothing for invalid index',
        build: createBloc,
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [createTestVideo('video1')],
        ),
        act: (bloc) =>
            bloc.add(const FullscreenFeedVideoCacheStarted(index: 5)),
        wait: const Duration(milliseconds: 50),
        verify: (_) {
          verifyNever(
            () => mockMediaCache.downloadFile(
              any(),
              key: any(named: 'key'),
              authHeaders: any(named: 'authHeaders'),
            ),
          );
        },
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'background caching uses HTTP URL '
        '(never passes local file path to downloadFile)',
        setUp: () {
          when(
            () => mockMediaCache.downloadFile(
              any(),
              key: any(named: 'key'),
              authHeaders: any(named: 'authHeaders'),
            ),
          ).thenAnswer((_) async => MockFileInfo());
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const FullscreenFeedStarted());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController.add([createTestVideo('video1')]);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          bloc.add(const FullscreenFeedVideoCacheStarted(index: 0));
        },
        wait: const Duration(milliseconds: 200),
        verify: (_) {
          // downloadFile must receive an HTTP URL, not a local file path
          verify(
            () => mockMediaCache.downloadFile(
              'https://example.com/video_video1.mp4',
              key: 'video1',
            ),
          ).called(1);
          // Must never be called with a file path
          verifyNever(
            () => mockMediaCache.downloadFile(
              any(that: startsWith('/')),
              key: any(named: 'key'),
              authHeaders: any(named: 'authHeaders'),
            ),
          );
        },
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'skips caching when videoUrl is a local file path',
        build: createBloc,
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [
            VideoEvent(
              id: 'video1',
              pubkey: '0' * 64,
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              content: '',
              timestamp: DateTime.now(),
              title: 'Test',
              videoUrl: '/data/user/0/cache/video1.mp4',
            ),
          ],
        ),
        act: (bloc) =>
            bloc.add(const FullscreenFeedVideoCacheStarted(index: 0)),
        wait: const Duration(milliseconds: 100),
        verify: (_) {
          verifyNever(
            () => mockMediaCache.downloadFile(
              any(),
              key: any(named: 'key'),
              authHeaders: any(named: 'authHeaders'),
            ),
          );
        },
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'includes auth headers when BlossomAuthService is provided',
        setUp: () {
          when(
            () => mockBlossomAuth.createGetAuthHeader(
              sha256Hash: any(named: 'sha256Hash'),
            ),
          ).thenAnswer((_) async => 'Nostr test-token');
          when(
            () => mockMediaCache.downloadFile(
              any(),
              key: any(named: 'key'),
              authHeaders: any(named: 'authHeaders'),
            ),
          ).thenAnswer((_) async => MockFileInfo());
        },
        build: () => createBloc(blossomAuthService: mockBlossomAuth),
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [createTestVideo('video1', sha256: 'abc123')],
        ),
        act: (bloc) =>
            bloc.add(const FullscreenFeedVideoCacheStarted(index: 0)),
        wait: const Duration(milliseconds: 100),
        verify: (_) {
          verify(
            () => mockMediaCache.downloadFile(
              'https://example.com/video_video1.mp4',
              key: 'video1',
              authHeaders: {'Authorization': 'Nostr test-token'},
            ),
          ).called(1);
        },
      );
    });
  });
}
