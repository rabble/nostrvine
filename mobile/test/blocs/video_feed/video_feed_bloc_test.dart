// ABOUTME: Tests for VideoFeedBloc - unified video feed with mode switching
// ABOUTME: Tests loading, pagination, mode switching, and following changes

// ignore_for_file: prefer_const_literals_to_create_immutables

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_feed/home_feed_cache.dart';
import 'package:openvine/blocs/video_feed/video_feed_bloc.dart';
import 'package:openvine/repositories/follow_repository.dart';
import 'package:openvine/services/feed_performance_tracker.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockCuratedListRepository extends Mock
    implements CuratedListRepository {}

class _MockFeedPerformanceTracker extends Mock
    implements FeedPerformanceTracker {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockHomeFeedCache extends Mock implements HomeFeedCache {}

class _FakeSharedPreferences extends Fake implements SharedPreferences {}

void main() {
  group('VideoFeedBloc', () {
    late _MockVideosRepository mockVideosRepository;
    late _MockFollowRepository mockFollowRepository;
    late _MockCuratedListRepository mockCuratedListRepository;
    late _MockProfileRepository mockProfileRepository;
    late StreamController<List<String>> followingController;
    late StreamController<List<CuratedList>> curatedListsController;

    setUp(() {
      mockVideosRepository = _MockVideosRepository();
      mockFollowRepository = _MockFollowRepository();
      mockCuratedListRepository = _MockCuratedListRepository();
      mockProfileRepository = _MockProfileRepository();
      followingController = StreamController<List<String>>.broadcast();
      curatedListsController = StreamController<List<CuratedList>>.broadcast();

      // Default stubs
      when(
        () => mockFollowRepository.followingStream,
      ).thenAnswer((_) => followingController.stream);
      when(() => mockFollowRepository.followingPubkeys).thenReturn([]);

      when(
        () => mockCuratedListRepository.subscribedListsStream,
      ).thenAnswer((_) => curatedListsController.stream);
      when(
        () => mockCuratedListRepository.getSubscribedListVideoRefs(),
      ).thenReturn({});

      when(
        () => mockProfileRepository.fetchBatchProfiles(
          pubkeys: any(named: 'pubkeys'),
        ),
      ).thenAnswer((_) async => {});
    });

    tearDown(() {
      followingController.close();
      curatedListsController.close();
    });

    VideoFeedBloc createBloc() => VideoFeedBloc(
      videosRepository: mockVideosRepository,
      followRepository: mockFollowRepository,
      curatedListRepository: mockCuratedListRepository,
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
      expect(bloc.state.mode, FeedMode.following);
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
          mode: FeedMode.latest,
        );

        final updated = state.copyWith();

        expect(updated.status, VideoFeedStatus.success);
        expect(updated.mode, FeedMode.latest);
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
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: videos));
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(const VideoFeedStarted(mode: FeedMode.following)),
        expect: () => [
          const VideoFeedState(),
          isA<VideoFeedState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.videos.length, 'videos count', pageSize)
              .having((s) => s.mode, 'mode', FeedMode.following)
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
              skipCache: any(named: 'skipCache'),
            ),
          ).thenAnswer((_) async => videos);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const VideoFeedStarted(mode: FeedMode.latest)),
        expect: () => [
          const VideoFeedState(mode: FeedMode.latest),
          isA<VideoFeedState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.mode, 'mode', FeedMode.latest),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'emits [loading, success] with forYou mode when specified',
        setUp: () {
          final videos = createTestVideos(5);
          final authors = ['author1', 'author2'];

          when(() => mockFollowRepository.followingPubkeys).thenReturn(authors);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: authors,
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: videos));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const VideoFeedStarted()),
        expect: () => [
          const VideoFeedState(mode: FeedMode.forYou),
          isA<VideoFeedState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.mode, 'mode', FeedMode.forYou),
        ],
        verify: (_) {
          verify(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: ['author1', 'author2'],
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).called(1);
        },
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'emits noFollowedUsers when following list is empty on startup',
        setUp: () {
          when(() => mockFollowRepository.followingPubkeys).thenReturn([]);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenAnswer((_) async => const HomeFeedResult(videos: []));
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(const VideoFeedStarted(mode: FeedMode.following)),
        expect: () => [
          const VideoFeedState(),
          // _loadVideos emits success with empty videos
          const VideoFeedState(status: VideoFeedStatus.success, hasMore: false),
          // _onStarted detects empty follows → noFollowedUsers CTA
          const VideoFeedState(
            status: VideoFeedStatus.success,
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
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenThrow(Exception('Network error'));
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(const VideoFeedStarted(mode: FeedMode.following)),
        expect: () => [
          const VideoFeedState(),
          const VideoFeedState(
            status: VideoFeedStatus.failure,
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
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: videos));
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(const VideoFeedStarted(mode: FeedMode.following)),
        expect: () => [
          const VideoFeedState(),
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
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenAnswer((_) async => const HomeFeedResult(videos: []));
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(const VideoFeedStarted(mode: FeedMode.following)),
        expect: () => [
          const VideoFeedState(),
          isA<VideoFeedState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.videos, 'videos', isEmpty)
              .having((s) => s.hasMore, 'hasMore', false),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'does not await initialized before calling repository',
        setUp: () {
          final videos = createTestVideos(pageSize);

          when(() => mockFollowRepository.followingPubkeys).thenReturn([]);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: videos));
        },
        build: () => VideoFeedBloc(
          videosRepository: mockVideosRepository,
          followRepository: mockFollowRepository,
          curatedListRepository: mockCuratedListRepository,
          userPubkey: 'user-pubkey',
        ),
        act: (bloc) =>
            bloc.add(const VideoFeedStarted(mode: FeedMode.following)),
        verify: (_) {
          // Repository is called with empty authors (follow list
          // not yet initialized) — the fast path relies on
          // userPubkey to hit Funnelcake directly.
          verify(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: [],
              videoRefs: any(named: 'videoRefs'),
              userPubkey: 'user-pubkey',
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).called(1);
        },
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
              skipCache: any(named: 'skipCache'),
            ),
          ).thenAnswer((_) async => latestVideos);
        },
        build: createBloc,
        seed: () => VideoFeedState(
          status: VideoFeedStatus.success,
          videos: createTestVideos(3),
        ),
        act: (bloc) => bloc.add(const VideoFeedModeChanged(FeedMode.latest)),
        expect: () => [
          const VideoFeedState(mode: FeedMode.latest),
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
              skipCache: any(named: 'skipCache'),
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
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: moreVideos));
        },
        build: createBloc,
        seed: () => VideoFeedState(
          status: VideoFeedStatus.success,
          videos: createTestVideos(pageSize, startTimestamp: 2000),
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
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).called(1);
        },
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'does nothing when not in success state',
        build: createBloc,
        seed: () => const VideoFeedState(),
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
        seed: () => const VideoFeedState(status: VideoFeedStatus.success),
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
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: moreVideos));
        },
        build: createBloc,
        seed: () => VideoFeedState(
          status: VideoFeedStatus.success,
          videos: createTestVideos(pageSize, startTimestamp: 2000),
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
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenAnswer((_) async => const HomeFeedResult(videos: []));
        },
        build: createBloc,
        seed: () => VideoFeedState(
          status: VideoFeedStatus.success,
          videos: createTestVideos(pageSize, startTimestamp: 2000),
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
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenAnswer((_) async {
            // Simulate network delay
            await Future<void>.delayed(const Duration(milliseconds: 50));
            return HomeFeedResult(videos: moreVideos);
          });
        },
        build: createBloc,
        seed: () => VideoFeedState(
          status: VideoFeedStatus.success,
          videos: createTestVideos(pageSize, startTimestamp: 2000),
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
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
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
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: overlappingVideos));
        },
        build: createBloc,
        seed: () => VideoFeedState(
          status: VideoFeedStatus.success,
          videos: createTestVideos(
            3,
            startTimestamp: 2000,
            idPrefix: 'existing',
          ),
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
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenThrow(Exception('Network error'));
        },
        build: createBloc,
        seed: () => VideoFeedState(
          status: VideoFeedStatus.success,
          videos: createTestVideos(5),
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
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: freshVideos));
        },
        build: createBloc,
        seed: () => VideoFeedState(
          status: VideoFeedStatus.success,
          videos: createTestVideos(10), // Previous videos
          hasMore: false,
        ),
        act: (bloc) => bloc.add(const VideoFeedRefreshRequested()),
        expect: () => [
          const VideoFeedState(),
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
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
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
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: videos));
        },
        build: createBloc,
        seed: () => const VideoFeedState(
          status: VideoFeedStatus.failure,
          error: VideoFeedError.loadFailed,
        ),
        act: (bloc) => bloc.add(const VideoFeedRefreshRequested()),
        expect: () => [
          const VideoFeedState(),
          isA<VideoFeedState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.error, 'error', isNull),
        ],
      );
    });

    group('VideoFeedAutoRefreshRequested', () {
      blocTest<VideoFeedBloc, VideoFeedState>(
        'refreshes when on home mode and data is stale',
        setUp: () {
          final videos = createTestVideos(pageSize);

          when(() => mockFollowRepository.followingPubkeys).thenReturn(['a']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: videos));
        },
        build: () => VideoFeedBloc(
          videosRepository: mockVideosRepository,
          followRepository: mockFollowRepository,
          curatedListRepository: mockCuratedListRepository,
          autoRefreshMinInterval: Duration.zero,
        ),
        seed: () => VideoFeedState(
          status: VideoFeedStatus.success,
          videos: createTestVideos(3),
        ),
        act: (bloc) => bloc.add(const VideoFeedAutoRefreshRequested()),
        expect: () => [
          const VideoFeedState(),
          isA<VideoFeedState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.videos.length, 'videos count', pageSize),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'does nothing when mode is not home',
        build: createBloc,
        seed: () => VideoFeedState(
          status: VideoFeedStatus.success,
          mode: FeedMode.latest,
          videos: createTestVideos(5),
        ),
        act: (bloc) => bloc.add(const VideoFeedAutoRefreshRequested()),
        expect: () => <VideoFeedState>[],
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'does nothing when mode is forYou',
        build: createBloc,
        seed: () => VideoFeedState(
          status: VideoFeedStatus.success,
          mode: FeedMode.forYou,
          videos: createTestVideos(5),
        ),
        act: (bloc) => bloc.add(const VideoFeedAutoRefreshRequested()),
        expect: () => <VideoFeedState>[],
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'does nothing when data is fresh '
        '(last refresh within auto-refresh interval)',
        setUp: () {
          final videos = createTestVideos(pageSize);

          when(() => mockFollowRepository.followingPubkeys).thenReturn(['a']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: videos));
        },
        build: () => VideoFeedBloc(
          videosRepository: mockVideosRepository,
          followRepository: mockFollowRepository,
          curatedListRepository: mockCuratedListRepository,
          // Large interval so data is always considered fresh
          autoRefreshMinInterval: const Duration(hours: 1),
        ),
        seed: () => VideoFeedState(
          status: VideoFeedStatus.success,
          videos: createTestVideos(pageSize),
        ),
        act: (bloc) async {
          // First, trigger a load so _lastRefreshedAt gets set
          bloc.add(const VideoFeedStarted(mode: FeedMode.following));
          await Future<void>.delayed(Duration.zero);

          // Now the auto-refresh should be skipped (data is fresh)
          bloc.add(const VideoFeedAutoRefreshRequested());
        },
        skip: 2, // Skip the loading + success from VideoFeedStarted
        expect: () => <VideoFeedState>[],
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'refreshes when auto-refresh interval has elapsed',
        setUp: () {
          final videos = createTestVideos(pageSize);

          when(() => mockFollowRepository.followingPubkeys).thenReturn(['a']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: videos));
        },
        build: () => VideoFeedBloc(
          videosRepository: mockVideosRepository,
          followRepository: mockFollowRepository,
          curatedListRepository: mockCuratedListRepository,
          autoRefreshMinInterval: Duration.zero,
        ),
        seed: () => VideoFeedState(
          status: VideoFeedStatus.success,
          videos: createTestVideos(pageSize),
        ),
        act: (bloc) async {
          // First load sets _lastRefreshedAt
          bloc.add(const VideoFeedStarted(mode: FeedMode.following));
          await Future<void>.delayed(Duration.zero);

          // With Duration.zero interval, this should refresh
          bloc.add(const VideoFeedAutoRefreshRequested());
        },
        skip: 2, // Skip the loading + success from VideoFeedStarted
        expect: () => [
          const VideoFeedState(),
          isA<VideoFeedState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.videos.length, 'videos count', pageSize),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'refreshes when _lastRefreshedAt is null '
        '(feed never loaded successfully)',
        setUp: () {
          final videos = createTestVideos(pageSize);

          when(() => mockFollowRepository.followingPubkeys).thenReturn(['a']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: videos));
        },
        build: createBloc,
        seed: () => const VideoFeedState(
          status: VideoFeedStatus.failure,
          error: VideoFeedError.loadFailed,
        ),
        act: (bloc) => bloc.add(const VideoFeedAutoRefreshRequested()),
        expect: () => [
          const VideoFeedState(),
          isA<VideoFeedState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.videos.length, 'videos count', pageSize),
        ],
      );
    });

    group('VideoFeedFollowingListChanged', () {
      blocTest<VideoFeedBloc, VideoFeedState>(
        'silently refreshes home feed on follow list change',
        setUp: () {
          final videos = createTestVideos(pageSize);

          when(
            () => mockFollowRepository.followingPubkeys,
          ).thenReturn(['new-author']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: videos));
        },
        build: createBloc,
        seed: () => VideoFeedState(
          status: VideoFeedStatus.success,
          videos: createTestVideos(3),
        ),
        act: (bloc) =>
            bloc.add(const VideoFeedFollowingListChanged(['new-author'])),
        expect: () => [
          // No loading state — silent refresh replaces in-place
          isA<VideoFeedState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.videos.length, 'videos count', pageSize)
              .having((s) => s.mode, 'mode', FeedMode.following),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'does nothing when mode is not home',
        build: createBloc,
        seed: () => VideoFeedState(
          status: VideoFeedStatus.success,
          mode: FeedMode.latest,
          videos: createTestVideos(5),
        ),
        act: (bloc) =>
            bloc.add(const VideoFeedFollowingListChanged(['new-author'])),
        expect: () => <VideoFeedState>[],
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'does nothing when feed is still loading',
        build: createBloc,
        seed: () => const VideoFeedState(),
        act: (bloc) =>
            bloc.add(const VideoFeedFollowingListChanged(['new-author'])),
        expect: () => <VideoFeedState>[],
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'transitions from noFollowedUsers to loaded feed',
        setUp: () {
          final videos = createTestVideos(pageSize);

          when(
            () => mockFollowRepository.followingPubkeys,
          ).thenReturn(['first-follow']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: videos));
        },
        build: createBloc,
        seed: () => const VideoFeedState(
          status: VideoFeedStatus.success,
          hasMore: false,
          error: VideoFeedError.noFollowedUsers,
        ),
        act: (bloc) =>
            bloc.add(const VideoFeedFollowingListChanged(['first-follow'])),
        expect: () => [
          // No loading state — silent refresh replaces in-place
          isA<VideoFeedState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.videos.length, 'videos count', pageSize)
              .having((s) => s.error, 'error', isNull),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'skips initial follow list replay to avoid redundant API call',
        setUp: () {
          final videos = createTestVideos(pageSize);

          when(
            () => mockFollowRepository.followingPubkeys,
          ).thenReturn(['author']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: videos));
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const VideoFeedStarted(mode: FeedMode.following));
          // Wait for initial load to complete (Funnelcake loaded content)
          await Future<void>.delayed(Duration.zero);
          // First stream emission is skipped (BehaviorSubject replay)
          followingController.add(['author']);
        },
        skip: 2, // Skip loading + success from VideoFeedStarted
        expect: () => <VideoFeedState>[],
        verify: (_) {
          // Called only once — the replay is skipped, no redundant call
          verify(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).called(1);
        },
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'silently refreshes on second follow list emission after feed '
        'is empty (Funnelcake failed)',
        setUp: () {
          final videos = createTestVideos(pageSize);
          var callCount = 0;

          when(
            () => mockFollowRepository.followingPubkeys,
          ).thenReturn(['author']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenAnswer((_) async {
            callCount++;
            if (callCount == 1) {
              return const HomeFeedResult(videos: []);
            }
            return HomeFeedResult(videos: videos);
          });
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const VideoFeedStarted(mode: FeedMode.following));
          // Wait for initial load to complete (Funnelcake returned empty)
          await Future<void>.delayed(Duration.zero);
          // First emission is skipped (BehaviorSubject replay)
          followingController.add(['author']);
          await Future<void>.delayed(Duration.zero);
          // Second emission triggers recovery
          followingController.add(['author', 'new-follow']);
        },
        skip: 2, // Skip loading + success(empty) from VideoFeedStarted
        expect: () => [
          // No loading state — silent refresh replaces in-place
          isA<VideoFeedState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.videos.length, 'videos count', pageSize),
        ],
        verify: (_) {
          // Called twice: initial (empty), then recovery on 2nd emission
          verify(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).called(2);
        },
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'silently refreshes on runtime follow list changes '
        '(skips initial replay)',
        setUp: () {
          final videos = createTestVideos(pageSize);

          when(
            () => mockFollowRepository.followingPubkeys,
          ).thenReturn(['author']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: videos));
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const VideoFeedStarted(mode: FeedMode.following));
          await Future<void>.delayed(Duration.zero);
          // First emission is skipped (BehaviorSubject replay)
          followingController.add(['author']);
          await Future<void>.delayed(Duration.zero);
          // Runtime follow — triggers silent refresh
          followingController.add(['author', 'new-author']);
        },
        skip: 2, // Skip loading + success from VideoFeedStarted
        // No state changes — same videos returned, Equatable deduplicates
        expect: () => <VideoFeedState>[],
        verify: (_) {
          // Called 2 times: initial + runtime (replay is skipped)
          verify(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).called(2);
        },
      );
    });

    group('VideoFeedCuratedListsChanged', () {
      blocTest<VideoFeedBloc, VideoFeedState>(
        'refreshes home feed when curated lists change',
        setUp: () {
          final videos = createTestVideos(pageSize);

          when(
            () => mockFollowRepository.followingPubkeys,
          ).thenReturn(['author']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: videos));
        },
        build: createBloc,
        seed: () => VideoFeedState(
          status: VideoFeedStatus.success,
          videos: createTestVideos(3),
        ),
        act: (bloc) => bloc.add(const VideoFeedCuratedListsChanged()),
        expect: () => [
          const VideoFeedState(),
          isA<VideoFeedState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.videos.length, 'videos count', pageSize)
              .having((s) => s.mode, 'mode', FeedMode.following),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'does nothing when mode is not home',
        build: createBloc,
        seed: () => VideoFeedState(
          status: VideoFeedStatus.success,
          mode: FeedMode.latest,
          videos: createTestVideos(5),
        ),
        act: (bloc) => bloc.add(const VideoFeedCuratedListsChanged()),
        expect: () => <VideoFeedState>[],
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'does nothing when feed is still loading',
        build: createBloc,
        seed: () => const VideoFeedState(),
        act: (bloc) => bloc.add(const VideoFeedCuratedListsChanged()),
        expect: () => <VideoFeedState>[],
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'subscribes to subscribedListsStream via emit.onEach on startup',
        setUp: () {
          final videos = createTestVideos(pageSize);

          when(
            () => mockFollowRepository.followingPubkeys,
          ).thenReturn(['author']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: videos));
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const VideoFeedStarted(mode: FeedMode.following));
          // Wait for initial load to complete
          await Future<void>.delayed(Duration.zero);
          // First stream emission is skipped (BehaviorSubject replay)
          curatedListsController.add(const []);
          await Future<void>.delayed(Duration.zero);
          // Second emission triggers the handler
          curatedListsController.add(const []);
        },
        skip: 2, // Skip loading + success from VideoFeedStarted
        expect: () => [
          const VideoFeedState(),
          isA<VideoFeedState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.videos.length, 'videos count', pageSize),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'emits state with videoListSources and listOnlyVideoIds '
        'from HomeFeedResult',
        setUp: () {
          final videos = createTestVideos(pageSize);

          when(
            () => mockFollowRepository.followingPubkeys,
          ).thenReturn(['author']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenAnswer(
            (_) async => HomeFeedResult(
              videos: videos,
              videoListSources: {
                'video-0': {'list-1'},
              },
              listOnlyVideoIds: {'video-0'},
            ),
          );
        },
        build: createBloc,
        seed: () => VideoFeedState(
          status: VideoFeedStatus.success,
          videos: createTestVideos(3),
        ),
        act: (bloc) => bloc.add(const VideoFeedCuratedListsChanged()),
        expect: () => [
          const VideoFeedState(),
          isA<VideoFeedState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.videoListSources, 'videoListSources', {
                'video-0': {'list-1'},
              })
              .having((s) => s.listOnlyVideoIds, 'listOnlyVideoIds', {
                'video-0',
              }),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'merges attribution metadata on load more',
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
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenAnswer(
            (_) async => HomeFeedResult(
              videos: moreVideos,
              videoListSources: {
                'more-0': {'list-2'},
              },
              listOnlyVideoIds: {'more-0'},
            ),
          );
        },
        build: createBloc,
        seed: () => VideoFeedState(
          status: VideoFeedStatus.success,
          videos: createTestVideos(pageSize, startTimestamp: 2000),
          videoListSources: const {
            'existing-0': {'list-1'},
          },
          listOnlyVideoIds: const {'existing-0'},
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
              .having((s) => s.videoListSources, 'videoListSources', {
                'existing-0': {'list-1'},
                'more-0': {'list-2'},
              })
              .having((s) => s.listOnlyVideoIds, 'listOnlyVideoIds', {
                'existing-0',
                'more-0',
              }),
        ],
      );
    });

    group('close', () {
      test('does not throw when stream emits after close', () async {
        final bloc = createBloc();

        await bloc.close();

        // After closing, stream events should not cause errors
        expect(() => followingController.add(['a']), returnsNormally);
      });
    });

    group('feed performance tracking', () {
      late _MockFeedPerformanceTracker mockTracker;

      setUp(() {
        mockTracker = _MockFeedPerformanceTracker();
      });

      VideoFeedBloc createBlocWithTracker() => VideoFeedBloc(
        videosRepository: mockVideosRepository,
        followRepository: mockFollowRepository,
        curatedListRepository: mockCuratedListRepository,
        feedTracker: mockTracker,
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'calls startFeedLoad on VideoFeedStarted',
        setUp: () {
          final videos = createTestVideos(3);
          when(() => mockFollowRepository.followingPubkeys).thenReturn(['a']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: videos));
        },
        build: createBlocWithTracker,
        act: (bloc) =>
            bloc.add(const VideoFeedStarted(mode: FeedMode.following)),
        verify: (_) {
          verify(() => mockTracker.startFeedLoad('following')).called(1);
        },
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'calls markFirstVideosReceived and markFeedDisplayed on success',
        setUp: () {
          final videos = createTestVideos(3);
          when(() => mockFollowRepository.followingPubkeys).thenReturn(['a']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: videos));
        },
        build: createBlocWithTracker,
        act: (bloc) =>
            bloc.add(const VideoFeedStarted(mode: FeedMode.following)),
        verify: (_) {
          verify(
            () => mockTracker.markFirstVideosReceived('following', 3),
          ).called(1);
          verify(() => mockTracker.markFeedDisplayed('following', 3)).called(1);
        },
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'calls trackFeedError on failure',
        setUp: () {
          when(() => mockFollowRepository.followingPubkeys).thenReturn(['a']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenThrow(Exception('Network error'));
        },
        build: createBlocWithTracker,
        act: (bloc) =>
            bloc.add(const VideoFeedStarted(mode: FeedMode.following)),
        verify: (_) {
          verify(
            () => mockTracker.trackFeedError(
              'following',
              errorType: 'load_failed',
              errorMessage: any(named: 'errorMessage'),
            ),
          ).called(1);
          verifyNever(() => mockTracker.markFirstVideosReceived(any(), any()));
          verifyNever(() => mockTracker.markFeedDisplayed(any(), any()));
        },
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'uses correct feed type for latest mode',
        setUp: () {
          final videos = createTestVideos(3);
          when(
            () => mockVideosRepository.getNewVideos(
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenAnswer((_) async => videos);
        },
        build: createBlocWithTracker,
        act: (bloc) => bloc.add(const VideoFeedStarted(mode: FeedMode.latest)),
        verify: (_) {
          verify(() => mockTracker.startFeedLoad('latest')).called(1);
          verify(
            () => mockTracker.markFirstVideosReceived('latest', 3),
          ).called(1);
          verify(() => mockTracker.markFeedDisplayed('latest', 3)).called(1);
        },
      );
    });

    group('cache-first home feed', () {
      late _MockHomeFeedCache mockCache;
      late SharedPreferences sharedPreferences;
      late StreamController<List<String>> cacheFollowingController;
      late StreamController<List<CuratedList>> cacheCuratedListsController;

      setUpAll(() {
        registerFallbackValue(_FakeSharedPreferences());
      });

      setUp(() async {
        mockCache = _MockHomeFeedCache();
        SharedPreferences.setMockInitialValues({});
        sharedPreferences = await SharedPreferences.getInstance();
        cacheFollowingController = StreamController<List<String>>.broadcast();
        cacheCuratedListsController =
            StreamController<List<CuratedList>>.broadcast();

        when(
          () => mockFollowRepository.followingStream,
        ).thenAnswer((_) => cacheFollowingController.stream);
        when(() => mockFollowRepository.followingPubkeys).thenReturn([]);
        when(
          () => mockCuratedListRepository.subscribedListsStream,
        ).thenAnswer((_) => cacheCuratedListsController.stream);
        when(
          () => mockCuratedListRepository.getSubscribedListVideoRefs(),
        ).thenReturn({});
      });

      tearDown(() {
        cacheFollowingController.close();
        cacheCuratedListsController.close();
      });

      VideoFeedBloc createBlocWithCache() => VideoFeedBloc(
        videosRepository: mockVideosRepository,
        followRepository: mockFollowRepository,
        curatedListRepository: mockCuratedListRepository,
        sharedPreferences: sharedPreferences,
        homeFeedCache: mockCache,
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'emits cached videos then fresh videos on cold start',
        setUp: () {
          final cachedVideos = createTestVideos(2, idPrefix: 'cached');
          final freshVideos = createTestVideos(3, idPrefix: 'fresh');

          when(
            () => mockCache.read(sharedPreferences),
          ).thenReturn(HomeFeedResult(videos: cachedVideos));
          when(() => mockCache.write(any(), any())).thenAnswer((_) async {});
          when(() => mockFollowRepository.followingPubkeys).thenReturn([]);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenAnswer(
            (_) async => HomeFeedResult(
              videos: freshVideos,
              rawResponseBody: '{"videos":[]}',
            ),
          );
        },
        build: createBlocWithCache,
        act: (bloc) =>
            bloc.add(const VideoFeedStarted(mode: FeedMode.following)),
        expect: () => [
          // 1. Loading state from _onStarted
          const VideoFeedState(),
          // 2. Cached videos served immediately
          isA<VideoFeedState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.videos.length, 'cached count', 2)
              .having((s) => s.videos[0].id, 'first cached id', 'cached-0'),
          // 3. Fresh videos replace cached
          isA<VideoFeedState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.videos.length, 'fresh count', 3)
              .having((s) => s.videos[0].id, 'first fresh id', 'fresh-0'),
        ],
        verify: (_) {
          verify(() => mockCache.read(sharedPreferences)).called(1);
        },
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'skips cache when no SharedPreferences provided',
        setUp: () {
          final videos = createTestVideos(3);
          when(() => mockFollowRepository.followingPubkeys).thenReturn([]);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: videos));
        },
        build: () => VideoFeedBloc(
          videosRepository: mockVideosRepository,
          followRepository: mockFollowRepository,
          curatedListRepository: mockCuratedListRepository,
          homeFeedCache: mockCache,
          // No sharedPreferences — cache should be skipped
        ),
        act: (bloc) =>
            bloc.add(const VideoFeedStarted(mode: FeedMode.following)),
        expect: () => [
          const VideoFeedState(),
          isA<VideoFeedState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.videos.length, 'count', 3),
        ],
        verify: (_) {
          verifyNever(() => mockCache.read(any()));
        },
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'skips cache when cache returns null',
        setUp: () {
          final videos = createTestVideos(3);
          when(() => mockCache.read(sharedPreferences)).thenReturn(null);
          when(() => mockCache.write(any(), any())).thenAnswer((_) async {});
          when(() => mockFollowRepository.followingPubkeys).thenReturn([]);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenAnswer(
            (_) async => HomeFeedResult(
              videos: videos,
              rawResponseBody: '{"videos":[]}',
            ),
          );
        },
        build: createBlocWithCache,
        act: (bloc) =>
            bloc.add(const VideoFeedStarted(mode: FeedMode.following)),
        expect: () => [
          const VideoFeedState(),
          isA<VideoFeedState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.videos.length, 'count', 3),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'writes raw response body to cache after fresh fetch',
        setUp: () {
          final videos = createTestVideos(3);
          when(() => mockCache.read(sharedPreferences)).thenReturn(null);
          when(() => mockCache.write(any(), any())).thenAnswer((_) async {});
          when(() => mockFollowRepository.followingPubkeys).thenReturn([]);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenAnswer(
            (_) async => HomeFeedResult(
              videos: videos,
              rawResponseBody: '{"videos":[{"id":"v1"}]}',
            ),
          );
        },
        build: createBlocWithCache,
        act: (bloc) =>
            bloc.add(const VideoFeedStarted(mode: FeedMode.following)),
        verify: (_) {
          verify(
            () =>
                mockCache.write(sharedPreferences, '{"videos":[{"id":"v1"}]}'),
          ).called(1);
        },
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'does not write cache when rawResponseBody is null',
        setUp: () {
          final videos = createTestVideos(3);
          when(() => mockCache.read(sharedPreferences)).thenReturn(null);
          when(() => mockFollowRepository.followingPubkeys).thenReturn([]);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: videos));
        },
        build: createBlocWithCache,
        act: (bloc) =>
            bloc.add(const VideoFeedStarted(mode: FeedMode.following)),
        verify: (_) {
          verifyNever(() => mockCache.write(any(), any()));
        },
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'does not serve cache on non-home mode',
        setUp: () {
          final videos = createTestVideos(3);
          when(() => mockFollowRepository.followingPubkeys).thenReturn([]);
          when(
            () => mockVideosRepository.getNewVideos(
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenAnswer((_) async => videos);
        },
        build: createBlocWithCache,
        act: (bloc) => bloc.add(const VideoFeedStarted(mode: FeedMode.latest)),
        expect: () => [
          isA<VideoFeedState>().having((s) => s.mode, 'mode', FeedMode.latest),
          isA<VideoFeedState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.videos.length, 'count', 3),
        ],
        verify: (_) {
          verifyNever(() => mockCache.read(any()));
        },
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'keeps cached data visible when network fails',
        setUp: () {
          final cachedVideos = createTestVideos(2, idPrefix: 'cached');

          when(
            () => mockCache.read(sharedPreferences),
          ).thenReturn(HomeFeedResult(videos: cachedVideos));
          when(() => mockFollowRepository.followingPubkeys).thenReturn([]);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenThrow(Exception('network error'));
        },
        build: createBlocWithCache,
        act: (bloc) =>
            bloc.add(const VideoFeedStarted(mode: FeedMode.following)),
        expect: () => [
          // 1. Loading state
          const VideoFeedState(),
          // 2. Cached videos served
          isA<VideoFeedState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.videos.length, 'cached count', 2),
          // No failure state emitted because cached data is displayed
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'serves cache only once per bloc instance',
        setUp: () {
          final cachedVideos = createTestVideos(2, idPrefix: 'cached');
          final freshVideos = createTestVideos(3, idPrefix: 'fresh');

          when(
            () => mockCache.read(sharedPreferences),
          ).thenReturn(HomeFeedResult(videos: cachedVideos));
          when(() => mockCache.write(any(), any())).thenAnswer((_) async {});
          when(
            () => mockFollowRepository.followingPubkeys,
          ).thenReturn(['author1']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: freshVideos));
        },
        build: createBlocWithCache,
        act: (bloc) async {
          bloc.add(const VideoFeedStarted(mode: FeedMode.following));
          await Future<void>.delayed(Duration.zero);
          // Trigger a refresh — should NOT serve cache again
          bloc.add(const VideoFeedRefreshRequested());
        },
        verify: (_) {
          // Cache read should only be called once (on first load)
          verify(() => mockCache.read(sharedPreferences)).called(1);
        },
      );
    });

    group('creator profile prefetching', () {
      final pubkeyA = 'a' * 64;
      final pubkeyB = 'b' * 64;
      final pubkeyC = 'c' * 64;

      VideoEvent videoWithPubkey(String id, String pubkey, {int? createdAt}) {
        final timestamp =
            createdAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
        return VideoEvent(
          id: id,
          pubkey: pubkey,
          createdAt: timestamp,
          content: '',
          timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp * 1000),
          title: 'Test Video $id',
          videoUrl: 'https://example.com/$id.mp4',
          thumbnailUrl: 'https://example.com/$id.jpg',
        );
      }

      UserProfile profileForPubkey(String pubkey) => UserProfile(
        pubkey: pubkey,
        eventId: 'event-$pubkey',
        rawData: const {},
        createdAt: DateTime(2024),
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'fetches creator profiles when videos load',
        setUp: () {
          final baseTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          final videos = [
            videoWithPubkey('v1', pubkeyA, createdAt: baseTime),
            videoWithPubkey('v2', pubkeyB, createdAt: baseTime - 1),
          ];

          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: videos));

          when(
            () => mockProfileRepository.fetchBatchProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenAnswer(
            (_) async => {
              pubkeyA: profileForPubkey(pubkeyA),
              pubkeyB: profileForPubkey(pubkeyB),
            },
          );
        },
        build: () => VideoFeedBloc(
          videosRepository: mockVideosRepository,
          followRepository: mockFollowRepository,
          curatedListRepository: mockCuratedListRepository,
          profileRepository: mockProfileRepository,
        ),
        act: (bloc) =>
            bloc.add(const VideoFeedStarted(mode: FeedMode.following)),
        verify: (_) {
          verify(
            () => mockProfileRepository.fetchBatchProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).called(1);
        },
        expect: () => [
          const VideoFeedState(),
          // Videos loaded (no profiles yet)
          isA<VideoFeedState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.videos, 'videos', hasLength(2))
              .having((s) => s.creatorProfiles, 'profiles', isEmpty),
          // Profiles fetched
          isA<VideoFeedState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.creatorProfiles, 'profiles', hasLength(2)),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'fetches only new profiles on pagination',
        setUp: () {
          final baseTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          final initialVideos = [
            videoWithPubkey('v1', pubkeyA, createdAt: baseTime),
          ];
          final moreVideos = [
            videoWithPubkey('v2', pubkeyB, createdAt: baseTime - 2),
            videoWithPubkey('v3', pubkeyC, createdAt: baseTime - 3),
          ];

          var callCount = 0;
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenAnswer((_) async {
            callCount++;
            if (callCount == 1) {
              return HomeFeedResult(videos: initialVideos);
            }
            return HomeFeedResult(videos: moreVideos);
          });

          when(
            () => mockProfileRepository.fetchBatchProfiles(pubkeys: [pubkeyA]),
          ).thenAnswer((_) async => {pubkeyA: profileForPubkey(pubkeyA)});

          when(
            () => mockProfileRepository.fetchBatchProfiles(
              pubkeys: any(named: 'pubkeys', that: isNot(equals([pubkeyA]))),
            ),
          ).thenAnswer(
            (_) async => {
              pubkeyB: profileForPubkey(pubkeyB),
              pubkeyC: profileForPubkey(pubkeyC),
            },
          );
        },
        build: () => VideoFeedBloc(
          videosRepository: mockVideosRepository,
          followRepository: mockFollowRepository,
          curatedListRepository: mockCuratedListRepository,
          profileRepository: mockProfileRepository,
        ),
        act: (bloc) async {
          bloc.add(const VideoFeedStarted(mode: FeedMode.following));
          await Future<void>.delayed(const Duration(milliseconds: 100));
          bloc.add(const VideoFeedLoadMoreRequested());
        },
        verify: (_) {
          verify(
            () => mockProfileRepository.fetchBatchProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).called(2);
        },
        expect: () => [
          // Loading
          const VideoFeedState(),
          // Initial videos loaded
          isA<VideoFeedState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.videos, 'videos', hasLength(1)),
          // Profiles for initial videos
          isA<VideoFeedState>().having(
            (s) => s.creatorProfiles,
            'profiles after initial',
            hasLength(1),
          ),
          // Pagination loading
          isA<VideoFeedState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            isTrue,
          ),
          // Pagination complete
          isA<VideoFeedState>()
              .having((s) => s.videos, 'videos', hasLength(3))
              .having((s) => s.isLoadingMore, 'isLoadingMore', isFalse),
          // Profiles for new creators
          isA<VideoFeedState>().having(
            (s) => s.creatorProfiles,
            'profiles after pagination',
            hasLength(3),
          ),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedState>(
        'does not re-fetch existing profiles on pagination',
        setUp: () {
          final baseTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          final initialVideos = [
            videoWithPubkey('v1', pubkeyA, createdAt: baseTime),
          ];
          // Pagination returns a video from the same creator
          final moreVideos = [
            videoWithPubkey('v2', pubkeyA, createdAt: baseTime - 2),
          ];

          var callCount = 0;
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenAnswer((_) async {
            callCount++;
            if (callCount == 1) {
              return HomeFeedResult(videos: initialVideos);
            }
            return HomeFeedResult(videos: moreVideos);
          });

          when(
            () => mockProfileRepository.fetchBatchProfiles(pubkeys: [pubkeyA]),
          ).thenAnswer((_) async => {pubkeyA: profileForPubkey(pubkeyA)});
        },
        build: () => VideoFeedBloc(
          videosRepository: mockVideosRepository,
          followRepository: mockFollowRepository,
          curatedListRepository: mockCuratedListRepository,
          profileRepository: mockProfileRepository,
        ),
        act: (bloc) async {
          bloc.add(const VideoFeedStarted(mode: FeedMode.following));
          await Future<void>.delayed(const Duration(milliseconds: 100));
          bloc.add(const VideoFeedLoadMoreRequested());
        },
        verify: (_) {
          // fetchBatchProfiles should only be called once (initial load).
          // Pagination has no new pubkeys, so no second call.
          verify(
            () => mockProfileRepository.fetchBatchProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).called(1);
        },
      );
    });
  });
}
