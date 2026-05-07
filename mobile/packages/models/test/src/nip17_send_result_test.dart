// ABOUTME: Tests for NIP17SendResult including the per-wrap status
// ABOUTME: that surfaces partial delivery (recipient delivered but
// ABOUTME: self-wrap dropped); future retry handling tracked in #3909.

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

      test('preserves selfWrapPublished=false when explicitly passed '
          '(NIP17MessageService partial-delivery path)', () {
        final result = NIP17SendResult.success(
          rumorEventId: rumorEventId,
          messageEventId: messageEventId,
          recipientPubkey: recipientPubkey,
          selfWrapPublished: false,
        );

        expect(result.success, isTrue);
        expect(result.selfWrapPublished, isFalse);
      });
    });

    group('failure factory', () {
      test('builds a failure result with error and no message ids', () {
        const result = NIP17SendResult.failure('publish to relays failed');

        expect(result.success, isFalse);
        expect(result.error, equals('publish to relays failed'));
        expect(result.rumorEventId, isNull);
        expect(result.messageEventId, isNull);
        expect(result.recipientPubkey, isNull);
        expect(result.timestamp, isNull);
      });

      test('leaves selfWrapPublished as null on the failure branch — the '
          'field is meaningful only when success is true (self-wrap is '
          'never attempted when the recipient publish fails)', () {
        const result = NIP17SendResult.failure('publish to relays failed');

        expect(result.success, isFalse);
        // Sealed shape: NIP17SendFailure has no `selfWrapPublished`
        // field; the base getter returns `null`. A failure cannot
        // carry a misleading success-like `true` because the field
        // does not exist on this branch.
        expect(result.selfWrapPublished, isNull);
      });
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
        expect(result.toString(), startsWith('NIP17SendSuccess('));
      });

      test('failure path omits selfWrapPublished and shows error', () {
        const result = NIP17SendResult.failure('relay timeout');

        expect(result.toString(), startsWith('NIP17SendFailure('));
        expect(result.toString(), contains('error: relay timeout'));
        expect(result.toString(), isNot(contains('selfWrapPublished')));
      });
    });

    group('sealed shape', () {
      test('NIP17SendSuccess requires non-null selfWrapPublished at '
          'compile time — pin a runtime example so the test breaks '
          'loudly if someone changes the parameter to a default later', () {
        const result = NIP17SendSuccess(
          rumorEventId: rumorEventId,
          messageEventId: messageEventId,
          recipientPubkey: recipientPubkey,
          selfWrapPublished: true,
        );

        expect(result.selfWrapPublished, isTrue);
        expect(result.success, isTrue);
        expect(result, isA<NIP17SendResult>());
      });

      test('NIP17SendFailure does not expose selfWrapPublished', () {
        const result = NIP17SendFailure('boom');

        expect(result.selfWrapPublished, isNull);
        expect(result.success, isFalse);
        expect(result.error, equals('boom'));
        expect(result, isA<NIP17SendResult>());
      });

      test('factories produce the matching subclass', () {
        final success = NIP17SendResult.success(
          rumorEventId: rumorEventId,
          messageEventId: messageEventId,
          recipientPubkey: recipientPubkey,
        );
        expect(success, isA<NIP17SendSuccess>());
        expect(success, isNot(isA<NIP17SendFailure>()));

        const failure = NIP17SendResult.failure('boom');
        expect(failure, isA<NIP17SendFailure>());
        expect(failure, isNot(isA<NIP17SendSuccess>()));
      });

      test('exhaustive switch at the use site compiles and discriminates '
          'the variant', () {
        const result = NIP17SendResult.failure('x');
        final label = switch (result) {
          NIP17SendSuccess() => 'ok',
          NIP17SendFailure() => 'err',
        };
        expect(label, equals('err'));
      });

      test('value equality: identical successes are equal', () {
        final timestamp = DateTime(2026, 5, 7);
        final a = NIP17SendSuccess(
          rumorEventId: rumorEventId,
          messageEventId: messageEventId,
          recipientPubkey: recipientPubkey,
          selfWrapPublished: true,
          timestamp: timestamp,
        );
        final b = NIP17SendSuccess(
          rumorEventId: rumorEventId,
          messageEventId: messageEventId,
          recipientPubkey: recipientPubkey,
          selfWrapPublished: true,
          timestamp: timestamp,
        );

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('value equality: differing selfWrapPublished breaks equality', () {
        final timestamp = DateTime(2026, 5, 7);
        final fully = NIP17SendSuccess(
          rumorEventId: rumorEventId,
          messageEventId: messageEventId,
          recipientPubkey: recipientPubkey,
          selfWrapPublished: true,
          timestamp: timestamp,
        );
        final partially = NIP17SendSuccess(
          rumorEventId: rumorEventId,
          messageEventId: messageEventId,
          recipientPubkey: recipientPubkey,
          selfWrapPublished: false,
          timestamp: timestamp,
        );

        expect(fully, isNot(equals(partially)));
      });

      test('value equality: failures with same error are equal', () {
        expect(
          const NIP17SendFailure('boom'),
          equals(const NIP17SendFailure('boom')),
        );
        expect(
          const NIP17SendFailure('boom').hashCode,
          equals(const NIP17SendFailure('boom').hashCode),
        );
      });

      test('value equality: success and failure are never equal', () {
        final success = NIP17SendSuccess(
          rumorEventId: rumorEventId,
          messageEventId: messageEventId,
          recipientPubkey: recipientPubkey,
          selfWrapPublished: true,
          timestamp: DateTime(2026, 5, 7),
        );
        const failure = NIP17SendFailure('boom');

        expect(success, isNot(equals(failure)));
        expect(failure, isNot(equals(success)));
      });
    });
  });
}
