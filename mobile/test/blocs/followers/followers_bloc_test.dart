// ABOUTME: Tests for FollowersBloc - loading followers list and toggle follow
// ABOUTME: Uses bloc_test for state emission verification and mocktail for mocks

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart' as nostr_sdk;
import 'package:openvine/blocs/followers/followers_bloc.dart';
import 'package:openvine/repositories/follow_repository.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockFollowRepository extends Mock implements FollowRepository {}

void main() {
  group('FollowersBloc', () {
    late _MockNostrClient mockNostrClient;
    late _MockFollowRepository mockFollowRepository;

    // Helper to create valid hex pubkeys (64 hex characters)
    String validPubkey(String suffix) {
      final hexSuffix = suffix.codeUnits
          .map((c) => c.toRadixString(16).padLeft(2, '0'))
          .join();
      return hexSuffix.padLeft(64, '0');
    }

    setUp(() {
      mockNostrClient = _MockNostrClient();
      mockFollowRepository = _MockFollowRepository();

      // Default stub for queryEvents - returns empty list
      when(
        () => mockNostrClient.queryEvents(any()),
      ).thenAnswer((_) async => []);

      // Default stub for isFollowing
      when(() => mockFollowRepository.isFollowing(any())).thenReturn(false);
    });

    FollowersBloc createBloc() => FollowersBloc(
      followRepository: mockFollowRepository,
      nostrClient: mockNostrClient,
    );

    test('initial state is correct', () {
      final bloc = createBloc();
      expect(bloc.state, const FollowersState());
      bloc.close();
    });

    group('FollowersListLoadRequested', () {
      blocTest<FollowersBloc, FollowersState>(
        'emits [loading, success] when load completes with followers',
        setUp: () {
          final targetPubkey = validPubkey('target');
          final followerPubkey = validPubkey('follower1');

          when(() => mockNostrClient.queryEvents(any())).thenAnswer(
            (_) async => [
              nostr_sdk.Event(
                followerPubkey,
                3,
                [
                  ['p', targetPubkey],
                ],
                '',
                createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              ),
            ],
          );
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(FollowersListLoadRequested(validPubkey('target'))),
        expect: () => [
          FollowersState(
            status: FollowersStatus.loading,
            targetPubkey: validPubkey('target'),
          ),
          FollowersState(
            status: FollowersStatus.success,
            targetPubkey: validPubkey('target'),
            followersPubkeys: [validPubkey('follower1')],
          ),
        ],
      );

      blocTest<FollowersBloc, FollowersState>(
        'emits [loading, success] with empty list when no followers',
        setUp: () {
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => []);
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(FollowersListLoadRequested(validPubkey('target'))),
        expect: () => [
          FollowersState(
            status: FollowersStatus.loading,
            targetPubkey: validPubkey('target'),
          ),
          FollowersState(
            status: FollowersStatus.success,
            targetPubkey: validPubkey('target'),
            followersPubkeys: const [],
          ),
        ],
      );

      blocTest<FollowersBloc, FollowersState>(
        'deduplicates followers when same pubkey appears multiple times',
        setUp: () {
          final targetPubkey = validPubkey('target');
          final followerPubkey = validPubkey('follower1');

          when(() => mockNostrClient.queryEvents(any())).thenAnswer(
            (_) async => [
              nostr_sdk.Event(
                followerPubkey,
                3,
                [
                  ['p', targetPubkey],
                ],
                '',
                createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              ),
              nostr_sdk.Event(
                followerPubkey, // Same pubkey
                3,
                [
                  ['p', targetPubkey],
                ],
                '',
                createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              ),
            ],
          );
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(FollowersListLoadRequested(validPubkey('target'))),
        expect: () => [
          FollowersState(
            status: FollowersStatus.loading,
            targetPubkey: validPubkey('target'),
          ),
          // Only one follower (deduplicated)
          FollowersState(
            status: FollowersStatus.success,
            targetPubkey: validPubkey('target'),
            followersPubkeys: [validPubkey('follower1')],
          ),
        ],
      );

      blocTest<FollowersBloc, FollowersState>(
        'clears previous followers when loading new list',
        setUp: () {
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => []);
        },
        build: createBloc,
        seed: () => FollowersState(
          status: FollowersStatus.success,
          targetPubkey: validPubkey('old'),
          followersPubkeys: [validPubkey('old_follower')],
        ),
        act: (bloc) => bloc.add(FollowersListLoadRequested(validPubkey('new'))),
        expect: () => [
          FollowersState(
            status: FollowersStatus.loading,
            targetPubkey: validPubkey('new'),
            followersPubkeys: const [], // Cleared
          ),
          FollowersState(
            status: FollowersStatus.success,
            targetPubkey: validPubkey('new'),
            followersPubkeys: const [],
          ),
        ],
      );
    });

    group('FollowerToggleFollowRequested', () {
      blocTest<FollowersBloc, FollowersState>(
        'calls toggleFollow on repository',
        setUp: () {
          when(
            () => mockFollowRepository.toggleFollow(any()),
          ).thenAnswer((_) async {});
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(FollowerToggleFollowRequested(validPubkey('user'))),
        verify: (_) {
          verify(
            () => mockFollowRepository.toggleFollow(validPubkey('user')),
          ).called(1);
        },
      );

      blocTest<FollowersBloc, FollowersState>(
        'handles toggleFollow error gracefully',
        setUp: () {
          when(
            () => mockFollowRepository.toggleFollow(any()),
          ).thenThrow(Exception('Network error'));
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(FollowerToggleFollowRequested(validPubkey('user'))),
        // Should not throw or emit error state - just logs
        expect: () => <FollowersState>[],
      );
    });
  });

  group('FollowersState', () {
    test('supports value equality', () {
      const state1 = FollowersState(
        status: FollowersStatus.success,
        followersPubkeys: ['pubkey1'],
        targetPubkey: 'target',
      );
      const state2 = FollowersState(
        status: FollowersStatus.success,
        followersPubkeys: ['pubkey1'],
        targetPubkey: 'target',
      );

      expect(state1, equals(state2));
    });

    test('copyWith creates copy with updated values', () {
      const state = FollowersState(
        status: FollowersStatus.initial,
        followersPubkeys: [],
        targetPubkey: 'target1',
      );

      final updated = state.copyWith(
        status: FollowersStatus.loading,
        followersPubkeys: ['pubkey1'],
        targetPubkey: 'target2',
      );

      expect(updated.status, FollowersStatus.loading);
      expect(updated.followersPubkeys, ['pubkey1']);
      expect(updated.targetPubkey, 'target2');
    });

    test('copyWith preserves values when not specified', () {
      const state = FollowersState(
        status: FollowersStatus.success,
        followersPubkeys: ['pubkey1'],
        targetPubkey: 'target',
      );

      final updated = state.copyWith();

      expect(updated.status, FollowersStatus.success);
      expect(updated.followersPubkeys, ['pubkey1']);
      expect(updated.targetPubkey, 'target');
    });

    test('props includes all fields', () {
      const state = FollowersState(
        status: FollowersStatus.success,
        followersPubkeys: ['pubkey1'],
        targetPubkey: 'target',
      );

      expect(state.props, [
        FollowersStatus.success,
        ['pubkey1'],
        'target',
      ]);
    });
  });
}
