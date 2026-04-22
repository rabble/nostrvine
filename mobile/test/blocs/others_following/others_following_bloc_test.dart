// ABOUTME: Tests for OthersFollowingBloc - another user's following list
// ABOUTME: Tests loading from Nostr and error handling

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart' as nostr_sdk;
import 'package:openvine/blocs/others_following/others_following_bloc.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

void main() {
  group('OthersFollowingBloc', () {
    late _MockNostrClient mockNostrClient;
    late _MockContentBlocklistRepository mockBlocklistRepository;

    // Helper to create valid hex pubkeys (64 hex characters)
    String validPubkey(String suffix) {
      final hexSuffix = suffix.codeUnits
          .map((c) => c.toRadixString(16).padLeft(2, '0'))
          .join();
      return hexSuffix.padLeft(64, '0');
    }

    setUp(() {
      mockNostrClient = _MockNostrClient();
      mockBlocklistRepository = _MockContentBlocklistRepository();

      // Default: nothing is blocked
      when(() => mockBlocklistRepository.isBlocked(any())).thenReturn(false);
      when(
        () => mockBlocklistRepository.isFollowSevered(any()),
      ).thenReturn(false);
    });

    OthersFollowingBloc createBloc() => OthersFollowingBloc(
      nostrClient: mockNostrClient,
      contentBlocklistRepository: mockBlocklistRepository,
      currentUserPubkey: validPubkey('currentUser'),
    );

    test('initial state is initial with empty list', () {
      final bloc = createBloc();
      expect(bloc.state, const OthersFollowingState());
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

      test(
        'retains existing following list while a reload is in flight',
        () async {
          final reloadCompleter = Completer<List<nostr_sdk.Event>>();
          var queryCount = 0;

          when(() => mockNostrClient.queryEvents(any())).thenAnswer((_) {
            queryCount++;
            if (queryCount == 1) {
              return Future.value([
                nostr_sdk.Event(
                  validPubkey('other'),
                  3,
                  [
                    ['p', validPubkey('following1')],
                    ['p', validPubkey('following2')],
                  ],
                  '',
                  createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                ),
              ]);
            }
            return reloadCompleter.future;
          });

          final bloc = createBloc();

          final initialLoad = expectLater(
            bloc.stream,
            emitsThrough(
              isA<OthersFollowingState>()
                  .having(
                    (state) => state.status,
                    'status',
                    OthersFollowingStatus.success,
                  )
                  .having(
                    (state) => state.followingPubkeys,
                    'followingPubkeys',
                    [
                      validPubkey('following1'),
                      validPubkey('following2'),
                    ],
                  ),
            ),
          );

          bloc.add(OthersFollowingListLoadRequested(validPubkey('other')));
          await initialLoad;

          bloc.add(OthersFollowingListLoadRequested(validPubkey('other')));
          await Future<void>.delayed(Duration.zero);

          expect(bloc.state.status, OthersFollowingStatus.loading);
          expect(bloc.state.followingPubkeys, [
            validPubkey('following1'),
            validPubkey('following2'),
          ]);

          reloadCompleter.complete(const []);
          await Future<void>.delayed(Duration.zero);
          await bloc.close();
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
      const state = OthersFollowingState(targetPubkey: 'target1');

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
