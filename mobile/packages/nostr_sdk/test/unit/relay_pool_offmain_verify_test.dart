// ABOUTME: Tests RelayPool's off-main verify integration (#5863 P2).
// ABOUTME: Worker verify, per-relay ordering, and inline fallback.

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

/// A verify worker whose per-event decision (and optional delay) the test
/// controls, so ordering and fallback are deterministic.
class _FakeVerifyWorker implements EventVerifyWorker {
  _FakeVerifyWorker(this._decide);

  final FutureOr<bool> Function(Map<String, dynamic> json) _decide;
  int calls = 0;
  bool closed = false;

  @override
  Future<bool> verify(Map<String, dynamic> eventJson) async {
    if (closed) throw StateError('closed');
    calls++;
    return _decide(eventJson);
  }

  @override
  void close() => closed = true;
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

Nostr _nostr() => Nostr(
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
  group('RelayPool off-main verify (#5863 P2)', () {
    test('routes verify to the worker and delivers accepted events', () async {
      final nostr = _nostr();
      final worker = _FakeVerifyWorker((_) => true);
      nostr.relayPool.eventVerifyWorker = worker;
      final relay = _FakeRelay('wss://relay.a');
      expect(await nostr.relayPool.add(relay), isTrue);
      final delivered = _subscribe(nostr);

      final event = await _signedEvent('accepted');
      await relay.deliver(['EVENT', 'sub', event.toJson()]);

      expect(delivered, hasLength(1));
      expect(worker.calls, 1, reason: 'verify ran on the worker, not inline');
    });

    test('drops events the worker rejects', () async {
      final nostr = _nostr();
      nostr.relayPool.eventVerifyWorker = _FakeVerifyWorker((_) => false);
      final relay = _FakeRelay('wss://relay.a');
      expect(await nostr.relayPool.add(relay), isTrue);
      final delivered = _subscribe(nostr);

      // A genuinely valid event, but the worker says no → dropped.
      final event = await _signedEvent('rejected-by-worker');
      await relay.deliver(['EVENT', 'sub', event.toJson()]);

      expect(delivered, isEmpty);
    });

    test('falls back to inline verify when the worker throws', () async {
      final nostr = _nostr();
      nostr.relayPool.eventVerifyWorker = _FakeVerifyWorker(
        (_) => throw StateError('isolate died'),
      );
      final relay = _FakeRelay('wss://relay.a');
      expect(await nostr.relayPool.add(relay), isTrue);
      final delivered = _subscribe(nostr);

      // Worker throws → inline check runs; the real signature is valid → kept.
      final valid = await _signedEvent('fallback-valid');
      await relay.deliver(['EVENT', 'sub', valid.toJson()]);
      expect(delivered, hasLength(1));

      // And a tampered event still fails the inline fallback → dropped.
      final tampered = (await _signedEvent('orig')).toJson()
        ..['content'] = 'tampered';
      await relay.deliver(['EVENT', 'sub', tampered]);
      expect(delivered, hasLength(1));
    });

    test(
      'preserves per-relay delivery order despite out-of-order verify',
      () async {
        final nostr = _nostr();
        final gate = Completer<void>();
        // 'A' verifies slowly (gated); 'B' verifies immediately. Without ordering
        // B would dispatch first; the per-relay chain must still deliver A then B.
        nostr.relayPool.eventVerifyWorker = _FakeVerifyWorker((json) async {
          if (json['content'] == 'A') await gate.future;
          return true;
        });
        final relay = _FakeRelay('wss://relay.a');
        expect(await nostr.relayPool.add(relay), isTrue);
        final delivered = _subscribe(nostr);

        final a = await _signedEvent('A');
        final b = await _signedEvent('B');
        final dA = relay.deliver(['EVENT', 'sub', a.toJson()]);
        final dB = relay.deliver(['EVENT', 'sub', b.toJson()]);
        await Future<void>.delayed(Duration.zero);

        expect(delivered, isEmpty, reason: 'A gated, B queued behind it');
        gate.complete();
        await Future.wait([dA, dB]);

        expect(delivered.map((e) => e.content), ['A', 'B']);
      },
    );
  });
}
