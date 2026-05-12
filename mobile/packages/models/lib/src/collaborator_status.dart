// ABOUTME: Per-pubkey collaborator confirmation status for a video.
// ABOUTME: Drives render decisions in CollaboratorAvatarRow and metadata chips.

import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// Confirmation state for a collaborator pubkey on a specific video.
///
/// The Nostr protocol carries pending collaborators on the creator-authored
/// video event as `['p', pubkey, relay, 'collaborator']` tags. Confirmation
/// is derived from the collaborator-authored kind-34238 acceptance event
/// (plus the latest creator-authored tag still naming them). See
/// `docs/superpowers/specs/2026-04-25-collab-invite-acceptance-design.md`.
enum CollaboratorStatus {
  /// Tagged by the creator on the latest video event; no acceptance observed.
  pending,

  /// Tagged by the creator AND the collaborator has published a kind-34238
  /// acceptance for this video, OR the current user (acting as the
  /// collaborator) has marked the invite accepted locally.
  confirmed,

  /// The current user (acting as the collaborator) has marked the invite
  /// ignored locally. Ignore is local-only per spec — no protocol publish.
  /// Only meaningful when the queried pubkey matches the current user.
  ignored,
}

/// Immutable status snapshot for a video, keyed by collaborator pubkey.
@immutable
class VideoCollaboratorStatus extends Equatable {
  const VideoCollaboratorStatus({
    required this.videoAddress,
    this.statusByPubkey = const {},
  });

  /// NIP-33 addressable id of the video, e.g. `34236:<creator>:<dTag>`.
  final String videoAddress;

  /// Per-collaborator status. Pubkeys absent from the map are treated as
  /// [CollaboratorStatus.pending] by callers.
  final Map<String, CollaboratorStatus> statusByPubkey;

  CollaboratorStatus statusFor(String pubkey) =>
      statusByPubkey[pubkey] ?? CollaboratorStatus.pending;

  VideoCollaboratorStatus copyWith({
    Map<String, CollaboratorStatus>? statusByPubkey,
  }) {
    return VideoCollaboratorStatus(
      videoAddress: videoAddress,
      statusByPubkey: statusByPubkey ?? this.statusByPubkey,
    );
  }

  @override
  List<Object?> get props => [videoAddress, statusByPubkey];
}
