// ABOUTME: Tests for GiftWrapUtil.getRumorEvent's injectable off-isolate
// ABOUTME: verifier (verifyPart) and the shared verifyGiftWrapPart helper.
// ABOUTME: Covers: the inline (null-verifier) path is unchanged, the injected
// ABOUTME: verifier gates both the outer wrap and the seal, and the inner
// ABOUTME: rumor is intentionally not signature-checked. See #5424.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

/// A signer that encrypts normally but refuses to sign, returning `null` from
/// [signEvent] exactly as a remote signer does when the user dismisses the
/// Amber approval prompt, a NIP-46 bunker RPC times out, or NIP-07 rejects.
class _RefusesToSignSigner implements NostrSigner {
  _RefusesToSignSigner(this._delegate);

  final LocalNostrSigner _delegate;

  @override
  Future<Event?> signEvent(Event event) async => null;

  @override
  Future<String?> getPublicKey() => _delegate.getPublicKey();

  @override
  Future<Map<dynamic, dynamic>?> getRelays() => _delegate.getRelays();

  @override
  Future<String?> encrypt(String pubkey, String plaintext) =>
      _delegate.encrypt(pubkey, plaintext);

  @override
  Future<String?> decrypt(String pubkey, String ciphertext) =>
      _delegate.decrypt(pubkey, ciphertext);

  @override
  Future<String?> nip44Encrypt(String pubkey, String plaintext) =>
      _delegate.nip44Encrypt(pubkey, plaintext);

  @override
  Future<String?> nip44Decrypt(String pubkey, String ciphertext) =>
      _delegate.nip44Decrypt(pubkey, ciphertext);

