// ABOUTME: Reliability tests for ConversationBloc pending/failed flow
// ABOUTME: — per-message sendStatus, feedback propagation, and Retry
// ABOUTME: event handling.

import 'package:bloc_test/bloc_test.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/blocs/dm/conversation/conversation_bloc.dart';

class _MockDmRepository extends Mock implements DmRepository {}

PublishOutcome _transientFailure() {
  return PublishOutcome(
    eventId: 'a' * 64,
    acceptedBy: const {},
    rejectedBy: const {},
    noResponseFrom: const {'wss://a', 'wss://b'},
  );
}

PublishOutcome _permanentRejection() {
  return PublishOutcome(
    eventId: 'a' * 64,
    acceptedBy: const {},
    rejectedBy: const {'wss://a': 'blocked: spam'},
    noResponseFrom: const {},
  );
}

PublishOutcome _accepted() {
  return PublishOutcome(
    eventId: 'a' * 64,
    acceptedBy: const {'wss://ok'},
    rejectedBy: const {},
    noResponseFrom: const {},
  );
}

void main() {
  const conversationId =
      'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
  const senderPubkey =
      '1111111111111111111111111111111111111111111111111111111111111111';
  const recipientPubkey =
      '2222222222222222222222222222222222222222222222222222222222222222';
  const sentEventId =
      '6666666666666666666666666666666666666666666666666666666666666666';

  group('ConversationBloc reliability (per-message status)', () {
    late _MockDmRepository dmRepository;

    setUp(() {
      dmRepository = _MockDmRepository();
    });

    ConversationBloc build() => ConversationBloc(
      dmRepository: dmRepository,
      conversationId: conversationId,
      currentUserPubkey: senderPubkey,
    );

    blocTest<ConversationBloc, ConversationState>(
      'send success clears per-message sending status '
      '(optimistic → confirmed via stream)',
      setUp: () {
        when(
          () => dmRepository.sendMessage(
            recipientPubkey: recipientPubkey,
            content: 'Hi',
          ),
        ).thenAnswer(
          (_) async => NIP17SendResult.success(
            rumorEventId: sentEventId,
            messageEventId: sentEventId,
            recipientPubkey: recipientPubkey,
            outcome: _accepted(),
          ),
        );
      },
      build: build,
      act: (bloc) => bloc.add(
        const ConversationMessageSent(
          recipientPubkeys: [recipientPubkey],
          content: 'Hi',
        ),
      ),
      expect: () => [
        // Optimistic: sending row present, bubble icon = clock
        isA<ConversationState>()
            .having(
              (s) => s.sendStatus,
              'aggregate sendStatus',
              SendStatus.sending,
            )
            .having(
              (s) => s.sendStatusByMessageId.values,
              'per-message statuses',
              [MessageSendStatus.sending],
            )
            .having(
              (s) => s.messages.first.content,
              'optimistic content',
              'Hi',
            ),
        // Success: per-message status cleared (row awaits stream
        // confirmation via watchMessages), feedback empty
        isA<ConversationState>()
            .having(
              (s) => s.sendStatus,
              'aggregate sendStatus',
              SendStatus.sent,
            )
            .having(
              (s) => s.sendStatusByMessageId,
              'per-message statuses',
              isEmpty,
            )
            .having(
              (s) => s.feedbackByMessageId,
              'feedback',
              isEmpty,
            ),
      ],
    );

    blocTest<ConversationBloc, ConversationState>(
      'send failure — transient → per-message failed + retryable feedback',
      setUp: () {
        when(
          () => dmRepository.sendMessage(
            recipientPubkey: recipientPubkey,
            content: 'Hi',
          ),
        ).thenAnswer(
          (_) async => NIP17SendResult.failure(
            'publish failed',
            outcome: _transientFailure(),
          ),
        );
      },
      build: build,
      act: (bloc) => bloc.add(
        const ConversationMessageSent(
          recipientPubkeys: [recipientPubkey],
          content: 'Hi',
        ),
      ),
      expect: () => [
        isA<ConversationState>()
            .having(
              (s) => s.sendStatus,
              'aggregate',
              SendStatus.sending,
            )
            .having(
              (s) => s.sendStatusByMessageId.values,
              'per-message',
              [MessageSendStatus.sending],
            ),
        isA<ConversationState>()
            .having(
              (s) => s.sendStatus,
              'aggregate',
              SendStatus.failed,
            )
            .having(
              (s) => s.sendStatusByMessageId.values,
              'per-message',
              [MessageSendStatus.failed],
            )
            .having(
              (s) => s.feedbackByMessageId.values.first.retryable,
              'retryable',
              isTrue,
            )
            .having(
              (s) => s.feedbackByMessageId.values.first.messageKey,
              'messageKey',
              'publish_no_relay_response',
            ),
      ],
      errors: () => [isA<Exception>()],
    );

    blocTest<ConversationBloc, ConversationState>(
      'send failure — permanent rejection → non-retryable feedback '
      'with rejection reason surfaced',
      setUp: () {
        when(
          () => dmRepository.sendMessage(
            recipientPubkey: recipientPubkey,
            content: 'Hi',
          ),
        ).thenAnswer(
          (_) async => NIP17SendResult.failure(
            'rejected',
            outcome: _permanentRejection(),
          ),
        );
      },
      build: build,
      act: (bloc) => bloc.add(
        const ConversationMessageSent(
          recipientPubkeys: [recipientPubkey],
          content: 'Hi',
        ),
      ),
      skip: 1, // skip sending state
      expect: () => [
        isA<ConversationState>()
            .having(
              (s) => s.feedbackByMessageId.values.first.retryable,
              'retryable',
              isFalse,
            )
            .having(
              (s) => s.feedbackByMessageId.values.first.firstRejectionReason,
              'rejection reason',
              contains('blocked'),
            ),
      ],
      errors: () => [isA<Exception>()],
    );

    blocTest<ConversationBloc, ConversationState>(
      'retry clears failure feedback and flips bubble back to sending',
      setUp: () {
        // First call fails transient, retry succeeds.
        var callCount = 0;
        when(
          () => dmRepository.sendMessage(
            recipientPubkey: recipientPubkey,
            content: 'Hi',
          ),
        ).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) {
            return NIP17SendResult.failure(
              'transient',
              outcome: _transientFailure(),
            );
          }
          return NIP17SendResult.success(
            rumorEventId: sentEventId,
            messageEventId: sentEventId,
            recipientPubkey: recipientPubkey,
            outcome: _accepted(),
          );
        });
      },
      build: build,
      act: (bloc) async {
        bloc.add(
          const ConversationMessageSent(
            recipientPubkeys: [recipientPubkey],
            content: 'Hi',
          ),
        );
        // Let the first send finish (sending → failed).
        await Future<void>.delayed(const Duration(milliseconds: 20));
        // Grab the pending id off the current state and retry it.
        final pendingId = bloc.state.sendStatusByMessageId.keys.first;
        bloc.add(
          ConversationMessageRetried(
            pendingId: pendingId,
            recipientPubkeys: const [recipientPubkey],
            content: 'Hi',
          ),
        );
      },
      wait: const Duration(milliseconds: 100),
      verify: (bloc) {
        // After retry success, per-message status is cleared and
        // feedback is gone.
        expect(bloc.state.sendStatusByMessageId, isEmpty);
        expect(bloc.state.feedbackByMessageId, isEmpty);
        verify(
          () => dmRepository.sendMessage(
            recipientPubkey: recipientPubkey,
            content: 'Hi',
          ),
        ).called(2);
      },
      errors: () => [isA<Exception>()],
    );

    blocTest<ConversationBloc, ConversationState>(
      'exception thrown by repository marks pending-id failed '
      'with generic retryable feedback',
      setUp: () {
        when(
          () => dmRepository.sendMessage(
            recipientPubkey: recipientPubkey,
            content: 'Hi',
          ),
        ).thenThrow(Exception('network down'));
      },
      build: build,
      act: (bloc) => bloc.add(
        const ConversationMessageSent(
          recipientPubkeys: [recipientPubkey],
          content: 'Hi',
        ),
      ),
      verify: (bloc) {
        expect(
          bloc.state.sendStatusByMessageId.values,
          [MessageSendStatus.failed],
        );
        expect(
          bloc.state.feedbackByMessageId.values.first.retryable,
          isTrue,
        );
      },
      errors: () => [isA<Exception>()],
    );
  });
}
