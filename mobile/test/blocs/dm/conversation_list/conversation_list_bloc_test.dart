// ABOUTME: Tests for ConversationListBloc - DM conversation list management.
// ABOUTME: Tests loading conversations via stream, error handling,
// ABOUTME: marking conversations as read, and event transformer behavior.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/conversation_list/conversation_list_bloc.dart';
import 'package:openvine/repositories/dm_repository.dart';

class _MockDmRepository extends Mock implements DmRepository {}

// Full 64-character hex Nostr IDs for test data.
const _testConversationId1 =
    'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
const _testConversationId2 =
    'b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3';
const _testPubkey1 =
    'c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4';
const _testPubkey2 =
    'd4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5';

DmConversation _createConversation({
  required String id,
  bool isRead = true,
}) {
  return DmConversation(
    id: id,
    participantPubkeys: const [_testPubkey1, _testPubkey2],
    isGroup: false,
    createdAt: 1700000000,
    lastMessageContent: 'Hello',
    lastMessageTimestamp: 1700000100,
    lastMessageSenderPubkey: _testPubkey1,
    isRead: isRead,
  );
}

void main() {
  group(ConversationListBloc, () {
    late _MockDmRepository mockDmRepository;

    setUp(() {
      mockDmRepository = _MockDmRepository();
    });

    ConversationListBloc createBloc() =>
        ConversationListBloc(dmRepository: mockDmRepository);

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
          when(
            () => mockDmRepository.watchConversations(),
          ).thenAnswer((_) => Stream.value(conversations));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ConversationListStarted()),
        expect: () => [
          const ConversationListState(
            status: ConversationListStatus.loading,
          ),
          ConversationListState(
            status: ConversationListStatus.loaded,
            conversations: [
              _createConversation(id: _testConversationId1),
              _createConversation(id: _testConversationId2),
            ],
          ),
        ],
      );

      blocTest<ConversationListBloc, ConversationListState>(
        'emits [loading, loaded] with empty list '
        'when stream emits no conversations',
        setUp: () {
          when(
            () => mockDmRepository.watchConversations(),
          ).thenAnswer((_) => Stream.value(const []));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ConversationListStarted()),
        expect: () => [
          const ConversationListState(
            status: ConversationListStatus.loading,
          ),
          const ConversationListState(
            status: ConversationListStatus.loaded,
          ),
        ],
      );

      blocTest<ConversationListBloc, ConversationListState>(
        'emits [loading, error] when stream emits an error',
        setUp: () {
          when(
            () => mockDmRepository.watchConversations(),
          ).thenAnswer((_) => Stream.error(Exception('db failure')));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ConversationListStarted()),
        errors: () => [isA<Exception>()],
        expect: () => [
          const ConversationListState(
            status: ConversationListStatus.loading,
          ),
          const ConversationListState(
            status: ConversationListStatus.error,
          ),
        ],
      );

      blocTest<ConversationListBloc, ConversationListState>(
        'loaded state contains the correct conversations',
        setUp: () {
          final conversation = _createConversation(
            id: _testConversationId1,
            isRead: false,
          );
          when(
            () => mockDmRepository.watchConversations(),
          ).thenAnswer((_) => Stream.value([conversation]));
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
        'emits updated state when stream emits multiple values',
        setUp: () {
          final first = [_createConversation(id: _testConversationId1)];
          final second = [
            _createConversation(id: _testConversationId1),
            _createConversation(id: _testConversationId2),
          ];
          when(
            () => mockDmRepository.watchConversations(),
          ).thenAnswer((_) => Stream.fromIterable([first, second]));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ConversationListStarted()),
        expect: () => [
          const ConversationListState(
            status: ConversationListStatus.loading,
          ),
          ConversationListState(
            status: ConversationListStatus.loaded,
            conversations: [
              _createConversation(id: _testConversationId1),
            ],
          ),
          ConversationListState(
            status: ConversationListStatus.loaded,
            conversations: [
              _createConversation(id: _testConversationId1),
              _createConversation(id: _testConversationId2),
            ],
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
        act: (bloc) => bloc.add(
          const ConversationListMarkRead(_testConversationId1),
        ),
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
        act: (bloc) => bloc.add(
          const ConversationListMarkRead(_testConversationId1),
        ),
        expect: () => const <ConversationListState>[],
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
            Future<void>.delayed(
              const Duration(milliseconds: 50),
            ).then((_) {
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
              () => mockDmRepository.markConversationAsRead(
                _testConversationId1,
              ),
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
            bloc.add(
              const ConversationListMarkRead(_testConversationId1),
            );
            // Wait for the first to complete before adding the second
            await Future<void>.delayed(
              const Duration(milliseconds: 30),
            );
            bloc.add(
              const ConversationListMarkRead(_testConversationId2),
            );
          },
          wait: const Duration(milliseconds: 100),
          verify: (_) {
            verify(
              () => mockDmRepository.markConversationAsRead(
                _testConversationId1,
              ),
            ).called(1);
            verify(
              () => mockDmRepository.markConversationAsRead(
                _testConversationId2,
              ),
            ).called(1);
          },
        );
      });

      group('restartable() on $ConversationListStarted', () {
        blocTest<ConversationListBloc, ConversationListState>(
          'cancels the old subscription and starts a new one '
          'when $ConversationListStarted is re-added',
          setUp: () {
            final controller1 = StreamController<List<DmConversation>>();
            final controller2 = StreamController<List<DmConversation>>();
            var watchCallCount = 0;

            when(
              () => mockDmRepository.watchConversations(),
            ).thenAnswer((_) {
              watchCallCount++;
              if (watchCallCount == 1) return controller1.stream;
              return controller2.stream;
            });

            // First stream emits quickly
            Future<void>.delayed(
              const Duration(milliseconds: 10),
            ).then((_) {
              controller1.add([
                _createConversation(id: _testConversationId1),
              ]);
            });

            // After restart, emit on old stream (should be ignored)
            Future<void>.delayed(
              const Duration(milliseconds: 60),
            ).then((_) {
              controller1.add([
                _createConversation(id: _testConversationId1),
                _createConversation(id: _testConversationId2),
              ]);
              controller1.close();
            });

            // New stream emits its data
            Future<void>.delayed(
              const Duration(milliseconds: 70),
            ).then((_) {
              controller2.add([
                _createConversation(id: _testConversationId2),
              ]);
              controller2.close();
            });
          },
          build: createBloc,
          act: (bloc) async {
            bloc.add(const ConversationListStarted());
            // Wait for first emission, then restart
            await Future<void>.delayed(
              const Duration(milliseconds: 30),
            );
            bloc.add(const ConversationListStarted());
          },
          wait: const Duration(milliseconds: 200),
          expect: () => [
            // First subscription starts
            const ConversationListState(
              status: ConversationListStatus.loading,
            ),
            // First stream emits
            ConversationListState(
              status: ConversationListStatus.loaded,
              conversations: [
                _createConversation(id: _testConversationId1),
              ],
            ),
            // Second ConversationListStarted restarts: emits loading.
            // copyWith preserves conversations from previous state.
            ConversationListState(
              status: ConversationListStatus.loading,
              conversations: [
                _createConversation(id: _testConversationId1),
              ],
            ),
            // Second stream emits (old stream's late emission is
            // ignored because restartable() cancelled it)
            ConversationListState(
              status: ConversationListStatus.loaded,
              conversations: [
                _createConversation(id: _testConversationId2),
              ],
            ),
          ],
          verify: (_) {
            verify(
              () => mockDmRepository.watchConversations(),
            ).called(2);
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

      expect(state.props, [ConversationListStatus.loaded, conversations]);
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
  });
}
