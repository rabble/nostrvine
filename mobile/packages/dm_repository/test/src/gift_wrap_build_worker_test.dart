// ABOUTME: Tests for buildGiftWrapBatch — the off-main-isolate NIP-17 gift-wrap
// ABOUTME: build worker. Covers per-receiver ordering, round-trip decrypt, the
// ABOUTME: never-throws contract, and a real compute() isolate run.

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter/foundation.dart' show compute;
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

  Map<String, dynamic> rumorJson({String content = 'hi'}) => Event(
    senderPubkey,
    EventKind.privateDirectMessage,
    const <List<String>>[],
    content,
  ).toJson();

  Future<Event?> decryptFor(
    String recipientPriv,
    Map<String, dynamic> wrapJson,
  ) {
    final nostr = Nostr(LocalNostrSigner(recipientPriv), const [], dummyRelay);
    return GiftWrapUtil.getRumorEvent(nostr, Event.fromJson(wrapJson));
  }

  group('buildGiftWrapBatch', () {
    test(
      'returns one result per receiver, in order, and both round-trip',
      () async {
        final results = await buildGiftWrapBatch(
          BuildGiftWrapRequest(
            privateKeyHex: senderPrivateKey,
            rumorJson: rumorJson(content: 'batched'),
            receiverPublicKeys: [recipientPubkey, senderPubkey],
          ),
        );

        expect(results, hasLength(2));
        expect(results.every((r) => r.isSuccess), isTrue);

        // results[0] = recipient wrap, results[1] = self wrap; order preserved.
        final toRecipient = await decryptFor(
          recipientPrivateKey,
          results[0].giftWrap!,
        );
        expect(toRecipient, isNotNull);
        expect(toRecipient!.content, equals('batched'));
        expect(toRecipient.pubkey, equals(senderPubkey));

        final toSelf = await decryptFor(senderPrivateKey, results[1].giftWrap!);
        expect(toSelf, isNotNull);
        expect(toSelf!.content, equals('batched'));
      },
    );

    test(
      'never throws on a malformed receiver — emits a failure entry',
      () async {
        final results = await buildGiftWrapBatch(
          BuildGiftWrapRequest(
            privateKeyHex: senderPrivateKey,
            rumorJson: rumorJson(),
            receiverPublicKeys: ['not-a-valid-pubkey', recipientPubkey],
          ),
        );

        expect(results, hasLength(2));
        expect(results[0].isSuccess, isFalse);
        expect(results[0].error, isNotNull);
        // A valid receiver still succeeds despite the bad one.
        expect(results[1].isSuccess, isTrue);
      },
    );

    test('empty receiver list yields an empty result list', () async {
      final results = await buildGiftWrapBatch(
        BuildGiftWrapRequest(
          privateKeyHex: senderPrivateKey,
          rumorJson: rumorJson(),
          receiverPublicKeys: const [],
        ),
      );
      expect(results, isEmpty);
    });

    test('runs inside a real compute() isolate and round-trips', () async {
      final results = await compute(
        buildGiftWrapBatch,
        BuildGiftWrapRequest(
          privateKeyHex: senderPrivateKey,
          rumorJson: rumorJson(content: 'from isolate'),
          receiverPublicKeys: [recipientPubkey],
        ),
      );
      expect(results, hasLength(1));
      expect(results.single.isSuccess, isTrue);
      final decrypted = await decryptFor(
        recipientPrivateKey,
        results.single.giftWrap!,
      );
      expect(decrypted, isNotNull);
      expect(decrypted!.content, equals('from isolate'));
    });
  });
}