  @override
  void close() => _delegate.close();
}

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
    void Function(Map<String, dynamic> rumorMap)? mutateRumorMap,
  }) async {
    final senderPubkey = getPublicKey(senderPrivateKey);
    final rumorMap = rumor.toJson();
    if (!keepRumorSig) rumorMap.remove('sig');
    mutateRumorMap?.call(rumorMap);
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

    group('inner rumor id is derived, never trusted', () {
      // NIP-59 leaves the rumor unsigned, so nothing binds its claimed `id`
      // to its body — yet that id becomes the direct_messages primary key
      // and the reaction upsert key. A sender who claims an id already in
      // use could otherwise silently overwrite another user's row.
      test(
        'a claimed non-canonical id is replaced by the canonical one',
        () async {
          final tampered = Event(
            senderPubkey,
            EventKind.privateDirectMessage,
            const <List<String>>[],
            'secret message',
          );
          final canonicalId = tampered.id;
          // Claim an id that does not match the body at all.
          tampered.id = 'f' * 64;

          final wrap = await buildGiftWrap(
            rumor: tampered,
            senderPrivateKey: senderPrivateKey,
            recipientPubkey: getPublicKey(recipientPrivateKey),
          );

          final rumor = await GiftWrapUtil.getRumorEvent(recipientNostr, wrap);

          expect(rumor, isNotNull);
          expect(rumor!.id, isNot(equals('f' * 64)));
          expect(rumor.id, equals(canonicalId));
          expect(rumor.isValid, isTrue);
          // Body is untouched — only the id is re-derived.
          expect(rumor.content, equals('secret message'));
          expect(rumor.pubkey, equals(senderPubkey));
        },
      );

      test('an honest sender sees no divergence in the id', () async {
        final honest = Event(
          senderPubkey,
          EventKind.privateDirectMessage,
          const <List<String>>[
            ['p', 'abc'],
          ],
          'round trip',
        );
        final wrap = await buildGiftWrap(
          rumor: honest,
          senderPrivateKey: senderPrivateKey,
          recipientPubkey: getPublicKey(recipientPrivateKey),
        );

        final rumor = await GiftWrapUtil.getRumorEvent(recipientNostr, wrap);

        // Our own send path builds rumors through the same constructor, so
        // the self-wrap round trip and outgoing-queue key stay consistent.
        expect(rumor!.id, equals(honest.id));
      });

      test('a spoofed author is re-attributed AND its id re-derived from the '
          'seal pubkey', () async {
        final impostorPubkey = getPublicKey(generatePrivateKey());
        final spoofed = Event(
          impostorPubkey,
          EventKind.privateDirectMessage,
          const <List<String>>[],
          'i am someone else',
        );
        final spoofedId = spoofed.id;

        final wrap = await buildGiftWrap(
          rumor: spoofed,
          // Sealed and signed by the real sender, claiming another author.
          senderPrivateKey: senderPrivateKey,
          recipientPubkey: getPublicKey(recipientPrivateKey),
        );

        final rumor = await GiftWrapUtil.getRumorEvent(recipientNostr, wrap);

        expect(rumor, isNotNull);
        expect(rumor!.pubkey, equals(senderPubkey));
        expect(rumor.id, isNot(equals(spoofedId)));
        expect(rumor.isValid, isTrue);
      });

      test('an omitted claimed id and pubkey still unwraps', () async {
        final honest = Event(
          senderPubkey,
          EventKind.privateDirectMessage,
          const <List<String>>[
            ['p', 'abc'],
          ],
          'minimal rumor',
        );
        final expectedId = honest.id;
        final wrap = await buildGiftWrap(
          rumor: honest,
          senderPrivateKey: senderPrivateKey,
          recipientPubkey: getPublicKey(recipientPrivateKey),
          mutateRumorMap: (rumorMap) {
            rumorMap.remove('id');
            rumorMap.remove('pubkey');
          },
        );

        final rumor = await GiftWrapUtil.getRumorEvent(recipientNostr, wrap);

        expect(rumor, isNotNull);
        expect(rumor!.id, equals(expectedId));
        expect(rumor.pubkey, equals(senderPubkey));
        expect(rumor.content, equals('minimal rumor'));
      });
    });
  });

  group('getGiftWrapEvent refuses to ship an unsigned seal', () {
    late String senderPrivateKey;
    late String recipientPubkey;

    setUp(() {
      senderPrivateKey = generatePrivateKey();
      recipientPubkey = getPublicKey(generatePrivateKey());
    });

    Event rumorFor(String senderPubkey) =>
        Event(senderPubkey, EventKind.privateDirectMessage, <List<String>>[
          ['p', recipientPubkey],
        ], 'never delivered');

    test('returns null when the signer declines to sign the seal', () async {
      final signer = _RefusesToSignSigner(LocalNostrSigner(senderPrivateKey));
      final nostr = Nostr(signer, const [], dummyRelay);
      await nostr.refreshPublicKey();

      final wrap = await GiftWrapUtil.getGiftWrapEvent(
        nostr,
        rumorFor(getPublicKey(senderPrivateKey)),
        recipientPubkey,
      );

      // A wrap here would be signed by a valid ephemeral key, so relays would
      // accept it and the send would report delivered — while every recipient
      // dropped it at the seal signature check.
      expect(wrap, isNull);
    });

    test('still builds a signed wrap when the signer cooperates', () async {
      final nostr = Nostr(
        LocalNostrSigner(senderPrivateKey),
        const [],
        dummyRelay,
      );
      await nostr.refreshPublicKey();

      final wrap = await GiftWrapUtil.getGiftWrapEvent(
        nostr,
        rumorFor(getPublicKey(senderPrivateKey)),
        recipientPubkey,
      );

      expect(wrap, isNotNull);
      expect(verifyGiftWrapPart(wrap!), isTrue);
    });

    test(
      'buildGiftWrapFromHex fails loudly on a key Event.sign would no-op on',
      () async {
        // Event.sign silently no-ops when keyIsValid is false, which would
        // otherwise produce the same unsigned seal as a declining signer. On
        // this path getPublicKey rejects those keys first, so the build throws
        // instead of returning a wrap — no unsigned DM can escape either way.
        expect(
          () => buildGiftWrapFromHex(
            senderPrivateKeyHex: 'not-a-valid-private-key',
            rumorJson: rumorFor(getPublicKey(generatePrivateKey())).toJson(),
            receiverPublicKey: recipientPubkey,
          ),
          throwsArgumentError,
        );
      },
    );

    test('buildGiftWrapFromHex still builds for a valid key', () async {
      final wrap = await buildGiftWrapFromHex(
        senderPrivateKeyHex: senderPrivateKey,
        rumorJson: rumorFor(getPublicKey(senderPrivateKey)).toJson(),
        receiverPublicKey: recipientPubkey,
      );

      expect(wrap, isNotNull);
      expect(verifyGiftWrapPart(wrap!), isTrue);
    });
  });
}
