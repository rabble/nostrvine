// ABOUTME: Tests for VideoSearchBloc - progressive search via
// ABOUTME: VideosRepository.searchVideos() stream.
// ABOUTME: Verifies debounce, clear, progressive emission, and error handling.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_search/video_search_bloc.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockVideosRepository extends Mock implements VideosRepository {}

void main() {
  group(VideoSearchBloc, () {
    late _MockVideosRepository mockVideosRepository;

    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch ~/ 1000;

    VideoEvent createVideo({
      required String id,
      String pubkey =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      String? title,
      String? content,
      List<String> hashtags = const [],
    }) {
      return VideoEvent(
        id: id,
        pubkey: pubkey,
        content: content ?? '',
        title: title,
        createdAt: timestamp,
        timestamp: now,
        hashtags: hashtags,
      );
    }

    setUp(() {
      mockVideosRepository = _MockVideosRepository();

      // Default stub: empty stream
      when(
        () => mockVideosRepository.searchVideos(
          query: any(named: 'query'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) => const Stream.empty());
    });

    VideoSearchBloc createBloc() =>
        VideoSearchBloc(videosRepository: mockVideosRepository);

    test('initial state is correct', () {
      final bloc = createBloc();
      expect(bloc.state.status, VideoSearchStatus.initial);
      expect(bloc.state.query, isEmpty);
      expect(bloc.state.videos, isEmpty);
      bloc.close();
    });

    group('VideoSearchQueryChanged', () {
      const debounceDuration = Duration(milliseconds: 400);

      blocTest<VideoSearchBloc, VideoSearchState>(
        'emits initial state when query is empty',
        build: createBloc,
        act: (bloc) => bloc.add(const VideoSearchQueryChanged('')),
        wait: debounceDuration,
        expect: () => [const VideoSearchState()],
        verify: (_) {
          verifyNever(
            () => mockVideosRepository.searchVideos(query: any(named: 'query')),
          );
        },
      );

      blocTest<VideoSearchBloc, VideoSearchState>(
        'emits initial state when query is whitespace only',
        build: createBloc,
        act: (bloc) => bloc.add(const VideoSearchQueryChanged('   ')),
        wait: debounceDuration,
        expect: () => [const VideoSearchState()],
        verify: (_) {
          verifyNever(
            () => mockVideosRepository.searchVideos(query: any(named: 'query')),
          );
        },
      );

      blocTest<VideoSearchBloc, VideoSearchState>(
        'emits [searching, searching(videos), success] '
        'when stream yields results',
        setUp: () {
          final video = createVideo(id: 'v1', title: 'Flutter Tutorial');

          when(
            () => mockVideosRepository.searchVideos(query: 'flutter'),
          ).thenAnswer((_) => Stream.value([video]));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const VideoSearchQueryChanged('flutter')),
        wait: debounceDuration,
        expect: () => [
          isA<VideoSearchState>()
              .having((s) => s.status, 'status', VideoSearchStatus.searching)
              .having((s) => s.query, 'query', 'flutter'),
          isA<VideoSearchState>()
              .having((s) => s.status, 'status', VideoSearchStatus.searching)
              .having((s) => s.videos, 'videos', hasLength(1)),
          isA<VideoSearchState>()
              .having((s) => s.status, 'status', VideoSearchStatus.success)
              .having((s) => s.videos, 'videos', hasLength(1)),
        ],
      );

      blocTest<VideoSearchBloc, VideoSearchState>(
        'emits progressive searching states then success '
        'when stream yields multiple times',
        setUp: () {
          final localVideo = createVideo(id: 'local-1', title: 'Local');
          final combinedVideos = [
            localVideo,
            createVideo(id: 'relay-1', title: 'Relay'),
          ];

          when(
            () => mockVideosRepository.searchVideos(query: 'flutter'),
          ).thenAnswer(
            (_) => Stream.fromIterable([
              [localVideo],
              combinedVideos,
            ]),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const VideoSearchQueryChanged('flutter')),
        wait: debounceDuration,
        expect: () => [
          isA<VideoSearchState>()
              .having((s) => s.status, 'status', VideoSearchStatus.searching)
              .having((s) => s.query, 'query', 'flutter'),
          isA<VideoSearchState>()
              .having((s) => s.status, 'status', VideoSearchStatus.searching)
              .having((s) => s.videos, 'videos', hasLength(1)),
          isA<VideoSearchState>()
              .having((s) => s.status, 'status', VideoSearchStatus.searching)
              .having((s) => s.videos, 'videos', hasLength(2)),
          isA<VideoSearchState>()
              .having((s) => s.status, 'status', VideoSearchStatus.success)
              .having((s) => s.videos, 'videos', hasLength(2)),
        ],
      );

      blocTest<VideoSearchBloc, VideoSearchState>(
        'stays searching when local cache is empty '
        'until API yields results and stream completes',
        setUp: () {
          final apiVideo = createVideo(id: 'api-1', title: 'API Result');

          when(
            () => mockVideosRepository.searchVideos(query: 'flutter'),
          ).thenAnswer(
            (_) => Stream.fromIterable([
              <VideoEvent>[], // local cache empty
              [apiVideo], // API returns results
            ]),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const VideoSearchQueryChanged('flutter')),
        wait: debounceDuration,
        expect: () => [
          isA<VideoSearchState>()
              .having((s) => s.status, 'status', VideoSearchStatus.searching)
              .having((s) => s.query, 'query', 'flutter')
              .having((s) => s.videos, 'videos', isEmpty),
          // local cache yields [] — deduped by Equatable (same state)
          // API yields results — still searching
          isA<VideoSearchState>()
              .having((s) => s.status, 'status', VideoSearchStatus.searching)
              .having((s) => s.videos, 'videos', hasLength(1)),
          // stream done — now success
          isA<VideoSearchState>()
              .having((s) => s.status, 'status', VideoSearchStatus.success)
              .having((s) => s.videos, 'videos', hasLength(1)),
        ],
      );

      blocTest<VideoSearchBloc, VideoSearchState>(
        'emits [searching, searching(empty), success(empty)] '
        'when stream yields empty list',
        setUp: () {
          when(
            () => mockVideosRepository.searchVideos(query: 'flutter'),
          ).thenAnswer((_) => Stream.value([]));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const VideoSearchQueryChanged('flutter')),
        wait: debounceDuration,
        expect: () => [
          isA<VideoSearchState>().having(
            (s) => s.status,
            'status',
            VideoSearchStatus.searching,
          ),
          isA<VideoSearchState>()
              .having((s) => s.status, 'status', VideoSearchStatus.success)
              .having((s) => s.videos, 'videos', isEmpty),
        ],
      );

      blocTest<VideoSearchBloc, VideoSearchState>(
        'emits [searching, failure] when stream throws',
        setUp: () {
          when(
            () => mockVideosRepository.searchVideos(query: 'flutter'),
          ).thenAnswer((_) => Stream.error(Exception('search failed')));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const VideoSearchQueryChanged('flutter')),
        wait: debounceDuration,
        expect: () => [
          isA<VideoSearchState>().having(
            (s) => s.status,
            'status',
            VideoSearchStatus.searching,
          ),
          isA<VideoSearchState>().having(
            (s) => s.status,
            'status',
            VideoSearchStatus.failure,
          ),
        ],
      );

      blocTest<VideoSearchBloc, VideoSearchState>(
        'debounces rapid query changes and only processes final query',
        setUp: () {
          final video = createVideo(id: 'v1', title: 'Final Result');

          when(
            () => mockVideosRepository.searchVideos(query: 'final'),
          ).thenAnswer((_) => Stream.value([video]));
        },
        build: createBloc,
        act: (bloc) {
          bloc
            ..add(const VideoSearchQueryChanged('f'))
            ..add(const VideoSearchQueryChanged('fi'))
            ..add(const VideoSearchQueryChanged('fin'))
            ..add(const VideoSearchQueryChanged('fina'))
            ..add(const VideoSearchQueryChanged('final'));
        },
        wait: debounceDuration,
        verify: (bloc) {
          expect(bloc.state.query, 'final');
          verify(
            () => mockVideosRepository.searchVideos(query: 'final'),
          ).called(1);
        },
      );

      blocTest<VideoSearchBloc, VideoSearchState>(
        'does not re-search when query has not changed',
        build: createBloc,
        seed: () => VideoSearchState(
          status: VideoSearchStatus.success,
          query: 'flutter',
          videos: [createVideo(id: 'v1', title: 'Flutter Tutorial')],
        ),
        act: (bloc) => bloc.add(const VideoSearchQueryChanged('flutter')),
        wait: debounceDuration,
        expect: () => <VideoSearchState>[],
        verify: (_) {
          verifyNever(
            () => mockVideosRepository.searchVideos(
              query: any(named: 'query'),
            ),
          );
        },
      );

      blocTest<VideoSearchBloc, VideoSearchState>(
        'passes query to repository trimmed',
        build: createBloc,
        act: (bloc) => bloc.add(const VideoSearchQueryChanged('  flutter  ')),
        wait: debounceDuration,
        verify: (_) {
          verify(
            () => mockVideosRepository.searchVideos(query: 'flutter'),
          ).called(1);
        },
      );
    });

    group('VideoSearchCleared', () {
      blocTest<VideoSearchBloc, VideoSearchState>(
        'resets to initial state',
        build: createBloc,
        seed: () => VideoSearchState(
          status: VideoSearchStatus.success,
          query: 'flutter',
          videos: [createVideo(id: 'v1', title: 'Flutter')],
        ),
        act: (bloc) => bloc.add(const VideoSearchCleared()),
        expect: () => [const VideoSearchState()],
      );
    });

    group(VideoSearchState, () {
      test('copyWith creates copy with updated values', () {
        const state = VideoSearchState();

        final updated = state.copyWith(
          status: VideoSearchStatus.success,
          query: 'test',
          videos: [],
        );

        expect(updated.status, VideoSearchStatus.success);
        expect(updated.query, 'test');
        expect(updated.videos, isEmpty);
      });

      test('copyWith preserves existing values when not specified', () {
        final state = VideoSearchState(
          status: VideoSearchStatus.success,
          query: 'flutter',
          videos: [createVideo(id: 'v1', title: 'Flutter')],
        );

        final updated = state.copyWith(status: VideoSearchStatus.searching);

        expect(updated.status, VideoSearchStatus.searching);
        expect(updated.query, 'flutter');
        expect(updated.videos, hasLength(1));
      });

      test('props includes all fields', () {
        final videos = [createVideo(id: 'v1', title: 'Test')];
        final state = VideoSearchState(
          status: VideoSearchStatus.success,
          query: 'test',
          videos: videos,
        );

        expect(state.props, [VideoSearchStatus.success, 'test', videos]);
      });

      test('two states with same values are equal', () {
        const state1 = VideoSearchState(
          status: VideoSearchStatus.success,
          query: 'flutter',
        );
        const state2 = VideoSearchState(
          status: VideoSearchStatus.success,
          query: 'flutter',
        );

        expect(state1, equals(state2));
      });

      test('two states with different values are not equal', () {
        const state1 = VideoSearchState(query: 'flutter');
        const state2 = VideoSearchState(query: 'dart');

        expect(state1, isNot(equals(state2)));
      });
    });
  });
}
