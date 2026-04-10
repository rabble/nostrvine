// ABOUTME: Tests for the off-main-isolate NIP-17 gift-wrap decryption
// ABOUTME: helper used by DmRepository for local signers.

import 'dart:convert';

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/nip44/nip44_v2.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show GiftWrapUtil, Nostr;

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

/// Builds a gift wrap whose inner ciphertext decrypts to [sealPlaintext]
/// instead of a serialized seal Event. Exercises the "seal parse failed"
/// error branch.
Future<Event> _buildGiftWrapWithRawSealContent({
  required String sealPlaintext,
  required String recipientPubkey,
}) async {
  final ephemeralPriv = generatePrivateKey();
  final ephemeralPub = getPublicKey(ephemeralPriv);
  final wrapKey = NIP44V2.shareSecret(ephemeralPriv, recipientPubkey);
  final wrapContent = await NIP44V2.encrypt(sealPlaintext, wrapKey);
  return Event(
    ephemeralPub,
    EventKind.giftWrap,
    <List<String>>[
      ['p', recipientPubkey],
    ],
    wrapContent,
  )..sign(ephemeralPriv);
}

/// Builds a gift wrap containing a seal with a zeroed-out signature.
/// Exercises the "seal signature invalid" error branch.
Future<Event> _buildGiftWrapWithUnsignedSeal({
  required String recipientPubkey,
}) async {
  final senderPriv = generatePrivateKey();
  final senderPub = getPublicKey(senderPriv);

  // Build an unsigned seal — fromJson accepts empty sig, but isSigned
  // returns false.
  final sealJson = <String, dynamic>{
    'id': '0' * 64,
    'pubkey': senderPub,
    'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    'kind': EventKind.sealEventKind,
    'tags': <List<String>>[],
    'content': 'placeholder',
    'sig': '',
  };

  final ephemeralPriv = generatePrivateKey();
  final ephemeralPub = getPublicKey(ephemeralPriv);
  final wrapKey = NIP44V2.shareSecret(ephemeralPriv, recipientPubkey);
  final wrapContent = await NIP44V2.encrypt(jsonEncode(sealJson), wrapKey);
  return Event(
    ephemeralPub,
    EventKind.giftWrap,
    <List<String>>[
      ['p', recipientPubkey],
    ],
    wrapContent,
  )..sign(ephemeralPriv);
}

/// Builds a gift wrap containing a properly signed seal whose content
/// is not a valid NIP-44 ciphertext, so the seal-to-rumor decryption
/// fails. Exercises the "seal decrypt failed" error branch.
Future<Event> _buildGiftWrapWithBadSealContent({
  required String senderPrivateKey,
  required String senderPubkey,
  required String recipientPubkey,
}) async {
  // Create a signed seal whose content is plain text, not NIP-44.
  final sealEvent = Event(
    senderPubkey,
    EventKind.sealEventKind,
    <List<String>>[],
    'not-a-valid-nip44-ciphertext',
  )..sign(senderPrivateKey);

  final ephemeralPriv = generatePrivateKey();
  final ephemeralPub = getPublicKey(ephemeralPriv);
  final wrapKey = NIP44V2.shareSecret(ephemeralPriv, recipientPubkey);
  final wrapContent = await NIP44V2.encrypt(
    jsonEncode(sealEvent.toJson()),
    wrapKey,
  );
  return Event(
    ephemeralPub,
    EventKind.giftWrap,
    <List<String>>[
      ['p', recipientPubkey],
    ],
    wrapContent,
  )..sign(ephemeralPriv);
}

/// Builds a full gift wrap chain where the seal encrypts [rumorPlaintext]
/// (e.g. non-JSON) as the rumor layer. Exercises the "rumor parse failed"
/// error branch.
Future<Event> _buildGiftWrapWithRawRumorContent({
  required String senderPrivateKey,
  required String senderPubkey,
  required String recipientPubkey,
  required String rumorPlaintext,
}) async {
  // Seal: encrypt the raw plaintext (not a valid rumor) to the recipient.
  final sealKey = NIP44V2.shareSecret(senderPrivateKey, recipientPubkey);
  final sealContent = await NIP44V2.encrypt(rumorPlaintext, sealKey);
  final sealEvent = Event(
    senderPubkey,
    EventKind.sealEventKind,
    <List<String>>[],
    sealContent,
  )..sign(senderPrivateKey);

  final ephemeralPriv = generatePrivateKey();
  final ephemeralPub = getPublicKey(ephemeralPriv);
  final wrapKey = NIP44V2.shareSecret(ephemeralPriv, recipientPubkey);
  final wrapContent = await NIP44V2.encrypt(
    jsonEncode(sealEvent.toJson()),
    wrapKey,
  );
  return Event(
    ephemeralPub,
    EventKind.giftWrap,
    <List<String>>[
      ['p', recipientPubkey],
    ],
    wrapContent,
  )..sign(ephemeralPriv);
}

