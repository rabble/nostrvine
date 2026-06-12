// ABOUTME: Regression tests for defensive RelayPool frame parsing.
// ABOUTME: Ensures malformed relay-controlled JSON does not crash handlers.

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';

class _MalformedFrameRelay extends Relay {
  _MalformedFrameRelay(String url) : super(url, RelayStatus(url));

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
  group('RelayPool malformed frame handling', () {
    Relay dummyTempRelay(String url) => RelayBase(url, RelayStatus(url));

    test('drops malformed relay frames instead of throwing', () async {
      final signer = LocalNostrSigner(
        '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
      );
      final nostr = Nostr(signer, [], dummyTempRelay);
      final relay = _MalformedFrameRelay('wss://malformed.example');

      final added = await nostr.relayPool.add(relay);
      expect(added, isTrue);

      final malformedFrames = <List<dynamic>>[
        [],
        [42, 'not-a-message-type'],
        ['EVENT', 'sub-1'],
        ['EOSE', 42],
        ['OK', 'event-id', 'not-a-bool'],
        [
          'NOTICE',
          {'message': 'not-a-string'},
        ],
        [
          'AUTH',
          {'challenge': 'not-a-string'},
        ],
        ['COUNT', 'count-sub', 'not-a-map'],
        ['COUNT', 'count-sub', <String, dynamic>{}],
        ['CLOSED', 42, 'closed reason'],
        ['CLOSED', 'sub-1', 42],
      ];

      for (final frame in malformedFrames) {
        await expectLater(
          relay.deliver(frame),
          completes,
          reason: 'malformed relay frame should be dropped: $frame',
        );
      }
    });
  });
}
