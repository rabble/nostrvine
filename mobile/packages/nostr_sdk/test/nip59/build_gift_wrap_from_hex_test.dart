// ABOUTME: Tests for buildGiftWrapFromHex — the isolate-safe send-side NIP-17
// ABOUTME: gift-wrap builder. Covers round-trip decrypt, wrap structure,
// ABOUTME: timestamp backdating, per-call CSPRNG, and the self-addressed wrap.

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

void main() {
  Relay dummyRelay(String url) => RelayBase(url, RelayStatus(url));

  late String senderPrivateKey;
  late String senderPubkey;
  late String recipientPrivateKey;
  late String recipientPubkey;

  setUp(() {
    senderPrivateKey = generatePrivateKey();
    senderPubkey = getPublicKey(senderPrivateKey);
    recipientPrivateKey = generatePrivateKey();
    recipientPubkey = getPublicKey(recipientPrivateKey);
  });

  Event buildRumor({String content = 'secret message'}) => Event(
    senderPubkey,
    EventKind.privateDirectMessage,
    const <List<String>>[],
    content,
  );

  group('buildGiftWrapFromHex', () {
    test('round-trips back to the identical rumor for the recipient', () async {
      final rumor = buildRumor();
      final wrap = await buildGiftWrapFromHex(
        senderPrivateKeyHex: senderPrivateKey,
        rumorJson: rumor.toJson(),
        receiverPublicKey: recipientPubkey,
      );
      expect(wrap, isNotNull);

      final recipientNostr = Nostr(
        LocalNostrSigner(recipientPrivateKey),
        const [],
        dummyRelay,
      );
      final decrypted = await GiftWrapUtil.getRumorEvent(recipientNostr, wrap!);

      expect(decrypted, isNotNull);
      expect(decrypted!.content, equals('secret message'));
      expect(decrypted.pubkey, equals(senderPubkey));
      expect(decrypted.kind, equals(EventKind.privateDirectMessage));
      // Rumor id is preserved — receiver-side gift-wrap dedup keys on it.
      expect(decrypted.id, equals(rumor.id));
    });

    test(
      'produces a well-formed kind-1059 wrap with an ephemeral key',
      () async {
        final rumor = buildRumor();
        final wrap = (await buildGiftWrapFromHex(
          senderPrivateKeyHex: senderPrivateKey,
          rumorJson: rumor.toJson(),
          receiverPublicKey: recipientPubkey,
        ))!;

        expect(wrap.kind, equals(EventKind.giftWrap));
        // id recomputes and the ephemeral signature verifies.
        expect(verifyGiftWrapPart(wrap), isTrue);
        // Outer pubkey is a throwaway ephemeral key, never the sender's.
        expect(wrap.pubkey, isNot(equals(senderPubkey)));
        final pTags = wrap.tags
            .where((t) => t.isNotEmpty && t[0] == 'p')
            .toList();
        expect(pTags, hasLength(1));
        expect(pTags.first[1], equals(recipientPubkey));
      },
    );

    test(
      'backdates the gift-wrap timestamp within 2 days and never to the future',
      () async {
        final rumor = buildRumor();
        final base = rumor.createdAt;
        final wrap = (await buildGiftWrapFromHex(
          senderPrivateKeyHex: senderPrivateKey,
          rumorJson: rumor.toJson(),
          receiverPublicKey: recipientPubkey,
        ))!;

        const twoDays = 60 * 60 * 24 * 2;
        expect(wrap.createdAt, lessThanOrEqualTo(base));
        expect(wrap.createdAt, greaterThanOrEqualTo(base - twoDays));
      },
    );

    test(
      'uses a fresh CSPRNG per call (distinct ephemeral keys and wrap ids)',
      () async {
        final rumor = buildRumor();
        final a = (await buildGiftWrapFromHex(
          senderPrivateKeyHex: senderPrivateKey,
          rumorJson: rumor.toJson(),
          receiverPublicKey: recipientPubkey,
        ))!;
        final b = (await buildGiftWrapFromHex(
          senderPrivateKeyHex: senderPrivateKey,
          rumorJson: rumor.toJson(),
          receiverPublicKey: recipientPubkey,
        ))!;
        expect(a.pubkey, isNot(equals(b.pubkey)));
        expect(a.id, isNot(equals(b.id)));
      },
    );

    test('self-addressed wrap round-trips for the sender', () async {
      final rumor = buildRumor(content: 'note to self');
      final wrap = (await buildGiftWrapFromHex(
        senderPrivateKeyHex: senderPrivateKey,
        rumorJson: rumor.toJson(),
        receiverPublicKey: senderPubkey,
      ))!;

      final senderNostr = Nostr(
        LocalNostrSigner(senderPrivateKey),
        const [],
        dummyRelay,
      );
      final decrypted = await GiftWrapUtil.getRumorEvent(senderNostr, wrap);
      expect(decrypted, isNotNull);
      expect(decrypted!.content, equals('note to self'));
      expect(decrypted.pubkey, equals(senderPubkey));
    });
  });
}
