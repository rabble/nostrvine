// ABOUTME: Regression tests for RelayPool inbound event signature validation.
// ABOUTME: Ensures relay-delivered events are verified before app handlers see them.

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';

class _FakeRelay extends Relay {
  _FakeRelay(String url) : super(url, RelayStatus(url));

  final List<List<dynamic>> sentMessages = [];

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
    sentMessages.add(message);
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

Future<Event> _signedEvent(String content) async {
  const privateKey =
      '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
  final signer = LocalNostrSigner(privateKey);
  final pubkey = await signer.getPublicKey();
  final event = Event(
    pubkey!,
    EventKind.textNote,
    [],
    content,
    createdAt: 1780000000,
  );
  await signer.signEvent(event);
  return event;
}

void main() {
  group('RelayPool inbound event signature validation', () {
    Relay dummyTempRelay(String url) => RelayBase(url, RelayStatus(url));

    test('delivers signed events with valid ids', () async {
      final nostr = Nostr(
        LocalNostrSigner(generatePrivateKey()),
        [],
        dummyTempRelay,
      );
      final relay = _FakeRelay('wss://relay.example');
      expect(await nostr.relayPool.add(relay), isTrue);

      final delivered = <Event>[];
      nostr.subscribe(
        [
          {
            'kinds': [EventKind.textNote],
          },
        ],
        delivered.add,
        id: 'sub',
      );

      final event = await _signedEvent('valid relay event');
      await relay.deliver(['EVENT', 'sub', event.toJson()]);

      expect(delivered, hasLength(1));
      expect(delivered.single.id, event.id);
    });

    test(
      'drops events whose content no longer matches the signed id',
      () async {
        final nostr = Nostr(
          LocalNostrSigner(generatePrivateKey()),
          [],
          dummyTempRelay,
        );
        final relay = _FakeRelay('wss://relay.example');
        expect(await nostr.relayPool.add(relay), isTrue);

        final delivered = <Event>[];
        nostr.subscribe(
          [
            {
              'kinds': [EventKind.textNote],
            },
          ],
          delivered.add,
          id: 'sub',
        );

        final event = await _signedEvent('original content');
        final tampered = event.toJson()..['content'] = 'tampered content';
        await relay.deliver(['EVENT', 'sub', tampered]);

        expect(delivered, isEmpty);
      },
    );

    test('drops unsigned events even when the event id is valid', () async {
      final nostr = Nostr(
        LocalNostrSigner(generatePrivateKey()),
        [],
        dummyTempRelay,
      );
      final relay = _FakeRelay('wss://relay.example');
      expect(await nostr.relayPool.add(relay), isTrue);

      final delivered = <Event>[];
      nostr.subscribe(
        [
          {
            'kinds': [EventKind.textNote],
          },
        ],
        delivered.add,
        id: 'sub',
      );

      final event = Event(
        getPublicKey(generatePrivateKey()),
        EventKind.textNote,
        [],
        'unsigned relay event',
        createdAt: 1780000000,
      );
      await relay.deliver(['EVENT', 'sub', event.toJson()]);

      expect(delivered, isEmpty);
    });
  });
}
