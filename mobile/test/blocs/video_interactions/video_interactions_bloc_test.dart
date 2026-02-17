// ABOUTME: Tests for VideoInteractionsBloc - per-video interactions management
// ABOUTME: Tests fetching counts, toggling likes, and state synchronization

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:comments_repository/comments_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:reposts_repository/reposts_repository.dart';

class _MockLikesRepository extends Mock implements LikesRepository {}

class _MockCommentsRepository extends Mock implements CommentsRepository {}

class _MockRepostsRepository extends Mock implements RepostsRepository {}

void main() {
  group('VideoInteractionsBloc', () {
    late _MockLikesRepository mockLikesRepository;
    late _MockCommentsRepository mockCommentsRepository;
    late _MockRepostsRepository mockRepostsRepository;
    late StreamController<List<String>> likedIdsController;
    late StreamController<Set<String>> repostedIdsController;

    const testEventId = 'test-event-id';
    const testAuthorPubkey = 'test-author-pubkey';
    const testAddressableId = '34236:$testAuthorPubkey:test-d-tag';

    setUp(() {
      mockLikesRepository = _MockLikesRepository();
      mockCommentsRepository = _MockCommentsRepository();
      mockRepostsRepository = _MockRepostsRepository();
      likedIdsController = StreamController<List<String>>.broadcast();
      repostedIdsController = StreamController<Set<String>>.broadcast();

      // Default stub for watchLikedEventIds
      when(
        () => mockLikesRepository.watchLikedEventIds(),
      ).thenAnswer((_) => likedIdsController.stream);

      // Default stub for watchRepostedAddressableIds
      when(
        () => mockRepostsRepository.watchRepostedAddressableIds(),
      ).thenAnswer((_) => repostedIdsController.stream);

      // Default stub for isReposted (returns false by default)
      when(
        () => mockRepostsRepository.isReposted(any()),
      ).thenAnswer((_) async => false);
    });

    tearDown(() {
      likedIdsController.close();
      repostedIdsController.close();
    });

    VideoInteractionsBloc createBloc({String? addressableId}) =>
        VideoInteractionsBloc(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
          likesRepository: mockLikesRepository,
          commentsRepository: mockCommentsRepository,
          repostsRepository: mockRepostsRepository,
          addressableId: addressableId,
        );

    test('initial state is initial with default values', () {
      final bloc = createBloc();
      expect(bloc.state.status, VideoInteractionsStatus.initial);
      expect(bloc.state.isLiked, isFalse);
      expect(bloc.state.likeCount, isNull);
      expect(bloc.state.isReposted, isFalse);
      expect(bloc.state.repostCount, isNull);
      expect(bloc.state.commentCount, isNull);
      expect(bloc.state.isLikeInProgress, isFalse);
      expect(bloc.state.isRepostInProgress, isFalse);
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
          when(
            () => mockRepostsRepository.getRepostCountByEventId(testEventId),
          ).thenAnswer((_) async => 5);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const VideoInteractionsFetchRequested()),
        expect: () => [
          const VideoInteractionsState(status: VideoInteractionsStatus.loading),
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLiked: true,
            likeCount: 42,
            repostCount: 5,
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
          when(
            () => mockRepostsRepository.getRepostCountByEventId(testEventId),
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
            repostCount: 0,
            commentCount: 0,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'fetches repost count by addressable ID per NIP-18 for addressable '
        'videos',
        setUp: () {
          when(
            () => mockLikesRepository.isLiked(testEventId),
          ).thenAnswer((_) async => false);
          when(
            () => mockRepostsRepository.isReposted(testAddressableId),
          ).thenAnswer((_) async => true);
          // Mock with addressableId parameter for addressable videos
          when(
            () => mockLikesRepository.getLikeCount(
              testEventId,
              addressableId: testAddressableId,
            ),
          ).thenAnswer((_) async => 10);
          when(
            () => mockCommentsRepository.getCommentsCount(
              testEventId,
              rootAddressableId: testAddressableId,
            ),
          ).thenAnswer((_) async => 5);
          when(
            () => mockRepostsRepository.getRepostCount(testAddressableId),
          ).thenAnswer((_) async => 3);
        },
        build: () => createBloc(addressableId: testAddressableId),
        act: (bloc) => bloc.add(const VideoInteractionsFetchRequested()),
        expect: () => [
          const VideoInteractionsState(status: VideoInteractionsStatus.loading),
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLiked: false,
            isReposted: true,
            likeCount: 10,
            repostCount: 3,
            commentCount: 5,
          ),
        ],
        verify: (_) {
          // Uses addressable ID for addressable videos per NIP-18
          verify(
            () => mockRepostsRepository.getRepostCount(testAddressableId),
          ).called(1);
          verifyNever(
            () => mockRepostsRepository.getRepostCountByEventId(any()),
          );
          // Verifies getLikeCount is called with addressableId
          verify(
            () => mockLikesRepository.getLikeCount(
              testEventId,
              addressableId: testAddressableId,
            ),
          ).called(1);
        },
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'fetches repost count by event ID for non-addressable videos',
        setUp: () {
          when(
            () => mockLikesRepository.isLiked(testEventId),
          ).thenAnswer((_) async => false);
          when(
            () => mockLikesRepository.getLikeCount(testEventId),
          ).thenAnswer((_) async => 10);
          when(
            () => mockCommentsRepository.getCommentsCount(testEventId),
          ).thenAnswer((_) async => 5);
          when(
            () => mockRepostsRepository.getRepostCountByEventId(testEventId),
          ).thenAnswer((_) async => 2);
        },
        build: createBloc, // No addressable ID
        act: (bloc) => bloc.add(const VideoInteractionsFetchRequested()),
        expect: () => [
          const VideoInteractionsState(status: VideoInteractionsStatus.loading),
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLiked: false,
            likeCount: 10,
            repostCount: 2,
            commentCount: 5,
          ),
        ],
        verify: (_) {
          // Uses event ID for non-addressable videos
          verify(
            () => mockRepostsRepository.getRepostCountByEventId(testEventId),
          ).called(1);
          verifyNever(() => mockRepostsRepository.getRepostCount(any()));
        },
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
          // Non-addressable video: no addressableId or targetKind
          when(
            () => mockLikesRepository.toggleLike(
              eventId: testEventId,
              authorPubkey: testAuthorPubkey,
              addressableId: null,
              targetKind: null,
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
        'likes addressable video with a-tag params',
        setUp: () {
          // Addressable video: includes addressableId and targetKind 34236
          when(
            () => mockLikesRepository.toggleLike(
              eventId: testEventId,
              authorPubkey: testAuthorPubkey,
              addressableId: testAddressableId,
              targetKind: 34236,
            ),
          ).thenAnswer((_) async => true);
        },
        build: () => createBloc(addressableId: testAddressableId),
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
        verify: (_) {
          verify(
            () => mockLikesRepository.toggleLike(
              eventId: testEventId,
              authorPubkey: testAuthorPubkey,
              addressableId: testAddressableId,
              targetKind: 34236,
            ),
          ).called(1);
        },
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'unlikes video when already liked',
        setUp: () {
          when(
            () => mockLikesRepository.toggleLike(
              eventId: testEventId,
              authorPubkey: testAuthorPubkey,
              addressableId: null,
              targetKind: null,
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
              addressableId: null,
              targetKind: null,
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
              addressableId: null,
              targetKind: null,
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
              addressableId: null,
              targetKind: null,
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
              addressableId: null,
              targetKind: null,
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

    group('VideoInteractionsRepostToggled', () {
      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'reposts video when not already reposted',
        setUp: () {
          when(
            () => mockRepostsRepository.toggleRepost(
              addressableId: testAddressableId,
              originalAuthorPubkey: testAuthorPubkey,
              eventId: testEventId,
              currentCount: 5,
            ),
          ).thenAnswer((_) async => true);
        },
        build: () => createBloc(addressableId: testAddressableId),
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          isReposted: false,
          repostCount: 5,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsRepostToggled()),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isReposted: false,
            repostCount: 5,
            isRepostInProgress: true,
          ),
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isReposted: true,
            repostCount: 6,
            isRepostInProgress: false,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'unreposts video when already reposted',
        setUp: () {
          when(
            () => mockRepostsRepository.toggleRepost(
              addressableId: testAddressableId,
              originalAuthorPubkey: testAuthorPubkey,
              eventId: testEventId,
              currentCount: 5,
            ),
          ).thenAnswer((_) async => false);
        },
        build: () => createBloc(addressableId: testAddressableId),
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          isReposted: true,
          repostCount: 5,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsRepostToggled()),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isReposted: true,
            repostCount: 5,
            isRepostInProgress: true,
          ),
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isReposted: false,
            repostCount: 4,
            isRepostInProgress: false,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'does not allow repost count to go below zero',
        setUp: () {
          when(
            () => mockRepostsRepository.toggleRepost(
              addressableId: testAddressableId,
              originalAuthorPubkey: testAuthorPubkey,
              eventId: testEventId,
              currentCount: 0,
            ),
          ).thenAnswer((_) async => false);
        },
        build: () => createBloc(addressableId: testAddressableId),
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          isReposted: true,
          repostCount: 0,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsRepostToggled()),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isReposted: true,
            repostCount: 0,
            isRepostInProgress: true,
          ),
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isReposted: false,
            repostCount: 0,
            isRepostInProgress: false,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'does not toggle when operation already in progress',
        build: () => createBloc(addressableId: testAddressableId),
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          isRepostInProgress: true,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsRepostToggled()),
        expect: () => <VideoInteractionsState>[],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'emits error when no addressable ID is present',
        build: createBloc, // No addressable ID
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsRepostToggled()),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            error: VideoInteractionsError.repostFailed,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'handles AlreadyRepostedException by updating state to reposted',
        setUp: () {
          when(
            () => mockRepostsRepository.toggleRepost(
              addressableId: testAddressableId,
              originalAuthorPubkey: testAuthorPubkey,
              eventId: testEventId,
              currentCount: 0,
            ),
          ).thenThrow(const AlreadyRepostedException(testAddressableId));
        },
        build: () => createBloc(addressableId: testAddressableId),
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          isReposted: false,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsRepostToggled()),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isReposted: false,
            isRepostInProgress: true,
          ),
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isReposted: true,
            isRepostInProgress: false,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'handles NotRepostedException by updating state to not reposted',
        setUp: () {
          when(
            () => mockRepostsRepository.toggleRepost(
              addressableId: testAddressableId,
              originalAuthorPubkey: testAuthorPubkey,
              eventId: testEventId,
              currentCount: 0,
            ),
          ).thenThrow(const NotRepostedException(testAddressableId));
        },
        build: () => createBloc(addressableId: testAddressableId),
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          isReposted: true,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsRepostToggled()),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isReposted: true,
            isRepostInProgress: true,
          ),
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isReposted: false,
            isRepostInProgress: false,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'emits error when toggle fails with generic exception',
        setUp: () {
          when(
            () => mockRepostsRepository.toggleRepost(
              addressableId: testAddressableId,
              originalAuthorPubkey: testAuthorPubkey,
              eventId: testEventId,
              currentCount: 0,
            ),
          ).thenThrow(Exception('Network error'));
        },
        build: () => createBloc(addressableId: testAddressableId),
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsRepostToggled()),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isRepostInProgress: true,
          ),
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isRepostInProgress: false,
            error: VideoInteractionsError.repostFailed,
          ),
        ],
      );
    });

    group('VideoInteractionsSubscriptionRequested', () {
      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'updates isLiked without adjusting likeCount when stream emits liked',
        build: createBloc,
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          isLiked: false,
          likeCount: 10,
        ),
        act: (bloc) async {
          bloc.add(const VideoInteractionsSubscriptionRequested());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          likedIdsController.add([testEventId]);
        },
        wait: const Duration(milliseconds: 100),
        expect: () => [
          // likeCount stays at 10 — count is only adjusted by _onLikeToggled
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLiked: true,
            likeCount: 10,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'updates isLiked without adjusting likeCount when stream emits '
        'unliked',
        build: createBloc,
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          isLiked: true,
          likeCount: 10,
        ),
        act: (bloc) async {
          bloc.add(const VideoInteractionsSubscriptionRequested());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          likedIdsController.add(<String>[]);
        },
        wait: const Duration(milliseconds: 100),
        expect: () => [
          // likeCount stays at 10 — count is only adjusted by _onLikeToggled
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLiked: false,
            likeCount: 10,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'does not emit when like status unchanged',
        build: createBloc,
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          isLiked: true,
          likeCount: 10,
        ),
        act: (bloc) async {
          bloc.add(const VideoInteractionsSubscriptionRequested());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          likedIdsController.add([testEventId]);
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
        expect(() => likedIdsController.add([testEventId]), returnsNormally);
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
