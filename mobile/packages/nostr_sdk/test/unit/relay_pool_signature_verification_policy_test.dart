// ABOUTME: Tests RelayPool signature-verification policy decisions.
// ABOUTME: Ensures policy skips compose with the off-main verify worker.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';

class _FakeRelay extends Relay {
  _FakeRelay(String url) : super(url, RelayStatus(url));

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
  }) async => true;

  Future<void> deliver(List<dynamic> json) async {
    final dynamic result = onMessage!(this, json);
    if (result is Future) await result;
  }
}

class _FakeVerifyWorker implements EventVerifyWorker {
  _FakeVerifyWorker(this._decide);

  final FutureOr<bool> Function(Map<String, dynamic> json) _decide;
  int calls = 0;

  @override
  Future<bool> verify(Map<String, dynamic> eventJson) async {
    calls++;
    return _decide(eventJson);
  }

  @override
  void close() {}
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

Nostr _nostr(SignatureVerificationPolicy policy) => Nostr(
  LocalNostrSigner(generatePrivateKey()),
  [],
  (url) => RelayBase(url, RelayStatus(url)),
  signatureVerificationPolicy: policy,
);

Nostr _nostrWithDefaultPolicy() => Nostr(
  LocalNostrSigner(generatePrivateKey()),
  [],
  (url) => RelayBase(url, RelayStatus(url)),
);

List<Event> _subscribe(Nostr nostr) {
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
  return delivered;
}

void main() {
  group('RelayPool signature verification policy', () {
    test('defaults to verifying events from all relays', () async {
      final nostr = _nostrWithDefaultPolicy();
      final worker = _FakeVerifyWorker((_) => false);
      nostr.relayPool.eventVerifyWorker = worker;
      final relay = _FakeRelay('wss://relay.divine.video');
      expect(await nostr.relayPool.add(relay), isTrue);
      final delivered = _subscribe(nostr);

      final event = await _signedEvent('default-policy');
      await relay.deliver(['EVENT', 'sub', event.toJson()]);

      expect(worker.calls, 1);
      expect(delivered, isEmpty);
    });

    test('all relays policy verifies through the worker', () async {
      final nostr = _nostr(SignatureVerificationPolicy.all);
      final worker = _FakeVerifyWorker((_) => false);
      nostr.relayPool.eventVerifyWorker = worker;
      final relay = _FakeRelay('wss://relay.divine.video');
      expect(await nostr.relayPool.add(relay), isTrue);
      final delivered = _subscribe(nostr);

      final event = await _signedEvent('rejected-by-worker');
      await relay.deliver(['EVENT', 'sub', event.toJson()]);

      expect(worker.calls, 1);
      expect(delivered, isEmpty);
    });

    test('non-Divine policy skips worker for Divine relay hosts', () async {
      final nostr = _nostr(SignatureVerificationPolicy.nonDivineRelays);
      final worker = _FakeVerifyWorker((_) => false);
      nostr.relayPool.eventVerifyWorker = worker;
      final relay = _FakeRelay('wss://relay.divine.video');
      expect(await nostr.relayPool.add(relay), isTrue);
      final delivered = _subscribe(nostr);

      final event = await _signedEvent('trusted-host');
      await relay.deliver(['EVENT', 'sub', event.toJson()]);

      expect(worker.calls, 0);
      expect(nostr.relayPool.verifiesSkippedByPolicy, 1);
      expect(delivered, hasLength(1));
    });

    test('non-Divine policy does not trust lookalike relay hosts', () async {
      final nostr = _nostr(SignatureVerificationPolicy.nonDivineRelays);
      final worker = _FakeVerifyWorker((_) => false);
      nostr.relayPool.eventVerifyWorker = worker;
      final relay = _FakeRelay('wss://divine.video.evil.example');
      expect(await nostr.relayPool.add(relay), isTrue);
      final delivered = _subscribe(nostr);

      final event = await _signedEvent('lookalike-host');
      await relay.deliver(['EVENT', 'sub', event.toJson()]);

      expect(worker.calls, 1);
      expect(delivered, isEmpty);
    });

    test('untrusted relays policy skips configured relays', () async {
      final nostr = _nostr(SignatureVerificationPolicy.untrustedRelays);
      final worker = _FakeVerifyWorker((_) => false);
      nostr.relayPool.eventVerifyWorker = worker;
      final relay = _FakeRelay('wss://configured.example');
      expect(await nostr.relayPool.add(relay), isTrue);
      final delivered = _subscribe(nostr);

      final event = await _signedEvent('configured-relay');
      await relay.deliver(['EVENT', 'sub', event.toJson()]);

      expect(worker.calls, 0);
      expect(nostr.relayPool.verifiesSkippedByPolicy, 1);
      expect(delivered, hasLength(1));
    });

    test('empty signatures are rejected before policy skips', () async {
      final nostr = _nostr(SignatureVerificationPolicy.nonDivineRelays);
      final worker = _FakeVerifyWorker((_) => true);
      nostr.relayPool.eventVerifyWorker = worker;
      final relay = _FakeRelay('wss://relay.divine.video');
      expect(await nostr.relayPool.add(relay), isTrue);
      final delivered = _subscribe(nostr);

      final eventJson = (await _signedEvent('empty-signature')).toJson()
        ..['sig'] = '';
      await relay.deliver(['EVENT', 'sub', eventJson]);

      expect(worker.calls, 0);
      expect(nostr.relayPool.verifiesSkippedByPolicy, 0);
      expect(delivered, isEmpty);
    });

    test('policy-skipped relays still reject mismatched event ids', () async {
      final nostr = _nostr(SignatureVerificationPolicy.nonDivineRelays);
      final worker = _FakeVerifyWorker((_) => true);
      nostr.relayPool.eventVerifyWorker = worker;
      final relay = _FakeRelay('wss://relay.divine.video');
      expect(await nostr.relayPool.add(relay), isTrue);
      final delivered = _subscribe(nostr);

      final eventJson = (await _signedEvent('original-body')).toJson()
        ..['content'] = 'tampered-body';
      await relay.deliver(['EVENT', 'sub', eventJson]);

      expect(worker.calls, 0);
      expect(nostr.relayPool.verifiesSkippedByPolicy, 0);
      expect(delivered, isEmpty);
    });
  });
}
