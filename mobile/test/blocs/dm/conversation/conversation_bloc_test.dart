// ABOUTME: Tests for ConversationBloc - loading messages, sending 1:1 and
// ABOUTME: group messages, error handling, event transformer behavior,
// ABOUTME: and state/event equality.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/conversation/conversation_bloc.dart';
import 'package:openvine/repositories/dm_repository.dart';

class _MockDmRepository extends Mock implements DmRepository {}

void main() {
  // Full 64-char hex IDs per project rules
  const conversationId =
      'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
  const senderPubkey =
      '1111111111111111111111111111111111111111111111111111111111111111';
  const recipientPubkey =
      '2222222222222222222222222222222222222222222222222222222222222222';
  const recipientPubkey2 =
      '3333333333333333333333333333333333333333333333333333333333333333';
  const messageId =
      '4444444444444444444444444444444444444444444444444444444444444444';
  const giftWrapId =
      '5555555555555555555555555555555555555555555555555555555555555555';
  const sentEventId =
      '6666666666666666666666666666666666666666666666666666666666666666';

  const testMessage = DmMessage(
    id: messageId,
    conversationId: conversationId,
    senderPubkey: senderPubkey,
    content: 'Hello there',
    createdAt: 1700000000,
    giftWrapId: giftWrapId,
  );

  group(ConversationBloc, () {
    late _MockDmRepository mockDmRepository;

    setUp(() {
      mockDmRepository = _MockDmRepository();
    });

    ConversationBloc buildBloc() => ConversationBloc(
      dmRepository: mockDmRepository,
      conversationId: conversationId,
    );

    test('initial state is correct', () {
      when(
        () => mockDmRepository.markConversationAsRead(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockDmRepository.watchMessages(any()),
      ).thenAnswer((_) => const Stream.empty());

      final bloc = buildBloc();

      expect(bloc.state, equals(const ConversationState()));
      expect(bloc.state.status, equals(ConversationStatus.initial));
      expect(bloc.state.messages, isEmpty);
      expect(bloc.state.sendStatus, equals(SendStatus.idle));
    });

    group('ConversationStarted', () {
      blocTest<ConversationBloc, ConversationState>(
        'emits [loading, loaded] when messages stream emits successfully',
        setUp: () {
          when(
            () => mockDmRepository.markConversationAsRead(conversationId),
          ).thenAnswer((_) async {});
          when(
            () => mockDmRepository.watchMessages(conversationId),
          ).thenAnswer((_) => Stream.value([testMessage]));
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const ConversationStarted()),
        expect: () => [
          const ConversationState(status: ConversationStatus.loading),
          const ConversationState(
            status: ConversationStatus.loaded,
            messages: [testMessage],
          ),
        ],
        verify: (_) {
          // Called once on initial open + once per stream emission
          verify(
            () => mockDmRepository.markConversationAsRead(conversationId),
          ).called(2);
          verify(
            () => mockDmRepository.watchMessages(conversationId),
          ).called(1);
        },
      );

      blocTest<ConversationBloc, ConversationState>(
        'calls markConversationAsRead with the correct conversation ID',
        setUp: () {
          when(
            () => mockDmRepository.markConversationAsRead(conversationId),
          ).thenAnswer((_) async {});
          when(
            () => mockDmRepository.watchMessages(conversationId),
          ).thenAnswer((_) => const Stream.empty());
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const ConversationStarted()),
        verify: (_) {
          verify(
            () => mockDmRepository.markConversationAsRead(conversationId),
          ).called(1);
        },
      );

      blocTest<ConversationBloc, ConversationState>(
        'emits [loading, error] when messages stream errors',
        setUp: () {
          when(
            () => mockDmRepository.markConversationAsRead(conversationId),
          ).thenAnswer((_) async {});
          when(
            () => mockDmRepository.watchMessages(conversationId),
          ).thenAnswer((_) => Stream.error(Exception('stream failed')));
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const ConversationStarted()),
        expect: () => [
          const ConversationState(status: ConversationStatus.loading),
          const ConversationState(status: ConversationStatus.error),
        ],
        errors: () => [isA<Exception>()],
      );

      blocTest<ConversationBloc, ConversationState>(
        'emits updated messages when stream emits multiple times',
        setUp: () {
          final controller = StreamController<List<DmMessage>>();
          when(
            () => mockDmRepository.markConversationAsRead(conversationId),
          ).thenAnswer((_) async {});
          when(
            () => mockDmRepository.watchMessages(conversationId),
          ).thenAnswer((_) => controller.stream);

          // Schedule emissions after bloc subscribes
          Future<void>.delayed(Duration.zero).then((_) {
            controller.add([testMessage]);
            const secondMessage = DmMessage(
              id: '7777777777777777777777777777777777777777777777777777777777777777',
              conversationId: conversationId,
              senderPubkey: recipientPubkey,
              content: 'Reply message',
              createdAt: 1700000100,
              giftWrapId:
                  '8888888888888888888888888888888888888888888888888888888888888888',
            );
            controller.add([testMessage, secondMessage]);
            controller.close();
          });
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const ConversationStarted()),
        expect: () => [
          const ConversationState(status: ConversationStatus.loading),
          const ConversationState(
            status: ConversationStatus.loaded,
            messages: [testMessage],
          ),
          isA<ConversationState>()
              .having(
                (s) => s.status,
                'status',
                equals(ConversationStatus.loaded),
              )
              .having(
                (s) => s.messages.length,
                'messages.length',
                equals(2),
              ),
        ],
      );
    });

    group('ConversationMessageSent', () {
      group('1:1 message', () {
        blocTest<ConversationBloc, ConversationState>(
          'emits [sending, sent] on successful sendMessage',
          setUp: () {
            when(
              () => mockDmRepository.sendMessage(
                recipientPubkey: recipientPubkey,
                content: 'Hello',
              ),
            ).thenAnswer(
              (_) async => NIP17SendResult.success(
                messageEventId: sentEventId,
                recipientPubkey: recipientPubkey,
              ),
            );
          },
          build: buildBloc,
          act: (bloc) => bloc.add(
            const ConversationMessageSent(
              recipientPubkeys: [recipientPubkey],
              content: 'Hello',
            ),
          ),
          expect: () => [
            const ConversationState(sendStatus: SendStatus.sending),
            const ConversationState(sendStatus: SendStatus.sent),
          ],
        );

        blocTest<ConversationBloc, ConversationState>(
          'emits [sending, failed] on failed sendMessage',
          setUp: () {
            when(
              () => mockDmRepository.sendMessage(
                recipientPubkey: recipientPubkey,
                content: 'Hello',
              ),
            ).thenAnswer(
              (_) async => NIP17SendResult.failure('Failed to publish message'),
            );
          },
          build: buildBloc,
          act: (bloc) => bloc.add(
            const ConversationMessageSent(
              recipientPubkeys: [recipientPubkey],
              content: 'Hello',
            ),
          ),
          expect: () => [
            const ConversationState(sendStatus: SendStatus.sending),
            const ConversationState(sendStatus: SendStatus.failed),
          ],
          errors: () => [isA<Exception>()],
        );
      });

      group('group message', () {
        blocTest<ConversationBloc, ConversationState>(
          'emits [sending, sent] when at least one sendGroupMessage succeeds',
          setUp: () {
            when(
              () => mockDmRepository.sendGroupMessage(
                recipientPubkeys: [recipientPubkey, recipientPubkey2],
                content: 'Group hello',
              ),
            ).thenAnswer(
              (_) async => [
                NIP17SendResult.success(
                  messageEventId: sentEventId,
                  recipientPubkey: recipientPubkey,
                ),
                NIP17SendResult.failure('Failed for second recipient'),
              ],
            );
          },
          build: buildBloc,
          act: (bloc) => bloc.add(
            const ConversationMessageSent(
              recipientPubkeys: [recipientPubkey, recipientPubkey2],
              content: 'Group hello',
            ),
          ),
          expect: () => [
            const ConversationState(sendStatus: SendStatus.sending),
            const ConversationState(sendStatus: SendStatus.sent),
          ],
        );

        blocTest<ConversationBloc, ConversationState>(
          'emits [sending, failed] when all sendGroupMessage fail',
          setUp: () {
            when(
              () => mockDmRepository.sendGroupMessage(
                recipientPubkeys: [recipientPubkey, recipientPubkey2],
                content: 'Group hello',
              ),
            ).thenAnswer(
              (_) async => [
                NIP17SendResult.failure('Relay timeout'),
                NIP17SendResult.failure('Connection refused'),
              ],
            );
          },
          build: buildBloc,
          act: (bloc) => bloc.add(
            const ConversationMessageSent(
              recipientPubkeys: [recipientPubkey, recipientPubkey2],
              content: 'Group hello',
            ),
          ),
          expect: () => [
            const ConversationState(sendStatus: SendStatus.sending),
            const ConversationState(sendStatus: SendStatus.failed),
          ],
          errors: () => [isA<Exception>()],
        );
      });

      group('exception handling', () {
        blocTest<ConversationBloc, ConversationState>(
          'emits [sending, failed] when sendMessage throws an exception',
          setUp: () {
            when(
              () => mockDmRepository.sendMessage(
                recipientPubkey: recipientPubkey,
                content: 'Hello',
              ),
            ).thenThrow(Exception('Network error'));
          },
          build: buildBloc,
          act: (bloc) => bloc.add(
            const ConversationMessageSent(
              recipientPubkeys: [recipientPubkey],
              content: 'Hello',
            ),
          ),
          expect: () => [
            const ConversationState(sendStatus: SendStatus.sending),
            const ConversationState(sendStatus: SendStatus.failed),
          ],
          errors: () => [isA<Exception>()],
        );

        blocTest<ConversationBloc, ConversationState>(
          'emits [sending, failed] when sendGroupMessage throws an exception',
          setUp: () {
            when(
              () => mockDmRepository.sendGroupMessage(
                recipientPubkeys: [recipientPubkey, recipientPubkey2],
                content: 'Group hello',
              ),
            ).thenThrow(Exception('Network error'));
          },
          build: buildBloc,
          act: (bloc) => bloc.add(
            const ConversationMessageSent(
              recipientPubkeys: [recipientPubkey, recipientPubkey2],
              content: 'Group hello',
            ),
          ),
          expect: () => [
            const ConversationState(sendStatus: SendStatus.sending),
            const ConversationState(sendStatus: SendStatus.failed),
          ],
          errors: () => [isA<Exception>()],
        );
      });
    });

    group('event transformers', () {
      group('sequential() on $ConversationMessageSent', () {
        blocTest<ConversationBloc, ConversationState>(
          'processes two rapid sends in order '
          '(second waits for first to complete)',
          setUp: () {
            // First send completes after a delay, second completes instantly.
            // With sequential(), the second handler waits for the first to
            // finish, so we observe: sending1 -> sent1 -> sending2 -> sent2.
            var callCount = 0;
            when(
              () => mockDmRepository.sendMessage(
                recipientPubkey: recipientPubkey,
                content: any(named: 'content'),
              ),
            ).thenAnswer((_) async {
              callCount++;
              if (callCount == 1) {
                // Simulate slow first send
                await Future<void>.delayed(
                  const Duration(milliseconds: 50),
                );
              }
              return NIP17SendResult.success(
                messageEventId: sentEventId,
                recipientPubkey: recipientPubkey,
              );
            });
          },
          build: buildBloc,
          act: (bloc) async {
            bloc.add(
              const ConversationMessageSent(
                recipientPubkeys: [recipientPubkey],
                content: 'First message',
              ),
            );
            await Future<void>.delayed(Duration.zero);
            bloc.add(
              const ConversationMessageSent(
                recipientPubkeys: [recipientPubkey],
                content: 'Second message',
              ),
            );
          },
          wait: const Duration(milliseconds: 200),
          expect: () => [
            // First send starts
            const ConversationState(sendStatus: SendStatus.sending),
            // First send completes
            const ConversationState(sendStatus: SendStatus.sent),
            // Second send starts (sequential: waited for first)
            const ConversationState(sendStatus: SendStatus.sending),
            // Second send completes
            const ConversationState(sendStatus: SendStatus.sent),
          ],
          verify: (_) {
            verify(
              () => mockDmRepository.sendMessage(
                recipientPubkey: recipientPubkey,
                content: any(named: 'content'),
              ),
            ).called(2);
          },
        );

        blocTest<ConversationBloc, ConversationState>(
          'does not drop the second event when first is still processing',
          setUp: () {
            final completer1 = Completer<NIP17SendResult>();
            final completer2 = Completer<NIP17SendResult>();
            var callCount = 0;
            when(
              () => mockDmRepository.sendMessage(
                recipientPubkey: recipientPubkey,
                content: any(named: 'content'),
              ),
            ).thenAnswer((_) {
              callCount++;
              if (callCount == 1) return completer1.future;
              return completer2.future;
            });

            // Complete both after a short delay so sequential gets to
            // process them one-by-one.
            Future<void>.delayed(
              const Duration(milliseconds: 30),
            ).then((_) {
              completer1.complete(
                NIP17SendResult.success(
                  messageEventId: sentEventId,
                  recipientPubkey: recipientPubkey,
                ),
              );
            });
            Future<void>.delayed(
              const Duration(milliseconds: 60),
            ).then((_) {
              completer2.complete(
                NIP17SendResult.success(
                  messageEventId: sentEventId,
                  recipientPubkey: recipientPubkey,
                ),
              );
            });
          },
          build: buildBloc,
          act: (bloc) {
            bloc
              ..add(
                const ConversationMessageSent(
                  recipientPubkeys: [recipientPubkey],
                  content: 'First',
                ),
              )
              ..add(
                const ConversationMessageSent(
                  recipientPubkeys: [recipientPubkey],
                  content: 'Second',
                ),
              );
          },
          wait: const Duration(milliseconds: 150),
          expect: () => [
            // First send
            const ConversationState(sendStatus: SendStatus.sending),
            const ConversationState(sendStatus: SendStatus.sent),
            // Second send (not dropped)
            const ConversationState(sendStatus: SendStatus.sending),
            const ConversationState(sendStatus: SendStatus.sent),
          ],
        );
      });

      group('restartable() on $ConversationStarted', () {
        blocTest<ConversationBloc, ConversationState>(
          'cancels the previous subscription and starts a new one '
          'when $ConversationStarted is re-added',
          setUp: () {
            final controller1 = StreamController<List<DmMessage>>();
            final controller2 = StreamController<List<DmMessage>>();
            var watchCallCount = 0;

            when(
              () => mockDmRepository.markConversationAsRead(conversationId),
            ).thenAnswer((_) async {});

            when(
              () => mockDmRepository.watchMessages(conversationId),
            ).thenAnswer((_) {
              watchCallCount++;
              if (watchCallCount == 1) return controller1.stream;
              return controller2.stream;
            });

            // Emit on first stream, then trigger re-add, then emit on second
            // stream. The first stream's later emission should be ignored
            // because restartable() cancels it.
            Future<void>.delayed(const Duration(milliseconds: 10)).then((_) {
              controller1.add([testMessage]);
            });
            Future<void>.delayed(const Duration(milliseconds: 60)).then((_) {
              // This emission on the old stream should be ignored
              controller1.add([
                testMessage,
                const DmMessage(
                  id: '9999999999999999999999999999999999999999999999999999999999999999',
                  conversationId: conversationId,
                  senderPubkey: senderPubkey,
                  content: 'Should be ignored',
                  createdAt: 1700000200,
                  giftWrapId:
                      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
                ),
              ]);
              controller1.close();
            });
            Future<void>.delayed(const Duration(milliseconds: 70)).then((_) {
              controller2.add([
                const DmMessage(
                  id: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
                  conversationId: conversationId,
                  senderPubkey: recipientPubkey,
                  content: 'New subscription message',
                  createdAt: 1700000300,
                  giftWrapId:
                      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
                ),
              ]);
              controller2.close();
            });
          },
          build: buildBloc,
          act: (bloc) async {
            bloc.add(const ConversationStarted());
            // Wait for first stream to emit, then re-add
            await Future<void>.delayed(const Duration(milliseconds: 30));
            bloc.add(const ConversationStarted());
          },
          wait: const Duration(milliseconds: 200),
          expect: () => [
            // First subscription starts
            const ConversationState(status: ConversationStatus.loading),
            // First stream emits messages
            const ConversationState(
              status: ConversationStatus.loaded,
              messages: [testMessage],
            ),
            // Second ConversationStarted restarts: emits loading.
            // copyWith preserves messages from previous state.
            const ConversationState(
              status: ConversationStatus.loading,
              messages: [testMessage],
            ),
            // Second stream emits its message (first stream's late emit
            // is ignored because restartable() cancelled it)
            isA<ConversationState>()
                .having(
                  (s) => s.status,
                  'status',
                  equals(ConversationStatus.loaded),
                )
                .having(
                  (s) => s.messages.length,
                  'messages.length',
                  equals(1),
                )
                .having(
                  (s) => s.messages.first.content,
                  'messages.first.content',
                  equals('New subscription message'),
                ),
          ],
          verify: (_) {
            verify(
              () => mockDmRepository.watchMessages(conversationId),
            ).called(2);
            // Called once per ConversationStarted (×2) + once per onData
            // emission (×2: one from controller1 before restart, one from
            // controller2 after restart) = 4 total.
            verify(
              () => mockDmRepository.markConversationAsRead(conversationId),
            ).called(4);
          },
        );
      });
    });
  });

  group(ConversationState, () {
    test('supports value equality', () {
      expect(
        const ConversationState(),
        equals(const ConversationState()),
      );
    });

    test('props are correct', () {
      expect(
        const ConversationState().props,
        equals([
          ConversationStatus.initial,
          <DmMessage>[],
          SendStatus.idle,
        ]),
      );
    });

    test('states with different status are not equal', () {
      expect(
        const ConversationState(),
        isNot(
          equals(
            const ConversationState(status: ConversationStatus.loading),
          ),
        ),
      );
    });

    test('states with different messages are not equal', () {
      const message = DmMessage(
        id: messageId,
        conversationId: conversationId,
        senderPubkey: senderPubkey,
        content: 'Hello',
        createdAt: 1700000000,
        giftWrapId: giftWrapId,
      );

      expect(
        const ConversationState(),
        isNot(equals(const ConversationState(messages: [message]))),
      );
    });

    test('states with different sendStatus are not equal', () {
      expect(
        const ConversationState(),
        isNot(
          equals(
            const ConversationState(sendStatus: SendStatus.sending),
          ),
        ),
      );
    });

    test('copyWith returns same object when no parameters are provided', () {
      const state = ConversationState();

      expect(state.copyWith(), equals(state));
    });

    test('copyWith replaces every value', () {
      const message = DmMessage(
        id: messageId,
        conversationId: conversationId,
        senderPubkey: senderPubkey,
        content: 'Hello',
        createdAt: 1700000000,
        giftWrapId: giftWrapId,
      );

      const state = ConversationState();

      final copied = state.copyWith(
        status: ConversationStatus.loaded,
        messages: [message],
        sendStatus: SendStatus.sent,
      );

      expect(copied.status, equals(ConversationStatus.loaded));
      expect(copied.messages, equals([message]));
      expect(copied.sendStatus, equals(SendStatus.sent));
    });
  });

  group(ConversationEvent, () {
    group(ConversationStarted, () {
      test('supports value equality', () {
        expect(
          const ConversationStarted(),
          equals(const ConversationStarted()),
        );
      });

      test('props are correct', () {
        expect(const ConversationStarted().props, equals(<Object?>[]));
      });
    });

    group(ConversationMessageSent, () {
      test('supports value equality', () {
        expect(
          const ConversationMessageSent(
            recipientPubkeys: [recipientPubkey],
            content: 'Hello',
          ),
          equals(
            const ConversationMessageSent(
              recipientPubkeys: [recipientPubkey],
              content: 'Hello',
            ),
          ),
        );
      });

      test('events with different recipientPubkeys are not equal', () {
        expect(
          const ConversationMessageSent(
            recipientPubkeys: [recipientPubkey],
            content: 'Hello',
          ),
          isNot(
            equals(
              const ConversationMessageSent(
                recipientPubkeys: [recipientPubkey2],
                content: 'Hello',
              ),
            ),
          ),
        );
      });

      test('events with different content are not equal', () {
        expect(
          const ConversationMessageSent(
            recipientPubkeys: [recipientPubkey],
            content: 'Hello',
          ),
          isNot(
            equals(
              const ConversationMessageSent(
                recipientPubkeys: [recipientPubkey],
                content: 'Goodbye',
              ),
            ),
          ),
        );
      });

      test('props are correct', () {
        expect(
          const ConversationMessageSent(
            recipientPubkeys: [recipientPubkey],
            content: 'Hello',
          ).props,
          equals([
            [recipientPubkey],
            'Hello',
          ]),
        );
      });
    });
  });
}
