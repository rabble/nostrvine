// ABOUTME: Tests for FullscreenFeedBloc - fullscreen video playback state
// ABOUTME: Tests stream subscription, index changes, pagination, cache resolution,
// ABOUTME: and background caching

import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:media_cache/media_cache.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/fullscreen_feed/fullscreen_feed_bloc.dart';
import 'package:openvine/services/media_availability_checker.dart';

class MockFileInfo extends Mock implements FileInfo {}

class MockMediaCacheManager extends Mock implements MediaCacheManager {}

class MockBlossomAuthService extends Mock implements BlossomAuthService {}

class MockFile extends Mock implements File {}

void main() {
  group('FullscreenFeedBloc', () {
    late StreamController<List<VideoEvent>> videosController;
    late StreamController<bool> hasMoreController;
    late MockMediaCacheManager mockMediaCache;
    late MockBlossomAuthService mockBlossomAuth;

    setUp(() {
      videosController = StreamController<List<VideoEvent>>.broadcast();
      hasMoreController = StreamController<bool>.broadcast();
      mockMediaCache = MockMediaCacheManager();
      mockBlossomAuth = MockBlossomAuthService();

      // Default: no cached files
      when(() => mockMediaCache.getCachedFileSync(any())).thenReturn(null);
    });

    tearDown(() {
      videosController.close();
      hasMoreController.close();
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
      Stream<bool>? hasMoreStream,
      MediaCacheManager? mediaCache,
      BlossomAuthService? blossomAuthService,
      OnRemoveVideo? onRemoveVideo,
      MediaAvailabilityChecker? availabilityChecker,
    }) => FullscreenFeedBloc(
      videosStream: videosController.stream,
      initialIndex: initialIndex,
      onLoadMore: onLoadMore,
      hasMoreStream: hasMoreStream,
      mediaCache: mediaCache ?? mockMediaCache,
      blossomAuthService: blossomAuthService,
      onRemoveVideo: onRemoveVideo,
      availabilityChecker: availabilityChecker,
    );

    test('initial state has correct values', () {
      final bloc = createBloc(initialIndex: 2);
      expect(bloc.state.status, FullscreenFeedStatus.initial);
      expect(bloc.state.videos, isEmpty);
      expect(bloc.state.currentIndex, 2);
      expect(bloc.state.isLoadingMore, isFalse);
      expect(bloc.state.canLoadMore, isFalse);
      bloc.close();
    });

    test('load more stays unavailable until hasMoreStream emits true', () {
      final bloc = createBloc(
        onLoadMore: () {},
        hasMoreStream: hasMoreController.stream,
      );

      expect(bloc.state.canLoadMore, isFalse);
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
          <String>{},
          null,
        ]);
      });
    });

    group('FullscreenFeedStarted', () {
      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'updates canLoadMore from hasMoreStream',
        build: () => createBloc(
          onLoadMore: () {},
          hasMoreStream: hasMoreController.stream,
        ),
        act: (bloc) async {
          bloc.add(const FullscreenFeedStarted());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          hasMoreController.add(true);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          hasMoreController.add(false);
        },
        wait: const Duration(milliseconds: 200),
        expect: () => [
          isA<FullscreenFeedState>().having(
            (s) => s.canLoadMore,
            'canLoadMore',
            true,
          ),
          isA<FullscreenFeedState>().having(
            (s) => s.canLoadMore,
            'canLoadMore',
            false,
          ),
        ],
      );

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

    group('FullscreenFeedVideoUnavailable', () {
      MediaAvailabilityChecker checkerReturning(int statusCode) {
        final client = MockClient(
          (_) async => http.Response('', statusCode),
        );
        return MediaAvailabilityChecker(client: client);
      }

      MediaAvailabilityChecker throwingChecker() {
        final client = MockClient(
          (_) async => throw http.ClientException('timeout'),
        );
        return MediaAvailabilityChecker(client: client);
      }

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'removes video and emits pending skip when HEAD confirms 404',
        build: () {
          final removed = <String>[];
          return createBloc(
            onRemoveVideo: removed.add,
            availabilityChecker: checkerReturning(404),
          );
        },
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [
            createTestVideo('video1'),
            createTestVideo('video2'),
          ],
        ),
        act: (bloc) => bloc.add(const FullscreenFeedVideoUnavailable('video1')),
        wait: const Duration(milliseconds: 100),
        expect: () => [
          isA<FullscreenFeedState>()
              .having(
                (s) => s.removedVideoIds,
                'removedVideoIds',
                equals({'video1'}),
              )
              .having(
                (s) => s.pendingSkipTarget,
                'pendingSkipTarget',
                equals(1),
              ),
        ],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'calls onRemoveVideo callback when HEAD confirms 404',
        build: () => createBloc(
          onRemoveVideo: expectAsync1<void, String>((id) {
            expect(id, equals('video1'));
          }),
          availabilityChecker: checkerReturning(404),
        ),
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [createTestVideo('video1')],
        ),
        act: (bloc) => bloc.add(const FullscreenFeedVideoUnavailable('video1')),
        wait: const Duration(milliseconds: 100),
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'does not remove or skip when HEAD returns 200 (transient error)',
        build: () {
          return createBloc(
            onRemoveVideo: (_) => fail('should not remove on non-404'),
            availabilityChecker: checkerReturning(200),
          );
        },
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [createTestVideo('video1')],
        ),
        act: (bloc) => bloc.add(const FullscreenFeedVideoUnavailable('video1')),
        wait: const Duration(milliseconds: 100),
        expect: () => <FullscreenFeedState>[],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'does not remove when HEAD request throws (network error)',
        build: () {
          return createBloc(
            onRemoveVideo: (_) => fail('should not remove on network error'),
            availabilityChecker: throwingChecker(),
          );
        },
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [createTestVideo('video1')],
        ),
        act: (bloc) => bloc.add(const FullscreenFeedVideoUnavailable('video1')),
        wait: const Duration(milliseconds: 100),
        expect: () => <FullscreenFeedState>[],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'deduplicates repeated unavailable events for the same video',
        build: () {
          var callCount = 0;
          return createBloc(
            onRemoveVideo: (_) => callCount++,
            availabilityChecker: checkerReturning(404),
          );
        },
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [
            createTestVideo('video1'),
            createTestVideo('video2'),
          ],
        ),
        act: (bloc) async {
          bloc.add(const FullscreenFeedVideoUnavailable('video1'));
          await Future<void>.delayed(const Duration(milliseconds: 50));
          bloc.add(const FullscreenFeedVideoUnavailable('video1'));
          await Future<void>.delayed(const Duration(milliseconds: 50));
          bloc.add(const FullscreenFeedVideoUnavailable('video1'));
        },
        wait: const Duration(milliseconds: 200),
        expect: () => [
          isA<FullscreenFeedState>()
              .having(
                (s) => s.removedVideoIds,
                'removedVideoIds',
                equals({'video1'}),
              )
              .having(
                (s) => s.pendingSkipTarget,
                'pendingSkipTarget',
                equals(1),
              ),
        ],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'no-ops when video id is not in the current list',
        build: () => createBloc(
          onRemoveVideo: (_) => fail('unknown video should not trigger remove'),
          availabilityChecker: checkerReturning(404),
        ),
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [createTestVideo('video1')],
        ),
        act: (bloc) =>
            bloc.add(const FullscreenFeedVideoUnavailable('unknown')),
        wait: const Duration(milliseconds: 50),
        expect: () => <FullscreenFeedState>[],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'no-ops when video has no URL',
        build: () => createBloc(
          onRemoveVideo: (_) => fail('videos without URL cannot be confirmed'),
          availabilityChecker: checkerReturning(404),
        ),
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [
            VideoEvent(
              id: 'video1',
              pubkey: '0' * 64,
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              content: '',
              timestamp: DateTime.now(),
              title: 'no url',
            ),
          ],
        ),
        act: (bloc) => bloc.add(const FullscreenFeedVideoUnavailable('video1')),
        wait: const Duration(milliseconds: 50),
        expect: () => <FullscreenFeedState>[],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'skip target matches index of removed video + 1',
        build: () => createBloc(
          onRemoveVideo: (_) {},
          availabilityChecker: checkerReturning(404),
        ),
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [
            createTestVideo('video1'),
            createTestVideo('video2'),
            createTestVideo('video3'),
          ],
          currentIndex: 1,
        ),
        act: (bloc) => bloc.add(const FullscreenFeedVideoUnavailable('video2')),
        wait: const Duration(milliseconds: 100),
        expect: () => [
          isA<FullscreenFeedState>().having(
            (s) => s.pendingSkipTarget,
            'pendingSkipTarget',
            equals(2),
          ),
        ],
      );
    });

    group('FullscreenFeedSkipAcknowledged', () {
      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'clears pendingSkipTarget when acknowledged',
        build: createBloc,
        seed: () => const FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          pendingSkipTarget: 2,
        ),
        act: (bloc) => bloc.add(const FullscreenFeedSkipAcknowledged()),
        expect: () => [
          isA<FullscreenFeedState>().having(
            (s) => s.pendingSkipTarget,
            'pendingSkipTarget',
            isNull,
          ),
        ],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'no-ops when no pending skip',
        build: createBloc,
        seed: () => const FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
        ),
        act: (bloc) => bloc.add(const FullscreenFeedSkipAcknowledged()),
        expect: () => <FullscreenFeedState>[],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'allows subsequent unavailable events to emit a new skip',
        build: () => createBloc(
          onRemoveVideo: (_) {},
          availabilityChecker: MediaAvailabilityChecker(
            client: MockClient((_) async => http.Response('', 404)),
          ),
        ),
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [
            createTestVideo('video1'),
            createTestVideo('video2'),
          ],
        ),
        act: (bloc) async {
          bloc.add(const FullscreenFeedVideoUnavailable('video1'));
          await Future<void>.delayed(const Duration(milliseconds: 50));
          bloc.add(const FullscreenFeedSkipAcknowledged());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          bloc.add(const FullscreenFeedVideoUnavailable('video2'));
        },
        wait: const Duration(milliseconds: 300),
        expect: () => [
          isA<FullscreenFeedState>().having(
            (s) => s.pendingSkipTarget,
            'pendingSkipTarget after first unavailable',
            equals(1),
          ),
          isA<FullscreenFeedState>().having(
            (s) => s.pendingSkipTarget,
            'pendingSkipTarget cleared',
            isNull,
          ),
          isA<FullscreenFeedState>().having(
            (s) => s.pendingSkipTarget,
            'pendingSkipTarget after second unavailable',
            equals(2),
          ),
        ],
      );
    });

    group('props and copyWith for new fields', () {
      test('removedVideoIds default is empty', () {
        const state = FullscreenFeedState();
        expect(state.removedVideoIds, isEmpty);
      });

      test('pendingSkipTarget default is null', () {
        const state = FullscreenFeedState();
        expect(state.pendingSkipTarget, isNull);
      });

      test('copyWith updates removedVideoIds', () {
        const state = FullscreenFeedState();
        final updated = state.copyWith(removedVideoIds: {'a', 'b'});
        expect(updated.removedVideoIds, equals({'a', 'b'}));
      });

      test('copyWith updates pendingSkipTarget', () {
        const state = FullscreenFeedState();
        final updated = state.copyWith(pendingSkipTarget: 5);
        expect(updated.pendingSkipTarget, equals(5));
      });

      test('copyWith clearPendingSkipTarget resets to null', () {
        const state = FullscreenFeedState(pendingSkipTarget: 5);
        final updated = state.copyWith(clearPendingSkipTarget: true);
        expect(updated.pendingSkipTarget, isNull);
      });

      test('FullscreenFeedVideoUnavailable props contains videoId', () {
        const event = FullscreenFeedVideoUnavailable('abc');
        expect(event.props, equals(['abc']));
      });

      test('FullscreenFeedSkipAcknowledged props is empty', () {
        const event = FullscreenFeedSkipAcknowledged();
        expect(event.props, isEmpty);
      });
    });
  });
}
