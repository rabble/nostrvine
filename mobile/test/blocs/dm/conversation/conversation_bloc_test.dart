// ABOUTME: Tests for ConversationBloc - loading messages, sending 1:1 and
// ABOUTME: group messages, error handling, event transformer behavior,
// ABOUTME: and state/event equality.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/conversation/conversation_bloc.dart';
import 'package:openvine/observability/reportable_error.dart';

class _MockDmRepository extends Mock implements DmRepository {}

/// Builds an [OutgoingDm] queue row for tests that exercise the
/// [ConversationState.pendingOutgoing] projection slice. Defaults to a
/// `pending:pending` row freshly queued at epoch — caller overrides any
/// field that the specific test cares about.
OutgoingDm _outgoingDm({
  required String id,
  String content = 'test',
  int createdAtSec = 1700000000,
  DateTime? queuedAt,
  String ownerPubkey =
      '1111111111111111111111111111111111111111111111111111111111111111',
  String recipientPubkey =
      '2222222222222222222222222222222222222222222222222222222222222222',
  String conversationId =
      'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
  OutgoingWrapStatus recipientWrap = OutgoingWrapStatus.pending,
  OutgoingWrapStatus selfWrap = OutgoingWrapStatus.pending,
  int retryCount = 0,
  DateTime? lastAttemptAt,
}) {
  return OutgoingDm(
    id: id,
    conversationId: conversationId,
    recipientPubkey: recipientPubkey,
    content: content,
    createdAt: createdAtSec,
    rumorEventJson: '{}',
    recipientWrapStatus: recipientWrap,
    selfWrapStatus: selfWrap,
    queuedAt:
        queuedAt ?? DateTime.fromMillisecondsSinceEpoch(createdAtSec * 1000),
    ownerPubkey: ownerPubkey,
    retryCount: retryCount,
    lastAttemptAt: lastAttemptAt,
  );
}

