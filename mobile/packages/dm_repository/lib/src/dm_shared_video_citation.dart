// ABOUTME: Builds + parses the NIP-18 `q` citation for a video shared in a DM.
// ABOUTME: Encodes naddr (addressable 34236) / nevent (regular 22) per NIP-19.

import 'package:models/models.dart';
import 'package:nostr_sdk/nip19/nip19_tlv.dart';

/// Shared-video citation constants.
abstract class DmShareConstants {
  /// Relay hint used when the video carries no known source relay.
  static const String defaultRelayHint = 'wss://relay.divine.video';
}

final RegExp _hex64 = RegExp(r'^[0-9a-fA-F]{64}$');

bool _isHex64(String value) => _hex64.hasMatch(value);

/// The machine-readable + human-readable halves of a video citation inside a
/// NIP-17 kind-14 rumor: the NIP-18 `q` tag and the NIP-21 `nostr:` URI.
class DmSharedVideoCitation {
  /// Creates a citation from a prebuilt [qTag] and [nostrUri].
  const DmSharedVideoCitation({required this.qTag, required this.nostrUri});

  /// The `["q", "<coordinate-or-id>", "<relay>", "<author?>"]` tag.
  final List<String> qTag;

  /// The `nostr:naddr1…` / `nostr:nevent1…` URI for the message content.
  final String nostrUri;

  /// Builds a citation for a video, choosing `naddr` (addressable) vs `nevent`
  /// (regular) by [videoKind]. Returns `null` when the inputs can't form a
  /// valid reference (so the caller can fall back to a plain-text share).
  ///
  /// - Addressable (34236/34235): `q = ["q", "<kind>:<author>:<d>", relay]`
  ///   with NO 4th element (the pubkey is already in the coordinate).
  /// - Regular (22): `q = ["q", "<event-id>", relay, "<author>"]`.
  static DmSharedVideoCitation? build({
    required int videoKind,
    required String authorPubkey,
    required String relayHint,
    String? dTag,
    String? eventId,
  }) {
    if (!_isHex64(authorPubkey)) return null;
    final relay = relayHint.isNotEmpty
        ? relayHint
        : DmShareConstants.defaultRelayHint;

    final isAddressable =
        videoKind == NIP71VideoKinds.addressableShortVideo ||
        videoKind == NIP71VideoKinds.addressableNormalVideo;

    if (isAddressable) {
      if (dTag == null || dTag.isEmpty) return null;
      final coordinate = '$videoKind:$authorPubkey:$dTag';
      final naddr = NIP19Tlv.encodeNaddr(
        Naddr(
          id: dTag,
          author: authorPubkey,
          kind: videoKind,
          relays: [relay],
        ),
      );
      return DmSharedVideoCitation(
        qTag: ['q', coordinate, relay],
        nostrUri: 'nostr:$naddr',
      );
    }

    if (eventId == null || !_isHex64(eventId)) return null;
    final nevent = NIP19Tlv.encodeNevent(
      Nevent(id: eventId, author: authorPubkey, relays: [relay]),
    );
    return DmSharedVideoCitation(
      qTag: ['q', eventId, relay, authorPubkey],
      nostrUri: 'nostr:$nevent',
    );
  }

  /// Parses the first `q` tag of a kind-14 rumor's [tags] into a
  /// [DmSharedVideoRef]. Total — returns `null` for absent/malformed tags so a
  /// plain message degrades gracefully.
  static DmSharedVideoRef? parse(List<List<String>> tags) {
    for (final tag in tags) {
      if (tag.length < 2 || tag[0] != 'q') continue;
      final value = tag[1];
      if (value.isEmpty) continue;
      final relayHint = tag.length >= 3 && tag[2].isNotEmpty ? tag[2] : null;
      final explicitAuthor = tag.length >= 4 && tag[3].isNotEmpty
          ? tag[3]
          : null;

      // Addressable coordinate: "<kind>:<author>:<d>".
      final coordParts = value.split(':');
      final coordinateKind = int.tryParse(coordParts.first);
      final isSupportedAddressableKind =
          coordinateKind == DmSharedVideoKind.addressableShortVideo.kind ||
          coordinateKind == DmSharedVideoKind.addressableNormalVideo.kind;
      if (coordParts.length >= 3 && isSupportedAddressableKind) {
        return DmSharedVideoRef(
          coordinateOrId: value,
          videoKind: DmSharedVideoKind.fromKind(coordinateKind!),
          relayHint: relayHint,
          authorPubkey: coordParts[1].isNotEmpty
              ? coordParts[1]
              : explicitAuthor,
        );
      }

      // Regular event id (64-hex).
      if (_isHex64(value)) {
        return DmSharedVideoRef(
          coordinateOrId: value,
          videoKind: DmSharedVideoKind.shortVideo,
          relayHint: relayHint,
          authorPubkey: explicitAuthor,
        );
      }
    }
    return null;
  }
}
