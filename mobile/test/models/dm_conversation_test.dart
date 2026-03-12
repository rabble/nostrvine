// ABOUTME: Unit tests for the DmConversation domain model.
// ABOUTME: Verifies equality, copyWith, and default values.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';

void main() {
  group(DmConversation, () {
    const pubkeyA =
        'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
    const pubkeyB =
        'b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3';
    const conversationId =
        'aabbccdd11223344aabbccdd11223344aabbccdd11223344aabbccdd11223344';

    DmConversation createConversation({
      String id = conversationId,
      List<String> participantPubkeys = const [],
      bool isGroup = false,
      int createdAt = 1700000000,
      String? lastMessageContent,
      int? lastMessageTimestamp,
      String? lastMessageSenderPubkey,
      String? subject,
      bool isRead = true,
    }) {
      return DmConversation(
        id: id,
        participantPubkeys: participantPubkeys.isEmpty
            ? [pubkeyA, pubkeyB]
            : participantPubkeys,
        isGroup: isGroup,
        createdAt: createdAt,
        lastMessageContent: lastMessageContent,
        lastMessageTimestamp: lastMessageTimestamp,
        lastMessageSenderPubkey: lastMessageSenderPubkey,
        subject: subject,
        isRead: isRead,
      );
    }

    group('equality', () {
      test('two identical instances are equal', () {
        final a = createConversation();
        final b = createConversation();

        expect(a, equals(b));
      });

      test('instances with different id are not equal', () {
        final a = createConversation();
        final b = createConversation(
          id:
              'ff00ff00ff00ff00ff00ff00ff00ff00'
              'ff00ff00ff00ff00ff00ff00ff00ff00',
        );

        expect(a, isNot(equals(b)));
      });
    });

    group('copyWith', () {
      test('returns new instance with updated field', () {
        final original = createConversation();
        final updated = original.copyWith(
          lastMessageContent: 'Hello!',
        );

        expect(updated.lastMessageContent, equals('Hello!'));
        expect(updated, isNot(equals(original)));
      });

      test('allows clearing nullable fields via clear flags', () {
        final original = createConversation(
          lastMessageContent: 'Hi there',
          lastMessageTimestamp: 1700000100,
          lastMessageSenderPubkey: pubkeyA,
          subject: 'Test Subject',
        );
        final updated = original.copyWith(
          clearLastMessageContent: true,
          clearLastMessageTimestamp: true,
          clearLastMessageSenderPubkey: true,
          clearSubject: true,
        );

        expect(updated.lastMessageContent, isNull);
        expect(updated.lastMessageTimestamp, isNull);
        expect(updated.lastMessageSenderPubkey, isNull);
        expect(updated.subject, isNull);
        // Non-nullable fields preserved
        expect(updated.id, equals(original.id));
        expect(updated.isRead, equals(original.isRead));
      });

      test('preserves unchanged fields', () {
        final original = createConversation(
          lastMessageContent: 'Hi there',
          lastMessageTimestamp: 1700000100,
          lastMessageSenderPubkey: pubkeyA,
          subject: 'Test Subject',
        );
        final updated = original.copyWith(isRead: false);

        expect(updated.id, equals(original.id));
        expect(
          updated.participantPubkeys,
          equals(original.participantPubkeys),
        );
        expect(updated.isGroup, equals(original.isGroup));
        expect(updated.createdAt, equals(original.createdAt));
        expect(
          updated.lastMessageContent,
          equals(original.lastMessageContent),
        );
        expect(
          updated.lastMessageTimestamp,
          equals(original.lastMessageTimestamp),
        );
        expect(
          updated.lastMessageSenderPubkey,
          equals(original.lastMessageSenderPubkey),
        );
        expect(updated.subject, equals(original.subject));
        expect(updated.isRead, isFalse);
      });
    });

    group('defaults', () {
      test('isRead defaults to true', () {
        final conversation = createConversation();

        expect(conversation.isRead, isTrue);
      });
    });
  });
}
