import 'dart:convert';
import 'dart:developer';
import 'dart:math' as math;

import '../client_utils/keys.dart';
import '../event.dart';
import '../event_kind.dart';
import '../nip44/nip44_v2.dart';
import '../nostr.dart';

/// Verifies one gift-wrap-layer event's integrity and signature: it recomputes
/// the event id (sha256, [Event.isValid]) and verifies the Schnorr signature
/// ([Event.isSigned]). This is the single shared definition of "this gift-wrap
/// part is well-formed and authentically signed", used by
/// [GiftWrapUtil.getRumorEvent] (inline and via an injected
/// [GiftWrapPartVerifier]) and by the off-isolate DM history-drain verifier.
///
/// Pure (no I/O, no private key), so it is safe to run inside an isolate.
bool verifyGiftWrapPart(Event event) => event.isValid && event.isSigned;

/// [verifyGiftWrapPart] over an [Event.toJson] map, so the check can cross an
/// isolate boundary. Returns `false` for malformed JSON rather than throwing.
bool verifyGiftWrapPartJson(Map<String, dynamic> eventJson) {
  try {
    return verifyGiftWrapPart(Event.fromJson(eventJson));
  } on Object {
    return false;
  }
}

/// Asynchronously verifies a single gift-wrap-layer [Event]. Injected into
/// [GiftWrapUtil.getRumorEvent] so the (CPU-bound, pure-Dart) id + Schnorr
/// verification can be moved off the main isolate on the high-volume remote-
/// signer history drain — where the decrypt itself must stay on the main
/// isolate (a remote signer cannot cross a `SendPort`). When omitted,
/// `getRumorEvent` verifies inline on the calling isolate, unchanged.
typedef GiftWrapPartVerifier = Future<bool> Function(Event event);

class GiftWrapUtil {
  static final math.Random _secureRandom = math.Random.secure();

  /// Two days in seconds — the NIP-17 upper bound for created_at jitter.
  static const int _maxBackdateSeconds = 60 * 60 * 24 * 2;

  /// Returns [base] shifted into the past by a CSPRNG offset of 0..2 days.
  /// Call once per layer (seal, gift wrap) so each gets an independent
  /// offset, per NIP-17/NIP-59 metadata-protection guidance.
  static int _randomizedPastTimestamp(int base) =>
      base - _secureRandom.nextInt(_maxBackdateSeconds);

