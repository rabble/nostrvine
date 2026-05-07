// ABOUTME: Tests for ConversationBloc - loading messages, sending 1:1 and
// ABOUTME: group messages, error handling, event transformer behavior,
// ABOUTME: and state/event equality.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/conversation/conversation_bloc.dart';

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

    ConversationBloc buildBloc({String Function()? pendingIdFactory}) =>
        ConversationBloc(
          dmRepository: mockDmRepository,
          conversationId: conversationId,
          currentUserPubkey: senderPubkey,
          pendingIdFactory: pendingIdFactory,
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
              .having((s) => s.messages.length, 'messages.length', equals(2)),
        ],
      );
    });

    group('ConversationMessageSent', () {
      group('1:1 message', () {
        blocTest<ConversationBloc, ConversationState>(
          'emits [sending with optimistic message, sent] '
          'on successful sendMessage',
          setUp: () {
            when(
              () => mockDmRepository.sendMessage(
                recipientPubkey: recipientPubkey,
                content: 'Hello',
              ),
            ).thenAnswer(
              (_) async => NIP17SendResult.success(
                rumorEventId: sentEventId,
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
            isA<ConversationState>()
                .having((s) => s.sendStatus, 'sendStatus', SendStatus.sending)
                .having((s) => s.messages.length, 'messages.length', 1)
                .having(
                  (s) => s.messages.first.content,
                  'optimistic message content',
                  'Hello',
                )
                .having(
                  (s) => s.messages.first.senderPubkey,
                  'optimistic message sender',
                  senderPubkey,
                ),
            isA<ConversationState>().having(
              (s) => s.sendStatus,
              'sendStatus',
              SendStatus.sent,
            ),
          ],
        );

        blocTest<ConversationBloc, ConversationState>(
          'emits [sending with optimistic message, failed without '
          'optimistic and with lastFailedSend] on failed sendMessage',
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
            // Sending: optimistic added.
            isA<ConversationState>()
                .having((s) => s.sendStatus, 'sendStatus', SendStatus.sending)
                .having((s) => s.messages.length, 'messages.length', 1)
                .having(
                  (s) => s.lastFailedSend,
                  'lastFailedSend cleared on new attempt',
                  isNull,
                ),
            // Failed: optimistic stripped, lastFailedSend populated so the
            // UI can offer a retry. Without the strip, the optimistic
            // would survive in bloc memory until pop, then vanish on
            // re-entry — the "looks sent, then disappeared" bug.
            isA<ConversationState>()
                .having((s) => s.sendStatus, 'sendStatus', SendStatus.failed)
                .having(
                  (s) => s.messages,
                  'messages',
                  isEmpty,
                )
                .having(
                  (s) => s.lastFailedSend,
                  'lastFailedSend',
                  equals(
                    const FailedSend(
                      content: 'Hello',
                      recipientPubkeys: [recipientPubkey],
                    ),
                  ),
                ),
          ],
          errors: () => [isA<Exception>()],
        );

        blocTest<ConversationBloc, ConversationState>(
          'retry attempt clears prior lastFailedSend and reinserts '
          'an optimistic row',
          seed: () => const ConversationState(
            sendStatus: SendStatus.failed,
            lastFailedSend: FailedSend(
              content: 'Hello',
              recipientPubkeys: [recipientPubkey],
            ),
          ),
          setUp: () {
            when(
              () => mockDmRepository.sendMessage(
                recipientPubkey: recipientPubkey,
                content: 'Hello',
              ),
            ).thenAnswer(
              (_) async => NIP17SendResult.success(
                rumorEventId: sentEventId,
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
            // New attempt: optimistic added, lastFailedSend cleared so a
            // stale SnackBar can't refire from a previous failure.
            isA<ConversationState>()
                .having((s) => s.sendStatus, 'sendStatus', SendStatus.sending)
                .having((s) => s.messages.length, 'messages.length', 1)
                .having((s) => s.lastFailedSend, 'lastFailedSend', isNull),
            // Success: status flips, lastFailedSend stays null.
            isA<ConversationState>()
                .having((s) => s.sendStatus, 'sendStatus', SendStatus.sent)
                .having((s) => s.lastFailedSend, 'lastFailedSend', isNull),
          ],
        );

        blocTest<ConversationBloc, ConversationState>(
          'emits [sending with optimistic, sentPartial with lastFailedSend] '
          'when sendMessage succeeds but the self-wrap was not published',
          setUp: () {
            when(
              () => mockDmRepository.sendMessage(
                recipientPubkey: recipientPubkey,
                content: 'Hello',
              ),
            ).thenAnswer(
              (_) async => NIP17SendResult.success(
                rumorEventId: sentEventId,
                messageEventId: sentEventId,
                recipientPubkey: recipientPubkey,
                selfWrapPublished: false,
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
          // Partial-delivery: the recipient got the message and the local
          // DB persist already happened inside DmRepository.sendMessage,
          // so the optimistic stays — stripping it would race with the
          // watchMessages re-emit and cause a brief disappearance.
          // lastFailedSend is recorded so the UI can offer retry.
          expect: () => [
            isA<ConversationState>()
                .having((s) => s.sendStatus, 'sendStatus', SendStatus.sending)
                .having((s) => s.messages.length, 'messages.length', 1),
            isA<ConversationState>()
                .having(
                  (s) => s.sendStatus,
                  'sendStatus',
                  SendStatus.sentPartial,
                )
                .having(
                  (s) => s.messages.length,
                  'optimistic preserved',
                  1,
                )
                .having(
                  (s) => s.lastFailedSend,
                  'lastFailedSend',
                  equals(
                    const FailedSend(
                      content: 'Hello',
                      recipientPubkeys: [recipientPubkey],
                    ),
                  ),
                ),
          ],
        );
      });

      group('group message', () {
        blocTest<ConversationBloc, ConversationState>(
          'emits [sending with optimistic message, sent] '
          'when at least one sendGroupMessage succeeds',
          setUp: () {
            when(
              () => mockDmRepository.sendGroupMessage(
                recipientPubkeys: [recipientPubkey, recipientPubkey2],
                content: 'Group hello',
              ),
            ).thenAnswer(
              (_) async => [
                NIP17SendResult.success(
                  rumorEventId: sentEventId,
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
            isA<ConversationState>()
                .having((s) => s.sendStatus, 'sendStatus', SendStatus.sending)
                .having(
                  (s) => s.messages.first.content,
                  'optimistic message content',
                  'Group hello',
                ),
            isA<ConversationState>().having(
              (s) => s.sendStatus,
              'sendStatus',
              SendStatus.sent,
            ),
          ],
        );

        blocTest<ConversationBloc, ConversationState>(
          'emits [sending with optimistic message, failed without '
          'optimistic and with lastFailedSend] when all sendGroupMessage fail',
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
            isA<ConversationState>()
                .having((s) => s.sendStatus, 'sendStatus', SendStatus.sending)
                .having((s) => s.messages.length, 'messages.length', 1),
            isA<ConversationState>()
                .having((s) => s.sendStatus, 'sendStatus', SendStatus.failed)
                .having((s) => s.messages, 'messages', isEmpty)
                .having(
                  (s) => s.lastFailedSend,
                  'lastFailedSend',
                  equals(
                    const FailedSend(
                      content: 'Group hello',
                      recipientPubkeys: [recipientPubkey, recipientPubkey2],
                    ),
                  ),
                ),
          ],
          errors: () => [isA<Exception>()],
        );

        blocTest<ConversationBloc, ConversationState>(
          'emits [sending, sentPartial] when any successful per-recipient '
          'sendGroupMessage had its self-wrap unpublished',
          setUp: () {
            when(
              () => mockDmRepository.sendGroupMessage(
                recipientPubkeys: [recipientPubkey, recipientPubkey2],
                content: 'Group hello',
              ),
            ).thenAnswer(
              (_) async => [
                NIP17SendResult.success(
                  rumorEventId: sentEventId,
                  messageEventId: sentEventId,
                  recipientPubkey: recipientPubkey,
                ),
                NIP17SendResult.success(
                  rumorEventId: sentEventId,
                  messageEventId: sentEventId,
                  recipientPubkey: recipientPubkey2,
                  selfWrapPublished: false,
                ),
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
            isA<ConversationState>().having(
              (s) => s.sendStatus,
              'sendStatus',
              SendStatus.sending,
            ),
            isA<ConversationState>()
                .having(
                  (s) => s.sendStatus,
                  'sendStatus',
                  SendStatus.sentPartial,
                )
                .having(
                  (s) => s.lastFailedSend,
                  'lastFailedSend',
                  equals(
                    const FailedSend(
                      content: 'Group hello',
                      recipientPubkeys: [recipientPubkey, recipientPubkey2],
                    ),
                  ),
                ),
          ],
        );
      });

      group('exception handling', () {
        blocTest<ConversationBloc, ConversationState>(
          'strips optimistic and records lastFailedSend '
          'when sendMessage throws an exception',
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
            isA<ConversationState>()
                .having((s) => s.sendStatus, 'sendStatus', SendStatus.sending)
                .having((s) => s.messages.length, 'messages.length', 1),
            isA<ConversationState>()
                .having((s) => s.sendStatus, 'sendStatus', SendStatus.failed)
                .having((s) => s.messages, 'messages', isEmpty)
                .having(
                  (s) => s.lastFailedSend,
                  'lastFailedSend',
                  equals(
                    const FailedSend(
                      content: 'Hello',
                      recipientPubkeys: [recipientPubkey],
                    ),
                  ),
                ),
          ],
          errors: () => [isA<Exception>()],
        );

        blocTest<ConversationBloc, ConversationState>(
          'strips optimistic and records lastFailedSend '
          'when sendGroupMessage throws an exception',
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
            isA<ConversationState>()
                .having((s) => s.sendStatus, 'sendStatus', SendStatus.sending)
                .having((s) => s.messages.length, 'messages.length', 1),
            isA<ConversationState>()
                .having((s) => s.sendStatus, 'sendStatus', SendStatus.failed)
                .having((s) => s.messages, 'messages', isEmpty)
                .having(
                  (s) => s.lastFailedSend,
                  'lastFailedSend',
                  equals(
                    const FailedSend(
                      content: 'Group hello',
                      recipientPubkeys: [recipientPubkey, recipientPubkey2],
                    ),
                  ),
                ),
          ],
          errors: () => [isA<Exception>()],
        );

        blocTest<ConversationBloc, ConversationState>(
          'strips only the optimistic for the failed attempt — '
          'preserves persisted messages already in state',
          seed: () => const ConversationState(
            status: ConversationStatus.loaded,
            messages: [testMessage],
          ),
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
            isA<ConversationState>()
                .having((s) => s.sendStatus, 'sendStatus', SendStatus.sending)
                .having((s) => s.messages.length, 'messages.length', 2),
            isA<ConversationState>()
                .having((s) => s.sendStatus, 'sendStatus', SendStatus.failed)
                .having(
                  (s) => s.messages,
                  'messages preserves existing testMessage',
                  equals(const [testMessage]),
                ),
          ],
          errors: () => [isA<Exception>()],
        );
      });

      // Regression for #3908 review feedback. The failure cleanup strips by
      // `m.id != pendingId`, so the contract relies on every optimistic row
      // having a unique id. The original implementation derived `pendingId`
      // from a second-resolution timestamp; two sends within the same second
      // collided, and the second one's failure stripped the first one's row
      // along with its own. The fix replaces the timestamp with a UUID v4
      // and exposes a test-only [ConversationBloc.pendingIdFactory] hook so
      // this regression can be pinned without depending on real wall-clock
      // timing.
      group('pendingId uniqueness', () {
        blocTest<ConversationBloc, ConversationState>(
          "failure cleanup strips only the failing attempt's optimistic "
          'when a sibling optimistic from a prior send is still in state',
          setUp: () {
            var callCount = 0;
            when(
              () => mockDmRepository.sendMessage(
                recipientPubkey: recipientPubkey,
                content: any(named: 'content'),
              ),
            ).thenAnswer((_) async {
              callCount++;
              if (callCount == 1) {
                // First send resolves successfully but `watchMessages`
                // stays silent — this models the production window where
                // the DB write has committed but the stream emission has
                // not yet reached the bloc, so the optimistic row from
                // the first send is still present in `state.messages`.
                return NIP17SendResult.success(
                  rumorEventId: sentEventId,
                  messageEventId: sentEventId,
                  recipientPubkey: recipientPubkey,
                );
              }
              return NIP17SendResult.failure('Relay timeout');
            });
          },
          build: () {
            var counter = 0;
            return buildBloc(
              pendingIdFactory: () => 'pending-${++counter}',
            );
          },
          act: (bloc) async {
            bloc.add(
              const ConversationMessageSent(
                recipientPubkeys: [recipientPubkey],
                content: 'First',
              ),
            );
            // Sequential() already serialises the two events; the explicit
            // wait makes the timeline observable in the captured states.
            await Future<void>.delayed(const Duration(milliseconds: 5));
            bloc.add(
              const ConversationMessageSent(
                recipientPubkeys: [recipientPubkey],
                content: 'Second',
              ),
            );
          },
          wait: const Duration(milliseconds: 30),
          expect: () => [
            // First attempt: optimistic added with pending-1.
            isA<ConversationState>()
                .having((s) => s.sendStatus, 'sendStatus', SendStatus.sending)
                .having((s) => s.messages.length, 'messages.length', 1)
                .having(
                  (s) => s.messages.first.id,
                  'first attempt pending id',
                  'pending-1',
                ),
            isA<ConversationState>().having(
              (s) => s.sendStatus,
              'sendStatus',
              SendStatus.sent,
            ),
            // Second attempt starts before the watch stream has cleared
            // the first's optimistic — both rows coexist, with distinct
            // ids so the upcoming strip can target the right one.
            isA<ConversationState>()
                .having((s) => s.sendStatus, 'sendStatus', SendStatus.sending)
                .having((s) => s.messages.length, 'messages.length', 2)
                .having(
                  (s) => s.messages.first.id,
                  'second attempt pending id',
                  'pending-2',
                )
                .having(
                  (s) => s.messages.last.id,
                  'first attempt sibling still present',
                  'pending-1',
                ),
            // Second attempt fails. Cleanup strips pending-2 only; the
            // sibling pending-1 row remains. Under the old timestamp-
            // based id this state would be `messages: isEmpty`.
            isA<ConversationState>()
                .having((s) => s.sendStatus, 'sendStatus', SendStatus.failed)
                .having((s) => s.messages.length, 'messages.length', 1)
                .having(
                  (s) => s.messages.single.id,
                  'sibling optimistic preserved',
                  'pending-1',
                )
                .having(
                  (s) => s.lastFailedSend,
                  'lastFailedSend records the failing attempt only',
                  equals(
                    const FailedSend(
                      content: 'Second',
                      recipientPubkeys: [recipientPubkey],
                    ),
                  ),
                ),
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
                await Future<void>.delayed(const Duration(milliseconds: 50));
              }
              return NIP17SendResult.success(
                rumorEventId: sentEventId,
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
            // First send starts (with optimistic message)
            isA<ConversationState>()
                .having((s) => s.sendStatus, 'sendStatus', SendStatus.sending)
                .having(
                  (s) => s.messages.first.content,
                  'content',
                  'First message',
                ),
            // First send completes
            isA<ConversationState>().having(
              (s) => s.sendStatus,
              'sendStatus',
              SendStatus.sent,
            ),
            // Second send starts (sequential: waited for first)
            isA<ConversationState>()
                .having((s) => s.sendStatus, 'sendStatus', SendStatus.sending)
                .having(
                  (s) => s.messages.first.content,
                  'content',
                  'Second message',
                ),
            // Second send completes
            isA<ConversationState>().having(
              (s) => s.sendStatus,
              'sendStatus',
              SendStatus.sent,
            ),
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
            Future<void>.delayed(const Duration(milliseconds: 30)).then((_) {
              completer1.complete(
                NIP17SendResult.success(
                  rumorEventId: sentEventId,
                  messageEventId: sentEventId,
                  recipientPubkey: recipientPubkey,
                ),
              );
            });
            Future<void>.delayed(const Duration(milliseconds: 60)).then((_) {
              completer2.complete(
                NIP17SendResult.success(
                  rumorEventId: sentEventId,
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
            // First send (with optimistic message)
            isA<ConversationState>().having(
              (s) => s.sendStatus,
              'sendStatus',
              SendStatus.sending,
            ),
            isA<ConversationState>().having(
              (s) => s.sendStatus,
              'sendStatus',
              SendStatus.sent,
            ),
            // Second send (not dropped)
            isA<ConversationState>().having(
              (s) => s.sendStatus,
              'sendStatus',
              SendStatus.sending,
            ),
            isA<ConversationState>().having(
              (s) => s.sendStatus,
              'sendStatus',
              SendStatus.sent,
            ),
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
                .having((s) => s.messages.length, 'messages.length', equals(1))
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

    group('ConversationMessageDeleted', () {
      blocTest<ConversationBloc, ConversationState>(
        'calls deleteMessageForEveryone on the repository',
        setUp: () {
          when(
            () => mockDmRepository.deleteMessageForEveryone(messageId),
          ).thenAnswer((_) async {});
        },
        build: buildBloc,
        act: (bloc) =>
            bloc.add(const ConversationMessageDeleted(rumorId: messageId)),
        verify: (_) {
          verify(
            () => mockDmRepository.deleteMessageForEveryone(messageId),
          ).called(1);
        },
      );

      blocTest<ConversationBloc, ConversationState>(
        'reports error via addError when deleteMessageForEveryone throws',
        setUp: () {
          when(
            () => mockDmRepository.deleteMessageForEveryone(messageId),
          ).thenThrow(ArgumentError('message not found'));
        },
        build: buildBloc,
        act: (bloc) =>
            bloc.add(const ConversationMessageDeleted(rumorId: messageId)),
        errors: () => [isA<ArgumentError>()],
      );
    });
  });

  group(ConversationState, () {
    test('supports value equality', () {
      expect(const ConversationState(), equals(const ConversationState()));
    });

    test('props are correct', () {
      expect(
        const ConversationState().props,
        equals([
          ConversationStatus.initial,
          <DmMessage>[],
          SendStatus.idle,
          null,
        ]),
      );
    });

    test('states with different lastFailedSend are not equal', () {
      expect(
        const ConversationState(),
        isNot(
          equals(
            const ConversationState(
              lastFailedSend: FailedSend(
                content: 'Hello',
                recipientPubkeys: [recipientPubkey],
              ),
            ),
          ),
        ),
      );
    });

    test('copyWith carries lastFailedSend forward when not overridden', () {
      const failed = FailedSend(
        content: 'Hello',
        recipientPubkeys: [recipientPubkey],
      );
      const seeded = ConversationState(lastFailedSend: failed);

      // Copying without specifying lastFailedSend keeps the existing value.
      expect(
        seeded.copyWith(sendStatus: SendStatus.sending).lastFailedSend,
        equals(failed),
      );
    });

    test('copyWith(clearLastFailedSend: true) wipes lastFailedSend', () {
      const failed = FailedSend(
        content: 'Hello',
        recipientPubkeys: [recipientPubkey],
      );
      const seeded = ConversationState(lastFailedSend: failed);

      expect(seeded.copyWith(clearLastFailedSend: true).lastFailedSend, isNull);
    });

    test('states with different status are not equal', () {
      expect(
        const ConversationState(),
        isNot(
          equals(const ConversationState(status: ConversationStatus.loading)),
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
        isNot(equals(const ConversationState(sendStatus: SendStatus.sending))),
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

    group(ConversationMessageDeleted, () {
      test('supports value equality', () {
        expect(
          const ConversationMessageDeleted(rumorId: messageId),
          equals(const ConversationMessageDeleted(rumorId: messageId)),
        );
      });

      test('props are correct', () {
        expect(
          const ConversationMessageDeleted(rumorId: messageId).props,
          equals([messageId]),
        );
      });
    });
  });
}
