// ABOUTME: Regression tests for defensive RelayPool frame parsing.
// ABOUTME: Ensures malformed relay-controlled JSON does not crash handlers.

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';

class _MalformedFrameRelay extends Relay {
  _MalformedFrameRelay(String url) : super(url, RelayStatus(url));

  String? capturedSubId;

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
    if (message.isNotEmpty && message[0] == 'REQ' && message.length > 1) {
      capturedSubId = message[1] as String;
    }
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

    test('drops signed events that do not match the query filter', () async {
      const privateKey =
          '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
      final signer = LocalNostrSigner(privateKey);
      final nostr = Nostr(signer, [], dummyTempRelay);
      final relay = _MalformedFrameRelay('wss://off-filter.example');

      expect(await nostr.relayPool.add(relay), isTrue);

      final pending = nostr.queryEventsDetailed([
        {
          'authors': [getPublicKey(privateKey)],
          'kinds': [EventKind.relayListMetadata],
        },
      ], timeout: const Duration(seconds: 2));

      for (var i = 0; i < 1000 && relay.capturedSubId == null; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      final subId = relay.capturedSubId;
      expect(subId, isNotNull);

      final offFilterEvent = Event(
        getPublicKey(privateKey),
        EventKind.textNote,
        [
          ['r', 'wss://attacker-selected.example'],
        ],
        '',
        createdAt: 1700000000,
      )..sign(privateKey);

      await relay.deliver(['EVENT', subId, offFilterEvent.toJson()]);
      await relay.deliver(['EOSE', subId]);

      final result = await pending;
      expect(result.events, isEmpty);
      expect(result.timedOut, isFalse);
    });
  });
}
