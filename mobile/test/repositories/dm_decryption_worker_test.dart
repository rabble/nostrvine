// ABOUTME: Tests for the off-main-isolate NIP-17 gift-wrap decryption
// ABOUTME: helper used by DmRepository for local signers.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/nip44/nip44_v2.dart';
import 'package:openvine/repositories/dm_decryption_worker.dart';

/// Builds a NIP-17 gift wrap for [rumor] addressed to [recipientPubkey]
/// using [senderPrivateKey] as the seal signer. Mirrors the production
/// [GiftWrapUtil.getGiftWrapEvent] flow but inline so tests do not need
/// to construct a full [Nostr] client.
Future<Event> _buildGiftWrap({
  required Event rumor,
  required String senderPrivateKey,
  required String recipientPubkey,
}) async {
  final senderPubkey = getPublicKey(senderPrivateKey);

  // Seal: encrypt the unsigned rumor to the recipient using the
  // sender's key, then sign with the sender's key.
  final rumorMap = rumor.toJson()..remove('sig');
  final sealKey = NIP44V2.shareSecret(senderPrivateKey, recipientPubkey);
  final sealContent = await NIP44V2.encrypt(jsonEncode(rumorMap), sealKey);
  final sealEvent = Event(
    senderPubkey,
    EventKind.sealEventKind,
    <List<String>>[],
    sealContent,
  )..sign(senderPrivateKey);

  // Gift wrap: ephemeral key encrypts the seal to the recipient.
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

Event _buildRumor({
  required String senderPubkey,
  required String recipientPubkey,
  required String content,
}) {
  return Event(
    senderPubkey,
    EventKind.privateDirectMessage,
    <List<String>>[
      ['p', recipientPubkey],
    ],
    content,
  );
}

void main() {
  group('decryptGiftWrapBatch', () {
    test('empty batch returns empty result', () async {
      final results = await decryptGiftWrapBatch(
        const DecryptBatchRequest(events: [], privateKeyHex: ''),
      );

      expect(results, isEmpty);
    });

    test('results preserve input order', () async {
      final recipientPriv = generatePrivateKey();
      final recipientPub = getPublicKey(recipientPriv);
      final senderAPriv = generatePrivateKey();
      final senderAPub = getPublicKey(senderAPriv);
      final senderBPriv = generatePrivateKey();
      final senderBPub = getPublicKey(senderBPriv);

      final giftA = await _buildGiftWrap(
        rumor: _buildRumor(
          senderPubkey: senderAPub,
          recipientPubkey: recipientPub,
          content: 'message A',
        ),
        senderPrivateKey: senderAPriv,
        recipientPubkey: recipientPub,
      );
      final giftB = await _buildGiftWrap(
        rumor: _buildRumor(
          senderPubkey: senderBPub,
          recipientPubkey: recipientPub,
          content: 'message B',
        ),
        senderPrivateKey: senderBPriv,
        recipientPubkey: recipientPub,
      );

      final results = await decryptGiftWrapBatch(
        DecryptBatchRequest(
          events: [giftA.toJson(), giftB.toJson()],
          privateKeyHex: recipientPriv,
        ),
      );

      expect(results, hasLength(2));
      expect(results[0].isSuccess, isTrue);
      expect(results[1].isSuccess, isTrue);
      expect(results[0].rumor!['content'], equals('message A'));
      expect(results[0].rumor!['pubkey'], equals(senderAPub));
      expect(results[1].rumor!['content'], equals('message B'));
      expect(results[1].rumor!['pubkey'], equals(senderBPub));
    });

    test(
      'malformed event returns failure entry but does not break the batch',
      () async {
        final recipientPriv = generatePrivateKey();
        final recipientPub = getPublicKey(recipientPriv);
        final senderPriv = generatePrivateKey();
        final senderPub = getPublicKey(senderPriv);

        final valid = await _buildGiftWrap(
          rumor: _buildRumor(
            senderPubkey: senderPub,
            recipientPubkey: recipientPub,
            content: 'hello',
          ),
          senderPrivateKey: senderPriv,
          recipientPubkey: recipientPub,
        );

        // Malformed event: valid event shape but unparseable content
        // (not a NIP-44 ciphertext). Event.fromJson will succeed, but
        // NIP44V2.decrypt will throw — the worker must catch it.
        final malformed = Event(
          getPublicKey(generatePrivateKey()),
          EventKind.giftWrap,
          <List<String>>[
            ['p', recipientPub],
          ],
          'not-a-valid-ciphertext',
        );

        final results = await decryptGiftWrapBatch(
          DecryptBatchRequest(
            events: [valid.toJson(), malformed.toJson()],
            privateKeyHex: recipientPriv,
          ),
        );

        expect(results, hasLength(2));
        expect(results[0].isSuccess, isTrue);
        expect(results[0].rumor!['content'], equals('hello'));
        expect(results[1].isSuccess, isFalse);
        expect(results[1].error, isNotNull);
        expect(results[1].error, isNotEmpty);
      },
    );

    test('wrong private key yields failure entry for every event', () async {
      final alicePriv = generatePrivateKey();
      final alicePub = getPublicKey(alicePriv);
      final bobPriv = generatePrivateKey();
      final senderPriv = generatePrivateKey();
      final senderPub = getPublicKey(senderPriv);

      // Gift wrap addressed to Alice.
      final gift = await _buildGiftWrap(
        rumor: _buildRumor(
          senderPubkey: senderPub,
          recipientPubkey: alicePub,
          content: 'for alice only',
        ),
        senderPrivateKey: senderPriv,
        recipientPubkey: alicePub,
      );

      // Attempt to decrypt with Bob's key.
      final results = await decryptGiftWrapBatch(
        DecryptBatchRequest(
          events: [gift.toJson()],
          privateKeyHex: bobPriv,
        ),
      );

      expect(results, hasLength(1));
      expect(results[0].isSuccess, isFalse);
      expect(results[0].error, isNotNull);
    });
  });
}
