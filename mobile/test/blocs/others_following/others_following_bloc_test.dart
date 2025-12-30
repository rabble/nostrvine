// ABOUTME: Tests for OthersFollowingBloc - another user's following list
// ABOUTME: Tests loading from Nostr and error handling

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart' as nostr_sdk;
import 'package:openvine/blocs/others_following/others_following_bloc.dart';

class _MockNostrClient extends Mock implements NostrClient {}

void main() {
  group('OthersFollowingBloc', () {
    late _MockNostrClient mockNostrClient;

    // Helper to create valid hex pubkeys (64 hex characters)
    String validPubkey(String suffix) {
      final hexSuffix = suffix.codeUnits
          .map((c) => c.toRadixString(16).padLeft(2, '0'))
          .join();
      return hexSuffix.padLeft(64, '0');
    }

    setUp(() {
      mockNostrClient = _MockNostrClient();
    });

    OthersFollowingBloc createBloc() =>
        OthersFollowingBloc(nostrClient: mockNostrClient);

    test('initial state is initial with empty list', () {
      final bloc = createBloc();
      expect(
        bloc.state,
        const OthersFollowingState(
          status: OthersFollowingStatus.initial,
          followingPubkeys: [],
        ),
      );
      bloc.close();
    });

    group('OthersFollowingListLoadRequested', () {
      blocTest<OthersFollowingBloc, OthersFollowingState>(
        'emits [loading, success] with Nostr data',
        setUp: () {
          final targetPubkey = validPubkey('other');
          when(() => mockNostrClient.queryEvents(any())).thenAnswer(
            (_) async => [
              nostr_sdk.Event(
                targetPubkey,
                3,
                [
                  ['p', validPubkey('following1')],
                  ['p', validPubkey('following2')],
                ],
                '',
                createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              ),
            ],
          );
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(OthersFollowingListLoadRequested(validPubkey('other'))),
        expect: () => [
          OthersFollowingState(
            status: OthersFollowingStatus.loading,
            targetPubkey: validPubkey('other'),
          ),
          OthersFollowingState(
            status: OthersFollowingStatus.success,
            followingPubkeys: [
              validPubkey('following1'),
              validPubkey('following2'),
            ],
            targetPubkey: validPubkey('other'),
          ),
        ],
      );

      blocTest<OthersFollowingBloc, OthersFollowingState>(
        'emits [loading, success] with empty list when no contact list found',
        setUp: () {
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => []);
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(OthersFollowingListLoadRequested(validPubkey('other'))),
        expect: () => [
          OthersFollowingState(
            status: OthersFollowingStatus.loading,
            targetPubkey: validPubkey('other'),
          ),
          OthersFollowingState(
            status: OthersFollowingStatus.success,
            followingPubkeys: const [],
            targetPubkey: validPubkey('other'),
          ),
        ],
      );

      blocTest<OthersFollowingBloc, OthersFollowingState>(
        'deduplicates pubkeys from contact list',
        setUp: () {
          final targetPubkey = validPubkey('other');
          final duplicatePubkey = validPubkey('following1');
          when(() => mockNostrClient.queryEvents(any())).thenAnswer(
            (_) async => [
              nostr_sdk.Event(
                targetPubkey,
                3,
                [
                  ['p', duplicatePubkey],
                  ['p', duplicatePubkey], // Duplicate
                  ['p', validPubkey('following2')],
                ],
                '',
                createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              ),
            ],
          );
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(OthersFollowingListLoadRequested(validPubkey('other'))),
        expect: () => [
          OthersFollowingState(
            status: OthersFollowingStatus.loading,
            targetPubkey: validPubkey('other'),
          ),
          OthersFollowingState(
            status: OthersFollowingStatus.success,
            followingPubkeys: [
              validPubkey('following1'),
              validPubkey('following2'),
            ],
            targetPubkey: validPubkey('other'),
          ),
        ],
      );

      blocTest<OthersFollowingBloc, OthersFollowingState>(
        'emits [loading, failure] when Nostr query fails',
        setUp: () {
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenThrow(Exception('Network error'));
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(OthersFollowingListLoadRequested(validPubkey('other'))),
        expect: () => [
          OthersFollowingState(
            status: OthersFollowingStatus.loading,
            targetPubkey: validPubkey('other'),
          ),
          OthersFollowingState(
            status: OthersFollowingStatus.failure,
            targetPubkey: validPubkey('other'),
          ),
        ],
      );

      blocTest<OthersFollowingBloc, OthersFollowingState>(
        'stores targetPubkey in state for retry',
        setUp: () {
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => []);
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(OthersFollowingListLoadRequested(validPubkey('other'))),
        verify: (bloc) {
          expect(bloc.state.targetPubkey, validPubkey('other'));
        },
      );
    });
  });

  group('OthersFollowingState', () {
    test('supports value equality', () {
      const state1 = OthersFollowingState(
        status: OthersFollowingStatus.success,
        followingPubkeys: ['pubkey1'],
        targetPubkey: 'target',
      );
      const state2 = OthersFollowingState(
        status: OthersFollowingStatus.success,
        followingPubkeys: ['pubkey1'],
        targetPubkey: 'target',
      );

      expect(state1, equals(state2));
    });

    test('copyWith creates copy with updated values', () {
      const state = OthersFollowingState(
        status: OthersFollowingStatus.initial,
        followingPubkeys: [],
        targetPubkey: 'target1',
      );

      final updated = state.copyWith(
        status: OthersFollowingStatus.loading,
        followingPubkeys: ['pubkey1'],
        targetPubkey: 'target2',
      );

      expect(updated.status, OthersFollowingStatus.loading);
      expect(updated.followingPubkeys, ['pubkey1']);
      expect(updated.targetPubkey, 'target2');
    });

    test('copyWith preserves values when not specified', () {
      const state = OthersFollowingState(
        status: OthersFollowingStatus.success,
        followingPubkeys: ['pubkey1'],
        targetPubkey: 'target',
      );

      final updated = state.copyWith();

      expect(updated.status, OthersFollowingStatus.success);
      expect(updated.followingPubkeys, ['pubkey1']);
      expect(updated.targetPubkey, 'target');
    });

    test('props includes all fields', () {
      const state = OthersFollowingState(
        status: OthersFollowingStatus.success,
        followingPubkeys: ['pubkey1'],
        targetPubkey: 'target',
      );

      expect(state.props, [
        OthersFollowingStatus.success,
        ['pubkey1'],
        'target',
      ]);
    });
  });
}