/// Builds a full gift wrap chain where the rumor's pubkey field differs
/// from the seal signer's pubkey. Exercises the NIP-17 sender
/// verification override at line 150-151 of dm_decryption_worker.dart.
Future<Event> _buildGiftWrapWithSpoofedRumorPubkey({
  required String senderPrivateKey,
  required String senderPubkey,
  required String recipientPubkey,
  required String spoofedRumorPubkey,
}) async {
  // Build the rumor with the spoofed pubkey.
  final rumor = Event(
    spoofedRumorPubkey,
    EventKind.privateDirectMessage,
    <List<String>>[
      ['p', recipientPubkey],
    ],
    'spoofed message',
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

  final ephemeralPriv = generatePrivateKey();
  final ephemeralPub = getPublicKey(ephemeralPriv);
  final wrapKey = NIP44V2.shareSecret(ephemeralPriv, recipientPubkey);
  final wrapContent = await NIP44V2.encrypt(
    jsonEncode(sealEvent.toJson()),
    wrapKey,
  );
  return Event(
    ephemeralPub,
    EventKind.giftWrap,
    <List<String>>[
      ['p', recipientPubkey],
    ],
    wrapContent,
  )..sign(ephemeralPriv);
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

    test('returns failure when Event.fromJson cannot parse the map', () async {
      final results = await decryptGiftWrapBatch(
        const DecryptBatchRequest(
          events: [<String, dynamic>{}],
          privateKeyHex: 'deadbeef',
        ),
      );

      expect(results, hasLength(1));
      expect(results[0].isSuccess, isFalse);
      expect(results[0].error, contains('invalid gift wrap json'));
    });

    test(
      'returns failure when decrypted seal content is not valid JSON',
      () async {
        final recipientPriv = generatePrivateKey();
        final recipientPub = getPublicKey(recipientPriv);

        // Build a gift wrap whose inner ciphertext decrypts to plain
        // text instead of a serialized seal Event.
        final giftWrap = await _buildGiftWrapWithRawSealContent(
          sealPlaintext: 'not valid json',
          recipientPubkey: recipientPub,
        );

        final results = await decryptGiftWrapBatch(
          DecryptBatchRequest(
            events: [giftWrap.toJson()],
            privateKeyHex: recipientPriv,
          ),
        );

        expect(results, hasLength(1));
        expect(results[0].isSuccess, isFalse);
        expect(results[0].error, contains('seal parse failed'));
      },
    );

    test(
      'returns failure when seal signature is invalid',
      () async {
        final recipientPriv = generatePrivateKey();
        final recipientPub = getPublicKey(recipientPriv);

        // Build a gift wrap containing a seal with a zeroed-out
        // signature that will fail the Schnorr verification check.
        final giftWrap = await _buildGiftWrapWithUnsignedSeal(
          recipientPubkey: recipientPub,
        );

        final results = await decryptGiftWrapBatch(
          DecryptBatchRequest(
            events: [giftWrap.toJson()],
            privateKeyHex: recipientPriv,
          ),
        );

        expect(results, hasLength(1));
        expect(results[0].isSuccess, isFalse);
        expect(results[0].error, contains('seal signature invalid'));
      },
    );

    test(
      'returns failure when seal-to-rumor decryption fails',
      () async {
        final recipientPriv = generatePrivateKey();
        final recipientPub = getPublicKey(recipientPriv);
        final senderPriv = generatePrivateKey();
        final senderPub = getPublicKey(senderPriv);

        // Build a gift wrap containing a properly signed seal whose
        // content field is not a valid NIP-44 ciphertext.
        final giftWrap = await _buildGiftWrapWithBadSealContent(
          senderPrivateKey: senderPriv,
          senderPubkey: senderPub,
          recipientPubkey: recipientPub,
        );

        final results = await decryptGiftWrapBatch(
          DecryptBatchRequest(
            events: [giftWrap.toJson()],
            privateKeyHex: recipientPriv,
          ),
        );

        expect(results, hasLength(1));
        expect(results[0].isSuccess, isFalse);
        expect(results[0].error, contains('seal decrypt failed'));
      },
    );

    test(
      'returns failure when decrypted rumor is not valid JSON',
      () async {
        final recipientPriv = generatePrivateKey();
        final recipientPub = getPublicKey(recipientPriv);
        final senderPriv = generatePrivateKey();
        final senderPub = getPublicKey(senderPriv);

        // Build a valid seal that encrypts non-JSON text as the rumor.
        final giftWrap = await _buildGiftWrapWithRawRumorContent(
          senderPrivateKey: senderPriv,
          senderPubkey: senderPub,
          recipientPubkey: recipientPub,
          rumorPlaintext: 'this is not json',
        );

        final results = await decryptGiftWrapBatch(
          DecryptBatchRequest(
            events: [giftWrap.toJson()],
            privateKeyHex: recipientPriv,
          ),
        );

        expect(results, hasLength(1));
        expect(results[0].isSuccess, isFalse);
        expect(results[0].error, contains('rumor parse failed'));
      },
    );

    test(
      'overrides rumor pubkey with seal pubkey when they differ',
      () async {
        final recipientPriv = generatePrivateKey();
        final recipientPub = getPublicKey(recipientPriv);
        final senderPriv = generatePrivateKey();
        final senderPub = getPublicKey(senderPriv);
        // Use a different key as the rumor's claimed author.
        final fakePub = getPublicKey(generatePrivateKey());

        final giftWrap = await _buildGiftWrapWithSpoofedRumorPubkey(
          senderPrivateKey: senderPriv,
          senderPubkey: senderPub,
          recipientPubkey: recipientPub,
          spoofedRumorPubkey: fakePub,
        );

        final results = await decryptGiftWrapBatch(
          DecryptBatchRequest(
            events: [giftWrap.toJson()],
            privateKeyHex: recipientPriv,
          ),
        );

        expect(results, hasLength(1));
        expect(results[0].isSuccess, isTrue);
        // The returned rumor pubkey must be the seal signer, NOT the
        // spoofed key that was embedded in the rumor.
        expect(results[0].rumor!['pubkey'], equals(senderPub));
        expect(results[0].rumor!['pubkey'], isNot(equals(fakePub)));
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