  /// Unwraps a NIP-17 gift wrap (kind 1059) → seal (kind 13) → rumor and
  /// returns the inner rumor, or `null` if any layer fails.
  ///
  /// The two id + Schnorr verifications (outer wrap and seal) are run via
  /// [verifyPart] when provided, so a caller can move that CPU-bound work off
  /// the main isolate (the remote-signer history drain does this). When
  /// [verifyPart] is `null` they run inline on the calling isolate, unchanged.
  /// The two `nip44Decrypt` calls always stay on the calling isolate — a remote
  /// signer's RPC/IPC cannot cross a `SendPort`.
  static Future<Event?> getRumorEvent(
    Nostr nostr,
    Event e, {
    GiftWrapPartVerifier? verifyPart,
  }) async {
    // C16/NIP-44: validate the outer gift wrap (kind 1059) signature before
    // decrypting. Defense-in-depth — diVine relays already verify, but an
    // untrusted relay or local cache could serve a forged/tampered wrap.
    final outerValid = verifyPart != null
        ? await verifyPart(e)
        : verifyGiftWrapPart(e);
    if (!outerValid) {
      log('GiftWrap outer event invalid or unsigned, id: ${e.id}');
      return null;
    }

    var rumorText = await nostr.nostrSigner.nip44Decrypt(e.pubkey, e.content);
    if (rumorText == null) {
      return null;
    }

    var rumorJson = jsonDecode(rumorText);
    var rumorEvent = Event.fromJson(rumorJson);

    // C16/NIP-44: validate the seal (kind 13). Unlike the outer wrap, the seal
    // is NIP-44-encrypted so no relay can ever verify it — this is the sole
    // cryptographic anchor of sender identity, so it is always enforced.
    final sealValid = verifyPart != null
        ? await verifyPart(rumorEvent)
        : verifyGiftWrapPart(rumorEvent);
    if (!sealValid) {
      log(
        "GiftWrap rumorEvent sign check result fail, id: ${e.id}, from: ${e.pubkey}",
      );
      return null;
    }

    var sourceText = await nostr.nostrSigner.nip44Decrypt(
      rumorEvent.pubkey,
      rumorEvent.content,
    );
    if (sourceText == null) {
      return null;
    }

    var jsonObj = jsonDecode(sourceText);
    var innerEvent = Event.fromJson(jsonObj);

    // The inner rumor is intentionally NOT signature-checked: NIP-59 requires
    // it to be unsigned, and its claimed authorship is never trusted for
    // identity — the seal pubkey (authenticated above) is authoritative below.

    // NIP-17 sender verification: the seal's pubkey should match the rumor's
    // pubkey. When they differ, the rumor's claimed author is unverified while
    // the seal's pubkey IS cryptographically authenticated (it's signed).
    // Some Nostr clients in the wild produce mismatched pubkeys. Rather than
    // rejecting the message entirely, we accept it but attribute it to the
    // seal's authenticated pubkey to prevent impersonation.
    if (rumorEvent.pubkey != innerEvent.pubkey) {
      log(
        'GiftWrap sender pubkey mismatch: seal=${rumorEvent.pubkey} '
        'rumor=${innerEvent.pubkey}. Using seal pubkey as authoritative sender.',
      );
      // C4: rebuild the rumor with the seal's authenticated pubkey so the
      // event id is RECOMPUTED to match (Event.fromJson would otherwise carry
      // over the spoofed id). The rebuilt rumor is unsigned, per NIP-59.
      return Event(
        rumorEvent.pubkey,
        innerEvent.kind,
        innerEvent.tags,
        innerEvent.content,
        createdAt: innerEvent.createdAt,
      );
    }

    return innerEvent;
  }

  static Future<Event?> getGiftWrapEvent(
    Nostr nostr,
    Event e,
    String receiverPublicKey,
  ) async {
    // C3/C7/NIP-17: randomize created_at on BOTH the seal and the gift wrap,
    // independently, up to two days into the past, using a CSPRNG — so a relay
    // observer cannot correlate the two layers by timestamp nor learn the true
    // send time. The canonical time stays on the (unsigned) inner rumor.
    final sealCreatedAt = _randomizedPastTimestamp(e.createdAt);
    final giftEventCreatedAt = _randomizedPastTimestamp(e.createdAt);
    var rumorEventMap = e.toJson();
    rumorEventMap.remove("sig");

    var sealEventContent = await nostr.nostrSigner.nip44Encrypt(
      receiverPublicKey,
      jsonEncode(rumorEventMap),
    );
    if (sealEventContent == null) {
      return null;
    }
    var sealEvent = Event(
      nostr.publicKey,
      EventKind.sealEventKind,
      [],
      sealEventContent,
      createdAt: sealCreatedAt,
    );
    await nostr.signEvent(sealEvent);

    var randomPrivateKey = generatePrivateKey();
    var randomPubkey = getPublicKey(randomPrivateKey);
    var randomKey = NIP44V2.shareSecret(randomPrivateKey, receiverPublicKey);
    var giftWrapEventContent = await NIP44V2.encrypt(
      jsonEncode(sealEvent.toJson()),
      randomKey,
    );
    var giftWrapEvent = Event(
      randomPubkey,
      EventKind.giftWrap,
      [
        ["p", receiverPublicKey],
      ],
      giftWrapEventContent,
      createdAt: giftEventCreatedAt,
    );
    giftWrapEvent.sign(randomPrivateKey);

    return giftWrapEvent;
  }
}
