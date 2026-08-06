// ABOUTME: A liker list re-resolved after a video's revision lookup landed.
// ABOUTME: Emitted by LikesRepository.watchRevisionEnrichedLikers.

import 'package:equatable/equatable.dart';

/// A "Liked by" list re-resolved once a video's superseded revision ids became
/// known (#6021).
///
/// Those ids come from a backend lookup, so they are not available at the
/// moment a fetch answers. Rather than hold the current-id result until the
/// lookup lands, the repository returns it immediately and publishes the wider
/// list here when it can. Only emitted when the wider list actually differs
/// from the one the fetch returned.
class RevisionEnrichedLikers extends Equatable {
  /// Creates a re-resolved liker list for [eventId].
  const RevisionEnrichedLikers({
    required this.eventId,
    required this.likerPubkeys,
  });

  /// The event id the original fetch asked about, not the revision a newly
  /// reachable reaction happened to name.
  final String eventId;

  /// Every active liker of [eventId], in the same shape
  /// `LikesRepository.fetchEventLikers` returns: deduplicated per pubkey,
  /// downvotes and self-deleted and blocked reactions removed, most recent
  /// first. Supersedes the previously returned list rather than adding to it.
  final List<String> likerPubkeys;

  @override
  List<Object?> get props => [eventId, likerPubkeys];
}
