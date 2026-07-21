// ABOUTME: Normalized identity for videos shared inside DM messages.
// ABOUTME: Resolves legacy Divine URLs and structured q references consistently.

import 'package:flutter/foundation.dart';
import 'package:models/models.dart';
import 'package:openvine/utils/divine_video_url.dart';

/// Normalized identity and routing metadata for a video shared in a DM.
@immutable
class DmVideoTarget {
  const DmVideoTarget({
    required this.stableId,
    this.authorPubkey,
    this.videoKind,
  });

  /// Stable route ID used by Divine video URLs and repository lookups.
  final String stableId;

  /// Full author pubkey when supplied by a structured NIP-18 reference.
  final String? authorPubkey;

  /// NIP-71 video event kind when supplied by a structured reference.
  final int? videoKind;

  /// Canonical web URL for copying or sharing this video.
  String get canonicalUrl => 'https://divine.video/video/$stableId';

  /// Author-scoped repository route used to disambiguate addressable videos.
  List<String> get fallbackRouteIds {
    final author = authorPubkey;
    final kind = videoKind;
    if (author == null || kind == null) return const [];
    return ['$kind:$author:$stableId'];
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DmVideoTarget &&
          stableId == other.stableId &&
          authorPubkey == other.authorPubkey &&
          videoKind == other.videoKind;

  @override
  int get hashCode => Object.hash(stableId, authorPubkey, videoKind);
}

/// Resolves the video represented by a DM's plaintext and structured citation.
///
/// Canonical Divine URLs remain the primary stable identity for compatibility
/// with older messages. A valid NIP-18 `q` reference contributes author/kind
/// routing metadata, or supplies the identity when no URL is present.
DmVideoTarget? resolveDmVideoTarget({
  required String content,
  DmSharedVideoRef? sharedVideoRef,
}) {
  final urlStableId = divineVideoUrlRegex.firstMatch(content)?.group(1);
  final structuredTarget = _targetFromRef(sharedVideoRef);

  if (urlStableId != null) {
    return DmVideoTarget(
      stableId: urlStableId,
      authorPubkey: structuredTarget?.authorPubkey,
      videoKind: structuredTarget?.videoKind,
    );
  }

  return structuredTarget;
}

DmVideoTarget? _targetFromRef(DmSharedVideoRef? ref) {
  if (ref == null) return null;
  if (!ref.isAddressable) {
    return DmVideoTarget(
      stableId: ref.coordinateOrId,
      authorPubkey: ref.authorPubkey,
      videoKind: ref.videoKind.kind,
    );
  }

  final parts = ref.coordinateOrId.split(':');
  if (parts.length < 3) return null;
  final kind = int.tryParse(parts.first);
  final author = parts[1].isNotEmpty ? parts[1] : ref.authorPubkey;
  final stableId = ref.dTag;
  if (kind == null || stableId == null) return null;

  return DmVideoTarget(
    stableId: stableId,
    authorPubkey: author,
    videoKind: kind,
  );
}
