// ABOUTME: Tests for VideoInteractionsBloc - per-video interactions management
// ABOUTME: Tests fetching counts, toggling likes, and state synchronization

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:comments_repository/comments_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';

class _MockLikesRepository extends Mock implements LikesRepository {}

class _MockCommentsRepository extends Mock implements CommentsRepository {}

void main() {
  group('VideoInteractionsBloc', () {
    late _MockLikesRepository mockLikesRepository;
    late _MockCommentsRepository mockCommentsRepository;
    late StreamController<Set<String>> likedIdsController;

    const testEventId = 'test-event-id';
    const testAuthorPubkey = 'test-author-pubkey';

    setUp(() {
      mockLikesRepository = _MockLikesRepository();
      mockCommentsRepository = _MockCommentsRepository();
      likedIdsController = StreamController<Set<String>>.broadcast();

      // Default stub for watchLikedEventIds
      when(
        () => mockLikesRepository.watchLikedEventIds(),
      ).thenAnswer((_) => likedIdsController.stream);
    });

    tearDown(() {
      likedIdsController.close();
    });

    VideoInteractionsBloc createBloc() => VideoInteractionsBloc(
      eventId: testEventId,
      authorPubkey: testAuthorPubkey,
      likesRepository: mockLikesRepository,
      commentsRepository: mockCommentsRepository,
    );

    test('initial state is initial with default values', () {
      final bloc = createBloc();
      expect(bloc.state.status, VideoInteractionsStatus.initial);
      expect(bloc.state.isLiked, isFalse);
      expect(bloc.state.likeCount, isNull);
      expect(bloc.state.commentCount, isNull);
      expect(bloc.state.isLikeInProgress, isFalse);
      expect(bloc.state.error, isNull);
      bloc.close();
    });

    group('VideoInteractionsFetchRequested', () {
      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'emits [loading, success] with fetched data when all calls succeed',
        setUp: () {
          when(
            () => mockLikesRepository.isLiked(testEventId),
          ).thenAnswer((_) async => true);
          when(
            () => mockLikesRepository.getLikeCount(testEventId),
          ).thenAnswer((_) async => 42);
          when(
            () => mockCommentsRepository.getCommentsCount(testEventId),
          ).thenAnswer((_) async => 10);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const VideoInteractionsFetchRequested()),
        expect: () => [
          const VideoInteractionsState(status: VideoInteractionsStatus.loading),
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLiked: true,
            likeCount: 42,
            commentCount: 10,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'emits [loading, success] when video is not liked',
        setUp: () {
          when(
            () => mockLikesRepository.isLiked(testEventId),
          ).thenAnswer((_) async => false);
          when(
            () => mockLikesRepository.getLikeCount(testEventId),
          ).thenAnswer((_) async => 5);
          when(
            () => mockCommentsRepository.getCommentsCount(testEventId),
          ).thenAnswer((_) async => 0);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const VideoInteractionsFetchRequested()),
        expect: () => [
          const VideoInteractionsState(status: VideoInteractionsStatus.loading),
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLiked: false,
            likeCount: 5,
            commentCount: 0,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'emits [loading, success] with error when fetch fails',
        setUp: () {
          when(
            () => mockLikesRepository.isLiked(testEventId),
          ).thenThrow(Exception('Network error'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const VideoInteractionsFetchRequested()),
        expect: () => [
          const VideoInteractionsState(status: VideoInteractionsStatus.loading),
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            error: VideoInteractionsError.fetchFailed,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'does not re-fetch when already loading',
        setUp: () {
          when(
            () => mockLikesRepository.isLiked(testEventId),
          ).thenAnswer((_) async => true);
          when(
            () => mockLikesRepository.getLikeCount(testEventId),
          ).thenAnswer((_) async => 42);
          when(
            () => mockCommentsRepository.getCommentsCount(testEventId),
          ).thenAnswer((_) async => 10);
        },
        build: createBloc,
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.loading,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsFetchRequested()),
        expect: () => <VideoInteractionsState>[],
        verify: (_) {
          verifyNever(() => mockLikesRepository.isLiked(any()));
        },
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'does not re-fetch when already loaded successfully',
        setUp: () {
          when(
            () => mockLikesRepository.isLiked(testEventId),
          ).thenAnswer((_) async => true);
          when(
            () => mockLikesRepository.getLikeCount(testEventId),
          ).thenAnswer((_) async => 42);
          when(
            () => mockCommentsRepository.getCommentsCount(testEventId),
          ).thenAnswer((_) async => 10);
        },
        build: createBloc,
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsFetchRequested()),
        expect: () => <VideoInteractionsState>[],
        verify: (_) {
          verifyNever(() => mockLikesRepository.isLiked(any()));
        },
      );
    });

    group('VideoInteractionsLikeToggled', () {
      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'likes video when not already liked',
        setUp: () {
          when(
            () => mockLikesRepository.toggleLike(
              eventId: testEventId,
              authorPubkey: testAuthorPubkey,
            ),
          ).thenAnswer((_) async => true);
        },
        build: createBloc,
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          isLiked: false,
          likeCount: 10,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsLikeToggled()),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLiked: false,
            likeCount: 10,
            isLikeInProgress: true,
          ),
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLiked: true,
            likeCount: 11,
            isLikeInProgress: false,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'unlikes video when already liked',
        setUp: () {
          when(
            () => mockLikesRepository.toggleLike(
              eventId: testEventId,
              authorPubkey: testAuthorPubkey,
            ),
          ).thenAnswer((_) async => false);
        },
        build: createBloc,
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          isLiked: true,
          likeCount: 10,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsLikeToggled()),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLiked: true,
            likeCount: 10,
            isLikeInProgress: true,
          ),
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLiked: false,
            likeCount: 9,
            isLikeInProgress: false,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'does not allow like count to go below zero',
        setUp: () {
          when(
            () => mockLikesRepository.toggleLike(
              eventId: testEventId,
              authorPubkey: testAuthorPubkey,
            ),
          ).thenAnswer((_) async => false);
        },
        build: createBloc,
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          isLiked: true,
          likeCount: 0,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsLikeToggled()),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLiked: true,
            likeCount: 0,
            isLikeInProgress: true,
          ),
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLiked: false,
            likeCount: 0,
            isLikeInProgress: false,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'does not toggle when operation already in progress',
        build: createBloc,
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          isLikeInProgress: true,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsLikeToggled()),
        expect: () => <VideoInteractionsState>[],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'handles AlreadyLikedException by updating state to liked',
        setUp: () {
          when(
            () => mockLikesRepository.toggleLike(
              eventId: testEventId,
              authorPubkey: testAuthorPubkey,
            ),
          ).thenThrow(const AlreadyLikedException(testEventId));
        },
        build: createBloc,
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          isLiked: false,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsLikeToggled()),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLiked: false,
            isLikeInProgress: true,
          ),
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLiked: true,
            isLikeInProgress: false,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'handles NotLikedException by updating state to not liked',
        setUp: () {
          when(
            () => mockLikesRepository.toggleLike(
              eventId: testEventId,
              authorPubkey: testAuthorPubkey,
            ),
          ).thenThrow(const NotLikedException(testEventId));
        },
        build: createBloc,
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          isLiked: true,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsLikeToggled()),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLiked: true,
            isLikeInProgress: true,
          ),
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLiked: false,
            isLikeInProgress: false,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'emits error when toggle fails with generic exception',
        setUp: () {
          when(
            () => mockLikesRepository.toggleLike(
              eventId: testEventId,
              authorPubkey: testAuthorPubkey,
            ),
          ).thenThrow(Exception('Network error'));
        },
        build: createBloc,
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsLikeToggled()),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLikeInProgress: true,
          ),
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLikeInProgress: false,
            error: VideoInteractionsError.likeFailed,
          ),
        ],
      );
    });

    group('VideoInteractionsSubscriptionRequested', () {
      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'updates like status when stream emits with this event liked',
        build: createBloc,
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          isLiked: false,
          likeCount: 10,
        ),
        act: (bloc) async {
          bloc.add(const VideoInteractionsSubscriptionRequested());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          likedIdsController.add({testEventId});
        },
        wait: const Duration(milliseconds: 100),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLiked: true,
            likeCount: 11,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'updates like status when stream emits without this event',
        build: createBloc,
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          isLiked: true,
          likeCount: 10,
        ),
        act: (bloc) async {
          bloc.add(const VideoInteractionsSubscriptionRequested());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          likedIdsController.add(<String>{});
        },
        wait: const Duration(milliseconds: 100),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLiked: false,
            likeCount: 9,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'does not emit when status unchanged',
        build: createBloc,
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          isLiked: true,
          likeCount: 10,
        ),
        act: (bloc) async {
          bloc.add(const VideoInteractionsSubscriptionRequested());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          likedIdsController.add({testEventId});
        },
        wait: const Duration(milliseconds: 100),
        expect: () => <VideoInteractionsState>[],
      );
    });

    group('close', () {
      test('cancels liked IDs subscription', () async {
        final bloc = createBloc();

        await bloc.close();

        // After closing, stream events should not affect anything
        // This mainly tests that no errors occur
        expect(() => likedIdsController.add({testEventId}), returnsNormally);
      });
    });
  });

  group('VideoInteractionsState', () {
    test('supports value equality', () {
      const state1 = VideoInteractionsState(
        status: VideoInteractionsStatus.success,
        isLiked: true,
        likeCount: 10,
        commentCount: 5,
      );
      const state2 = VideoInteractionsState(
        status: VideoInteractionsStatus.success,
        isLiked: true,
        likeCount: 10,
        commentCount: 5,
      );

      expect(state1, equals(state2));
    });

    test('hasLoadedCounts returns true when likeCount is not null', () {
      const stateWithCounts = VideoInteractionsState(likeCount: 10);
      const stateWithoutCounts = VideoInteractionsState();

      expect(stateWithCounts.hasLoadedCounts, isTrue);
      expect(stateWithoutCounts.hasLoadedCounts, isFalse);
    });

    test('copyWith creates copy with updated values', () {
      const state = VideoInteractionsState();

      final updated = state.copyWith(
        status: VideoInteractionsStatus.success,
        isLiked: true,
        likeCount: 42,
        commentCount: 10,
      );

      expect(updated.status, VideoInteractionsStatus.success);
      expect(updated.isLiked, isTrue);
      expect(updated.likeCount, 42);
      expect(updated.commentCount, 10);
    });

    test('copyWith preserves values when not specified', () {
      const state = VideoInteractionsState(
        status: VideoInteractionsStatus.success,
        isLiked: true,
        likeCount: 42,
        commentCount: 10,
      );

      final updated = state.copyWith();

      expect(updated.status, VideoInteractionsStatus.success);
      expect(updated.isLiked, isTrue);
      expect(updated.likeCount, 42);
      expect(updated.commentCount, 10);
    });

    test('copyWith clearError clears error', () {
      const state = VideoInteractionsState(
        error: VideoInteractionsError.likeFailed,
      );

      final updated = state.copyWith(clearError: true);

      expect(updated.error, isNull);
    });
  });
}
