// ABOUTME: Tests for ConversationListBloc - DM conversation list management.
// ABOUTME: Tests loading conversations via split streams (accepted + potential
// ABOUTME: requests), error handling, marking conversations as read, message
// ABOUTME: request classification, and event transformer behavior.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/conversation_list/conversation_list_bloc.dart';

class _MockDmRepository extends Mock implements DmRepository {}

class _MockFollowRepository extends Mock implements FollowRepository {}

// Full 64-character hex Nostr IDs for test data.
const _testConversationId1 =
    'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
const _testConversationId2 =
    'b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3';
const _testPubkey1 =
    'c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4';
const _testPubkey2 =
    'd4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5';
const _testPubkey3 =
    'e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6';

DmConversation _createConversation({
  required String id,
  bool isRead = true,
  bool isGroup = false,
  bool currentUserHasSent = false,
  List<String>? participantPubkeys,
}) {
  return DmConversation(
    id: id,
    participantPubkeys:
        participantPubkeys ?? const [_testPubkey1, _testPubkey2],
    isGroup: isGroup,
    createdAt: 1700000000,
    lastMessageContent: 'Hello',
    lastMessageTimestamp: 1700000100,
    lastMessageSenderPubkey: _testPubkey1,
    isRead: isRead,
    currentUserHasSent: currentUserHasSent,
  );
}

/// Stubs both split streams on the mock repository.
///
/// [accepted] goes to `watchAcceptedConversations` (currentUserHasSent=true).
/// [potentialRequests] goes to `watchPotentialRequests` (currentUserHasSent=false).
void _stubStreams(
  _MockDmRepository repo, {
  List<DmConversation> accepted = const [],
  List<DmConversation> potentialRequests = const [],
}) {
  when(
    () => repo.watchAcceptedConversations(limit: any(named: 'limit')),
  ).thenAnswer((_) => Stream.value(accepted));
  when(
    () => repo.watchPotentialRequests(),
  ).thenAnswer((_) => Stream.value(potentialRequests));
}

