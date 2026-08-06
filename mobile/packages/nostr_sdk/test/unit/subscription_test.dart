// ABOUTME: Tests that Subscription parses its filters once, at construction.
// ABOUTME: matchesEvent gates every inbound frame, so an unparseable filter
// ABOUTME: must fail loudly at subscribe time rather than per event.

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

void main() {
  group(Subscription, () {
    const pubkey =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const otherPubkey =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

    test('rejects an unparseable filter at construction', () {
      // `kinds` holding strings is the shape a hand-built filter map takes
      // when it skips Filter.toJson. Parsing per event instead would push the
      // TypeError inside RelayPool's frame handler, whose catch-all would
      // swallow it — every event on the subscription silently dropped, no
      // error anywhere. Failing here names the offending caller instead.
      expect(
        () => Subscription([
          {
            'kinds': ['1'],
          },
        ], (_) {}),
        throwsA(isA<TypeError>()),
      );
    });

    test('matches on any one of several filters', () {
      final event = Event(pubkey, 7, const [], '+', createdAt: 1);

      final subscription = Subscription([
        Filter(kinds: const [1]).toJson(),
        Filter(kinds: const [7], authors: const [pubkey]).toJson(),
      ], (_) {});

      expect(subscription.matchesEvent(event), isTrue);
    });

    test('does not match an event outside every filter', () {
      final event = Event(pubkey, 7, const [], '+', createdAt: 1);

      final subscription = Subscription([
        Filter(kinds: const [1]).toJson(),
        Filter(kinds: const [7], authors: const [otherPubkey]).toJson(),
      ], (_) {});

      expect(subscription.matchesEvent(event), isFalse);
    });
  });
}
