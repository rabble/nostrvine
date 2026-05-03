// ABOUTME: Tests for NIP17SendResult including the per-wrap status
// ABOUTME: surfaced for the DM outgoing-message queue (#3909).

import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  const rumorEventId =
      '1111111111111111111111111111111111111111111111111111111111111111';
  const messageEventId =
      '2222222222222222222222222222222222222222222222222222222222222222';
  const recipientPubkey =
      '3333333333333333333333333333333333333333333333333333333333333333';

  group(NIP17SendResult, () {
    group('success factory', () {
      test('defaults selfWrapPublished to true for backward compatibility', () {
        final result = NIP17SendResult.success(
          rumorEventId: rumorEventId,
          messageEventId: messageEventId,
          recipientPubkey: recipientPubkey,
        );

        expect(result.success, isTrue);
        expect(result.rumorEventId, equals(rumorEventId));
        expect(result.messageEventId, equals(messageEventId));
        expect(result.recipientPubkey, equals(recipientPubkey));
        expect(result.error, isNull);
        expect(result.timestamp, isNotNull);
        expect(
          result.selfWrapPublished,
          isTrue,
          reason:
              'Pre-existing call sites do not pass selfWrapPublished. '
              'The default must keep them in the fully-delivered state '
              'to avoid spurious "partial delivery" UX after the field '
              'was added.',
        );
      });

      test(
        'preserves selfWrapPublished=false when explicitly passed '
        '(NIP17MessageService partial-delivery path)',
        () {
          final result = NIP17SendResult.success(
            rumorEventId: rumorEventId,
            messageEventId: messageEventId,
            recipientPubkey: recipientPubkey,
            selfWrapPublished: false,
          );

          expect(result.success, isTrue);
          expect(result.selfWrapPublished, isFalse);
        },
      );
    });

    group('failure factory', () {
      test('builds a failure result with error and no message ids', () {
        final result = NIP17SendResult.failure('publish to relays failed');

        expect(result.success, isFalse);
        expect(result.error, equals('publish to relays failed'));
        expect(result.rumorEventId, isNull);
        expect(result.messageEventId, isNull);
        expect(result.recipientPubkey, isNull);
        expect(result.timestamp, isNull);
      });

      test(
        'leaves selfWrapPublished at the const-default true; the field is '
        'unused on the failure branch (recipient publish never landed, '
        'self-wrap is never attempted)',
        () {
          final result = NIP17SendResult.failure('publish to relays failed');

          expect(result.success, isFalse);
          // Documented as "unused when success=false"; the test pins
          // the default so unrelated changes to the constructor do not
          // accidentally flip its meaning.
          expect(result.selfWrapPublished, isTrue);
        },
      );
    });

    group('toString', () {
      test('success path includes selfWrapPublished status', () {
        final result = NIP17SendResult.success(
          rumorEventId: rumorEventId,
          messageEventId: messageEventId,
          recipientPubkey: recipientPubkey,
          selfWrapPublished: false,
        );

        expect(result.toString(), contains('selfWrapPublished: false'));
        expect(result.toString(), contains('success: true'));
      });

      test('failure path omits selfWrapPublished and shows error', () {
        final result = NIP17SendResult.failure('relay timeout');

        expect(result.toString(), contains('success: false'));
        expect(result.toString(), contains('error: relay timeout'));
        expect(result.toString(), isNot(contains('selfWrapPublished')));
      });
    });
  });
}
