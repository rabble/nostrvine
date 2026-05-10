// ABOUTME: Tests for VideoEngagementBloc — likers / reposters list loading.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_engagement/video_engagement_bloc.dart';
import 'package:reposts_repository/reposts_repository.dart';

class _MockLikesRepository extends Mock implements LikesRepository {}

class _MockRepostsRepository extends Mock implements RepostsRepository {}

void main() {
  group(VideoEngagementBloc, () {
    late _MockLikesRepository likesRepository;
    late _MockRepostsRepository repostsRepository;

    const testEventId = 'event-id-1';
    const testAddressableId = '34236:authorpubkey:dtag';
    const liker1 = 'liker-pubkey-1';
    const liker2 = 'liker-pubkey-2';
    const reposter1 = 'reposter-pubkey-1';

    setUp(() {
      likesRepository = _MockLikesRepository();
      repostsRepository = _MockRepostsRepository();
    });

    VideoEngagementBloc createBloc({
      VideoEngagementType type = VideoEngagementType.likers,
      String? addressableId = testAddressableId,
    }) => VideoEngagementBloc(
      eventId: testEventId,
      type: type,
      likesRepository: likesRepository,
      repostsRepository: repostsRepository,
      addressableId: addressableId,
    );

    test('initial state has type and initial status', () {
      final bloc = createBloc();
      expect(bloc.state.type, VideoEngagementType.likers);
      expect(bloc.state.status, VideoEngagementStatus.initial);
      expect(bloc.state.pubkeys, isEmpty);
      bloc.close();
    });

    group('VideoEngagementLoadRequested for likers', () {
      blocTest<VideoEngagementBloc, VideoEngagementState>(
        'emits [loading, success] with pubkeys from likes repo',
        setUp: () {
          when(
            () => likesRepository.fetchEventLikers(
              eventId: testEventId,
              addressableId: testAddressableId,
            ),
          ).thenAnswer((_) async => const [liker1, liker2]);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const VideoEngagementLoadRequested()),
        expect: () => [
          const VideoEngagementState(
            type: VideoEngagementType.likers,
            status: VideoEngagementStatus.loading,
          ),
          const VideoEngagementState(
            type: VideoEngagementType.likers,
            status: VideoEngagementStatus.success,
            pubkeys: [liker1, liker2],
          ),
        ],
      );

      blocTest<VideoEngagementBloc, VideoEngagementState>(
        'emits [loading, failure] and reports error when fetch throws',
        setUp: () {
          when(
            () => likesRepository.fetchEventLikers(
              eventId: testEventId,
              addressableId: testAddressableId,
            ),
          ).thenThrow(const FetchLikersFailedException('relay down'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const VideoEngagementLoadRequested()),
        expect: () => [
          const VideoEngagementState(
            type: VideoEngagementType.likers,
            status: VideoEngagementStatus.loading,
          ),
          const VideoEngagementState(
            type: VideoEngagementType.likers,
            status: VideoEngagementStatus.failure,
          ),
        ],
        errors: () => [isA<FetchLikersFailedException>()],
      );

      blocTest<VideoEngagementBloc, VideoEngagementState>(
        'forwards null addressableId when none was provided',
        setUp: () {
          when(
            () => likesRepository.fetchEventLikers(
              eventId: testEventId,
            ),
          ).thenAnswer((_) async => const [liker1]);
        },
        build: () => createBloc(addressableId: null),
        act: (bloc) => bloc.add(const VideoEngagementLoadRequested()),
        verify: (_) {
          verify(
            () => likesRepository.fetchEventLikers(
              eventId: testEventId,
            ),
          ).called(1);
          verifyNever(
            () => repostsRepository.fetchEventReposters(
              eventId: any(named: 'eventId'),
              addressableId: any(named: 'addressableId'),
            ),
          );
        },
      );
    });

    group('VideoEngagementLoadRequested for reposters', () {
      blocTest<VideoEngagementBloc, VideoEngagementState>(
        'emits [loading, success] with pubkeys from reposts repo',
        setUp: () {
          when(
            () => repostsRepository.fetchEventReposters(
              eventId: testEventId,
              addressableId: testAddressableId,
            ),
          ).thenAnswer((_) async => const [reposter1]);
        },
        build: () => createBloc(type: VideoEngagementType.reposters),
        act: (bloc) => bloc.add(const VideoEngagementLoadRequested()),
        expect: () => [
          const VideoEngagementState(
            type: VideoEngagementType.reposters,
            status: VideoEngagementStatus.loading,
          ),
          const VideoEngagementState(
            type: VideoEngagementType.reposters,
            status: VideoEngagementStatus.success,
            pubkeys: [reposter1],
          ),
        ],
        verify: (_) {
          verifyNever(
            () => likesRepository.fetchEventLikers(
              eventId: any(named: 'eventId'),
              addressableId: any(named: 'addressableId'),
            ),
          );
        },
      );

      blocTest<VideoEngagementBloc, VideoEngagementState>(
        'emits [loading, failure] and reports error when fetch throws',
        setUp: () {
          when(
            () => repostsRepository.fetchEventReposters(
              eventId: testEventId,
              addressableId: testAddressableId,
            ),
          ).thenThrow(const FetchRepostersFailedException('relay down'));
        },
        build: () => createBloc(type: VideoEngagementType.reposters),
        act: (bloc) => bloc.add(const VideoEngagementLoadRequested()),
        expect: () => [
          const VideoEngagementState(
            type: VideoEngagementType.reposters,
            status: VideoEngagementStatus.loading,
          ),
          const VideoEngagementState(
            type: VideoEngagementType.reposters,
            status: VideoEngagementStatus.failure,
          ),
        ],
        errors: () => [isA<FetchRepostersFailedException>()],
      );
    });

    group('VideoEngagementState.copyWith', () {
      test('preserves type and updates only supplied fields', () {
        const original = VideoEngagementState(
          type: VideoEngagementType.likers,
          pubkeys: [liker1],
        );

        final copied = original.copyWith(
          status: VideoEngagementStatus.loading,
        );

        expect(copied.type, VideoEngagementType.likers);
        expect(copied.status, VideoEngagementStatus.loading);
        expect(copied.pubkeys, const [liker1]);
      });

      test('returns new pubkeys when supplied', () {
        const original = VideoEngagementState(
          type: VideoEngagementType.reposters,
        );

        final copied = original.copyWith(
          status: VideoEngagementStatus.success,
          pubkeys: const [reposter1],
        );

        expect(copied.pubkeys, const [reposter1]);
        expect(copied.type, VideoEngagementType.reposters);
      });
    });
  });
}
