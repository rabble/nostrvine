// ABOUTME: Unit tests for PublishOutcome value type.

import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:test/test.dart';

void main() {
  group(PublishOutcome, () {
    test('acceptedByAll returns true when every relay accepted', () {
      final outcome = PublishOutcome(
        eventId: 'event-id-1',
        acceptedBy: const {'wss://a', 'wss://b'},
        rejectedBy: const {},
        noResponseFrom: const {},
      );

      expect(outcome.acceptedByAll, isTrue);
      expect(outcome.acceptedByAny, isTrue);
      expect(outcome.failed, isFalse);
    });

    test('acceptedByAny true when at least one accepts, even with rejects', () {
      final outcome = PublishOutcome(
        eventId: 'event-id-2',
        acceptedBy: const {'wss://a'},
        rejectedBy: const {'wss://b': 'blocked: spam'},
        noResponseFrom: const {},
      );

      expect(outcome.acceptedByAny, isTrue);
      expect(outcome.acceptedByAll, isFalse);
      expect(outcome.failed, isFalse);
    });

    test('failed true when no relay accepted', () {
      final outcome = PublishOutcome(
        eventId: 'event-id-3',
        acceptedBy: const {},
        rejectedBy: const {'wss://a': 'invalid: sig'},
        noResponseFrom: const {'wss://b'},
      );

      expect(outcome.failed, isTrue);
      expect(outcome.acceptedByAny, isFalse);
    });

    test('transientRelays = noResponseFrom plus rejectedBy with retryable '
        'reason prefixes', () {
      final outcome = PublishOutcome(
        eventId: 'event-id-4',
        acceptedBy: const {},
        rejectedBy: const {
          'wss://permanent': 'blocked: user',
          'wss://transient': 'error: temporarily unavailable',
          'wss://auth': 'auth-required: challenge',
          'wss://rate': 'rate-limited: too fast',
        },
        noResponseFrom: const {'wss://silent'},
      );

      expect(outcome.transientRelays, {'wss://transient', 'wss://silent'});
    });

    test('permanently rejected prefixes do NOT appear in transientRelays', () {
      final outcome = PublishOutcome(
        eventId: 'event-id-5',
        acceptedBy: const {},
        rejectedBy: const {
          'wss://blocked': 'blocked: banned',
          'wss://invalid': 'invalid: schema',
          'wss://pow': 'pow: insufficient difficulty',
          'wss://restricted': 'restricted: paid relay',
        },
        noResponseFrom: const {},
      );

      expect(outcome.transientRelays, isEmpty);
    });

    test('asserts disjoint sets — same relay in both acceptedBy and rejectedBy',
        () {
      expect(
        () => PublishOutcome(
          eventId: 'a' * 64,
          acceptedBy: const {'wss://a'},
          rejectedBy: const {'wss://a': 'rejected'},
          noResponseFrom: const {},
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('preserves full event id (no truncation) in toString', () {
      // Nostr event id is 64 hex chars — literal here since Dart `const`
      // context doesn't allow `'a' * 64`.
      const fullId =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      final outcome = PublishOutcome(
        eventId: fullId,
        acceptedBy: const {},
        rejectedBy: const {},
        noResponseFrom: const {},
      );

      expect(outcome.toString(), contains(fullId));
    });
  });
}
