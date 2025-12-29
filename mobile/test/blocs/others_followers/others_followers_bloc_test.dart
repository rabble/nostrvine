// ABOUTME: Tests for OthersFollowersBloc - another user's followers list
// ABOUTME: Tests loading from Nostr, error handling, and follow operations

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart' as nostr_sdk;
import 'package:openvine/blocs/others_followers/others_followers_bloc.dart';
import 'package:openvine/repositories/follow_repository.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockFollowRepository extends Mock implements FollowRepository {}

void main() {
  group('OthersFollowersBloc', () {
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
    });

    OthersFollowersBloc createBloc() => OthersFollowersBloc(
      nostrClient: mockNostrClient,
      followRepository: mockFollowRepository,
    );

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
        'emits [loading, success] with followers from Nostr',
        setUp: () {
          when(() => mockNostrClient.queryEvents(any())).thenAnswer(
            (_) async => [
              nostr_sdk.Event(
                validPubkey('follower1'),
                3,
                [
                  ['p', validPubkey('target')],
                ],
                '',
                createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              ),
              nostr_sdk.Event(
                validPubkey('follower2'),
                3,
                [
                  ['p', validPubkey('target')],
                ],
                '',
                createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              ),
            ],
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
            () => mockNostrClient.queryEvents(any()),
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
        'deduplicates followers',
        setUp: () {
          final duplicatePubkey = validPubkey('follower1');
          when(() => mockNostrClient.queryEvents(any())).thenAnswer(
            (_) async => [
              nostr_sdk.Event(
                duplicatePubkey,
                3,
                [
                  ['p', validPubkey('target')],
                ],
                '',
                createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              ),
              // Duplicate event from same author
              nostr_sdk.Event(
                duplicatePubkey,
                3,
                [
                  ['p', validPubkey('target')],
                ],
                '',
                createdAt:
                    DateTime.now().millisecondsSinceEpoch ~/ 1000 - 100000,
              ),
            ],
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
            followersPubkeys: [validPubkey('follower1')],
            targetPubkey: validPubkey('target'),
          ),
        ],
      );

      blocTest<OthersFollowersBloc, OthersFollowersState>(
        'emits [loading, failure] when Nostr query fails',
        setUp: () {
          when(
            () => mockNostrClient.queryEvents(any()),
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
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => []);
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(OthersFollowersListLoadRequested(validPubkey('target'))),
        verify: (bloc) {
          expect(bloc.state.targetPubkey, validPubkey('target'));
        },
      );
    });

    group('OthersFollowersToggleFollowRequested', () {
      blocTest<OthersFollowersBloc, OthersFollowersState>(
        'calls toggleFollow on repository',
        setUp: () {
          when(
            () => mockFollowRepository.toggleFollow(any()),
          ).thenAnswer((_) async {});
        },
        build: createBloc,
        act: (bloc) => bloc.add(
          OthersFollowersToggleFollowRequested(validPubkey('follower')),
        ),
        verify: (_) {
          verify(
            () => mockFollowRepository.toggleFollow(validPubkey('follower')),
          ).called(1);
        },
      );

      blocTest<OthersFollowersBloc, OthersFollowersState>(
        'handles toggleFollow error gracefully',
        setUp: () {
          when(
            () => mockFollowRepository.toggleFollow(any()),
          ).thenThrow(Exception('Network error'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(
          OthersFollowersToggleFollowRequested(validPubkey('follower')),
        ),
        // Should not throw or emit error state - just logs
        expect: () => <OthersFollowersState>[],
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
