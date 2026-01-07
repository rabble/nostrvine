// ABOUTME: Tests for LikesBloc - user's likes management
// ABOUTME: Tests syncing, toggling likes, and state management

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/likes/likes_bloc.dart';

class _MockLikesRepository extends Mock implements LikesRepository {}

void main() {
  group('LikesBloc', () {
    late _MockLikesRepository mockLikesRepository;

    setUp(() {
      mockLikesRepository = _MockLikesRepository();
    });

    LikesBloc createBloc() => LikesBloc(likesRepository: mockLikesRepository);

    test('initial state is initial with empty collections', () {
      final bloc = createBloc();
      expect(bloc.state.status, LikesStatus.initial);
      expect(bloc.state.likedEventIds, isEmpty);
      expect(bloc.state.operationsInProgress, isEmpty);
      expect(bloc.state.error, isNull);
      bloc.close();
    });

    group('LikesSyncRequested', () {
      blocTest<LikesBloc, LikesState>(
        'emits [syncing, success] with likes from repository',
        setUp: () {
          when(() => mockLikesRepository.syncUserReactions()).thenAnswer(
            (_) async => const LikesSyncResult(
              orderedEventIds: ['event2', 'event1'],
              eventIdToReactionId: {
                'event1': 'reaction1',
                'event2': 'reaction2',
              },
            ),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const LikesSyncRequested()),
        expect: () => [
          const LikesState(status: LikesStatus.syncing),
          const LikesState(
            status: LikesStatus.success,
            likedEventIds: ['event2', 'event1'],
          ),
        ],
      );

      blocTest<LikesBloc, LikesState>(
        'emits [syncing, success] with empty list when no likes',
        setUp: () {
          when(
            () => mockLikesRepository.syncUserReactions(),
          ).thenAnswer((_) async => const LikesSyncResult.empty());
        },
        build: createBloc,
        act: (bloc) => bloc.add(const LikesSyncRequested()),
        expect: () => [
          const LikesState(status: LikesStatus.syncing),
          const LikesState(status: LikesStatus.success, likedEventIds: []),
        ],
      );

      blocTest<LikesBloc, LikesState>(
        'emits [syncing, failure] when sync throws SyncFailedException',
        setUp: () {
          when(
            () => mockLikesRepository.syncUserReactions(),
          ).thenThrow(const SyncFailedException('Network error'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const LikesSyncRequested()),
        expect: () => [
          const LikesState(status: LikesStatus.syncing),
          const LikesState(
            status: LikesStatus.failure,
            error: LikesError.syncFailed,
          ),
        ],
      );

      blocTest<LikesBloc, LikesState>(
        'does not re-sync while already syncing',
        setUp: () {
          when(
            () => mockLikesRepository.syncUserReactions(),
          ).thenAnswer((_) async => const LikesSyncResult.empty());
        },
        build: createBloc,
        seed: () => const LikesState(status: LikesStatus.syncing),
        act: (bloc) => bloc.add(const LikesSyncRequested()),
        expect: () => <LikesState>[],
        verify: (_) {
          verifyNever(() => mockLikesRepository.syncUserReactions());
        },
      );
    });

    group('LikesToggleRequested', () {
      blocTest<LikesBloc, LikesState>(
        'likes an event when not already liked',
        setUp: () {
          when(
            () => mockLikesRepository.toggleLike(
              eventId: 'event1',
              authorPubkey: 'author1',
            ),
          ).thenAnswer((_) async => true);
        },
        build: createBloc,
        seed: () => const LikesState(status: LikesStatus.success),
        act: (bloc) => bloc.add(
          const LikesToggleRequested(
            eventId: 'event1',
            authorPubkey: 'author1',
          ),
        ),
        expect: () => [
          const LikesState(
            status: LikesStatus.success,
            operationsInProgress: {'event1'},
          ),
          const LikesState(
            status: LikesStatus.success,
            likedEventIds: ['event1'],
            likeCounts: {'event1': 1},
          ),
        ],
      );

      blocTest<LikesBloc, LikesState>(
        'prepends new like to existing list',
        setUp: () {
          when(
            () => mockLikesRepository.toggleLike(
              eventId: 'event2',
              authorPubkey: 'author2',
            ),
          ).thenAnswer((_) async => true);
        },
        build: createBloc,
        seed: () => const LikesState(
          status: LikesStatus.success,
          likedEventIds: ['event1'],
        ),
        act: (bloc) => bloc.add(
          const LikesToggleRequested(
            eventId: 'event2',
            authorPubkey: 'author2',
          ),
        ),
        expect: () => [
          const LikesState(
            status: LikesStatus.success,
            likedEventIds: ['event1'],
            operationsInProgress: {'event2'},
          ),
          const LikesState(
            status: LikesStatus.success,
            likedEventIds: ['event2', 'event1'],
            likeCounts: {'event2': 1},
          ),
        ],
      );

      blocTest<LikesBloc, LikesState>(
        'unlikes an event when already liked',
        setUp: () {
          when(
            () => mockLikesRepository.toggleLike(
              eventId: 'event1',
              authorPubkey: 'author1',
            ),
          ).thenAnswer((_) async => false);
        },
        build: createBloc,
        seed: () => const LikesState(
          status: LikesStatus.success,
          likedEventIds: ['event1'],
        ),
        act: (bloc) => bloc.add(
          const LikesToggleRequested(
            eventId: 'event1',
            authorPubkey: 'author1',
          ),
        ),
        expect: () => [
          const LikesState(
            status: LikesStatus.success,
            likedEventIds: ['event1'],
            operationsInProgress: {'event1'},
          ),
          const LikesState(
            status: LikesStatus.success,
            likeCounts: {'event1': 0},
          ),
        ],
      );

      blocTest<LikesBloc, LikesState>(
        'does not toggle while operation in progress for same event',
        build: createBloc,
        seed: () => const LikesState(
          status: LikesStatus.success,
          operationsInProgress: {'event1'},
        ),
        act: (bloc) => bloc.add(
          const LikesToggleRequested(
            eventId: 'event1',
            authorPubkey: 'author1',
          ),
        ),
        expect: () => <LikesState>[],
      );

      blocTest<LikesBloc, LikesState>(
        'emits error when toggle fails with LikeFailedException',
        setUp: () {
          when(
            () => mockLikesRepository.toggleLike(
              eventId: 'event1',
              authorPubkey: 'author1',
            ),
          ).thenThrow(const LikeFailedException('Network error'));
        },
        build: createBloc,
        seed: () => const LikesState(status: LikesStatus.success),
        act: (bloc) => bloc.add(
          const LikesToggleRequested(
            eventId: 'event1',
            authorPubkey: 'author1',
          ),
        ),
        expect: () => [
          const LikesState(
            status: LikesStatus.success,
            operationsInProgress: {'event1'},
          ),
          const LikesState(
            status: LikesStatus.success,
            error: LikesError.likeFailed,
          ),
        ],
      );

      blocTest<LikesBloc, LikesState>(
        'emits error when toggle fails with UnlikeFailedException',
        setUp: () {
          when(
            () => mockLikesRepository.toggleLike(
              eventId: 'event1',
              authorPubkey: 'author1',
            ),
          ).thenThrow(const UnlikeFailedException('Network error'));
        },
        build: createBloc,
        seed: () => const LikesState(
          status: LikesStatus.success,
          likedEventIds: ['event1'],
        ),
        act: (bloc) => bloc.add(
          const LikesToggleRequested(
            eventId: 'event1',
            authorPubkey: 'author1',
          ),
        ),
        expect: () => [
          const LikesState(
            status: LikesStatus.success,
            likedEventIds: ['event1'],
            operationsInProgress: {'event1'},
          ),
          const LikesState(
            status: LikesStatus.success,
            likedEventIds: ['event1'],
            error: LikesError.unlikeFailed,
          ),
        ],
      );

      blocTest<LikesBloc, LikesState>(
        'clears operation when AlreadyLikedException thrown',
        setUp: () {
          when(
            () => mockLikesRepository.toggleLike(
              eventId: 'event1',
              authorPubkey: 'author1',
            ),
          ).thenThrow(const AlreadyLikedException('event1'));
        },
        build: createBloc,
        seed: () => const LikesState(status: LikesStatus.success),
        act: (bloc) => bloc.add(
          const LikesToggleRequested(
            eventId: 'event1',
            authorPubkey: 'author1',
          ),
        ),
        expect: () => [
          const LikesState(
            status: LikesStatus.success,
            operationsInProgress: {'event1'},
          ),
          const LikesState(status: LikesStatus.success),
        ],
      );

      blocTest<LikesBloc, LikesState>(
        'clears operation when NotLikedException thrown',
        setUp: () {
          when(
            () => mockLikesRepository.toggleLike(
              eventId: 'event1',
              authorPubkey: 'author1',
            ),
          ).thenThrow(const NotLikedException('event1'));
        },
        build: createBloc,
        seed: () => const LikesState(status: LikesStatus.success),
        act: (bloc) => bloc.add(
          const LikesToggleRequested(
            eventId: 'event1',
            authorPubkey: 'author1',
          ),
        ),
        expect: () => [
          const LikesState(
            status: LikesStatus.success,
            operationsInProgress: {'event1'},
          ),
          const LikesState(status: LikesStatus.success),
        ],
      );
    });

    group('LikesErrorCleared', () {
      blocTest<LikesBloc, LikesState>(
        'clears error from state',
        build: createBloc,
        seed: () => const LikesState(
          status: LikesStatus.success,
          error: LikesError.likeFailed,
        ),
        act: (bloc) => bloc.add(const LikesErrorCleared()),
        expect: () => [const LikesState(status: LikesStatus.success)],
      );
    });
  });

  group('LikesState', () {
    test('supports value equality', () {
      const state1 = LikesState(
        status: LikesStatus.success,
        likedEventIds: ['event1'],
      );
      const state2 = LikesState(
        status: LikesStatus.success,
        likedEventIds: ['event1'],
      );

      expect(state1, equals(state2));
    });

    test('isLiked returns correct value', () {
      const state = LikesState(likedEventIds: ['event1', 'event2']);

      expect(state.isLiked('event1'), isTrue);
      expect(state.isLiked('event3'), isFalse);
    });

    test('isOperationInProgress returns correct value', () {
      const state = LikesState(operationsInProgress: {'event1'});

      expect(state.isOperationInProgress('event1'), isTrue);
      expect(state.isOperationInProgress('event2'), isFalse);
    });

    test('isInitialized returns true when status is success', () {
      const initialState = LikesState();
      const successState = LikesState(status: LikesStatus.success);

      expect(initialState.isInitialized, isFalse);
      expect(successState.isInitialized, isTrue);
    });

    test('totalLikedCount returns number of liked events', () {
      const emptyState = LikesState();
      const stateWithLikes = LikesState(likedEventIds: ['e1', 'e2', 'e3']);

      expect(emptyState.totalLikedCount, 0);
      expect(stateWithLikes.totalLikedCount, 3);
    });

    test('copyWith creates copy with updated values', () {
      const state = LikesState();

      final updated = state.copyWith(
        status: LikesStatus.success,
        likedEventIds: ['event1'],
      );

      expect(updated.status, LikesStatus.success);
      expect(updated.likedEventIds, ['event1']);
    });

    test('copyWith preserves values when not specified', () {
      const state = LikesState(
        status: LikesStatus.success,
        likedEventIds: ['event1'],
      );

      final updated = state.copyWith();

      expect(updated.status, LikesStatus.success);
      expect(updated.likedEventIds, ['event1']);
    });

    test('copyWith clearError clears error', () {
      const state = LikesState(error: LikesError.likeFailed);

      final updated = state.copyWith(clearError: true);

      expect(updated.error, isNull);
    });
  });
}
