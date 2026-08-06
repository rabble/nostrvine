// ABOUTME: Tests RelayPool.queryByFilters' argument validation.
// ABOUTME: A per-relay entry with no filters would build a subscription that
// ABOUTME: matches nothing, so every event it received would be dropped.

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

void main() {
  group('RelayPool.queryByFilters', () {
    Relay dummyTempRelay(String url) => RelayBase(url, RelayStatus(url));

    late RelayPool pool;

    setUp(() {
      final signer = LocalNostrSigner(
        '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
      );
      pool = Nostr(signer, [], dummyTempRelay).relayPool;
    });

    test('rejects an empty map', () {
      expect(
        () => pool.queryByFilters(const {}, (_) {}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects a relay entry carrying no filters', () {
      // The sibling entry points (subscribe, query, addInitQuery) all reject
      // an empty filter list. queryByFilters checked only the outer map, so
      // this built a Subscription with nothing to match against — it sends a
      // filterless REQ, which many relays answer with everything, and then
      // drops every frame at the admission gate.
      expect(
        () => pool.queryByFilters(const {
          'wss://relay.example': <Map<String, dynamic>>[],
        }, (_) {}),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
