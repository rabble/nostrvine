// ABOUTME: Tests for the off-main relay-event verify isolate (#5863 P2).
// ABOUTME: Verifies id+signature off the main isolate; safe close semantics.

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

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

Map<String, dynamic> _json(Event e) => Map<String, dynamic>.from(e.toJson());

void main() {
  group(EventVerifyIsolate, () {
    test('verifies a valid event off the main isolate', () async {
      final worker = await EventVerifyIsolate.spawn();
      addTearDown(worker.close);
      final event = await _signedEvent('valid');
      expect(await worker.verify(_json(event)), isTrue);
    });

    test(
      'rejects an event whose content no longer matches its signed id',
      () async {
        final worker = await EventVerifyIsolate.spawn();
        addTearDown(worker.close);
        final event = await _signedEvent('original');
        final tampered = _json(event)..['content'] = 'tampered';
        expect(await worker.verify(tampered), isFalse);
      },
    );

    test('rejects an unsigned event', () async {
      final worker = await EventVerifyIsolate.spawn();
      addTearDown(worker.close);
      final unsigned = Event(
        getPublicKey(generatePrivateKey()),
        EventKind.textNote,
        [],
        'unsigned',
        createdAt: 1780000000,
      );
      expect(await worker.verify(_json(unsigned)), isFalse);
    });

    test('resolves interleaved requests to their own results', () async {
      final worker = await EventVerifyIsolate.spawn();
      addTearDown(worker.close);
      final good = await _signedEvent('good');
      final bad = _json(await _signedEvent('bad'))..['content'] = 'x';
      final results = await Future.wait([
        worker.verify(_json(good)),
        worker.verify(bad),
        worker.verify(_json(good)),
      ]);
      expect(results, [true, false, true]);
    });

    test('verify after close throws StateError', () async {
      final worker = await EventVerifyIsolate.spawn();
      final event = await _signedEvent('x');
      worker.close();
      expect(() => worker.verify(_json(event)), throwsStateError);
    });

    test('close is idempotent', () async {
      final worker = await EventVerifyIsolate.spawn();
      worker.close();
      expect(worker.close, returnsNormally);
    });
  });
}
