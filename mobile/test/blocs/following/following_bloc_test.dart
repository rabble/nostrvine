// ABOUTME: Tests for FollowingBloc - loading following list and toggle follow
// ABOUTME: Tests both current user (reactive via repository) and other user (Nostr fetch) modes

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart' as nostr_sdk;
import 'package:openvine/blocs/following/following_bloc.dart';
import 'package:openvine/repositories/follow_repository.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockFollowRepository extends Mock implements FollowRepository {}

void main() {
  group('FollowingBloc', () {
    late _MockNostrClient mockNostrClient;
    late _MockFollowRepository mockFollowRepository;
    late StreamController<List<String>> followingStreamController;

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
      followingStreamController = StreamController<List<String>>.broadcast();

      when(
        () => mockFollowRepository.followingStream,
      ).thenAnswer((_) => followingStreamController.stream);
      when(() => mockFollowRepository.followingPubkeys).thenReturn([]);
      when(() => mockFollowRepository.isFollowing(any())).thenReturn(false);
      when(() => mockNostrClient.publicKey).thenReturn('');
    });

    tearDown(() {
      followingStreamController.close();
    });

    FollowingBloc createBloc({required String targetPubkey}) => FollowingBloc(
      followRepository: mockFollowRepository,
      nostrClient: mockNostrClient,
      targetPubkey: targetPubkey,
    );

    test('initial state for current user is success with cached data', () {
      when(() => mockNostrClient.publicKey).thenReturn(validPubkey('current'));
      when(
        () => mockFollowRepository.followingPubkeys,
      ).thenReturn([validPubkey('following1')]);

      final bloc = createBloc(targetPubkey: validPubkey('current'));
      expect(
        bloc.state,
        FollowingState(
          status: FollowingStatus.success,
          followingPubkeys: [validPubkey('following1')],
          targetPubkey: validPubkey('current'),
        ),
      );
      bloc.close();
    });

    test('initial state for other user is initial with targetPubkey', () {
      when(() => mockNostrClient.publicKey).thenReturn(validPubkey('current'));

      final bloc = createBloc(targetPubkey: validPubkey('other'));
      expect(bloc.state, FollowingState(targetPubkey: validPubkey('other')));
      bloc.close();
    });

    group('FollowingListLoadRequested', () {
      group('current user mode', () {
        blocTest<FollowingBloc, FollowingState>(
          'listens to repository stream for updates',
          setUp: () {
            when(
              () => mockNostrClient.publicKey,
            ).thenReturn(validPubkey('current'));
            when(
              () => mockFollowRepository.followingPubkeys,
            ).thenReturn([validPubkey('following1')]);
            when(() => mockFollowRepository.followingStream).thenAnswer(
              (_) => Stream.value([
                validPubkey('following1'),
                validPubkey('following2'),
              ]),
            );
          },
          build: () => createBloc(targetPubkey: validPubkey('current')),
          act: (bloc) => bloc.add(const FollowingListLoadRequested()),
          expect: () => [
            FollowingState(
              status: FollowingStatus.success,
              followingPubkeys: [
                validPubkey('following1'),
                validPubkey('following2'),
              ],
              targetPubkey: validPubkey('current'),
            ),
          ],
        );
      });

      group('other user mode', () {
        blocTest<FollowingBloc, FollowingState>(
          'emits [loading, success] with Nostr data for other user',
          setUp: () {
            when(
              () => mockNostrClient.publicKey,
            ).thenReturn(validPubkey('current'));

            final otherPubkey = validPubkey('other');
            when(() => mockNostrClient.queryEvents(any())).thenAnswer(
              (_) async => [
                nostr_sdk.Event(
                  otherPubkey,
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
          build: () => createBloc(targetPubkey: validPubkey('other')),
          act: (bloc) => bloc.add(const FollowingListLoadRequested()),
          expect: () => [
            FollowingState(
              status: FollowingStatus.loading,
              targetPubkey: validPubkey('other'),
            ),
            FollowingState(
              status: FollowingStatus.success,
              followingPubkeys: [
                validPubkey('following1'),
                validPubkey('following2'),
              ],
              targetPubkey: validPubkey('other'),
            ),
          ],
        );

        blocTest<FollowingBloc, FollowingState>(
          'emits [loading, success] with empty list when no contact list found',
          setUp: () {
            when(
              () => mockNostrClient.publicKey,
            ).thenReturn(validPubkey('current'));
            when(
              () => mockNostrClient.queryEvents(any()),
            ).thenAnswer((_) async => []);
          },
          build: () => createBloc(targetPubkey: validPubkey('other')),
          act: (bloc) => bloc.add(const FollowingListLoadRequested()),
          expect: () => [
            FollowingState(
              status: FollowingStatus.loading,
              targetPubkey: validPubkey('other'),
            ),
            FollowingState(
              status: FollowingStatus.success,
              followingPubkeys: const [],
              targetPubkey: validPubkey('other'),
            ),
          ],
        );
      });
    });

    group('FollowToggleRequested', () {
      blocTest<FollowingBloc, FollowingState>(
        'calls toggleFollow on repository',
        setUp: () {
          when(
            () => mockFollowRepository.toggleFollow(any()),
          ).thenAnswer((_) async {});
        },
        build: () => createBloc(targetPubkey: validPubkey('current')),
        act: (bloc) => bloc.add(FollowToggleRequested(validPubkey('user'))),
        verify: (_) {
          verify(
            () => mockFollowRepository.toggleFollow(validPubkey('user')),
          ).called(1);
        },
      );

      blocTest<FollowingBloc, FollowingState>(
        'handles toggleFollow error gracefully',
        setUp: () {
          when(
            () => mockFollowRepository.toggleFollow(any()),
          ).thenThrow(Exception('Network error'));
        },
        build: () => createBloc(targetPubkey: validPubkey('current')),
        act: (bloc) => bloc.add(FollowToggleRequested(validPubkey('user'))),
        // Should not throw or emit error state - just logs
        expect: () => <FollowingState>[],
      );
    });
  });

  group('FollowingState', () {
    test('supports value equality', () {
      const state1 = FollowingState(
        status: FollowingStatus.success,
        followingPubkeys: ['pubkey1'],
        targetPubkey: 'target',
      );
      const state2 = FollowingState(
        status: FollowingStatus.success,
        followingPubkeys: ['pubkey1'],
        targetPubkey: 'target',
      );

      expect(state1, equals(state2));
    });

    test('isFollowing returns true when pubkey in list', () {
      const state = FollowingState(
        status: FollowingStatus.success,
        followingPubkeys: ['pubkey1', 'pubkey2'],
      );

      expect(state.isFollowing('pubkey1'), isTrue);
      expect(state.isFollowing('pubkey2'), isTrue);
      expect(state.isFollowing('pubkey3'), isFalse);
    });

    test('copyWith creates copy with updated values', () {
      const state = FollowingState(
        status: FollowingStatus.initial,
        followingPubkeys: [],
        targetPubkey: 'target1',
      );

      final updated = state.copyWith(
        status: FollowingStatus.loading,
        followingPubkeys: ['pubkey1'],
        targetPubkey: 'target2',
      );

      expect(updated.status, FollowingStatus.loading);
      expect(updated.followingPubkeys, ['pubkey1']);
      expect(updated.targetPubkey, 'target2');
    });

    test('copyWith preserves values when not specified', () {
      const state = FollowingState(
        status: FollowingStatus.success,
        followingPubkeys: ['pubkey1'],
        targetPubkey: 'target',
      );

      final updated = state.copyWith();

      expect(updated.status, FollowingStatus.success);
      expect(updated.followingPubkeys, ['pubkey1']);
      expect(updated.targetPubkey, 'target');
    });

    test('props includes all fields', () {
      const state = FollowingState(
        status: FollowingStatus.success,
        followingPubkeys: ['pubkey1'],
        targetPubkey: 'target',
      );

      expect(state.props, [
        FollowingStatus.success,
        ['pubkey1'],
        'target',
      ]);
    });
  });
}
