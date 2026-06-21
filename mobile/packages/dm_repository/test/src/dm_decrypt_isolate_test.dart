// ABOUTME: Tests for DmDecryptIsolate, the long-lived drain-scoped NIP-17
// ABOUTME: gift-wrap decrypt worker. Covers the real round-trip, per-event
// ABOUTME: failure handling, concurrent request id-correlation, and close().

import 'dart:convert';

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/nip44/nip44_v2.dart';

/// Builds a NIP-17 gift wrap for [content] addressed to [recipientPubkey],
/// sealed and signed by [senderPrivateKey]. Mirrors the production
/// GiftWrapUtil flow inline so the worker can unwrap it for real.
Future<Event> buildGiftWrap({
  required String content,
  required String senderPrivateKey,
  required String recipientPubkey,
}) async {
  final senderPubkey = getPublicKey(senderPrivateKey);

  final rumor = Event(
    senderPubkey,
    EventKind.privateDirectMessage,
    <List<String>>[
      ['p', recipientPubkey],
    ],
    content,
  );

  final rumorMap = rumor.toJson()..remove('sig');
  final sealKey = NIP44V2.shareSecret(senderPrivateKey, recipientPubkey);
  final sealContent = await NIP44V2.encrypt(jsonEncode(rumorMap), sealKey);
  final sealEvent = Event(
    senderPubkey,
    EventKind.sealEventKind,
    <List<String>>[],
    sealContent,
  )..sign(senderPrivateKey);

  final ephemeralPrivateKey = generatePrivateKey();
  final ephemeralPubkey = getPublicKey(ephemeralPrivateKey);
  final wrapKey = NIP44V2.shareSecret(ephemeralPrivateKey, recipientPubkey);
  final wrapContent = await NIP44V2.encrypt(
    jsonEncode(sealEvent.toJson()),
    wrapKey,
  );
  return Event(
    ephemeralPubkey,
    EventKind.giftWrap,
    <List<String>>[
      ['p', recipientPubkey],
    ],
    wrapContent,
  )..sign(ephemeralPrivateKey);
}

void main() {
  group(DmDecryptIsolate, () {
    late String recipientPriv;
    late String recipientPub;
    late String senderPriv;
    late DmDecryptIsolate isolate;

    setUp(() async {
      recipientPriv = generatePrivateKey();
      recipientPub = getPublicKey(recipientPriv);
      senderPriv = generatePrivateKey();
      isolate = await DmDecryptIsolate.spawn(recipientPriv);
    });

    tearDown(() {
      isolate.close();
    });

    test('decrypts a real gift wrap to its rumor', () async {
      final wrap = await buildGiftWrap(
        content: 'hello isolate',
        senderPrivateKey: senderPriv,
        recipientPubkey: recipientPub,
      );

      final results = await isolate.decryptBatch([wrap.toJson()]);

      expect(results, hasLength(1));
      expect(results.single.isSuccess, isTrue);
      expect(Event.fromJson(results.single.rumor!).content, 'hello isolate');
    });

    test('returns a failure entry for a wrap addressed to another key '
        'without throwing', () async {
      final otherRecipientPriv = generatePrivateKey();
      final otherRecipientPub = getPublicKey(otherRecipientPriv);
      // Encrypted to someone else: our resident key cannot ECDH-decrypt it.
      final wrap = await buildGiftWrap(
        content: 'not for us',
        senderPrivateKey: senderPriv,
        recipientPubkey: otherRecipientPub,
      );

      final results = await isolate.decryptBatch([wrap.toJson()]);

      expect(results, hasLength(1));
      expect(results.single.isSuccess, isFalse);
      expect(results.single.error, isNotNull);
    });

    test('preserves per-event order within a batch', () async {
      final wraps = <Event>[
        for (var i = 0; i < 5; i++)
          await buildGiftWrap(
            content: 'ordered $i',
            senderPrivateKey: senderPriv,
            recipientPubkey: recipientPub,
          ),
      ];

      final results = await isolate.decryptBatch([
        for (final wrap in wraps) wrap.toJson(),
      ]);

      expect(results, hasLength(5));
      for (var i = 0; i < 5; i++) {
        expect(Event.fromJson(results[i].rumor!).content, 'ordered $i');
      }
    });

    test(
      'correlates concurrent decryptBatch calls to their own results',
      () async {
        // Fire each request without awaiting so they interleave on the shared
        // port; if ids were mismatched the contents would come back swapped.
        final futures = <Future<List<DecryptedRumorResult>>>[];
        for (var i = 0; i < 8; i++) {
          final wrap = await buildGiftWrap(
            content: 'concurrent $i',
            senderPrivateKey: senderPriv,
            recipientPubkey: recipientPub,
          );
          futures.add(isolate.decryptBatch([wrap.toJson()]));
        }

        final results = await Future.wait(futures);

        for (var i = 0; i < 8; i++) {
          expect(results[i], hasLength(1));
          expect(
            Event.fromJson(results[i].single.rumor!).content,
            'concurrent $i',
          );
        }
      },
    );

    test('throws StateError when used after close', () async {
      isolate.close();

      expect(
        () => isolate.decryptBatch(const [<String, dynamic>{}]),
        throwsStateError,
      );
    });

    test('close is idempotent', () {
      isolate
        ..close()
        ..close();
    });
  });
}
