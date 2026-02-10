// ABOUTME: Tests for HashtagFeedBloc - hashtag video feed
// ABOUTME: Tests loading, pagination, refresh, and error handling

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/hashtag_feed/hashtag_feed_bloc.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockVideosRepository extends Mock implements VideosRepository {}

void main() {
  group(HashtagFeedBloc, () {
    late _MockVideosRepository mockVideosRepository;

    setUp(() {
      mockVideosRepository = _MockVideosRepository();
    });

    HashtagFeedBloc createBloc() =>
        HashtagFeedBloc(videosRepository: mockVideosRepository);

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

    List<VideoEvent> createTestVideos(int count) {
      final baseTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return List.generate(
        count,
        (i) => createTestVideo('video-$i', createdAt: baseTimestamp - i),
      );
    }

    /// Page size must match the one in hashtag_feed_bloc.dart
    const pageSize = 20;

    test('initial state is correct', () {
      final bloc = createBloc();
      expect(bloc.state.status, HashtagFeedStatus.loading);
      expect(bloc.state.videos, isEmpty);
      expect(bloc.state.hashtag, isEmpty);
      expect(bloc.state.hasMore, isTrue);
      expect(bloc.state.isLoadingMore, isFalse);
      bloc.close();
    });

    group('HashtagFeedState', () {
      test('isLoading returns true when status is loading', () {
        const state = HashtagFeedState();
        expect(state.isLoading, isTrue);
      });

      test('isEmpty returns true when success with no videos', () {
        const emptyState = HashtagFeedState(status: HashtagFeedStatus.success);
        expect(emptyState.isEmpty, isTrue);
      });

      test('copyWith creates copy with updated values', () {
        const state = HashtagFeedState();
        final videos = createTestVideos(3);

        final updated = state.copyWith(
          status: HashtagFeedStatus.success,
          videos: videos,
          hashtag: 'cats',
          hasMore: false,
        );

        expect(updated.status, HashtagFeedStatus.success);
        expect(updated.videos, hasLength(3));
        expect(updated.hashtag, equals('cats'));
        expect(updated.hasMore, isFalse);
      });
    });

    group('HashtagFeedStarted', () {
      blocTest<HashtagFeedBloc, HashtagFeedState>(
        'emits [loading, success] when videos load successfully',
        setUp: () {
          final videos = createTestVideos(pageSize);
          when(
            () => mockVideosRepository.getVideosByHashtag(
              tag: any(named: 'tag'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
            ),
          ).thenAnswer((_) async => videos);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const HashtagFeedStarted('cats')),
        expect: () => [
          const HashtagFeedState(
            status: HashtagFeedStatus.loading,
            hashtag: 'cats',
          ),
          isA<HashtagFeedState>()
              .having((s) => s.status, 'status', HashtagFeedStatus.success)
              .having((s) => s.videos.length, 'videos count', pageSize)
              .having((s) => s.hashtag, 'hashtag', 'cats')
              .having((s) => s.hasMore, 'hasMore', true),
        ],
      );

      blocTest<HashtagFeedBloc, HashtagFeedState>(
        'emits [loading, success] with hasMore false '
        'when fewer than pageSize videos returned',
        setUp: () {
          final videos = createTestVideos(3);
          when(
            () => mockVideosRepository.getVideosByHashtag(
              tag: any(named: 'tag'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
            ),
          ).thenAnswer((_) async => videos);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const HashtagFeedStarted('dogs')),
        expect: () => [
          const HashtagFeedState(
            status: HashtagFeedStatus.loading,
            hashtag: 'dogs',
          ),
          isA<HashtagFeedState>()
              .having((s) => s.status, 'status', HashtagFeedStatus.success)
              .having((s) => s.videos.length, 'videos count', 3)
              .having((s) => s.hasMore, 'hasMore', false),
        ],
      );

      blocTest<HashtagFeedBloc, HashtagFeedState>(
        'emits [loading, success] with empty list when no videos found',
        setUp: () {
          when(
            () => mockVideosRepository.getVideosByHashtag(
              tag: any(named: 'tag'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
            ),
          ).thenAnswer((_) async => <VideoEvent>[]);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const HashtagFeedStarted('nonexistent')),
        expect: () => [
          const HashtagFeedState(
            status: HashtagFeedStatus.loading,
            hashtag: 'nonexistent',
          ),
          const HashtagFeedState(
            status: HashtagFeedStatus.success,
            hashtag: 'nonexistent',
            videos: [],
            hasMore: false,
          ),
        ],
      );

      blocTest<HashtagFeedBloc, HashtagFeedState>(
        'emits [loading, failure] when repository throws',
        setUp: () {
          when(
            () => mockVideosRepository.getVideosByHashtag(
              tag: any(named: 'tag'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
            ),
          ).thenThrow(Exception('Network error'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const HashtagFeedStarted('cats')),
        expect: () => [
          const HashtagFeedState(
            status: HashtagFeedStatus.loading,
            hashtag: 'cats',
          ),
          const HashtagFeedState(
            status: HashtagFeedStatus.failure,
            hashtag: 'cats',
          ),
        ],
      );

      blocTest<HashtagFeedBloc, HashtagFeedState>(
        'passes correct tag and limit to repository',
        setUp: () {
          when(
            () => mockVideosRepository.getVideosByHashtag(
              tag: any(named: 'tag'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
            ),
          ).thenAnswer((_) async => <VideoEvent>[]);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const HashtagFeedStarted('funny')),
        verify: (_) {
          verify(
            () => mockVideosRepository.getVideosByHashtag(
              tag: 'funny',
              limit: pageSize,
            ),
          ).called(1);
        },
      );
    });

    group('HashtagFeedLoadMoreRequested', () {
      blocTest<HashtagFeedBloc, HashtagFeedState>(
        'loads more videos with correct offset',
        seed: () {
          final videos = createTestVideos(pageSize);
          return HashtagFeedState(
            status: HashtagFeedStatus.success,
            videos: videos,
            hashtag: 'cats',
          );
        },
        setUp: () {
          final newVideos = createTestVideos(10);
          when(
            () => mockVideosRepository.getVideosByHashtag(
              tag: any(named: 'tag'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
            ),
          ).thenAnswer((_) async => newVideos);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const HashtagFeedLoadMoreRequested()),
        expect: () => [
          isA<HashtagFeedState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            true,
          ),
          isA<HashtagFeedState>()
              .having((s) => s.videos.length, 'videos count', pageSize + 10)
              .having((s) => s.isLoadingMore, 'isLoadingMore', false)
              .having((s) => s.hasMore, 'hasMore', false),
        ],
        verify: (_) {
          verify(
            () => mockVideosRepository.getVideosByHashtag(
              tag: 'cats',
              limit: pageSize,
              offset: pageSize,
            ),
          ).called(1);
        },
      );

      blocTest<HashtagFeedBloc, HashtagFeedState>(
        'does nothing when not in success state',
        seed: () => const HashtagFeedState(
          status: HashtagFeedStatus.loading,
          hashtag: 'cats',
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const HashtagFeedLoadMoreRequested()),
        expect: () => <HashtagFeedState>[],
      );

      blocTest<HashtagFeedBloc, HashtagFeedState>(
        'does nothing when already loading more',
        seed: () => HashtagFeedState(
          status: HashtagFeedStatus.success,
          videos: createTestVideos(pageSize),
          hashtag: 'cats',
          isLoadingMore: true,
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const HashtagFeedLoadMoreRequested()),
        expect: () => <HashtagFeedState>[],
      );

      blocTest<HashtagFeedBloc, HashtagFeedState>(
        'does nothing when hasMore is false',
        seed: () => HashtagFeedState(
          status: HashtagFeedStatus.success,
          videos: createTestVideos(3),
          hashtag: 'cats',
          hasMore: false,
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const HashtagFeedLoadMoreRequested()),
        expect: () => <HashtagFeedState>[],
      );

      blocTest<HashtagFeedBloc, HashtagFeedState>(
        'does nothing when videos are empty',
        seed: () => const HashtagFeedState(
          status: HashtagFeedStatus.success,
          hashtag: 'cats',
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const HashtagFeedLoadMoreRequested()),
        expect: () => <HashtagFeedState>[],
      );

      blocTest<HashtagFeedBloc, HashtagFeedState>(
        'resets isLoadingMore on error',
        seed: () => HashtagFeedState(
          status: HashtagFeedStatus.success,
          videos: createTestVideos(pageSize),
          hashtag: 'cats',
        ),
        setUp: () {
          when(
            () => mockVideosRepository.getVideosByHashtag(
              tag: any(named: 'tag'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
            ),
          ).thenThrow(Exception('Network error'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const HashtagFeedLoadMoreRequested()),
        expect: () => [
          isA<HashtagFeedState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            true,
          ),
          isA<HashtagFeedState>()
              .having((s) => s.isLoadingMore, 'isLoadingMore', false)
              .having((s) => s.videos.length, 'videos count', pageSize),
        ],
      );
    });

    group('HashtagFeedRefreshRequested', () {
      blocTest<HashtagFeedBloc, HashtagFeedState>(
        'clears videos and reloads from beginning',
        seed: () => HashtagFeedState(
          status: HashtagFeedStatus.success,
          videos: createTestVideos(pageSize),
          hashtag: 'cats',
          hasMore: false,
        ),
        setUp: () {
          final freshVideos = createTestVideos(10);
          when(
            () => mockVideosRepository.getVideosByHashtag(
              tag: any(named: 'tag'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
            ),
          ).thenAnswer((_) async => freshVideos);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const HashtagFeedRefreshRequested()),
        expect: () => [
          const HashtagFeedState(
            status: HashtagFeedStatus.loading,
            hashtag: 'cats',
          ),
          isA<HashtagFeedState>()
              .having((s) => s.status, 'status', HashtagFeedStatus.success)
              .having((s) => s.videos.length, 'videos count', 10)
              .having((s) => s.hasMore, 'hasMore', false),
        ],
      );

      blocTest<HashtagFeedBloc, HashtagFeedState>(
        'emits failure state when refresh throws',
        seed: () => HashtagFeedState(
          status: HashtagFeedStatus.success,
          videos: createTestVideos(5),
          hashtag: 'cats',
        ),
        setUp: () {
          when(
            () => mockVideosRepository.getVideosByHashtag(
              tag: any(named: 'tag'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
            ),
          ).thenThrow(Exception('Refresh failed'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const HashtagFeedRefreshRequested()),
        expect: () => [
          const HashtagFeedState(
            status: HashtagFeedStatus.loading,
            hashtag: 'cats',
          ),
          const HashtagFeedState(
            status: HashtagFeedStatus.failure,
            hashtag: 'cats',
          ),
        ],
      );
    });
  });
}
