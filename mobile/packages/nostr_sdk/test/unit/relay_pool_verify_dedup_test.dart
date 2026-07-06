// ABOUTME: Regression tests for RelayPool._onEvent signature-verification
// ABOUTME: dedup and cache-relay trust (cold-start CPU optimization).

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';

/// A fake relay that lets tests drive `onMessage` directly and records
/// nothing else. No real network I/O.
class _FakeRelay extends Relay {
  _FakeRelay(String url, {int relayType = RelayType.normal})
    : super(url, RelayStatus(url, relayType: relayType));

  @override
  Future<bool> doConnect() async {
    relayStatus.connected = ClientConnected.connected;
    return true;
  }

  @override
  Future<void> disconnect() async {
    relayStatus.connected = ClientConnected.disconnect;
  }

  @override
  Future<bool> send(
    List<dynamic> message, {
    bool? forceSend,
    bool queueIfFailed = true,
    bool skipReconnect = false,
    DateTime? deadline,
  }) async {
    return true;
  }

  /// Drive an inbound message through the handler RelayPool wired up.
  Future<void> deliver(List<dynamic> json) async {
    final handler = onMessage;
    expect(handler, isNotNull, reason: 'RelayPool did not wire onMessage');
    final dynamic result = handler!(this, json);
    if (result is Future) {
      await result;
    }
  }
}

void main() {
  group('RelayPool._onEvent signature verify', () {
    const privateKey =
        '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
    const subId = 'sub-verify-dedup';
    // A 64-byte (128 hex char) but cryptographically invalid signature.
    const badSig =
        '0000000000000000000000000000000000000000000000000000000000000000'
        '0000000000000000000000000000000000000000000000000000000000000000';

    Relay dummyTempRelay(String url) => RelayBase(url, RelayStatus(url));

    late Nostr nostr;
    late List<Event> received;

    setUp(() {
      nostr = Nostr(LocalNostrSigner(privateKey), [], dummyTempRelay);
      received = <Event>[];
      nostr.relayPool.subscribe(
        [
          {
            'kinds': [EventKind.textNote],
          },
        ],
        received.add,
        id: subId,
      );
    });

    /// Builds a validly signed text-note event JSON for [content].
    Map<String, dynamic> signedEventJson({String content = 'hello'}) {
      final pubkey = getPublicKey(privateKey);
      final event = Event(
        pubkey,
        EventKind.textNote,
        [],
        content,
        createdAt: 1700000000,
      );
      event.sign(privateKey);
      return event.toJson();
    }

    test('routes a validly signed network event', () async {
      final relay = _FakeRelay('wss://n1.example');
      await nostr.relayPool.add(relay);

      await relay.deliver(['EVENT', subId, signedEventJson()]);

      expect(received, hasLength(1));
    });

    test('drops a network event with an invalid signature', () async {
      final relay = _FakeRelay('wss://n1.example');
      await nostr.relayPool.add(relay);

      final json = signedEventJson()..['sig'] = badSig;
      await relay.deliver(['EVENT', subId, json]);

      expect(received, isEmpty);
    });

    test('routes a duplicate id from a second relay (dedup skips verify, '
        'never drops)', () async {
      final r1 = _FakeRelay('wss://n1.example');
      final r2 = _FakeRelay('wss://n2.example');
      await nostr.relayPool.add(r1);
      await nostr.relayPool.add(r2);

      final json = signedEventJson();
      await r1.deliver(['EVENT', subId, json]);
      await r2.deliver(['EVENT', subId, Map<String, dynamic>.from(json)]);

      expect(received, hasLength(2));
    });

    test(
      'skips verify for ids known-verified from a previous session',
      () async {
        // The app seeds ids verified and persisted in a prior session. A
        // network event whose id is known — even with a bad signature here —
        // is trusted and routed without re-verifying.
        final relay = _FakeRelay('wss://n1.example');
        await nostr.relayPool.add(relay);

        final json = signedEventJson()..['sig'] = badSig;
        nostr.relayPool.isKnownVerifiedEvent = {json['id'] as String}.contains;

        await relay.deliver(['EVENT', subId, json]);

        expect(received, hasLength(1));
        expect(nostr.relayPool.verifiesSkippedKnown, 1);
        expect(nostr.relayPool.verifiesPerformed, 0);
      },
    );

    test('still verifies ids absent from the known-verified set', () async {
      final relay = _FakeRelay('wss://n1.example');
      await nostr.relayPool.add(relay);
      nostr.relayPool.isKnownVerifiedEvent = (_) => false;

      await relay.deliver(['EVENT', subId, signedEventJson(content: 'ok')]);

      expect(received, hasLength(1));
      expect(nostr.relayPool.verifiesPerformed, 1);
      expect(nostr.relayPool.verifiesSkippedKnown, 0);
    });
  });
}
