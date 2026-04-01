// ABOUTME: Regression tests for RelayPool concurrent modification hazards.
// ABOUTME: Ensures autoSubscribe tolerates subscription changes during resend.

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';

class _MutatingRelay extends Relay {
  _MutatingRelay(String url, {required this.onFirstSend})
    : super(url, RelayStatus(url));

  final Future<void> Function() onFirstSend;
  final List<List<dynamic>> sentMessages = [];
  bool _didMutate = false;

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
  }) async {
    sentMessages.add(message);

    if (!_didMutate) {
      _didMutate = true;
      await onFirstSend();
    }

    return true;
  }
}

/// A relay that always fails to send, used to test that failed sends
/// do not block EOSE completion for other relays.
class _FailingSendRelay extends Relay {
  _FailingSendRelay(String url) : super(url, RelayStatus(url));

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
  }) async {
    return false; // Always fail
  }
}

void main() {
  group('RelayPool concurrency', () {
    late Nostr nostr;
    late LocalNostrSigner signer;

    setUp(() async {
      signer = LocalNostrSigner(
        '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
      );
      nostr = Nostr(signer, [], (url) => RelayBase(url, RelayStatus(url)));
      await nostr.refreshPublicKey();
    });

    test('failed relay send does not block query EOSE completion', () async {
      // Add a relay that always fails to send
      final failingRelay = _FailingSendRelay('wss://failing.relay');
      await nostr.relayPool.add(failingRelay);

      // Query should complete quickly (not hang for 10s timeout)
      // because the failing relay's query is never registered
      final stopwatch = Stopwatch()..start();
      final events = await nostr.queryEvents([
        {
          'kinds': [1],
          'limit': 1,
        },
      ], timeout: const Duration(seconds: 5));
      stopwatch.stop();

      // Should complete well under the 5s timeout since the only relay
      // fails to send and is not registered in the EOSE tracking
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));
      expect(events, isEmpty);
    });

    test(
      'add(autoSubscribe: true) tolerates subscriptions added during resend',
      () async {
        nostr.relayPool.subscribe([
          Filter(kinds: const [1], limit: 1).toJson(),
        ], (_) {});

        final relay = _MutatingRelay(
          'wss://test.relay',
          onFirstSend: () async {
            nostr.relayPool.subscribe([
              Filter(kinds: const [7], limit: 1).toJson(),
            ], (_) {});
          },
        );

        await expectLater(
          nostr.relayPool.add(relay, autoSubscribe: true),
          completes,
        );
        expect(
          relay.sentMessages.where((message) => message.first == 'REQ').length,
          greaterThanOrEqualTo(1),
        );
      },
    );
  });
}
