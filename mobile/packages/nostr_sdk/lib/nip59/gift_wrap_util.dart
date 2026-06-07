import 'dart:convert';
import 'dart:developer';
import 'dart:math' as math;

import '../client_utils/keys.dart';
import '../event.dart';
import '../event_kind.dart';
import '../nip44/nip44_v2.dart';
import '../nostr.dart';

class GiftWrapUtil {
  static final math.Random _secureRandom = math.Random.secure();

  /// Two days in seconds — the NIP-17 upper bound for created_at jitter.
  static const int _maxBackdateSeconds = 60 * 60 * 24 * 2;

  /// Returns [base] shifted into the past by a CSPRNG offset of 0..2 days.
  /// Call once per layer (seal, gift wrap) so each gets an independent
  /// offset, per NIP-17/NIP-59 metadata-protection guidance.
  static int _randomizedPastTimestamp(int base) =>
      base - _secureRandom.nextInt(_maxBackdateSeconds);

  static Future<Event?> getRumorEvent(Nostr nostr, Event e) async {
    // C16/NIP-44: validate the outer gift wrap (kind 1059) signature before
    // decrypting. Defense-in-depth — diVine relays already verify, but an
    // untrusted relay or local cache could serve a forged/tampered wrap.
    if (!e.isValid || !e.isSigned) {
      log('GiftWrap outer event invalid or unsigned, id: ${e.id}');
      return null;
    }

    var rumorText = await nostr.nostrSigner.nip44Decrypt(e.pubkey, e.content);
    if (rumorText == null) {
      return null;
    }

    var rumorJson = jsonDecode(rumorText);
    var rumorEvent = Event.fromJson(rumorJson);

    if (!rumorEvent.isValid || !rumorEvent.isSigned) {
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

    // C15/NIP-59: the inner rumor MUST be unsigned. A signed rumor is a
    // non-compliant (or malicious) peer — its signature is never trusted for
    // identity (the seal pubkey is authoritative below), but flag it.
    if (innerEvent.isSigned) {
      log(
        'GiftWrap inner rumor is unexpectedly signed (NIP-59 requires '
        'unsigned), gift wrap id: ${e.id}',
      );
    }

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
