// ABOUTME: Tests for DmVerifyIsolate — the key-less verify isolate that runs
// ABOUTME: gift-wrap id + Schnorr verification off the main isolate on the
// ABOUTME: remote-signer history drain. Covers valid/invalid verification,
// ABOUTME: interleaved concurrent requests, and use-after-close. See #5424.

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

Event _signed(int kind, {String content = 'hi'}) {
  final privateKey = generatePrivateKey();
  return Event(getPublicKey(privateKey), kind, const <List<String>>[], content)
    ..sign(privateKey);
}

void main() {
  group(DmVerifyIsolate, () {
    late DmVerifyIsolate worker;

    setUp(() async {
      worker = await DmVerifyIsolate.spawn();
    });

    tearDown(() {
      worker.close();
    });

    test('verifies a self-valid signed event as true', () async {
      expect(await worker.verifyPart(_signed(EventKind.textNote)), isTrue);
    });

    test('rejects an event whose signature does not verify', () async {
      final event = _signed(EventKind.textNote)..sig = '0' * 128;
      expect(await worker.verifyPart(event), isFalse);
    });

    test('rejects an event whose id no longer matches its content', () async {
      final event = _signed(EventKind.textNote)..content = 'tampered';
      expect(await worker.verifyPart(event), isFalse);
    });

    test(
      'resolves many interleaved concurrent requests independently',
      () async {
        final valid = [
          for (var i = 0; i < 8; i++)
            _signed(EventKind.textNote, content: 'valid-$i'),
        ];
        final invalid = [
          for (var i = 0; i < 8; i++)
            _signed(EventKind.textNote, content: 'invalid-$i')..sig = '0' * 128,
        ];

        final results = await Future.wait(<Future<bool>>[
          for (final event in valid) worker.verifyPart(event),
          for (final event in invalid) worker.verifyPart(event),
        ]);

        expect(results.sublist(0, 8), everyElement(isTrue));
        expect(results.sublist(8), everyElement(isFalse));
      },
    );

    test('throws StateError when verifyPart is called after close', () {
      worker.close();
      expect(
        () => worker.verifyPart(_signed(EventKind.textNote)),
        throwsStateError,
      );
    });

    test('close is idempotent', () {
      worker
        ..close()
        ..close();
      expect(worker.close, returnsNormally);
    });
  });
}
