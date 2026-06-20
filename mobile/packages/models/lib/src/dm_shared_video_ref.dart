// ABOUTME: Structured reference to a video event cited inside a NIP-17 DM.
// ABOUTME: Parsed from a NIP-18 `q` tag so clients can render a rich card.

import 'package:equatable/equatable.dart';

/// Which NIP-71 video kind a shared-video DM reference points at.
enum DmSharedVideoKind {
  /// Addressable short video (kind 34236) — referenced by `naddr` coordinate.
  addressableShortVideo(34236),

  /// Addressable normal video (kind 34235) — referenced by `naddr` coordinate.
  addressableNormalVideo(34235),

  /// Regular short video (kind 22) — referenced by `nevent` event id.
  shortVideo(22);

  const DmSharedVideoKind(this.kind);

  /// The numeric NIP-71 event kind.
  final int kind;

  /// Maps a raw kind to a [DmSharedVideoKind]; anything that isn't a supported
  /// addressable video kind is treated as a regular short video.
  static DmSharedVideoKind fromKind(int kind) => switch (kind) {
    34236 => addressableShortVideo,
    34235 => addressableNormalVideo,
    _ => shortVideo,
  };
}

/// A structured reference to a video event cited inside a NIP-17 DM.
///
/// Built from a NIP-18 `q` tag on a kind-14 rumor:
/// `["q", "<coordinate-or-id>", "<relay-hint>", "<author?>"]`. Lets the
/// recipient render a deterministic video card instead of regex-matching a URL
/// embedded in the message text.
class DmSharedVideoRef extends Equatable {
  const DmSharedVideoRef({
    required this.coordinateOrId,
    required this.videoKind,
    this.relayHint,
    this.authorPubkey,
    this.nip19,
  });

  /// The `q`-tag target: a `34236:<author>:<d>` coordinate for addressable
  /// events, or a 64-hex event id for regular events.
  final String coordinateOrId;

  /// The video kind this reference points at.
  final DmSharedVideoKind videoKind;

  /// Optional relay hint where the video can be fetched.
  final String? relayHint;

  /// Author pubkey of the referenced video (always present for regular
  /// events; embedded in the coordinate for addressable events).
  final String? authorPubkey;

  /// The `nostr:` URI form (`naddr1…` / `nevent1…`) when available.
  final String? nip19;

  /// Whether the reference is to an addressable (coordinate-keyed) event.
  bool get isAddressable =>
      videoKind == DmSharedVideoKind.addressableShortVideo ||
      videoKind == DmSharedVideoKind.addressableNormalVideo;

  /// For an addressable ref, the `<d>` identifier extracted from the
  /// `<kind>:<author>:<d>` coordinate; `null` for regular events or a
  /// malformed coordinate.
  String? get dTag {
    if (!isAddressable) return null;
    final parts = coordinateOrId.split(':');
    if (parts.length < 3) return null;
    final d = parts.sublist(2).join(':');
    return d.isEmpty ? null : d;
  }

  /// For a regular ref, the 64-hex event id (the `coordinateOrId` itself);
  /// `null` for addressable events.
  String? get eventId => isAddressable ? null : coordinateOrId;

  /// JSON form for persistence in the `direct_messages.shared_video_ref_json`
  /// Drift column.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'coordinateOrId': coordinateOrId,
    'kind': videoKind.kind,
    if (relayHint != null) 'relayHint': relayHint,
    if (authorPubkey != null) 'authorPubkey': authorPubkey,
    if (nip19 != null) 'nip19': nip19,
  };

  /// Rehydrates a [DmSharedVideoRef] from [toJson] output. Returns `null` for
  /// malformed maps so a corrupt persisted value degrades to a plain message.
  static DmSharedVideoRef? fromJson(Map<String, dynamic> json) {
    final coordinateOrId = json['coordinateOrId'] as String?;
    final kind = (json['kind'] as num?)?.toInt();
    if (coordinateOrId == null || coordinateOrId.isEmpty || kind == null) {
      return null;
    }
    return DmSharedVideoRef(
      coordinateOrId: coordinateOrId,
      videoKind: DmSharedVideoKind.fromKind(kind),
      relayHint: json['relayHint'] as String?,
      authorPubkey: json['authorPubkey'] as String?,
      nip19: json['nip19'] as String?,
    );
  }

  @override
  List<Object?> get props => [
    coordinateOrId,
    videoKind,
    relayHint,
    authorPubkey,
    nip19,
  ];
}
