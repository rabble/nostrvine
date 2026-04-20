// ABOUTME: Unit tests for PublishTracker and PublishOutcome used to await
// ABOUTME: OK responses from relays when publishing events.

import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:test/test.dart';

void main() {
  group(PublishTracker, () {
    group('onAccepted', () {
      test('completes immediately once any relay confirms, leaving the rest in '
          'noResponseFrom', () async {
        final tracker = PublishTracker(
          eventId: 'event-1',
          expectedRelays: {'wss://a.example', 'wss://b.example'},
          timeout: const Duration(seconds: 30),
        );

        tracker.onAccepted('wss://a.example');
        final outcome = await tracker.future;

        expect(outcome.eventId, equals('event-1'));
        expect(outcome.confirmed, isTrue);
        expect(outcome.acceptedBy, equals(['wss://a.example']));
        expect(outcome.noResponseFrom, equals(['wss://b.example']));
      });
    });

    group('onRejected', () {
      test(
        'reports rejection reason and does not consider the publish confirmed',
        () async {
          final tracker = PublishTracker(
            eventId: 'event-2',
            expectedRelays: {'wss://only.example'},
            timeout: const Duration(seconds: 30),
          );

          tracker.onRejected('wss://only.example', 'blocked: policy');
          final outcome = await tracker.future;

          expect(outcome.failed, isTrue);
          expect(
            outcome.rejectedBy,
            equals({'wss://only.example': 'blocked: policy'}),
          );
          expect(outcome.summary, contains('blocked: policy'));
        },
      );
    });

    group('timeout', () {
      test(
        'completes with every relay in noResponseFrom when no response arrives',
        () async {
          final tracker = PublishTracker(
            eventId: 'event-3',
            expectedRelays: {'wss://a.example', 'wss://b.example'},
            timeout: const Duration(milliseconds: 20),
          );

          final outcome = await tracker.future;

          expect(outcome.failed, isTrue);
          expect(outcome.acceptedBy, isEmpty);
          expect(outcome.rejectedBy, isEmpty);
          expect(
            outcome.noResponseFrom,
            unorderedEquals(['wss://a.example', 'wss://b.example']),
          );
        },
      );
    });

    group('cancel', () {
      test('completes the tracker synchronously for pool shutdown', () async {
        final tracker = PublishTracker(
          eventId: 'event-4',
          expectedRelays: {'wss://only.example'},
          timeout: const Duration(seconds: 30),
        );

        tracker.cancel();
        final outcome = await tracker.future;

        expect(outcome.failed, isTrue);
        expect(outcome.noResponseFrom, equals(['wss://only.example']));
      });
    });
  });
}