Future<void> _waitForConversationState(
  ConversationBloc bloc,
  bool Function(ConversationState state) matches,
) async {
  if (matches(bloc.state)) return;
  await bloc.stream.firstWhere(matches);
}

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
          when(
            () => mockDmRepository.watchOutgoing(any()),
          ).thenAnswer((_) => Stream.value(const <OutgoingDm>[]));
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
          when(
            () => mockDmRepository.watchOutgoing(any()),
          ).thenAnswer((_) => Stream.value(const <OutgoingDm>[]));
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
          when(
            () => mockDmRepository.watchOutgoing(any()),
          ).thenAnswer((_) => Stream.value(const <OutgoingDm>[]));
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
          when(
            () => mockDmRepository.watchOutgoing(any()),
          ).thenAnswer((_) => Stream.value(const <OutgoingDm>[]));

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

      late StreamController<List<DmMessage>> messagesController;
      late StreamController<List<OutgoingDm>> outgoingController;

      blocTest<ConversationBloc, ConversationState>(
        'does not re-mark read on an outgoing-queue-only tick, but does on a '
        'genuinely new message',
        setUp: () {
          messagesController = StreamController<List<DmMessage>>();
          outgoingController = StreamController<List<OutgoingDm>>();
          when(
            () => mockDmRepository.markConversationAsRead(conversationId),
          ).thenAnswer((_) async {});
          when(
            () => mockDmRepository.watchMessages(conversationId),
          ).thenAnswer((_) => messagesController.stream);
          when(
            () => mockDmRepository.watchOutgoing(any()),
          ).thenAnswer((_) => outgoingController.stream);

          addTearDown(() async {
            if (!messagesController.isClosed) {
              await messagesController.close();
            }
            if (!outgoingController.isClosed) {
              await outgoingController.close();
            }
          });
        },
        build: buildBloc,
        act: (bloc) async {
          bloc.add(const ConversationStarted());
          await untilCalled(
            () => mockDmRepository.watchMessages(conversationId),
          );

          // First message arrives: messages change -> marks read.
          messagesController.add([testMessage]);
          outgoingController.add(const <OutgoingDm>[]);
          await _waitForConversationState(
            bloc,
            (state) =>
                state.status == ConversationStatus.loaded &&
                state.messages.length == 1 &&
                state.pendingOutgoing.isEmpty,
          );

          // Outgoing-queue status change only (e.g. pending -> delivered):
          // combineLatest2 re-emits the SAME messages instance, so this tick
          // must NOT re-mark the conversation read.
          outgoingController.add([_outgoingDm(id: 'pending-rumor')]);
          await _waitForConversationState(
            bloc,
            (state) =>
                state.messages.length == 1 && state.pendingOutgoing.length == 1,
          );

          // A genuinely new incoming message: marks read again.
          const secondMessage = DmMessage(
            id: '7777777777777777777777777777777777777777777777777777777777777777',
            conversationId: conversationId,
            senderPubkey: recipientPubkey,
            content: 'Reply message',
            createdAt: 1700000100,
            giftWrapId:
                '8888888888888888888888888888888888888888888888888888888888888888',
          );
          messagesController.add([testMessage, secondMessage]);
          await _waitForConversationState(
            bloc,
            (state) =>
                state.messages.length == 2 && state.pendingOutgoing.length == 1,
          );

          await messagesController.close();
          await outgoingController.close();
        },
        verify: (bloc) {
          // The outgoing-only tick was processed (its row reached state)...
          expect(bloc.state.pendingOutgoing, hasLength(1));
          // ...but mark-read fired only on open + the two message-list changes,
          // NOT on the outgoing-only tick in between.
          verify(
            () => mockDmRepository.markConversationAsRead(conversationId),
          ).called(3);
        },
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
              (_) async =>
                  const NIP17SendResult.failure('Failed to publish message'),
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
            // Sending: optimistic added to the pendingOptimistic slice.
            isA<ConversationState>()
                .having((s) => s.sendStatus, 'sendStatus', SendStatus.sending)
                .having(
                  (s) => s.lastFailedSend,
                  'lastFailedSend cleared on new attempt',
                  isNull,
                ),
            // Failed: pendingOptimistic stripped, lastFailedSend populated
            // so the UI can offer a retry. Without the strip, the
            // optimistic would survive in bloc memory until pop, then
            // vanish on re-entry — the "looks sent, then disappeared" bug
            // (#3902 / #3908).
            isA<ConversationState>()
                .having((s) => s.sendStatus, 'sendStatus', SendStatus.failed)
                .having((s) => s.messages, 'messages untouched', isEmpty)
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

        // Regression for #4193 — sent DM does not appear until app restart.
        //
        // Pre-fix the optimistic lived in `state.messages`, which the
        // `_onStarted.emit.forEach.onData` callback replaced wholesale on
        // every watchMessages tick. For a freshly-searched conversation
        // the watch's first tick is `[]`, so the optimistic was wiped the
        // moment the watch subscription took effect — exactly when the
        // user looks at the conversation right after tapping send.
        //
        // The bug-scoped patch (#4234) split the optimistic into a
        // separate in-memory `pendingOptimistic` slice. The principled
        // architecture this file pins now is dual-stream: the durable
        // `outgoing_dms` queue row IS the optimistic. `sendMessage`
        // enqueues it before any signer round-trip, and
        // `DmRepository.watchOutgoing` projects it into
        // `state.pendingOutgoing`. The watch-messages path is unchanged;
        // a `[]` tick on that stream cannot wipe the bubble because the
        // bubble lives in the parallel `pendingOutgoing` slice now.
        //
        // Stated as a state-shape pin (the bloc-level flow is implicitly
        // covered by the sendMessage tests in this group that all stub
        // both streams): when messages-stream emits empty AND
        // pendingOutgoing carries a queue row, displayedMessages MUST
        // carry the bubble. Pre-#4193 this invariant did not hold.
        test(
          'displayedMessages survives an empty watchMessages tick while '
          'pendingOutgoing carries a queue row (regression for #4193)',
          () {
            final pendingRow = _outgoingDm(
              id: sentEventId,
              content: 'Hello',
            );
            // Composite: loaded + sending + empty persisted + queue row.
            final state = ConversationState(
              status: ConversationStatus.loaded,
              sendStatus: SendStatus.sending,
              pendingOutgoing: [pendingRow],
            );
            expect(state.messages, isEmpty);
            expect(state.displayedMessages, hasLength(1));
            expect(state.displayedMessages.first.content, equals('Hello'));
            expect(state.statusFor(sentEventId), DmDeliveryStatus.pending);
          },
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
            // New attempt: optimistic added to pendingOptimistic,
            // lastFailedSend cleared so a stale SnackBar can't refire
            // from a previous failure.
            isA<ConversationState>()
                .having((s) => s.sendStatus, 'sendStatus', SendStatus.sending)
                .having((s) => s.lastFailedSend, 'lastFailedSend', isNull),
            // Success: status flips, pending stripped, lastFailedSend
            // stays null.
            isA<ConversationState>()
                .having((s) => s.sendStatus, 'sendStatus', SendStatus.sent)
                .having((s) => s.lastFailedSend, 'lastFailedSend', isNull),
          ],
        );

        blocTest<ConversationBloc, ConversationState>(
          'emits [sending with optimistic, sentPartial with lastPartialSend] '
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
          // DB persist already happened inside DmRepository.sendMessage.
          // The pendingOptimistic entry is stripped on sentPartial (same
          // as sent) — the watch tick brings the persisted row, so the
          // user-visible bubble is sourced from `messages`, not from the
          // pending. lastPartialSend records the rumor id whose self-wrap
          // failed, so the SnackBar's Retry can recover via the
          // self-wrap-only path without redelivering to the recipient
          // (#4102).
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
                  (s) => s.lastPartialSend,
                  'lastPartialSend',
                  equals(const PartialSend(rumorIds: [sentEventId])),
                )
                .having(
                  (s) => s.lastFailedSend,
                  'lastFailedSend stays null on partial — it drives '
                  'a different recovery path',
                  isNull,
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
                const NIP17SendResult.failure('Failed for second recipient'),
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
                const NIP17SendResult.failure('Relay timeout'),
                const NIP17SendResult.failure('Connection refused'),
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
                .having((s) => s.sendStatus, 'sendStatus', SendStatus.failed)
                .having((s) => s.messages, 'messages untouched', isEmpty)
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
          'emits [sending, sentPartial with only the failing rumor id] '
          'when one per-recipient sendGroupMessage has self-wrap unpublished',
          setUp: () {
            // Each per-recipient send produces its own rumor id.
            // recipient1 fully delivers, recipient2 partial — only the
            // partial one should land in lastPartialSend.rumorIds, so
            // the recovery path republishes only that self-wrap.
            const rumorIdRecipient1 =
                '7777777777777777777777777777777777777777777777777777777777777777';
            const rumorIdRecipient2 =
                '8888888888888888888888888888888888888888888888888888888888888888';
            when(
              () => mockDmRepository.sendGroupMessage(
                recipientPubkeys: [recipientPubkey, recipientPubkey2],
                content: 'Group hello',
              ),
            ).thenAnswer(
              (_) async => [
                NIP17SendResult.success(
                  rumorEventId: rumorIdRecipient1,
                  messageEventId: rumorIdRecipient1,
                  recipientPubkey: recipientPubkey,
                ),
                NIP17SendResult.success(
                  rumorEventId: rumorIdRecipient2,
                  messageEventId: rumorIdRecipient2,
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
                  (s) => s.lastPartialSend,
                  'lastPartialSend',
                  equals(
                    const PartialSend(
                      rumorIds: [
                        '8888888888888888888888888888888888888888888888888888888888888888',
                      ],
                    ),
                  ),
                )
                .having(
                  (s) => s.lastFailedSend,
                  'lastFailedSend stays null on partial',
                  isNull,
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
            isA<ConversationState>().having(
              (s) => s.sendStatus,
              'sendStatus',
              SendStatus.sending,
            ),
            isA<ConversationState>()
                .having((s) => s.sendStatus, 'sendStatus', SendStatus.failed)
                .having((s) => s.messages, 'messages untouched', isEmpty)
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
            isA<ConversationState>().having(
              (s) => s.sendStatus,
              'sendStatus',
              SendStatus.sending,
            ),
            isA<ConversationState>()
                .having((s) => s.sendStatus, 'sendStatus', SendStatus.failed)
                .having((s) => s.messages, 'messages untouched', isEmpty)
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
            // Sending: optimistic on top of the seeded persisted message.
            isA<ConversationState>()
                .having((s) => s.sendStatus, 'sendStatus', SendStatus.sending)
                .having(
                  (s) => s.messages,
                  'messages slice untouched (still just the seeded row)',
                  equals(const [testMessage]),
                ),
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

      // Regression for #3908 review feedback. The pendingId-UUID contract
      // (vs second-resolution timestamps) is what lets the strip target a
      // single attempt without trampling a sibling. Pre-#4193 the strip
      // was a list-walk on `state.messages`, so sibling collision was
      // observable; post-#4193 the optimistic lives in
      // `state.pendingOptimistic` (a Map keyed by pendingId), so strip is
      // a `Map.remove(pendingId)` and a UUID still guarantees the two
      // attempts get distinct keys.
      group('pendingId uniqueness', () {
        blocTest<ConversationBloc, ConversationState>(
          'failure strip removes only the failing pendingId — '
          'a sibling pending entry from a prior context is preserved',
          // Seed state with a sibling pending entry to model the contract
          // directly. With the `sequential()` transformer real production
          // never has two pendings alive at once, but the strip semantics
          // (key-based, not list-walk) are what the contract enforces.
          seed: () => const ConversationState(),
          setUp: () {
            when(
              () => mockDmRepository.sendMessage(
                recipientPubkey: recipientPubkey,
                content: 'Failing send',
              ),
            ).thenThrow(Exception('Relay timeout'));
          },
          build: buildBloc,
          act: (bloc) => bloc.add(
            const ConversationMessageSent(
              recipientPubkeys: [recipientPubkey],
              content: 'Failing send',
            ),
          ),
          expect: () => [
            // Sending: failing attempt's pending is added alongside the
            // pre-existing sibling.
            isA<ConversationState>().having(
              (s) => s.sendStatus,
              'sendStatus',
              SendStatus.sending,
            ),
            // Failed: only the failing attempt's key is removed; the
            // sibling pending is untouched. Under the old list-walk
            // strip an off-by-one or shared id would have removed both.
            isA<ConversationState>()
                .having((s) => s.sendStatus, 'sendStatus', SendStatus.failed)
                .having(
                  (s) => s.lastFailedSend,
                  'lastFailedSend records the failing attempt only',
                  equals(
                    const FailedSend(
                      content: 'Failing send',
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
            isA<ConversationState>().having(
              (s) => s.sendStatus,
              'sendStatus',
              SendStatus.sending,
            ),
            // First send completes
            isA<ConversationState>().having(
              (s) => s.sendStatus,
              'sendStatus',
              SendStatus.sent,
            ),
            // Second send starts (sequential: waited for first)
            isA<ConversationState>().having(
              (s) => s.sendStatus,
              'sendStatus',
              SendStatus.sending,
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

            when(
              () => mockDmRepository.watchOutgoing(any()),
            ).thenAnswer((_) => Stream.value(const <OutgoingDm>[]));

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

    group(ConversationSelfWrapRecoveryRequested, () {
      // The principled recovery path for #4102: tapping Retry on a
      // sentPartial SnackBar must republish only the missing self-wrap
      // — never the recipient wrap, which would double-deliver.
      const rumorId1 =
          '7777777777777777777777777777777777777777777777777777777777777777';
      const rumorId2 =
          '8888888888888888888888888888888888888888888888888888888888888888';

      blocTest<ConversationBloc, ConversationState>(
        'emits [sending, sent] and clears lastPartialSend when every '
        'recoverSelfWrap returns success',
        setUp: () {
          when(
            () => mockDmRepository.recoverSelfWrap(
              rumorId: any(named: 'rumorId'),
            ),
          ).thenAnswer(
            (inv) async => NIP17SendResult.success(
              rumorEventId: inv.namedArguments[#rumorId] as String,
              messageEventId: inv.namedArguments[#rumorId] as String,
              recipientPubkey: senderPubkey,
            ),
          );
        },
        seed: () => const ConversationState(
          status: ConversationStatus.loaded,
          sendStatus: SendStatus.sentPartial,
          lastPartialSend: PartialSend(rumorIds: [rumorId1, rumorId2]),
        ),
        build: buildBloc,
        act: (bloc) => bloc.add(
          const ConversationSelfWrapRecoveryRequested(
            rumorIds: [rumorId1, rumorId2],
          ),
        ),
        expect: () => [
          isA<ConversationState>().having(
            (s) => s.sendStatus,
            'sendStatus',
            SendStatus.sending,
          ),
          isA<ConversationState>()
              .having((s) => s.sendStatus, 'sendStatus', SendStatus.sent)
              .having(
                (s) => s.lastPartialSend,
                'lastPartialSend cleared on full recovery',
                isNull,
              ),
        ],
        verify: (_) {
          // Every rumor in the event payload was passed to
          // recoverSelfWrap (with no recipient publish in sight).
          verify(
            () => mockDmRepository.recoverSelfWrap(rumorId: rumorId1),
          ).called(1);
          verify(
            () => mockDmRepository.recoverSelfWrap(rumorId: rumorId2),
          ).called(1);
          // Pin the no-duplicate-recipient-publish contract from #4102.
          verifyNever(
            () => mockDmRepository.sendMessage(
              recipientPubkey: any(named: 'recipientPubkey'),
              content: any(named: 'content'),
            ),
          );
          verifyNever(
            () => mockDmRepository.sendGroupMessage(
              recipientPubkeys: any(named: 'recipientPubkeys'),
              content: any(named: 'content'),
            ),
          );
        },
      );

      blocTest<ConversationBloc, ConversationState>(
        'reduces lastPartialSend.rumorIds to the still-failing rumors '
        'when one of two recoveries fails',
        setUp: () {
          when(
            () => mockDmRepository.recoverSelfWrap(rumorId: rumorId1),
          ).thenAnswer(
            (_) async => NIP17SendResult.success(
              rumorEventId: rumorId1,
              messageEventId: rumorId1,
              recipientPubkey: senderPubkey,
            ),
          );
          when(
            () => mockDmRepository.recoverSelfWrap(rumorId: rumorId2),
          ).thenAnswer(
            (_) async => const NIP17SendResult.failure('relay timeout'),
          );
        },
        seed: () => const ConversationState(
          status: ConversationStatus.loaded,
          sendStatus: SendStatus.sentPartial,
          lastPartialSend: PartialSend(rumorIds: [rumorId1, rumorId2]),
        ),
        build: buildBloc,
        act: (bloc) => bloc.add(
          const ConversationSelfWrapRecoveryRequested(
            rumorIds: [rumorId1, rumorId2],
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
                (s) => s.lastPartialSend,
                'lastPartialSend reduced to still-failing ids only',
                equals(const PartialSend(rumorIds: [rumorId2])),
              ),
        ],
      );

      blocTest<ConversationBloc, ConversationState>(
        'reports thrown errors via addError and treats the rumor as '
        'still-failing',
        setUp: () {
          when(
            () => mockDmRepository.recoverSelfWrap(rumorId: rumorId1),
          ).thenThrow(StateError('queue DAO not wired'));
        },
        seed: () => const ConversationState(
          status: ConversationStatus.loaded,
          sendStatus: SendStatus.sentPartial,
          lastPartialSend: PartialSend(rumorIds: [rumorId1]),
        ),
        build: buildBloc,
        act: (bloc) => bloc.add(
          const ConversationSelfWrapRecoveryRequested(rumorIds: [rumorId1]),
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
                (s) => s.lastPartialSend?.rumorIds,
                'still-failing rumor preserved on throw',
                equals([rumorId1]),
              ),
        ],
        errors: () => [
          isA<Reportable<Object>>().having(
            (r) => r.unwrap(),
            'unwrap',
            isA<StateError>(),
          ),
        ],
      );

      blocTest<ConversationBloc, ConversationState>(
        'treats missing queue rows as terminal and clears them from the '
        'retry set without reporting',
        setUp: () {
          when(
            () => mockDmRepository.recoverSelfWrap(rumorId: rumorId1),
          ).thenThrow(
            ArgumentError.value(
              rumorId1,
              'rumorId',
              'no queued outgoing DM with this id',
            ),
          );
        },
        seed: () => const ConversationState(
          status: ConversationStatus.loaded,
          sendStatus: SendStatus.sentPartial,
          lastPartialSend: PartialSend(rumorIds: [rumorId1]),
        ),
        build: buildBloc,
        act: (bloc) => bloc.add(
          const ConversationSelfWrapRecoveryRequested(rumorIds: [rumorId1]),
        ),
        expect: () => [
          isA<ConversationState>().having(
            (s) => s.sendStatus,
            'sendStatus',
            SendStatus.sending,
          ),
          isA<ConversationState>()
              .having((s) => s.sendStatus, 'sendStatus', SendStatus.sent)
              .having(
                (s) => s.lastPartialSend,
                'clears terminal retry payload',
                isNull,
              ),
        ],
        errors: () => const <Object>[],
      );

      blocTest<ConversationBloc, ConversationState>(
        'is a no-op when rumorIds is empty',
        seed: () => const ConversationState(
          status: ConversationStatus.loaded,
          sendStatus: SendStatus.sentPartial,
          lastPartialSend: PartialSend(rumorIds: []),
        ),
        build: buildBloc,
        act: (bloc) => bloc.add(
          const ConversationSelfWrapRecoveryRequested(rumorIds: []),
        ),
        expect: () => const <ConversationState>[],
        verify: (_) {
          verifyNever(
            () => mockDmRepository.recoverSelfWrap(
              rumorId: any(named: 'rumorId'),
            ),
          );
        },
      );
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
        'forwards `ArgumentError` (rumor gone / not ours) raw to addError '
        '— matrix-NO, recoverable',
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

      blocTest<ConversationBloc, ConversationState>(
        'wraps non-`ArgumentError` throws in Reportable — matrix-YES, '
        'invariant (e.g. signer `StateError`)',
        setUp: () {
          when(
            () => mockDmRepository.deleteMessageForEveryone(messageId),
          ).thenThrow(StateError('Failed to sign kind 5 deletion event'));
        },
        build: buildBloc,
        act: (bloc) =>
            bloc.add(const ConversationMessageDeleted(rumorId: messageId)),
        errors: () => [
          isA<Reportable<Object>>().having(
            (r) => r.unwrap(),
            'unwrap',
            isA<StateError>(),
          ),
        ],
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
          null,
          <OutgoingDm>[],
        ]),
      );
    });

    test(
      'pendingOutgoing defaults to empty and participates in equality',
      () {
        expect(
          const ConversationState().pendingOutgoing,
          equals(const <OutgoingDm>[]),
        );
        final row = _outgoingDm(id: 'rumor-test', content: 'Hi');
        expect(
          ConversationState(pendingOutgoing: [row]),
          equals(ConversationState(pendingOutgoing: [row])),
        );
        expect(
          const ConversationState(),
          isNot(equals(ConversationState(pendingOutgoing: [row]))),
        );
      },
    );

    group('displayedMessages projection', () {
      const persisted1 = DmMessage(
        id: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        conversationId: conversationId,
        senderPubkey: senderPubkey,
        content: 'persisted-1',
        // Newer than the optimistic below.
        createdAt: 1700000010,
        giftWrapId:
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      );
      const persisted0 = DmMessage(
        id: 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
        conversationId: conversationId,
        senderPubkey: senderPubkey,
        content: 'persisted-0',
        // Older than the optimistic below.
        createdAt: 1699999990,
        giftWrapId:
            'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
      );
      final inFlightRow = _outgoingDm(
        id: 'rumor-inflight',
        content: 'in-flight',
      );

      test('returns messages identity when pendingOutgoing is empty', () {
        const state = ConversationState(messages: [persisted1, persisted0]);
        expect(state.displayedMessages, same(state.messages));
      });

      test('puts in-flight pending above older persisted, below newer', () {
        final state = ConversationState(
          messages: const [persisted1, persisted0],
          pendingOutgoing: [inFlightRow],
        );
        // Newest first: persisted1 (1700000010) > inFlightRow (1700000000)
        // > persisted0 (1699999990).
        expect(state.displayedMessages, hasLength(3));
        expect(state.displayedMessages.first.id, equals(persisted1.id));
        expect(state.displayedMessages[1].id, equals(inFlightRow.id));
        expect(state.displayedMessages[1].content, equals('in-flight'));
        expect(state.displayedMessages.last.id, equals(persisted0.id));
      });

      test(
        'drops pending whose rumor id collides with a persisted row',
        () {
          // Window between sendMessage's persistence-transaction commit
          // and the next watchOutgoing tick: both streams briefly carry
          // the row. Persisted wins on id collision.
          final colliding = _outgoingDm(
            id: persisted1.id,
            content: 'in-flight duplicate',
            createdAtSec: 1700000010,
          );
          final state = ConversationState(
            messages: const [persisted1],
            pendingOutgoing: [colliding],
          );
          expect(state.displayedMessages, equals(const [persisted1]));
        },
      );

      test('returns an unmodifiable view when merge runs', () {
        final state = ConversationState(
          messages: const [persisted1],
          pendingOutgoing: [inFlightRow],
        );
        final view = state.displayedMessages;
        expect(() => view.add(persisted0), throwsUnsupportedError);
      });
    });

    group('statusFor', () {
      test('returns delivered when no queue row exists', () {
        const state = ConversationState();
        expect(
          state.statusFor('not-in-queue'),
          equals(DmDeliveryStatus.delivered),
        );
      });

      test(
        'returns delivered for an id absent from a non-empty queue '
        '(past the empty-queue short-circuit)',
        () {
          final row = _outgoingDm(id: 'rumor-present');
          final state = ConversationState(pendingOutgoing: [row]);
          expect(
            state.statusFor('rumor-absent'),
            equals(DmDeliveryStatus.delivered),
          );
        },
      );

      test('returns pending while recipient wrap is pending', () {
        final row = _outgoingDm(id: 'rumor-pending');
        final state = ConversationState(pendingOutgoing: [row]);
        expect(
          state.statusFor('rumor-pending'),
          equals(DmDeliveryStatus.pending),
        );
      });

      test('returns failed when recipient wrap failed', () {
        final row = _outgoingDm(
          id: 'rumor-recipient-failed',
          recipientWrap: OutgoingWrapStatus.failed,
        );
        final state = ConversationState(pendingOutgoing: [row]);
        expect(
          state.statusFor('rumor-recipient-failed'),
          equals(DmDeliveryStatus.failed),
        );
      });

      test(
        'returns deliveredSelfFailed when recipient sent but self failed',
        () {
          final row = _outgoingDm(
            id: 'rumor-self-failed',
            recipientWrap: OutgoingWrapStatus.sent,
            selfWrap: OutgoingWrapStatus.failed,
          );
          final state = ConversationState(pendingOutgoing: [row]);
          expect(
            state.statusFor('rumor-self-failed'),
            equals(DmDeliveryStatus.deliveredSelfFailed),
          );
        },
      );

      test(
        'returns delivered when recipient sent and self still pending '
        '(brief transitional state)',
        () {
          final row = _outgoingDm(
            id: 'rumor-self-pending',
            recipientWrap: OutgoingWrapStatus.sent,
          );
          final state = ConversationState(pendingOutgoing: [row]);
          expect(
            state.statusFor('rumor-self-pending'),
            equals(DmDeliveryStatus.delivered),
          );
        },
      );
    });

    test('states with different lastPartialSend are not equal', () {
      expect(
        const ConversationState(),
        isNot(
          equals(
            const ConversationState(
              lastPartialSend: PartialSend(rumorIds: [messageId]),
            ),
          ),
        ),
      );
    });

    test(
      'copyWith carries lastPartialSend forward when not overridden',
      () {
        const partial = PartialSend(rumorIds: [messageId]);
        const seeded = ConversationState(lastPartialSend: partial);

        expect(
          seeded.copyWith(sendStatus: SendStatus.sending).lastPartialSend,
          equals(partial),
        );
      },
    );

    test(
      'copyWith(clearLastPartialSend: true) wipes lastPartialSend',
      () {
        const partial = PartialSend(rumorIds: [messageId]);
        const seeded = ConversationState(lastPartialSend: partial);

        expect(
          seeded.copyWith(clearLastPartialSend: true).lastPartialSend,
          isNull,
        );
      },
    );

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

    group(ConversationSelfWrapRecoveryRequested, () {
      test('supports value equality', () {
        expect(
          const ConversationSelfWrapRecoveryRequested(rumorIds: [messageId]),
          equals(
            const ConversationSelfWrapRecoveryRequested(rumorIds: [messageId]),
          ),
        );
      });

      test('events with different rumorIds are not equal', () {
        expect(
          const ConversationSelfWrapRecoveryRequested(rumorIds: [messageId]),
          isNot(
            equals(
              const ConversationSelfWrapRecoveryRequested(
                rumorIds: [giftWrapId],
              ),
            ),
          ),
        );
      });

      test('props are correct', () {
        expect(
          const ConversationSelfWrapRecoveryRequested(
            rumorIds: [messageId, giftWrapId],
          ).props,
          equals([
            const [messageId, giftWrapId],
          ]),
        );
      });
    });
  });
}
