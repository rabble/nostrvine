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

    group('push control diagnostics metadata', () {
      test(
        'marks push registration, deregistration, and preferences kinds',
        () {
          for (final kind in [3079, 3080, 3083]) {
            final tracker = PublishTracker(
              eventId: 'push-control-$kind',
              eventKind: kind,
              expectedRelays: {'wss://relay.divine.video'},
              timeout: const Duration(seconds: 30),
            );

            expect(tracker.isPushControlEvent, isTrue);
            tracker.cancel();
          }
        },
      );

      test('does not mark unrelated event kinds as push control events', () {
        final tracker = PublishTracker(
          eventId: 'note-1',
          eventKind: 1,
          expectedRelays: {'wss://relay.divine.video'},
          timeout: const Duration(seconds: 30),
        );

        expect(tracker.isPushControlEvent, isFalse);
        tracker.cancel();
      });

      test('propagates event kind to publish outcome', () async {
        final tracker = PublishTracker(
          eventId: 'push-control-accepted',
          eventKind: 3079,
          expectedRelays: {'wss://relay.divine.video'},
          timeout: const Duration(seconds: 30),
        );

        tracker.onAccepted('wss://relay.divine.video');
        final outcome = await tracker.future;

        expect(outcome.eventKind, equals(3079));
      });
    });
  });
}
