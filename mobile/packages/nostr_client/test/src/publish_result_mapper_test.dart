// ABOUTME: Tests for PublishResultMapper - canonical outcome → UX decision.

import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:test/test.dart';

void main() {
  group(PublishResultMapper, () {
    test('accepted by all → success, not retryable', () {
      final fb = PublishResultMapper.map(
        PublishOutcome(
          eventId: 'a' * 64,
          acceptedBy: const {'wss://a', 'wss://b'},
          rejectedBy: const {},
          noResponseFrom: const {},
        ),
      );
      expect(fb.severity, PublishSeverity.success);
      expect(fb.retryable, isFalse);
      expect(fb.messageKey, 'publish_success');
    });

    test('partial accept → success (durable on one relay)', () {
      final fb = PublishResultMapper.map(
        PublishOutcome(
          eventId: 'a' * 64,
          acceptedBy: const {'wss://a'},
          rejectedBy: const {'wss://b': 'blocked: banned'},
          noResponseFrom: const {'wss://c'},
        ),
      );
      expect(fb.severity, PublishSeverity.success);
      expect(fb.retryable, isFalse);
    });

    test('all transient → error, retryable', () {
      final fb = PublishResultMapper.map(
        PublishOutcome(
          eventId: 'a' * 64,
          acceptedBy: const {},
          rejectedBy: const {},
          noResponseFrom: const {'wss://a', 'wss://b'},
        ),
      );
      expect(fb.severity, PublishSeverity.error);
      expect(fb.retryable, isTrue);
      expect(fb.messageKey, 'publish_no_relay_response');
    });

    test('all permanent rejects → error, NOT retryable, reason surfaced', () {
      final fb = PublishResultMapper.map(
        PublishOutcome(
          eventId: 'a' * 64,
          acceptedBy: const {},
          rejectedBy: const {
            'wss://a': 'blocked: user',
            'wss://b': 'invalid: sig',
          },
          noResponseFrom: const {},
        ),
      );
      expect(fb.severity, PublishSeverity.error);
      expect(fb.retryable, isFalse);
      expect(fb.messageKey, 'publish_rejected_permanent');
      expect(
        fb.firstRejectionReason,
        anyOf('blocked: user', 'invalid: sig'),
      );
    });

    test('empty outcome (no targets) → error, retryable', () {
      final fb = PublishResultMapper.map(
        PublishOutcome(
          eventId: 'a' * 64,
          acceptedBy: const {},
          rejectedBy: const {},
          noResponseFrom: const {},
        ),
      );
      expect(fb.severity, PublishSeverity.error);
      expect(fb.retryable, isTrue);
      expect(fb.messageKey, 'publish_no_relays_available');
    });

    test('mixed transient + permanent → retryable (transient wins)', () {
      final fb = PublishResultMapper.map(
        PublishOutcome(
          eventId: 'a' * 64,
          acceptedBy: const {},
          rejectedBy: const {'wss://blocked': 'blocked: user'},
          noResponseFrom: const {'wss://silent'},
        ),
      );
      expect(fb.retryable, isTrue);
      expect(fb.messageKey, 'publish_no_relay_response');
    });
  });
}
