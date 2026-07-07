// ABOUTME: Unit tests for VideoLinkPreviewCubit.
// ABOUTME: Tests repository-delegated resolve, hydration, fallback, not-found.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/screens/inbox/conversation/widgets/video_link_preview_cubit.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockVideosRepository extends Mock implements VideosRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(<String>[]);
  });

  group(VideoLinkPreviewCubit, () {
    late _MockVideosRepository mockVideosRepository;

    // Carries a hydrated `views` tag so totalLoops is non-zero: the exact
    // count the shared-video card and detail screen must surface (see #5844).
    final testVideo = VideoEvent(
      id:
          '0123456789abcdef0123456789abcdef'
          '0123456789abcdef0123456789abcdef',
      pubkey:
          'abcdef0123456789abcdef0123456789'
          'abcdef0123456789abcdef0123456789',
      createdAt: 1757385263,
      content: 'Test',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
      title: 'My Cool Video',
      rawTags: const {'views': '1234'},
    );

    setUp(() {
      mockVideosRepository = _MockVideosRepository();

      // Default: repository resolves nothing.
      when(
        () => mockVideosRepository.fetchVideoWithStatsForRouteId(
          any(),
          fallbackRouteIds: any(named: 'fallbackRouteIds'),
        ),
      ).thenAnswer((_) async => null);
    });

    VideoLinkPreviewCubit createCubit({String stableId = 'test-id'}) =>
        VideoLinkPreviewCubit(
          videoStableId: stableId,
          videosRepository: mockVideosRepository,
        );

    group('resolve', () {
      blocTest<VideoLinkPreviewCubit, VideoLinkPreviewState>(
        'emits $VideoLinkPreviewResolved with the repository-hydrated video',
        setUp: () {
          when(
            () => mockVideosRepository.fetchVideoWithStatsForRouteId(
              'test-id',
              fallbackRouteIds: any(named: 'fallbackRouteIds'),
            ),
          ).thenAnswer((_) async => testVideo);
        },
        build: createCubit,
        expect: () => [
          isA<VideoLinkPreviewResolved>()
              .having((s) => s.video.id, 'video.id', testVideo.id)
              .having((s) => s.video.totalLoops, 'video.totalLoops', 1234),
        ],
      );

      blocTest<VideoLinkPreviewCubit, VideoLinkPreviewState>(
        'passes an author/kind addressable fallback route when both are given',
        build: () => VideoLinkPreviewCubit(
          videoStableId: 'skate-loop',
          authorPubkey: testVideo.pubkey,
          videoKind: 34235,
          videosRepository: mockVideosRepository,
        ),
        expect: () => [isA<VideoLinkPreviewNotFound>()],
        verify: (_) {
          verify(
            () => mockVideosRepository.fetchVideoWithStatsForRouteId(
              'skate-loop',
              fallbackRouteIds: ['34235:${testVideo.pubkey}:skate-loop'],
            ),
          ).called(1);
        },
      );

      blocTest<VideoLinkPreviewCubit, VideoLinkPreviewState>(
        'passes no fallback route when author/kind are absent',
        build: createCubit,
        expect: () => [isA<VideoLinkPreviewNotFound>()],
        verify: (_) {
          verify(
            () => mockVideosRepository.fetchVideoWithStatsForRouteId(
              'test-id',
              fallbackRouteIds: any(named: 'fallbackRouteIds', that: isEmpty),
            ),
          ).called(1);
        },
      );
    });

    group('not found', () {
      blocTest<VideoLinkPreviewCubit, VideoLinkPreviewState>(
        'emits $VideoLinkPreviewNotFound when the repository resolves nothing',
        build: createCubit,
        expect: () => [isA<VideoLinkPreviewNotFound>()],
      );

      blocTest<VideoLinkPreviewCubit, VideoLinkPreviewState>(
        'emits $VideoLinkPreviewNotFound when the repository throws',
        setUp: () {
          when(
            () => mockVideosRepository.fetchVideoWithStatsForRouteId(
              any(),
              fallbackRouteIds: any(named: 'fallbackRouteIds'),
            ),
          ).thenThrow(Exception('network error'));
        },
        build: createCubit,
        expect: () => [isA<VideoLinkPreviewNotFound>()],
      );
    });

    group('close during in-flight resolve', () {
      test('does not emit or throw when closed mid resolve', () async {
        final completer = Completer<VideoEvent?>();
        when(
          () => mockVideosRepository.fetchVideoWithStatsForRouteId(
            any(),
            fallbackRouteIds: any(named: 'fallbackRouteIds'),
          ),
        ).thenAnswer((_) => completer.future);

        final cubit = createCubit();
        // Let _resolve run past scheduling to the awaited repository call.
        await pumpEventQueue();
        expect(cubit.state, isA<VideoLinkPreviewLoading>());

        // Close while the resolve is still in flight.
        await cubit.close();

        // Completing drives the post-await path; without the isClosed guard
        // this emits on the closed cubit and throws StateError.
        completer.complete(testVideo);
        await pumpEventQueue();

        expect(cubit.state, isA<VideoLinkPreviewLoading>());
      });
    });
  });
}
