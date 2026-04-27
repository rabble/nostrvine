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

    VideoInteractionsBloc createBloc({
      String? addressableId,
      int? initialLikeCount,
    }) => VideoInteractionsBloc(
      eventId: testEventId,
      authorPubkey: testAuthorPubkey,
      likesRepository: mockLikesRepository,
      commentsRepository: mockCommentsRepository,
      repostsRepository: mockRepostsRepository,
      addressableId: addressableId,
      initialLikeCount: initialLikeCount,
    );

    test('initial state is initial with default values', () {
      final bloc = createBloc();
      expect(bloc.state.status, VideoInteractionsStatus.initial);
      expect(bloc.state.isLiked, isFalse);
      expect(bloc.state.likeCount, isNull);
      expect(bloc.state.isReposted, isFalse);
      expect(bloc.state.repostCount, isNull);
      expect(bloc.state.commentCount, isNull);
      expect(bloc.state.error, isNull);
      bloc.close();
    });

    test('initial state seeds likeCount from initialLikeCount', () {
      final bloc = createBloc(initialLikeCount: 42);
      expect(bloc.state.likeCount, equals(42));
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
        'skips relay like count query when seeded with initialLikeCount',
        setUp: () {
          when(
            () => mockLikesRepository.isLiked(testEventId),
          ).thenAnswer((_) async => true);
          when(
            () => mockCommentsRepository.getCommentsCount(testEventId),
          ).thenAnswer((_) async => 10);
          when(
            () => mockRepostsRepository.getRepostCountByEventId(testEventId),
          ).thenAnswer((_) async => 5);
        },
        build: () => createBloc(initialLikeCount: 100),
        act: (bloc) => bloc.add(const VideoInteractionsFetchRequested()),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.loading,
            likeCount: 100,
          ),
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLiked: true,
            likeCount: 100,
            repostCount: 5,
            commentCount: 10,
          ),
        ],
        verify: (_) {
          verifyNever(() => mockLikesRepository.getLikeCount(any()));
          verifyNever(
            () => mockLikesRepository.getLikeCount(
              any(),
              addressableId: any(named: 'addressableId'),
            ),
          );
        },
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

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'preserves optimistic toggle when tap lands mid-fetch',
        setUp: () {
          // Pre-fetch repository state: not liked, count from initial seed.
          when(
            () => mockLikesRepository.isLiked(testEventId),
          ).thenAnswer((_) async => false);
          // Hold the fetch open via a slow comment count so the tap can
          // land between the loading emit and the success emit. Without
          // the pre-fetch snapshot guard in [_onFetchRequested], the
          // success emit overwrites isLiked + likeCount with stale relay
          // values and the heart bounces back off.
          when(
            () => mockCommentsRepository.getCommentsCount(testEventId),
          ).thenAnswer((_) async {
            await Future<void>.delayed(const Duration(milliseconds: 30));
            return 0;
          });
          when(
            () => mockRepostsRepository.getRepostCountByEventId(testEventId),
          ).thenAnswer((_) async => 0);
          when(
            () => mockLikesRepository.toggleLike(
              eventId: testEventId,
              authorPubkey: testAuthorPubkey,
            ),
          ).thenAnswer((_) async => true);
        },
        build: () => createBloc(initialLikeCount: 10),
        act: (bloc) async {
          bloc.add(const VideoInteractionsFetchRequested());
          // Let the fetch handler reach its first await on isLiked +
          // schedule the slow comments query, but not finish.
          await Future<void>.delayed(const Duration(milliseconds: 5));
          bloc.add(const VideoInteractionsLikeToggled());
        },
        wait: const Duration(milliseconds: 100),
        expect: () => [
          // Fetch enters loading. Seeded likeCount=10 carries through.
          const VideoInteractionsState(
            status: VideoInteractionsStatus.loading,
            likeCount: 10,
          ),
          // Tap lands while fetch awaits relay round-trips.
          const VideoInteractionsState(
            status: VideoInteractionsStatus.loading,
            isLiked: true,
            likeCount: 11,
          ),
          // Fetch resolves: isLiked + likeCount drifted from the
          // pre-fetch baseline (false, 10) to the optimistic values
          // (true, 11), so the success emit MUST preserve them and only
          // apply the untouched commentCount + repostCount.
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLiked: true,
            likeCount: 11,
            repostCount: 0,
            commentCount: 0,
          ),
        ],
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
            ),
          ).thenAnswer((_) async => true);
        },
        build: createBloc,
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          likeCount: 10,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsLikeToggled()),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLiked: true,
            likeCount: 11,
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
          likeCount: 10,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsLikeToggled()),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLiked: true,
            likeCount: 11,
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
            likeCount: 9,
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
            likeCount: 0,
          ),
        ],
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
        ),
        act: (bloc) => bloc.add(const VideoInteractionsLikeToggled()),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLiked: true,
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
          const VideoInteractionsState(status: VideoInteractionsStatus.success),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'emits optimistic flip then rollback when toggle throws',
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
          // Optimistic flip lands first so the heart updates immediately.
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLiked: true,
          ),
          // Rollback after the publish failure restores the pre-tap heart
          // state and surfaces the error.
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            error: VideoInteractionsError.likeFailed,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'rolls back like + count to baseline when toggle throws',
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
          likeCount: 10,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsLikeToggled()),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLiked: true,
            likeCount: 11,
          ),
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            likeCount: 10,
            error: VideoInteractionsError.likeFailed,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'subscription stream tick during toggle does not double-emit',
        setUp: () {
          when(
            () => mockLikesRepository.toggleLike(
              eventId: testEventId,
              authorPubkey: testAuthorPubkey,
            ),
          ).thenAnswer((_) async {
            // Repository ticks the stream BEFORE returning, mirroring
            // LikesRepository.likeEvent's optimistic-first ordering. The
            // bloc's optimistic emit has already set state.isLiked=true,
            // so the subscription handler's early-return absorbs this.
            likedIdsController.add([testEventId]);
            await Future<void>.delayed(Duration.zero);
            return true;
          });
        },
        build: createBloc,
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          likeCount: 10,
        ),
        act: (bloc) async {
          bloc.add(const VideoInteractionsSubscriptionRequested());
          await Future<void>.delayed(const Duration(milliseconds: 20));
          bloc.add(const VideoInteractionsLikeToggled());
        },
        wait: const Duration(milliseconds: 100),
        expect: () => [
          // Exactly one emit: optimistic flip with both fields. The
          // stream tick that follows is absorbed by the subscription
          // handler's early-return guard.
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLiked: true,
            likeCount: 11,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'optimistic emit lands before publish settles (fire-and-forget)',
        setUp: () {
          // Hold toggleLike open on a Completer so the publish never
          // settles within the test window. The bloc handler must still
          // emit the optimistic state and return — proving that the
          // network publish does not block the bloc's event queue.
          final completer = Completer<bool>();
          when(
            () => mockLikesRepository.toggleLike(
              eventId: testEventId,
              authorPubkey: testAuthorPubkey,
            ),
          ).thenAnswer((_) => completer.future);
        },
        build: createBloc,
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          likeCount: 10,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsLikeToggled()),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLiked: true,
            likeCount: 11,
          ),
        ],
        verify: (bloc) {
          // Settle event has not been dispatched (publish still pending),
          // but state already reflects the optimistic flip.
          expect(bloc.state.isLiked, isTrue);
          expect(bloc.state.likeCount, 11);
        },
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'out-of-band toggle reconciles count from pre-tap baseline',
        setUp: () {
          // User taps to like (optimistic: isLiked=true, count=11), but
          // the repository ends up with isLiked=false (e.g., another
          // device unliked mid-tap). Reconciliation in [_onLikeSettled]
          // applies _adjustCount to the pre-tap baseline (wasCount=10),
          // not the already-incremented current count (11). With
          // currentCount we would emit (false, 10) — incorrect because
          // another transition was missed. With wasCount we emit
          // (false, 9), reflecting the canonical decrement from the
          // baseline.
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
          likeCount: 10,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsLikeToggled()),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLiked: true,
            likeCount: 11,
          ),
          // Anchored on wasCount=10, not the optimistic 11.
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            likeCount: 9,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'closed bloc does not dispatch settle event after publish resolves',
        setUp: () {
          // Simulates scroll-away: user taps, immediately the feed item
          // disposes its bloc, and the publish settles afterward. The
          // unawaited future must check isClosed before dispatching a
          // _VideoInteractionsLikeSettled event — otherwise add() on a
          // closed bloc throws StateError.
          when(
            () => mockLikesRepository.toggleLike(
              eventId: testEventId,
              authorPubkey: testAuthorPubkey,
            ),
          ).thenAnswer((_) async {
            await Future<void>.delayed(const Duration(milliseconds: 5));
            return true;
          });
        },
        build: createBloc,
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          likeCount: 10,
        ),
        act: (bloc) async {
          bloc.add(const VideoInteractionsLikeToggled());
          // Close before the publish has had a chance to resolve.
          await bloc.close();
        },
        wait: const Duration(milliseconds: 50),
        expect: () => [
          // Only the optimistic emit. The settle event would be a no-op
          // on a closed bloc, but we must guard against it being
          // dispatched at all (StateError on add to closed bloc).
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLiked: true,
            likeCount: 11,
          ),
        ],
      );

      test('two blocs run in parallel — neither blocks the other', () async {
        // The architectural invariant rabble called out: a slow publish
        // on video A must not block tapping like on video B. Different
        // videos use different bloc instances; this test pins the
        // contract by keeping both publishes pending and asserting that
        // both blocs emit their optimistic state independently.
        final completerA = Completer<bool>();
        final completerB = Completer<bool>();
        final mockLikesA = _MockLikesRepository();
        final mockLikesB = _MockLikesRepository();
        final mockCommentsA = _MockCommentsRepository();
        final mockCommentsB = _MockCommentsRepository();
        final mockRepostsA = _MockRepostsRepository();
        final mockRepostsB = _MockRepostsRepository();
        final likedStreamA = StreamController<List<String>>.broadcast();
        final likedStreamB = StreamController<List<String>>.broadcast();
        final repostedStreamA = StreamController<Set<String>>.broadcast();
        final repostedStreamB = StreamController<Set<String>>.broadcast();
        addTearDown(() async {
          await likedStreamA.close();
          await likedStreamB.close();
          await repostedStreamA.close();
          await repostedStreamB.close();
        });

        // ignore_for_file: unnecessary_lambdas
        // The closures below cannot be tear-offs because thenAnswer
        // requires a Function(Invocation), but the captured locals are
        // variable references that the analyzer cannot prove constant.
        when(
          () => mockLikesA.watchLikedEventIds(),
        ).thenAnswer((_) => likedStreamA.stream);
        when(
          () => mockLikesB.watchLikedEventIds(),
        ).thenAnswer((_) => likedStreamB.stream);
        when(
          () => mockRepostsA.watchRepostedAddressableIds(),
        ).thenAnswer((_) => repostedStreamA.stream);
        when(
          () => mockRepostsB.watchRepostedAddressableIds(),
        ).thenAnswer((_) => repostedStreamB.stream);

        when(
          () => mockLikesA.toggleLike(
            eventId: 'event-a',
            authorPubkey: testAuthorPubkey,
          ),
        ).thenAnswer((_) => completerA.future);
        when(
          () => mockLikesB.toggleLike(
            eventId: 'event-b',
            authorPubkey: testAuthorPubkey,
          ),
        ).thenAnswer((_) => completerB.future);

        final blocA = VideoInteractionsBloc(
          eventId: 'event-a',
          authorPubkey: testAuthorPubkey,
          likesRepository: mockLikesA,
          commentsRepository: mockCommentsA,
          repostsRepository: mockRepostsA,
        );
        final blocB = VideoInteractionsBloc(
          eventId: 'event-b',
          authorPubkey: testAuthorPubkey,
          likesRepository: mockLikesB,
          commentsRepository: mockCommentsB,
          repostsRepository: mockRepostsB,
        );
        addTearDown(() async {
          await blocA.close();
          await blocB.close();
        });

        // Tap like on A (publish never resolves), then on B.
        blocA.add(const VideoInteractionsLikeToggled());
        blocB.add(const VideoInteractionsLikeToggled());

        // Allow both event loops to drain.
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // Both blocs already reflect the optimistic flip even though
        // neither publish has settled.
        expect(blocA.state.isLiked, isTrue, reason: 'bloc A should flip');
        expect(blocB.state.isLiked, isTrue, reason: 'bloc B should flip');
        expect(completerA.isCompleted, isFalse);
        expect(completerB.isCompleted, isFalse);

        // Both repositories were called — neither call queued behind the
        // other.
        verify(
          () => mockLikesA.toggleLike(
            eventId: 'event-a',
            authorPubkey: testAuthorPubkey,
          ),
        ).called(1);
        verify(
          () => mockLikesB.toggleLike(
            eventId: 'event-b',
            authorPubkey: testAuthorPubkey,
          ),
        ).called(1);
      });
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
            ),
          ).thenAnswer((_) async => true);
        },
        build: () => createBloc(addressableId: testAddressableId),
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          repostCount: 5,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsRepostToggled()),
        expect: () => [
          // Single optimistic emit: icon + count flip together.
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isReposted: true,
            repostCount: 6,
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
            repostCount: 4,
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
            repostCount: 0,
          ),
        ],
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
        'handles AlreadyRepostedException by leaving state reposted',
        setUp: () {
          when(
            () => mockRepostsRepository.toggleRepost(
              addressableId: testAddressableId,
              originalAuthorPubkey: testAuthorPubkey,
              eventId: testEventId,
            ),
          ).thenThrow(const AlreadyRepostedException(testAddressableId));
        },
        build: () => createBloc(addressableId: testAddressableId),
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsRepostToggled()),
        expect: () => [
          // Optimistic flip stands; the rollback emit produces the same
          // state and is deduped by Equatable.
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isReposted: true,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'handles NotRepostedException by leaving state not-reposted',
        setUp: () {
          when(
            () => mockRepostsRepository.toggleRepost(
              addressableId: testAddressableId,
              originalAuthorPubkey: testAuthorPubkey,
              eventId: testEventId,
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
          const VideoInteractionsState(status: VideoInteractionsStatus.success),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'emits optimistic flip then rollback when toggle throws',
        setUp: () {
          when(
            () => mockRepostsRepository.toggleRepost(
              addressableId: testAddressableId,
              originalAuthorPubkey: testAuthorPubkey,
              eventId: testEventId,
            ),
          ).thenThrow(Exception('Network error'));
        },
        build: () => createBloc(addressableId: testAddressableId),
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          repostCount: 5,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsRepostToggled()),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isReposted: true,
            repostCount: 6,
          ),
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            repostCount: 5,
            error: VideoInteractionsError.repostFailed,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'subscription stream tick during toggle does not double-emit',
        setUp: () {
          when(
            () => mockRepostsRepository.toggleRepost(
              addressableId: testAddressableId,
              originalAuthorPubkey: testAuthorPubkey,
              eventId: testEventId,
            ),
          ).thenAnswer((_) async {
            // Repository ticks the stream BEFORE returning. The bloc's
            // optimistic emit already set state.isReposted=true, so the
            // subscription handler's early-return absorbs the tick.
            repostedIdsController.add({testAddressableId});
            await Future<void>.delayed(Duration.zero);
            return true;
          });
        },
        build: () => createBloc(addressableId: testAddressableId),
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          repostCount: 5,
        ),
        act: (bloc) async {
          bloc.add(const VideoInteractionsSubscriptionRequested());
          await Future<void>.delayed(const Duration(milliseconds: 20));
          bloc.add(const VideoInteractionsRepostToggled());
        },
        wait: const Duration(milliseconds: 100),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isReposted: true,
            repostCount: 6,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'optimistic emit lands before publish settles (fire-and-forget)',
        setUp: () {
          final completer = Completer<bool>();
          when(
            () => mockRepostsRepository.toggleRepost(
              addressableId: testAddressableId,
              originalAuthorPubkey: testAuthorPubkey,
              eventId: testEventId,
            ),
          ).thenAnswer((_) => completer.future);
        },
        build: () => createBloc(addressableId: testAddressableId),
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          repostCount: 5,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsRepostToggled()),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isReposted: true,
            repostCount: 6,
          ),
        ],
        verify: (bloc) {
          expect(bloc.state.isReposted, isTrue);
          expect(bloc.state.repostCount, 6);
        },
      );
    });

    group('VideoInteractionsSubscriptionRequested', () {
      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'updates isLiked without adjusting likeCount when stream emits liked',
        build: createBloc,
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
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

    group('VideoInteractionsCommentCountUpdated', () {
      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'updates comment count',
        build: createBloc,
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          commentCount: 5,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsCommentCountUpdated(10)),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            commentCount: 10,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'updates comment count from null',
        build: createBloc,
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsCommentCountUpdated(3)),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            commentCount: 3,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'preserves other state fields when updating comment count',
        build: createBloc,
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          isLiked: true,
          likeCount: 42,
          repostCount: 7,
          commentCount: 5,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsCommentCountUpdated(8)),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLiked: true,
            likeCount: 42,
            repostCount: 7,
            commentCount: 8,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'does not call repository when updating comment count display',
        build: createBloc,
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          commentCount: 5,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsCommentCountUpdated(12)),
        verify: (_) {
          // Repository cache coherence is now owned by
          // CommentsRepository.loadComments(), not the BLoC.
          verifyNever(
            () => mockCommentsRepository.updateCachedCommentCount(any(), any()),
          );
        },
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
