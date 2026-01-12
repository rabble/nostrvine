// ABOUTME: Tests for OthersFollowersBloc - another user's followers list
// ABOUTME: Tests loading from repository, error handling, and follow operations

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/others_followers/others_followers_bloc.dart';
import 'package:openvine/repositories/follow_repository.dart';

class _MockFollowRepository extends Mock implements FollowRepository {}

void main() {
  group('OthersFollowersBloc', () {
    late _MockFollowRepository mockFollowRepository;

    // Helper to create valid hex pubkeys (64 hex characters)
    String validPubkey(String suffix) {
      final hexSuffix = suffix.codeUnits
          .map((c) => c.toRadixString(16).padLeft(2, '0'))
          .join();
      return hexSuffix.padLeft(64, '0');
    }

    setUp(() {
      mockFollowRepository = _MockFollowRepository();
    });

    OthersFollowersBloc createBloc() =>
        OthersFollowersBloc(followRepository: mockFollowRepository);

    test('initial state is initial with empty list', () {
      final bloc = createBloc();
      expect(
        bloc.state,
        const OthersFollowersState(
          status: OthersFollowersStatus.initial,
          followersPubkeys: [],
        ),
      );
      bloc.close();
    });

    group('OthersFollowersListLoadRequested', () {
      blocTest<OthersFollowersBloc, OthersFollowersState>(
        'emits [loading, success] with followers from repository',
        setUp: () {
          when(() => mockFollowRepository.getFollowers(any())).thenAnswer(
            (_) async => [validPubkey('follower1'), validPubkey('follower2')],
          );
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(OthersFollowersListLoadRequested(validPubkey('target'))),
        expect: () => [
          OthersFollowersState(
            status: OthersFollowersStatus.loading,
            targetPubkey: validPubkey('target'),
          ),
          OthersFollowersState(
            status: OthersFollowersStatus.success,
            followersPubkeys: [
              validPubkey('follower1'),
              validPubkey('follower2'),
            ],
            targetPubkey: validPubkey('target'),
          ),
        ],
      );

      blocTest<OthersFollowersBloc, OthersFollowersState>(
        'emits [loading, success] with empty list when no followers',
        setUp: () {
          when(
            () => mockFollowRepository.getFollowers(any()),
          ).thenAnswer((_) async => []);
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(OthersFollowersListLoadRequested(validPubkey('target'))),
        expect: () => [
          OthersFollowersState(
            status: OthersFollowersStatus.loading,
            targetPubkey: validPubkey('target'),
          ),
          OthersFollowersState(
            status: OthersFollowersStatus.success,
            followersPubkeys: const [],
            targetPubkey: validPubkey('target'),
          ),
        ],
      );

      blocTest<OthersFollowersBloc, OthersFollowersState>(
        'emits [loading, failure] when repository throws',
        setUp: () {
          when(
            () => mockFollowRepository.getFollowers(any()),
          ).thenThrow(Exception('Network error'));
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(OthersFollowersListLoadRequested(validPubkey('target'))),
        expect: () => [
          OthersFollowersState(
            status: OthersFollowersStatus.loading,
            targetPubkey: validPubkey('target'),
          ),
          OthersFollowersState(
            status: OthersFollowersStatus.failure,
            targetPubkey: validPubkey('target'),
          ),
        ],
      );

      blocTest<OthersFollowersBloc, OthersFollowersState>(
        'stores targetPubkey in state for retry',
        setUp: () {
          when(
            () => mockFollowRepository.getFollowers(any()),
          ).thenAnswer((_) async => []);
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(OthersFollowersListLoadRequested(validPubkey('target'))),
        verify: (bloc) {
          expect(bloc.state.targetPubkey, validPubkey('target'));
        },
      );

      blocTest<OthersFollowersBloc, OthersFollowersState>(
        'calls repository with correct pubkey',
        setUp: () {
          when(
            () => mockFollowRepository.getFollowers(any()),
          ).thenAnswer((_) async => []);
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(OthersFollowersListLoadRequested(validPubkey('target'))),
        verify: (_) {
          verify(
            () => mockFollowRepository.getFollowers(validPubkey('target')),
          ).called(1);
        },
      );
    });

    group('OthersFollowersIncrementRequested', () {
      blocTest<OthersFollowersBloc, OthersFollowersState>(
        'adds follower pubkey to list when not already present',
        build: createBloc,
        seed: () => OthersFollowersState(
          status: OthersFollowersStatus.success,
          followersPubkeys: [validPubkey('existing')],
          targetPubkey: validPubkey('target'),
        ),
        act: (bloc) =>
            bloc.add(OthersFollowersIncrementRequested(validPubkey('new'))),
        expect: () => [
          OthersFollowersState(
            status: OthersFollowersStatus.success,
            followersPubkeys: [validPubkey('existing'), validPubkey('new')],
            targetPubkey: validPubkey('target'),
          ),
        ],
      );

      blocTest<OthersFollowersBloc, OthersFollowersState>(
        'does not add duplicate follower pubkey',
        build: createBloc,
        seed: () => OthersFollowersState(
          status: OthersFollowersStatus.success,
          followersPubkeys: [validPubkey('existing')],
          targetPubkey: validPubkey('target'),
        ),
        act: (bloc) => bloc.add(
          OthersFollowersIncrementRequested(validPubkey('existing')),
        ),
        expect: () => <OthersFollowersState>[],
      );

      blocTest<OthersFollowersBloc, OthersFollowersState>(
        'works with empty initial list',
        build: createBloc,
        seed: () => OthersFollowersState(
          status: OthersFollowersStatus.success,
          targetPubkey: validPubkey('target'),
        ),
        act: (bloc) =>
            bloc.add(OthersFollowersIncrementRequested(validPubkey('first'))),
        expect: () => [
          OthersFollowersState(
            status: OthersFollowersStatus.success,
            followersPubkeys: [validPubkey('first')],
            targetPubkey: validPubkey('target'),
          ),
        ],
      );
    });

    group('OthersFollowersDecrementRequested', () {
      blocTest<OthersFollowersBloc, OthersFollowersState>(
        'removes follower pubkey from list when present',
        build: createBloc,
        seed: () => OthersFollowersState(
          status: OthersFollowersStatus.success,
          followersPubkeys: [
            validPubkey('follower1'),
            validPubkey('follower2'),
          ],
          targetPubkey: validPubkey('target'),
        ),
        act: (bloc) => bloc.add(
          OthersFollowersDecrementRequested(validPubkey('follower1')),
        ),
        expect: () => [
          OthersFollowersState(
            status: OthersFollowersStatus.success,
            followersPubkeys: [validPubkey('follower2')],
            targetPubkey: validPubkey('target'),
          ),
        ],
      );

      blocTest<OthersFollowersBloc, OthersFollowersState>(
        'does nothing when pubkey not in list',
        build: createBloc,
        seed: () => OthersFollowersState(
          status: OthersFollowersStatus.success,
          followersPubkeys: [validPubkey('existing')],
          targetPubkey: validPubkey('target'),
        ),
        act: (bloc) => bloc.add(
          OthersFollowersDecrementRequested(validPubkey('notexist')),
        ),
        expect: () => <OthersFollowersState>[],
      );

      blocTest<OthersFollowersBloc, OthersFollowersState>(
        'removes last follower leaving empty list',
        build: createBloc,
        seed: () => OthersFollowersState(
          status: OthersFollowersStatus.success,
          followersPubkeys: [validPubkey('only')],
          targetPubkey: validPubkey('target'),
        ),
        act: (bloc) =>
            bloc.add(OthersFollowersDecrementRequested(validPubkey('only'))),
        expect: () => [
          OthersFollowersState(
            status: OthersFollowersStatus.success,
            targetPubkey: validPubkey('target'),
          ),
        ],
      );
    });
  });

  group('OthersFollowersState', () {
    test('supports value equality', () {
      const state1 = OthersFollowersState(
        status: OthersFollowersStatus.success,
        followersPubkeys: ['pubkey1'],
        targetPubkey: 'target',
      );
      const state2 = OthersFollowersState(
        status: OthersFollowersStatus.success,
        followersPubkeys: ['pubkey1'],
        targetPubkey: 'target',
      );

      expect(state1, equals(state2));
    });

    test('copyWith creates copy with updated values', () {
      const state = OthersFollowersState(
        status: OthersFollowersStatus.initial,
        followersPubkeys: [],
        targetPubkey: 'target1',
      );

      final updated = state.copyWith(
        status: OthersFollowersStatus.loading,
        followersPubkeys: ['pubkey1'],
        targetPubkey: 'target2',
      );

      expect(updated.status, OthersFollowersStatus.loading);
      expect(updated.followersPubkeys, ['pubkey1']);
      expect(updated.targetPubkey, 'target2');
    });

    test('copyWith preserves values when not specified', () {
      const state = OthersFollowersState(
        status: OthersFollowersStatus.success,
        followersPubkeys: ['pubkey1'],
        targetPubkey: 'target',
      );

      final updated = state.copyWith();

      expect(updated.status, OthersFollowersStatus.success);
      expect(updated.followersPubkeys, ['pubkey1']);
      expect(updated.targetPubkey, 'target');
    });

    test('props includes all fields', () {
      const state = OthersFollowersState(
        status: OthersFollowersStatus.success,
        followersPubkeys: ['pubkey1'],
        targetPubkey: 'target',
      );

      expect(state.props, [
        OthersFollowersStatus.success,
        ['pubkey1'],
        'target',
      ]);
    });
  });
}
