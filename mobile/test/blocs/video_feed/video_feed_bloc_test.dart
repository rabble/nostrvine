// ABOUTME: Tests for VideoFeedBloc - unified video feed with mode switching
// ABOUTME: Tests loading, pagination, mode switching, and following changes

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_feed/video_feed_bloc.dart';
import 'package:openvine/repositories/follow_repository.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockFollowRepository extends Mock implements FollowRepository {}

void main() {
  group('VideoFeedBloc', () {
    late _MockVideosRepository mockVideosRepository;
    late _MockFollowRepository mockFollowRepository;
    late StreamController<List<String>> followingController;

    setUp(() {
      mockVideosRepository = _MockVideosRepository();
      mockFollowRepository = _MockFollowRepository();
      followingController = StreamController<List<String>>.broadcast();

      // Default stubs
      when(
        () => mockFollowRepository.followingStream,
      ).thenAnswer((_) => followingController.stream);
      when(() => mockFollowRepository.followingPubkeys).thenReturn([]);
    });

    tearDown(() {
      followingController.close();
    });

    VideoFeedBloc createBloc() => VideoFeedBloc(
      videosRepository: mockVideosRepository,
      followRepository: mockFollowRepository,
    );

    VideoEvent createTestVideo(String id, {int? createdAt}) {
      final timestamp =
          createdAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return VideoEvent(
        id: id,
        pubkey: '0' * 64,
        createdAt: timestamp,
        content: '',
        timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp * 1000),
        title: 'Test Video $id',
        videoUrl: 'https://example.com/$id.mp4',
        thumbnailUrl: 'https://example.com/$id.jpg',
      );
    }

    List<VideoEvent> createTestVideos(
      int count, {
      int? startTimestamp,
      String idPrefix = 'video',
    }) {
      final baseTimestamp =
          startTimestamp ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return List.generate(
        count,
        (i) => createTestVideo(
          '$idPrefix-$i',
          createdAt: baseTimestamp - i, // Decreasing timestamps
        ),
      );
    }

    /// Page size constant must match the one in video_feed_bloc.dart
    const pageSize = 5;

    test('initial state is correct', () {
      final bloc = createBloc();
      expect(bloc.state.status, VideoFeedStatus.loading);
      expect(bloc.state.videos, isEmpty);
      expect(bloc.state.mode, FeedMode.home);
      expect(bloc.state.hasMore, isTrue);
      expect(bloc.state.isLoadingMore, isFalse);
      expect(bloc.state.error, isNull);
      bloc.close();
    });

    group('VideoFeedState', () {
      test('isLoaded returns true when status is success', () {
        const initialState = VideoFeedState();
        const successState = VideoFeedState(status: VideoFeedStatus.success);

        expect(initialState.isLoaded, isFalse);
        expect(successState.isLoaded, isTrue);
      });

      test('isLoading returns true when status is loading', () {
        const initialState = VideoFeedState();

        expect(initialState.isLoading, isTrue);
      });

      test('isEmpty returns true when success with no videos', () {
        const emptyState = VideoFeedState(status: VideoFeedStatus.success);
        final loadedState = VideoFeedState(
          status: VideoFeedStatus.success,
          videos: [createTestVideo('v1')],
        );

        expect(emptyState.isEmpty, isTrue);
        expect(loadedState.isEmpty, isFalse);
      });

      test('copyWith creates copy with updated values', () {
        const state = VideoFeedState();

        final updated = state.copyWith(
          status: VideoFeedStatus.success,
          mode: FeedMode.latest,
        );

        expect(updated.status, VideoFeedStatus.success);
        expect(updated.mode, FeedMode.latest);
      });

      test('copyWith preserves values when not specified', () {
        const state = VideoFeedState(
          status: VideoFeedStatus.success,
          mode: FeedMode.popular,
        );

        final updated = state.copyWith();

        expect(updated.status, VideoFeedStatus.success);
        expect(updated.mode, FeedMode.popular);
      });

      test('copyWith clearError removes error', () {
        const state = VideoFeedState(error: VideoFeedError.loadFailed);

        final updated = state.copyWith(clearError: true);

        expect(updated.error, isNull);
      });
    });

    group('VideoFeedStarted', () {
      blocTest<VideoFeedBloc, VideoFeedState>(
        'emits [loading, success] when home feed loads successfully',
        setUp: () {
          final videos = createTestVideos(pageSize);
          final authors = ['author1', 'author2'];

          when(() => mockFollowRepository.followingPubkeys).thenReturn(authors);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: authors,
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) async => videos);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const VideoFeedStarted()),
        expect: () => [
          const VideoFeedState(
            status: VideoFeedStatus.loading,
            mode: FeedMode.home,
          ),
          isA<VideoFeedState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.videos.length, 'videos count', pageSize)
              .having((s) => s.mode, 'mode', FeedMode.home)
              .having((s) => s.hasMore, 'hasMore', true),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'emits [loading, success] with latest mode when specified',
        setUp: () {
          final videos = createTestVideos(5);

          when(
            () => mockVideosRepository.getNewVideos(
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) async => videos);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const VideoFeedStarted(mode: FeedMode.latest)),
        expect: () => [
          const VideoFeedState(
            status: VideoFeedStatus.loading,
            mode: FeedMode.latest,
          ),
          isA<VideoFeedState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.mode, 'mode', FeedMode.latest),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'emits [loading, success] with popular mode when specified',
        setUp: () {
          final videos = createTestVideos(5);

          when(
            () => mockVideosRepository.getPopularVideos(
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) async => videos);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const VideoFeedStarted(mode: FeedMode.popular)),
        expect: () => [
          const VideoFeedState(
            status: VideoFeedStatus.loading,
            mode: FeedMode.popular,
          ),
          isA<VideoFeedState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.mode, 'mode', FeedMode.popular),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'emits [loading, success] with noFollowedUsers error when home feed empty due to no follows',
        setUp: () {
          when(() => mockFollowRepository.followingPubkeys).thenReturn([]);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) async => []);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const VideoFeedStarted()),
        expect: () => [
          const VideoFeedState(
            status: VideoFeedStatus.loading,
            mode: FeedMode.home,
          ),
          const VideoFeedState(
            status: VideoFeedStatus.success,
            mode: FeedMode.home,
            videos: [],
            hasMore: false,
            error: VideoFeedError.noFollowedUsers,
          ),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'emits [loading, failure] when repository throws',
        setUp: () {
          when(() => mockFollowRepository.followingPubkeys).thenReturn(['a']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenThrow(Exception('Network error'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const VideoFeedStarted()),
        expect: () => [
          const VideoFeedState(
            status: VideoFeedStatus.loading,
            mode: FeedMode.home,
          ),
          const VideoFeedState(
            status: VideoFeedStatus.failure,
            mode: FeedMode.home,
            error: VideoFeedError.loadFailed,
          ),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'keeps hasMore true when fewer than page size returned',
        setUp: () {
          final videos = createTestVideos(3); // Less than 5 (page size)

          when(() => mockFollowRepository.followingPubkeys).thenReturn(['a']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) async => videos);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const VideoFeedStarted()),
        expect: () => [
          const VideoFeedState(
            status: VideoFeedStatus.loading,
            mode: FeedMode.home,
          ),
          isA<VideoFeedState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.videos.length, 'videos count', 3)
              .having((s) => s.hasMore, 'hasMore', true),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'sets hasMore to false when empty list returned',
        setUp: () {
          when(() => mockFollowRepository.followingPubkeys).thenReturn(['a']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) async => []);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const VideoFeedStarted()),
        expect: () => [
          const VideoFeedState(
            status: VideoFeedStatus.loading,
            mode: FeedMode.home,
          ),
          isA<VideoFeedState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.videos, 'videos', isEmpty)
              .having((s) => s.hasMore, 'hasMore', false),
        ],
      );
    });

    group('VideoFeedModeChanged', () {
      blocTest<VideoFeedBloc, VideoFeedState>(
        'clears videos and loads new mode',
        setUp: () {
          final latestVideos = createTestVideos(5);

          when(
            () => mockVideosRepository.getNewVideos(
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) async => latestVideos);
        },
        build: createBloc,
        seed: () => VideoFeedState(
          status: VideoFeedStatus.success,
          mode: FeedMode.home,
          videos: createTestVideos(3),
        ),
        act: (bloc) => bloc.add(const VideoFeedModeChanged(FeedMode.latest)),
        expect: () => [
          const VideoFeedState(
            status: VideoFeedStatus.loading,
            mode: FeedMode.latest,
            videos: [],
            hasMore: true,
          ),
          isA<VideoFeedState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.mode, 'mode', FeedMode.latest)
              .having((s) => s.videos.length, 'videos count', 5),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'does nothing when already on the same mode with success state',
        build: createBloc,
        seed: () => VideoFeedState(
          status: VideoFeedStatus.success,
          mode: FeedMode.latest,
          videos: createTestVideos(5),
        ),
        act: (bloc) => bloc.add(const VideoFeedModeChanged(FeedMode.latest)),
        expect: () => <VideoFeedState>[],
        verify: (_) {
          verifyNever(
            () => mockVideosRepository.getNewVideos(
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          );
        },
      );
    });

    group('VideoFeedLoadMoreRequested', () {
      blocTest<VideoFeedBloc, VideoFeedState>(
        'appends new videos to existing list',
        setUp: () {
          // Use different ID prefix to ensure unique videos
          final moreVideos = createTestVideos(
            pageSize,
            startTimestamp: 1000,
            idPrefix: 'more',
          );

          when(() => mockFollowRepository.followingPubkeys).thenReturn(['a']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) async => moreVideos);
        },
        build: createBloc,
        seed: () => VideoFeedState(
          status: VideoFeedStatus.success,
          mode: FeedMode.home,
          videos: createTestVideos(pageSize, startTimestamp: 2000),
          hasMore: true,
        ),
        act: (bloc) => bloc.add(const VideoFeedLoadMoreRequested()),
        expect: () => [
          isA<VideoFeedState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            true,
          ),
          isA<VideoFeedState>()
              .having((s) => s.isLoadingMore, 'isLoadingMore', false)
              .having((s) => s.videos.length, 'videos count', pageSize * 2)
              .having((s) => s.hasMore, 'hasMore', true),
        ],
        verify: (_) {
          verify(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).called(1);
        },
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'does nothing when not in success state',
        build: createBloc,
        seed: () => const VideoFeedState(status: VideoFeedStatus.loading),
        act: (bloc) => bloc.add(const VideoFeedLoadMoreRequested()),
        expect: () => <VideoFeedState>[],
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'does nothing when already loading more',
        build: createBloc,
        seed: () => VideoFeedState(
          status: VideoFeedStatus.success,
          videos: createTestVideos(5),
          isLoadingMore: true,
        ),
        act: (bloc) => bloc.add(const VideoFeedLoadMoreRequested()),
        expect: () => <VideoFeedState>[],
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'does nothing when hasMore is false',
        build: createBloc,
        seed: () => VideoFeedState(
          status: VideoFeedStatus.success,
          videos: createTestVideos(5),
          hasMore: false,
        ),
        act: (bloc) => bloc.add(const VideoFeedLoadMoreRequested()),
        expect: () => <VideoFeedState>[],
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'does nothing when videos list is empty',
        build: createBloc,
        seed: () => const VideoFeedState(
          status: VideoFeedStatus.success,
          videos: [],
          hasMore: true,
        ),
        act: (bloc) => bloc.add(const VideoFeedLoadMoreRequested()),
        expect: () => <VideoFeedState>[],
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'keeps hasMore true when fewer than page size returned from load more',
        setUp: () {
          // Return fewer videos than page size with unique IDs.
          // Server-side filtering can reduce the count below _pageSize
          // even when more content exists.
          final moreVideos = createTestVideos(
            2,
            startTimestamp: 1000,
            idPrefix: 'more',
          );

          when(() => mockFollowRepository.followingPubkeys).thenReturn(['a']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) async => moreVideos);
        },
        build: createBloc,
        seed: () => VideoFeedState(
          status: VideoFeedStatus.success,
          mode: FeedMode.home,
          videos: createTestVideos(pageSize, startTimestamp: 2000),
          hasMore: true,
        ),
        act: (bloc) => bloc.add(const VideoFeedLoadMoreRequested()),
        expect: () => [
          isA<VideoFeedState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            true,
          ),
          isA<VideoFeedState>()
              .having((s) => s.isLoadingMore, 'isLoadingMore', false)
              .having((s) => s.videos.length, 'videos count', pageSize + 2)
              .having((s) => s.hasMore, 'hasMore', true),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'sets hasMore to false when empty list returned from load more',
        setUp: () {
          when(() => mockFollowRepository.followingPubkeys).thenReturn(['a']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) async => []);
        },
        build: createBloc,
        seed: () => VideoFeedState(
          status: VideoFeedStatus.success,
          mode: FeedMode.home,
          videos: createTestVideos(pageSize, startTimestamp: 2000),
          hasMore: true,
        ),
        act: (bloc) => bloc.add(const VideoFeedLoadMoreRequested()),
        expect: () => [
          isA<VideoFeedState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            true,
          ),
          isA<VideoFeedState>()
              .having((s) => s.isLoadingMore, 'isLoadingMore', false)
              .having((s) => s.videos.length, 'videos count', pageSize)
              .having((s) => s.hasMore, 'hasMore', false),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'drops concurrent requests via droppable transformer',
        setUp: () {
          final moreVideos = createTestVideos(
            pageSize,
            startTimestamp: 1000,
            idPrefix: 'more',
          );

          when(() => mockFollowRepository.followingPubkeys).thenReturn(['a']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) async {
            // Simulate network delay
            await Future<void>.delayed(const Duration(milliseconds: 50));
            return moreVideos;
          });
        },
        build: createBloc,
        seed: () => VideoFeedState(
          status: VideoFeedStatus.success,
          mode: FeedMode.home,
          videos: createTestVideos(pageSize, startTimestamp: 2000),
          hasMore: true,
        ),
        act: (bloc) {
          // Fire multiple events simultaneously — droppable should
          // process only the first and drop the rest while it's running.
          bloc
            ..add(const VideoFeedLoadMoreRequested())
            ..add(const VideoFeedLoadMoreRequested())
            ..add(const VideoFeedLoadMoreRequested());
        },
        wait: const Duration(milliseconds: 200),
        verify: (_) {
          verify(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).called(1);
        },
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'deduplicates overlapping videos from Funnelcake and Nostr',
        setUp: () {
          // Return videos that partially overlap with existing ones.
          // This happens when Funnelcake runs out and Nostr returns
          // some of the same videos.
          createTestVideos(3, startTimestamp: 2000, idPrefix: 'existing');
          final overlappingVideos = [
            // 2 duplicates (same IDs as existing)
            ...createTestVideos(2, startTimestamp: 2000, idPrefix: 'existing'),
            // 3 truly new
            ...createTestVideos(3, startTimestamp: 1000, idPrefix: 'new'),
          ];

          when(() => mockFollowRepository.followingPubkeys).thenReturn(['a']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) async => overlappingVideos);
        },
        build: createBloc,
        seed: () => VideoFeedState(
          status: VideoFeedStatus.success,
          mode: FeedMode.home,
          videos: createTestVideos(
            3,
            startTimestamp: 2000,
            idPrefix: 'existing',
          ),
          hasMore: true,
        ),
        act: (bloc) => bloc.add(const VideoFeedLoadMoreRequested()),
        expect: () => [
          isA<VideoFeedState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            true,
          ),
          isA<VideoFeedState>()
              .having((s) => s.isLoadingMore, 'isLoadingMore', false)
              // 3 existing + 3 new = 6 (2 duplicates removed)
              .having((s) => s.videos.length, 'videos count', 6)
              .having((s) => s.hasMore, 'hasMore', true),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'resets isLoadingMore on error',
        setUp: () {
          when(() => mockFollowRepository.followingPubkeys).thenReturn(['a']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenThrow(Exception('Network error'));
        },
        build: createBloc,
        seed: () => VideoFeedState(
          status: VideoFeedStatus.success,
          mode: FeedMode.home,
          videos: createTestVideos(5),
          hasMore: true,
        ),
        act: (bloc) => bloc.add(const VideoFeedLoadMoreRequested()),
        expect: () => [
          isA<VideoFeedState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            true,
          ),
          isA<VideoFeedState>()
              .having((s) => s.isLoadingMore, 'isLoadingMore', false)
              .having((s) => s.videos.length, 'videos count', 5),
        ],
      );
    });

    group('VideoFeedRefreshRequested', () {
      blocTest<VideoFeedBloc, VideoFeedState>(
        'clears videos and reloads from beginning',
        setUp: () {
          final freshVideos = createTestVideos(pageSize);

          when(() => mockFollowRepository.followingPubkeys).thenReturn(['a']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) async => freshVideos);
        },
        build: createBloc,
        seed: () => VideoFeedState(
          status: VideoFeedStatus.success,
          mode: FeedMode.home,
          videos: createTestVideos(10), // Previous videos
          hasMore: false,
        ),
        act: (bloc) => bloc.add(const VideoFeedRefreshRequested()),
        expect: () => [
          const VideoFeedState(
            status: VideoFeedStatus.loading,
            mode: FeedMode.home,
            videos: [],
            hasMore: true,
          ),
          isA<VideoFeedState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.videos.length, 'videos count', pageSize)
              .having((s) => s.hasMore, 'hasMore', true),
        ],
        verify: (_) {
          // Verify called without 'until' parameter (fresh fetch)
          verify(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              limit: any(named: 'limit'),
              until: null,
            ),
          ).called(1);
        },
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'clears error on refresh',
        setUp: () {
          final videos = createTestVideos(5);

          when(() => mockFollowRepository.followingPubkeys).thenReturn(['a']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) async => videos);
        },
        build: createBloc,
        seed: () => const VideoFeedState(
          status: VideoFeedStatus.failure,
          mode: FeedMode.home,
          error: VideoFeedError.loadFailed,
        ),
        act: (bloc) => bloc.add(const VideoFeedRefreshRequested()),
        expect: () => [
          const VideoFeedState(
            status: VideoFeedStatus.loading,
            mode: FeedMode.home,
            videos: [],
            hasMore: true,
          ),
          isA<VideoFeedState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.error, 'error', isNull),
        ],
      );
    });

    group('close', () {
      test('cancels following subscription', () async {
        final bloc = createBloc();

        await bloc.close();

        // After closing, stream events should not cause errors
        expect(() => followingController.add(['a']), returnsNormally);
      });
    });
  });
}