void main() {
  group(ConversationListBloc, () {
    late _MockDmRepository mockDmRepository;
    late _MockFollowRepository mockFollowRepository;

    setUp(() {
      mockDmRepository = _MockDmRepository();
      mockFollowRepository = _MockFollowRepository();

      // Default: all pubkeys are followed (existing tests expect no splitting).
      when(() => mockFollowRepository.isFollowing(any())).thenReturn(true);
      when(
        () => mockFollowRepository.followingStream,
      ).thenAnswer((_) => const Stream<List<String>>.empty());
      when(() => mockDmRepository.userPubkey).thenReturn(_testPubkey1);

      // Stub subscription lifecycle methods (#2766).
      when(() => mockDmRepository.startListening()).thenAnswer((_) async {});
      when(() => mockDmRepository.stopListening()).thenAnswer((_) async {});
    });

    ConversationListBloc createBloc() => ConversationListBloc(
      dmRepository: mockDmRepository,
      followRepository: mockFollowRepository,
    );

    test('initial state is $ConversationListState with initial status', () {
      final bloc = createBloc();

      expect(bloc.state, equals(const ConversationListState()));
      expect(bloc.state.status, equals(ConversationListStatus.initial));
      expect(bloc.state.conversations, equals(const <DmConversation>[]));

      bloc.close();
    });

    group('ConversationListStarted', () {
      blocTest<ConversationListBloc, ConversationListState>(
        'emits [loading, loaded] when stream emits conversations',
        setUp: () {
          final conversations = [
            _createConversation(id: _testConversationId1),
            _createConversation(id: _testConversationId2),
          ];
          // Default currentUserHasSent=false → potential requests.
          // Default isFollowing=true → classified as followed.
          _stubStreams(mockDmRepository, potentialRequests: conversations);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ConversationListStarted()),
        expect: () => [
          const ConversationListState(status: ConversationListStatus.loading),
          ConversationListState(
            status: ConversationListStatus.loaded,
            conversations: [
              _createConversation(id: _testConversationId1),
              _createConversation(id: _testConversationId2),
            ],
            potentialRequests: [
              _createConversation(id: _testConversationId1),
              _createConversation(id: _testConversationId2),
            ],
            hasMore: false,
          ),
        ],
      );

      blocTest<ConversationListBloc, ConversationListState>(
        'emits [loading, loaded] with empty list '
        'when stream emits no conversations',
        setUp: () {
          _stubStreams(mockDmRepository);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ConversationListStarted()),
        expect: () => [
          const ConversationListState(status: ConversationListStatus.loading),
          const ConversationListState(
            status: ConversationListStatus.loaded,
            hasMore: false,
          ),
        ],
      );

      blocTest<ConversationListBloc, ConversationListState>(
        'emits [loading, error] when accepted stream emits an error',
        setUp: () {
          when(
            () => mockDmRepository.watchAcceptedConversations(
              limit: any(named: 'limit'),
            ),
          ).thenAnswer((_) => Stream.error(Exception('db failure')));
          when(
            () => mockDmRepository.watchPotentialRequests(),
          ).thenAnswer((_) => Stream.value(const []));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ConversationListStarted()),
        errors: () => [isA<Exception>()],
        expect: () => [
          const ConversationListState(status: ConversationListStatus.loading),
          const ConversationListState(status: ConversationListStatus.error),
        ],
      );

      blocTest<ConversationListBloc, ConversationListState>(
        'loaded state contains the correct conversations',
        setUp: () {
          final conversation = _createConversation(
            id: _testConversationId1,
            isRead: false,
          );
          _stubStreams(mockDmRepository, potentialRequests: [conversation]);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ConversationListStarted()),
        verify: (bloc) {
          expect(bloc.state.conversations, hasLength(1));
          expect(
            bloc.state.conversations.first.id,
            equals(_testConversationId1),
          );
          expect(bloc.state.conversations.first.isRead, isFalse);
          expect(
            bloc.state.conversations.first.participantPubkeys,
            equals([_testPubkey1, _testPubkey2]),
          );
        },
      );

      blocTest<ConversationListBloc, ConversationListState>(
        'emits updated state when streams emit multiple values',
        setUp: () {
          final acceptedController = StreamController<List<DmConversation>>();
          final requestsController = StreamController<List<DmConversation>>();

          when(
            () => mockDmRepository.watchAcceptedConversations(
              limit: any(named: 'limit'),
            ),
          ).thenAnswer((_) => acceptedController.stream);
          when(
            () => mockDmRepository.watchPotentialRequests(),
          ).thenAnswer((_) => requestsController.stream);

          // Emit initial empty requests, then accepted values.
          Future<void>.delayed(const Duration(milliseconds: 10)).then((_) {
            requestsController.add(const []);
            acceptedController.add([
              _createConversation(
                id: _testConversationId1,
                currentUserHasSent: true,
              ),
            ]);
          });

          Future<void>.delayed(const Duration(milliseconds: 50)).then((_) {
            acceptedController.add([
              _createConversation(
                id: _testConversationId1,
                currentUserHasSent: true,
              ),
              _createConversation(
                id: _testConversationId2,
                currentUserHasSent: true,
              ),
            ]);
            acceptedController.close();
            requestsController.close();
          });
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ConversationListStarted()),
        wait: const Duration(milliseconds: 200),
        expect: () => [
          const ConversationListState(status: ConversationListStatus.loading),
          ConversationListState(
            status: ConversationListStatus.loaded,
            conversations: [
              _createConversation(
                id: _testConversationId1,
                currentUserHasSent: true,
              ),
            ],
            hasMore: false,
          ),
          ConversationListState(
            status: ConversationListStatus.loaded,
            conversations: [
              _createConversation(
                id: _testConversationId1,
                currentUserHasSent: true,
              ),
              _createConversation(
                id: _testConversationId2,
                currentUserHasSent: true,
              ),
            ],
            hasMore: false,
          ),
        ],
      );
    });

    group('ConversationListMarkRead', () {
      blocTest<ConversationListBloc, ConversationListState>(
        'calls repository.markConversationAsRead with correct ID',
        setUp: () {
          when(
            () => mockDmRepository.markConversationAsRead(_testConversationId1),
          ).thenAnswer((_) async {});
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(const ConversationListMarkRead(_testConversationId1)),
        verify: (_) {
          verify(
            () => mockDmRepository.markConversationAsRead(_testConversationId1),
          ).called(1);
        },
      );

      blocTest<ConversationListBloc, ConversationListState>(
        'does not emit new states',
        setUp: () {
          when(
            () => mockDmRepository.markConversationAsRead(_testConversationId1),
          ).thenAnswer((_) async {});
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(const ConversationListMarkRead(_testConversationId1)),
        expect: () => const <ConversationListState>[],
      );
    });

    group('ConversationListNavigateToUser', () {
      blocTest<ConversationListBloc, ConversationListState>(
        'emits state with navigationTarget '
        'containing computed conversation ID',
        setUp: () {
          when(() => mockDmRepository.userPubkey).thenReturn(_testPubkey1);
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(const ConversationListNavigateToUser(_testPubkey2)),
        expect: () => [
          isA<ConversationListState>()
              .having((s) => s.navigationTarget, 'navigationTarget', isNotNull)
              .having(
                (s) => s.navigationTarget!.participantPubkeys,
                'participantPubkeys',
                equals([_testPubkey2]),
              )
              .having(
                (s) => s.navigationTarget!.conversationId,
                'conversationId',
                equals(
                  DmRepository.computeConversationId([
                    _testPubkey1,
                    _testPubkey2,
                  ]),
                ),
              ),
        ],
      );

      blocTest<ConversationListBloc, ConversationListState>(
        'does not emit when userPubkey is empty',
        setUp: () {
          when(() => mockDmRepository.userPubkey).thenReturn('');
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(const ConversationListNavigateToUser(_testPubkey2)),
        expect: () => const <ConversationListState>[],
      );
    });

    group('ConversationListNavigationConsumed', () {
      blocTest<ConversationListBloc, ConversationListState>(
        'clears the navigation target',
        setUp: () {
          when(() => mockDmRepository.userPubkey).thenReturn(_testPubkey1);
        },
        seed: () => ConversationListState(
          navigationTarget: ConversationNavigationTarget(
            conversationId: DmRepository.computeConversationId([
              _testPubkey1,
              _testPubkey2,
            ]),
            participantPubkeys: const [_testPubkey2],
          ),
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const ConversationListNavigationConsumed()),
        expect: () => [
          isA<ConversationListState>().having(
            (s) => s.navigationTarget,
            'navigationTarget',
            isNull,
          ),
        ],
      );
    });

    group('event transformers', () {
      group('droppable() on $ConversationListMarkRead', () {
        blocTest<ConversationListBloc, ConversationListState>(
          'drops additional mark-read events while one is processing',
          setUp: () {
            final completer = Completer<void>();
            var callCount = 0;
            when(
              () => mockDmRepository.markConversationAsRead(any()),
            ).thenAnswer((_) {
              callCount++;
              if (callCount == 1) {
                // First call is slow
                return completer.future;
              }
              // Subsequent calls would complete instantly, but should be
              // dropped by the droppable() transformer.
              return Future.value();
            });

            // Complete the first call after some time
            Future<void>.delayed(const Duration(milliseconds: 50)).then((_) {
              completer.complete();
            });
          },
          build: createBloc,
          act: (bloc) {
            // Fire three mark-read events rapidly; the second and third
            // should be dropped while the first is still processing.
            bloc
              ..add(const ConversationListMarkRead(_testConversationId1))
              ..add(const ConversationListMarkRead(_testConversationId1))
              ..add(const ConversationListMarkRead(_testConversationId1));
          },
          wait: const Duration(milliseconds: 150),
          expect: () => const <ConversationListState>[],
          verify: (_) {
            // Only the first call should have been processed; the rest
            // are dropped by droppable().
            verify(
              () =>
                  mockDmRepository.markConversationAsRead(_testConversationId1),
            ).called(1);
          },
        );

        blocTest<ConversationListBloc, ConversationListState>(
          'processes a new event after the previous one completes',
          setUp: () {
            when(
              () => mockDmRepository.markConversationAsRead(any()),
            ).thenAnswer((_) async {});
          },
          build: createBloc,
          act: (bloc) async {
            bloc.add(const ConversationListMarkRead(_testConversationId1));
            // Wait for the first to complete before adding the second
            await Future<void>.delayed(const Duration(milliseconds: 30));
            bloc.add(const ConversationListMarkRead(_testConversationId2));
          },
          wait: const Duration(milliseconds: 100),
          verify: (_) {
            verify(
              () =>
                  mockDmRepository.markConversationAsRead(_testConversationId1),
            ).called(1);
            verify(
              () =>
                  mockDmRepository.markConversationAsRead(_testConversationId2),
            ).called(1);
          },
        );
      });

      group('restartable() on $ConversationListStarted', () {
        blocTest<ConversationListBloc, ConversationListState>(
          'cancels the old subscription and starts a new one '
          'when $ConversationListStarted is re-added',
          setUp: () {
            final acceptedCtrl1 = StreamController<List<DmConversation>>();
            final acceptedCtrl2 = StreamController<List<DmConversation>>();
            final requestsCtrl1 = StreamController<List<DmConversation>>();
            final requestsCtrl2 = StreamController<List<DmConversation>>();
            var acceptedCallCount = 0;
            var requestsCallCount = 0;

            when(
              () => mockDmRepository.watchAcceptedConversations(
                limit: any(named: 'limit'),
              ),
            ).thenAnswer((_) {
              acceptedCallCount++;
              if (acceptedCallCount == 1) return acceptedCtrl1.stream;
              return acceptedCtrl2.stream;
            });

            when(() => mockDmRepository.watchPotentialRequests()).thenAnswer((
              _,
            ) {
              requestsCallCount++;
              if (requestsCallCount == 1) return requestsCtrl1.stream;
              return requestsCtrl2.stream;
            });

            // First streams emit quickly
            Future<void>.delayed(const Duration(milliseconds: 10)).then((_) {
              requestsCtrl1.add(const []);
              acceptedCtrl1.add([
                _createConversation(
                  id: _testConversationId1,
                  currentUserHasSent: true,
                ),
              ]);
            });

            // After restart, emit on old stream (should be ignored)
            Future<void>.delayed(const Duration(milliseconds: 60)).then((_) {
              acceptedCtrl1.add([
                _createConversation(
                  id: _testConversationId1,
                  currentUserHasSent: true,
                ),
                _createConversation(
                  id: _testConversationId2,
                  currentUserHasSent: true,
                ),
              ]);
              acceptedCtrl1.close();
              requestsCtrl1.close();
            });

            // New stream emits its data
            Future<void>.delayed(const Duration(milliseconds: 70)).then((_) {
              requestsCtrl2.add(const []);
              acceptedCtrl2.add([
                _createConversation(
                  id: _testConversationId2,
                  currentUserHasSent: true,
                ),
              ]);
              acceptedCtrl2.close();
              requestsCtrl2.close();
            });
          },
          build: createBloc,
          act: (bloc) async {
            bloc.add(const ConversationListStarted());
            // Wait for first emission, then restart
            await Future<void>.delayed(const Duration(milliseconds: 30));
            bloc.add(const ConversationListStarted());
          },
          wait: const Duration(milliseconds: 200),
          expect: () => [
            // First subscription starts (initial → loading)
            const ConversationListState(status: ConversationListStatus.loading),
            // First streams emit
            ConversationListState(
              status: ConversationListStatus.loaded,
              conversations: [
                _createConversation(
                  id: _testConversationId1,
                  currentUserHasSent: true,
                ),
              ],
              hasMore: false,
            ),
            // Second ConversationListStarted: no loading emission
            // because status is already loaded (not initial).
            // Second streams emit (old streams' late emission is
            // ignored because restartable() cancelled it)
            ConversationListState(
              status: ConversationListStatus.loaded,
              conversations: [
                _createConversation(
                  id: _testConversationId2,
                  currentUserHasSent: true,
                ),
              ],
              hasMore: false,
            ),
          ],
          verify: (_) {
            verify(
              () => mockDmRepository.watchAcceptedConversations(
                limit: any(named: 'limit'),
              ),
            ).called(2);
          },
        );
      });
    });

    group('ConversationListLoadMore', () {
      blocTest<ConversationListBloc, ConversationListState>(
        'increments currentLimit and re-triggers started',
        setUp: () {
          final conversations = List.generate(
            ConversationListState.pageSize,
            (i) => _createConversation(
              id: 'a${i.toRadixString(16).padLeft(63, '0')}',
              currentUserHasSent: true,
            ),
          );
          _stubStreams(mockDmRepository, accepted: conversations);
        },
        seed: () => ConversationListState(
          status: ConversationListStatus.loaded,
          conversations: List.generate(
            ConversationListState.pageSize,
            (i) => _createConversation(
              id: 'a${i.toRadixString(16).padLeft(63, '0')}',
              currentUserHasSent: true,
            ),
          ),
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const ConversationListLoadMore()),
        wait: const Duration(milliseconds: 100),
        verify: (bloc) {
          expect(
            bloc.state.currentLimit,
            equals(ConversationListState.pageSize * 2),
          );
        },
      );

      blocTest<ConversationListBloc, ConversationListState>(
        'does not emit when hasMore is false',
        seed: () => const ConversationListState(
          status: ConversationListStatus.loaded,
          hasMore: false,
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const ConversationListLoadMore()),
        expect: () => const <ConversationListState>[],
      );

      blocTest<ConversationListBloc, ConversationListState>(
        'does not emit when status is not loaded',
        build: createBloc,
        act: (bloc) => bloc.add(const ConversationListLoadMore()),
        expect: () => const <ConversationListState>[],
      );
    });

    group('message request splitting', () {
      blocTest<ConversationListBloc, ConversationListState>(
        'classifies unfollowed contacts as requests',
        setUp: () {
          // _testPubkey2 is NOT followed.
          when(
            () => mockFollowRepository.isFollowing(_testPubkey1),
          ).thenReturn(true);
          when(
            () => mockFollowRepository.isFollowing(_testPubkey2),
          ).thenReturn(false);
          when(() => mockDmRepository.userPubkey).thenReturn(_testPubkey1);

          // currentUserHasSent=false → come from potentialRequests stream.
          final conversations = [
            _createConversation(id: _testConversationId1),
            _createConversation(id: _testConversationId2),
          ];
          _stubStreams(mockDmRepository, potentialRequests: conversations);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ConversationListStarted()),
        verify: (bloc) {
          // Both conversations have participants [_testPubkey1, _testPubkey2].
          // The "other" pubkey from user _testPubkey1's perspective is
          // _testPubkey2, which is NOT followed. So both are requests.
          expect(bloc.state.conversations, isEmpty);
          expect(bloc.state.requestConversations, hasLength(2));
        },
      );

      blocTest<ConversationListBloc, ConversationListState>(
        'conversations from followed users stay in normal list',
        setUp: () {
          // All participants are followed.
          when(() => mockFollowRepository.isFollowing(any())).thenReturn(true);
          when(() => mockDmRepository.userPubkey).thenReturn(_testPubkey1);

          final conversations = [_createConversation(id: _testConversationId1)];
          _stubStreams(mockDmRepository, potentialRequests: conversations);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ConversationListStarted()),
        verify: (bloc) {
          expect(bloc.state.conversations, hasLength(1));
          expect(bloc.state.requestConversations, isEmpty);
        },
      );

      blocTest<ConversationListBloc, ConversationListState>(
        'accepted conversations always go to conversations list '
        'regardless of follow state',
        setUp: () {
          // Nobody is followed.
          when(() => mockFollowRepository.isFollowing(any())).thenReturn(false);
          when(() => mockDmRepository.userPubkey).thenReturn(_testPubkey1);

          // currentUserHasSent=true → accepted stream.
          final conversations = [
            _createConversation(
              id: _testConversationId1,
              currentUserHasSent: true,
            ),
          ];
          _stubStreams(mockDmRepository, accepted: conversations);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ConversationListStarted()),
        verify: (bloc) {
          expect(bloc.state.conversations, hasLength(1));
          expect(bloc.state.requestConversations, isEmpty);
        },
      );

      test('requestUnreadCount counts unread requests', () {
        final state = ConversationListState(
          status: ConversationListStatus.loaded,
          requestConversations: [
            _createConversation(id: _testConversationId1, isRead: false),
            _createConversation(id: _testConversationId2),
          ],
        );

        expect(state.requestUnreadCount, equals(1));
      });

      group('following changes', () {
        blocTest<ConversationListBloc, ConversationListState>(
          're-splits conversations when follow list changes',
          setUp: () {
            final followingController = StreamController<List<String>>();

            // Initially _testPubkey2 is NOT followed.
            when(
              () => mockFollowRepository.isFollowing(_testPubkey2),
            ).thenReturn(false);
            when(
              () => mockFollowRepository.followingStream,
            ).thenAnswer((_) => followingController.stream);
            when(() => mockDmRepository.userPubkey).thenReturn(_testPubkey1);

            final conversations = [
              _createConversation(id: _testConversationId1),
            ];
            _stubStreams(mockDmRepository, potentialRequests: conversations);

            // After a short delay, update follow state and emit on stream.
            Future<void>.delayed(const Duration(milliseconds: 50)).then((_) {
              when(
                () => mockFollowRepository.isFollowing(_testPubkey2),
              ).thenReturn(true);
              followingController.add([_testPubkey2]);
            });
          },
          build: createBloc,
          act: (bloc) => bloc.add(const ConversationListStarted()),
          wait: const Duration(milliseconds: 200),
          verify: (bloc) {
            // After following change, the conversation should move
            // from requestConversations to conversations.
            expect(bloc.state.conversations, hasLength(1));
            expect(bloc.state.requestConversations, isEmpty);
          },
        );
      });

      group('group conversation classification', () {
        blocTest<ConversationListBloc, ConversationListState>(
          'classifies group conversation as request '
          'when user has not sent regardless of follow state',
          setUp: () {
            // _testPubkey2 is followed, _testPubkey3 is not.
            when(
              () => mockFollowRepository.isFollowing(_testPubkey2),
            ).thenReturn(true);
            when(
              () => mockFollowRepository.isFollowing(_testPubkey3),
            ).thenReturn(false);
            when(() => mockDmRepository.userPubkey).thenReturn(_testPubkey1);

            final conversations = [
              _createConversation(
                id: _testConversationId1,
                isGroup: true,
                participantPubkeys: [_testPubkey1, _testPubkey2, _testPubkey3],
              ),
            ];
            _stubStreams(mockDmRepository, potentialRequests: conversations);
          },
          build: createBloc,
          act: (bloc) => bloc.add(const ConversationListStarted()),
          verify: (bloc) {
            expect(bloc.state.conversations, isEmpty);
            expect(bloc.state.requestConversations, hasLength(1));
          },
        );

        blocTest<ConversationListBloc, ConversationListState>(
          'classifies group conversation as normal '
          'when user has sent',
          setUp: () {
            when(
              () => mockFollowRepository.isFollowing(_testPubkey2),
            ).thenReturn(true);
            when(
              () => mockFollowRepository.isFollowing(_testPubkey3),
            ).thenReturn(false);
            when(() => mockDmRepository.userPubkey).thenReturn(_testPubkey1);

            final conversations = [
              _createConversation(
                id: _testConversationId1,
                isGroup: true,
                currentUserHasSent: true,
                participantPubkeys: [_testPubkey1, _testPubkey2, _testPubkey3],
              ),
            ];
            // currentUserHasSent=true → accepted stream.
            _stubStreams(mockDmRepository, accepted: conversations);
          },
          build: createBloc,
          act: (bloc) => bloc.add(const ConversationListStarted()),
          verify: (bloc) {
            expect(bloc.state.conversations, hasLength(1));
            expect(bloc.state.requestConversations, isEmpty);
          },
        );
      });

      group('pagination does not truncate requests', () {
        blocTest<ConversationListBloc, ConversationListState>(
          'requests appear even when accepted list fills page',
          setUp: () {
            when(
              () => mockFollowRepository.isFollowing(any()),
            ).thenReturn(false);
            when(() => mockDmRepository.userPubkey).thenReturn(_testPubkey1);

            // Page-sized accepted list (simulates full page).
            final accepted = List.generate(
              ConversationListState.pageSize,
              (i) => _createConversation(
                id: 'a${i.toRadixString(16).padLeft(63, '0')}',
                currentUserHasSent: true,
              ),
            );
            // Requests loaded separately, not truncated.
            final requests = [
              _createConversation(id: _testConversationId1),
              _createConversation(id: _testConversationId2),
            ];
            _stubStreams(
              mockDmRepository,
              accepted: accepted,
              potentialRequests: requests,
            );
          },
          build: createBloc,
          act: (bloc) => bloc.add(const ConversationListStarted()),
          verify: (bloc) {
            expect(
              bloc.state.conversations,
              hasLength(ConversationListState.pageSize),
            );
            expect(bloc.state.requestConversations, hasLength(2));
            expect(bloc.state.hasMore, isTrue);
          },
        );
      });
    });
  });

  group('$ConversationListState', () {
    test('supports value equality', () {
      final conversations = [_createConversation(id: _testConversationId1)];

      final state1 = ConversationListState(
        status: ConversationListStatus.loaded,
        conversations: conversations,
      );
      final state2 = ConversationListState(
        status: ConversationListStatus.loaded,
        conversations: conversations,
      );

      expect(state1, equals(state2));
    });

    test('states with different status are not equal', () {
      const state1 = ConversationListState(
        status: ConversationListStatus.loading,
      );
      const state2 = ConversationListState(
        status: ConversationListStatus.loaded,
      );

      expect(state1, isNot(equals(state2)));
    });

    test('states with different conversations are not equal', () {
      final state1 = ConversationListState(
        status: ConversationListStatus.loaded,
        conversations: [_createConversation(id: _testConversationId1)],
      );
      final state2 = ConversationListState(
        status: ConversationListStatus.loaded,
        conversations: [_createConversation(id: _testConversationId2)],
      );

      expect(state1, isNot(equals(state2)));
    });

    test('copyWith creates copy with updated values', () {
      const state = ConversationListState();
      final conversations = [_createConversation(id: _testConversationId1)];

      final updated = state.copyWith(
        status: ConversationListStatus.loaded,
        conversations: conversations,
      );

      expect(updated.status, equals(ConversationListStatus.loaded));
      expect(updated.conversations, equals(conversations));
    });

    test('copyWith preserves values when not specified', () {
      final conversations = [_createConversation(id: _testConversationId1)];
      final state = ConversationListState(
        status: ConversationListStatus.loaded,
        conversations: conversations,
      );

      final updated = state.copyWith();

      expect(updated.status, equals(ConversationListStatus.loaded));
      expect(updated.conversations, equals(conversations));
    });

    test('props includes all fields', () {
      final conversations = [_createConversation(id: _testConversationId1)];
      final state = ConversationListState(
        status: ConversationListStatus.loaded,
        conversations: conversations,
      );

      expect(state.props, [
        ConversationListStatus.loaded,
        conversations,
        const <DmConversation>[],
        const <DmConversation>[],
        true,
        false,
        ConversationListState.pageSize,
        null,
      ]);
    });
  });

  group('ConversationListEvent', () {
    test('$ConversationListStarted supports value equality', () {
      const event1 = ConversationListStarted();
      const event2 = ConversationListStarted();

      expect(event1, equals(event2));
    });

    test('$ConversationListStarted props is empty', () {
      const event = ConversationListStarted();

      expect(event.props, equals(const <Object?>[]));
    });

    test('$ConversationListMarkRead supports value equality', () {
      const event1 = ConversationListMarkRead(_testConversationId1);
      const event2 = ConversationListMarkRead(_testConversationId1);

      expect(event1, equals(event2));
    });

    test('$ConversationListMarkRead with different IDs are not equal', () {
      const event1 = ConversationListMarkRead(_testConversationId1);
      const event2 = ConversationListMarkRead(_testConversationId2);

      expect(event1, isNot(equals(event2)));
    });

    test('$ConversationListMarkRead props contains conversationId', () {
      const event = ConversationListMarkRead(_testConversationId1);

      expect(event.props, equals([_testConversationId1]));
    });

    test('$ConversationListNavigateToUser supports value equality', () {
      const event1 = ConversationListNavigateToUser(_testPubkey1);
      const event2 = ConversationListNavigateToUser(_testPubkey1);

      expect(event1, equals(event2));
    });

    test('$ConversationListNavigateToUser with different pubkeys '
        'are not equal', () {
      const event1 = ConversationListNavigateToUser(_testPubkey1);
      const event2 = ConversationListNavigateToUser(_testPubkey2);

      expect(event1, isNot(equals(event2)));
    });

    test('$ConversationListNavigateToUser props contains '
        'participantPubkey', () {
      const event = ConversationListNavigateToUser(_testPubkey1);

      expect(event.props, equals([_testPubkey1]));
    });

    test('$ConversationListNavigationConsumed supports value equality', () {
      const event1 = ConversationListNavigationConsumed();
      const event2 = ConversationListNavigationConsumed();

      expect(event1, equals(event2));
    });

    test('$ConversationListNavigationConsumed props is empty', () {
      const event = ConversationListNavigationConsumed();

      expect(event.props, equals(const <Object?>[]));
    });
  });

  group(ConversationNavigationTarget, () {
    test('supports value equality', () {
      const target1 = ConversationNavigationTarget(
        conversationId: _testConversationId1,
        participantPubkeys: [_testPubkey2],
      );
      const target2 = ConversationNavigationTarget(
        conversationId: _testConversationId1,
        participantPubkeys: [_testPubkey2],
      );

      expect(target1, equals(target2));
    });

    test('targets with different conversation IDs are not equal', () {
      const target1 = ConversationNavigationTarget(
        conversationId: _testConversationId1,
        participantPubkeys: [_testPubkey2],
      );
      const target2 = ConversationNavigationTarget(
        conversationId: _testConversationId2,
        participantPubkeys: [_testPubkey2],
      );

      expect(target1, isNot(equals(target2)));
    });
  });

  // -------------------------------------------------------------------
  // Subscription lifecycle (#2931)
  // -------------------------------------------------------------------

  group('subscription lifecycle (#2931)', () {
    late _MockDmRepository mockDmRepository;
    late _MockFollowRepository mockFollowRepository;

    setUp(() {
      mockDmRepository = _MockDmRepository();
      mockFollowRepository = _MockFollowRepository();

      when(() => mockFollowRepository.isFollowing(any())).thenReturn(true);
      when(
        () => mockFollowRepository.followingStream,
      ).thenAnswer((_) => const Stream<List<String>>.empty());
      when(() => mockDmRepository.userPubkey).thenReturn(_testPubkey1);
      when(() => mockDmRepository.startListening()).thenAnswer((_) async {});
      when(() => mockDmRepository.stopListening()).thenAnswer((_) async {});
    });

    blocTest<ConversationListBloc, ConversationListState>(
      'does not call startListening — auth-scoped via dmRepositoryProvider',
      build: () {
        _stubStreams(mockDmRepository);
        return ConversationListBloc(
          dmRepository: mockDmRepository,
          followRepository: mockFollowRepository,
        );
      },
      act: (bloc) => bloc.add(const ConversationListStarted()),
      verify: (_) {
        // Regression guard for #2931: the gift-wrap subscription lives
        // for the whole authenticated session via `dmRepositoryProvider`.
        // The BLoC must not start it on its own — that would break the
        // session-wide ingestion contract by creating overlapping
        // subscription bookkeeping.
        verifyNever(() => mockDmRepository.startListening());
      },
    );

    test('does not call stopListening on close', () async {
      _stubStreams(mockDmRepository);
      final bloc = ConversationListBloc(
        dmRepository: mockDmRepository,
        followRepository: mockFollowRepository,
      );

      await bloc.close();

      // Regression guard for #2931: closing the BLoC must NOT stop the
      // gift-wrap subscription. Doing so would silently break DM ingestion
      // for users who navigated away from the inbox tab.
      verifyNever(() => mockDmRepository.stopListening());
    });
  });
}
