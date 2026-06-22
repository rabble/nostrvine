// ABOUTME: Tests for GiftWrapUtil.getRumorEvent's injectable off-isolate
// ABOUTME: verifier (verifyPart) and the shared verifyGiftWrapPart helper.
// ABOUTME: Covers: the inline (null-verifier) path is unchanged, the injected
// ABOUTME: verifier gates both the outer wrap and the seal, and the inner
// ABOUTME: rumor is intentionally not signature-checked. See #5424.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

void main() {
  Relay dummyRelay(String url) => RelayBase(url, RelayStatus(url));

  Event signedEvent(
    String privateKey,
    int kind, {
    String content = 'hi',
    List<List<String>> tags = const <List<String>>[],
  }) {
    return Event(getPublicKey(privateKey), kind, tags, content)
      ..sign(privateKey);
  }

  /// Builds a real NIP-17 gift wrap for [rumor] addressed to [recipientPubkey],
  /// sealed and signed by [senderPrivateKey]. When [keepRumorSig] is true the
  /// rumor's signature is left intact (a non-compliant, signed inner rumor).
  Future<Event> buildGiftWrap({
    required Event rumor,
    required String senderPrivateKey,
    required String recipientPubkey,
    bool keepRumorSig = false,
  }) async {
    final senderPubkey = getPublicKey(senderPrivateKey);
    final rumorMap = rumor.toJson();
    if (!keepRumorSig) rumorMap.remove('sig');
    final sealKey = NIP44V2.shareSecret(senderPrivateKey, recipientPubkey);
    final sealContent = await NIP44V2.encrypt(jsonEncode(rumorMap), sealKey);
    final sealEvent = Event(
      senderPubkey,
      EventKind.sealEventKind,
      const <List<String>>[],
      sealContent,
    )..sign(senderPrivateKey);

    final ephemeralPrivateKey = generatePrivateKey();
    final ephemeralPubkey = getPublicKey(ephemeralPrivateKey);
    final wrapKey = NIP44V2.shareSecret(ephemeralPrivateKey, recipientPubkey);
    final wrapContent = await NIP44V2.encrypt(
      jsonEncode(sealEvent.toJson()),
      wrapKey,
    );
    return Event(ephemeralPubkey, EventKind.giftWrap, <List<String>>[
      ['p', recipientPubkey],
    ], wrapContent)..sign(ephemeralPrivateKey);
  }

  group('verifyGiftWrapPart', () {
    test('returns true for a self-valid signed event', () {
      final event = signedEvent(generatePrivateKey(), EventKind.textNote);
      expect(verifyGiftWrapPart(event), isTrue);
    });

    test('returns false when the signature does not verify', () {
      final event = signedEvent(generatePrivateKey(), EventKind.textNote)
        ..sig = '0' * 128;
      expect(verifyGiftWrapPart(event), isFalse);
    });

    test('returns false when the id no longer matches the content', () {
      final event = signedEvent(generatePrivateKey(), EventKind.textNote)
        ..content = 'tampered after signing';
      expect(verifyGiftWrapPart(event), isFalse);
    });
  });

  group('verifyGiftWrapPartJson', () {
    test('true for a valid event toJson round-trip', () {
      final event = signedEvent(generatePrivateKey(), EventKind.textNote);
      expect(verifyGiftWrapPartJson(event.toJson()), isTrue);
    });

    test('false for malformed json rather than throwing', () {
      expect(verifyGiftWrapPartJson(<String, dynamic>{}), isFalse);
    });
  });

  group('getRumorEvent', () {
    late String recipientPrivateKey;
    late String senderPrivateKey;
    late String senderPubkey;
    late Nostr recipientNostr;

    setUp(() {
      recipientPrivateKey = generatePrivateKey();
      senderPrivateKey = generatePrivateKey();
      senderPubkey = getPublicKey(senderPrivateKey);
      recipientNostr = Nostr(
        LocalNostrSigner(recipientPrivateKey),
        const [],
        dummyRelay,
      );
    });

    Future<Event> validWrap() async {
      final rumor = Event(
        senderPubkey,
        EventKind.privateDirectMessage,
        const <List<String>>[],
        'secret message',
      );
      return buildGiftWrap(
        rumor: rumor,
        senderPrivateKey: senderPrivateKey,
        recipientPubkey: getPublicKey(recipientPrivateKey),
      );
    }

    test('inline path (no verifier) unwraps a valid wrap', () async {
      final rumor = await GiftWrapUtil.getRumorEvent(
        recipientNostr,
        await validWrap(),
      );
      expect(rumor, isNotNull);
      expect(rumor!.content, equals('secret message'));
      expect(rumor.pubkey, equals(senderPubkey));
    });

    test(
      'injected verifier is invoked for the outer wrap then the seal',
      () async {
        final verifiedKinds = <int>[];
        Future<bool> verifier(Event event) async {
          verifiedKinds.add(event.kind);
          return verifyGiftWrapPart(event);
        }

        final rumor = await GiftWrapUtil.getRumorEvent(
          recipientNostr,
          await validWrap(),
          verifyPart: verifier,
        );

        expect(rumor, isNotNull);
        expect(rumor!.content, equals('secret message'));
        expect(
          verifiedKinds,
          orderedEquals(<int>[EventKind.giftWrap, EventKind.sealEventKind]),
        );
      },
    );

    test(
      'returns null when the injected verifier rejects the outer wrap',
      () async {
        final verifiedKinds = <int>[];
        Future<bool> rejectOuter(Event event) async {
          verifiedKinds.add(event.kind);
          return event.kind != EventKind.giftWrap;
        }

        final rumor = await GiftWrapUtil.getRumorEvent(
          recipientNostr,
          await validWrap(),
          verifyPart: rejectOuter,
        );

        expect(rumor, isNull);
        // Rejected at the outer wrap — the seal is never reached/verified.
        expect(verifiedKinds, equals(<int>[EventKind.giftWrap]));
      },
    );

    test('returns null when the injected verifier rejects the seal', () async {
      Future<bool> rejectSeal(Event event) async =>
          event.kind != EventKind.sealEventKind;

      final rumor = await GiftWrapUtil.getRumorEvent(
        recipientNostr,
        await validWrap(),
        verifyPart: rejectSeal,
      );

      expect(rumor, isNull);
    });

    test('a signed inner rumor still unwraps (3rd verify removed)', () async {
      final signedRumor = signedEvent(
        senderPrivateKey,
        EventKind.privateDirectMessage,
        content: 'still delivered',
      );
      final wrap = await buildGiftWrap(
        rumor: signedRumor,
        senderPrivateKey: senderPrivateKey,
        recipientPubkey: getPublicKey(recipientPrivateKey),
        keepRumorSig: true,
      );

      final rumor = await GiftWrapUtil.getRumorEvent(recipientNostr, wrap);

      expect(rumor, isNotNull);
      expect(rumor!.content, equals('still delivered'));
      expect(rumor.pubkey, equals(senderPubkey));
    });
  });
}
