// ABOUTME: View-model for status-aware collaborator rendering.
// ABOUTME: Combines tagged pubkeys with per-pubkey status + viewer context.

import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
import 'package:models/models.dart';

/// Encapsulates the inputs needed by collaborator-rendering surfaces
/// (avatar row, metadata section, edit dialog) so the filter / decoration /
/// pending-count logic lives in one place rather than being recomputed
/// surface-by-surface.
///
/// Construct with the default constructor when the status pipeline is
/// available; use [CollaboratorVisibility.fallback] when the repository is
/// gated off (Nostr not ready, no addressable id, no current user) and the
/// surface should render the raw tagged list unchanged from pre-pipeline
/// behaviour.
@immutable
class CollaboratorVisibility extends Equatable {
  const CollaboratorVisibility({
    required this.taggedPubkeys,
    required this.statusByPubkey,
    required this.currentUserPubkey,
    required this.creatorPubkey,
  }) : _hasStatusPipeline = true;

  const CollaboratorVisibility.fallback({required this.taggedPubkeys})
    : statusByPubkey = const {},
      currentUserPubkey = '',
      creatorPubkey = '',
      _hasStatusPipeline = false;

  /// Pubkeys tagged with the `'collaborator'` role on the latest
  /// creator-authored video event.
  final List<String> taggedPubkeys;

  /// Per-collaborator status as derived by the repository. Empty in
  /// fallback mode.
  final Map<String, CollaboratorStatus> statusByPubkey;

  /// Hex pubkey of the currently signed-in user. Empty in fallback mode.
  final String currentUserPubkey;

  /// Hex pubkey of the video's author. Empty in fallback mode.
  final String creatorPubkey;

  final bool _hasStatusPipeline;

  /// True when the current user authored the video. Always false in
  /// fallback mode.
  bool get isInviterView =>
      _hasStatusPipeline && currentUserPubkey == creatorPubkey;

  /// Status for [pubkey]. Returns [CollaboratorStatus.pending] when the
  /// status pipeline is unavailable or no entry exists.
  CollaboratorStatus statusFor(String pubkey) =>
      statusByPubkey[pubkey] ?? CollaboratorStatus.pending;

  /// Pubkeys to render. The current user's pubkey is filtered out when
  /// they have locally ignored the invite. In fallback mode this is the
  /// raw [taggedPubkeys] list.
  List<String> get visiblePubkeys {
    if (!_hasStatusPipeline) return taggedPubkeys;
    return [
      for (final pubkey in taggedPubkeys)
        if (!_isHiddenByCurrentUserIgnore(pubkey)) pubkey,
    ];
  }

  /// Whether [pubkey] should render a "pending" decoration. Only true on
  /// the inviter's own video for collaborators that haven't accepted yet.
  bool isPendingForInviter(String pubkey) {
    if (!isInviterView) return false;
    return statusFor(pubkey) == CollaboratorStatus.pending;
  }

  /// Count of pending collaborators visible on the inviter's view. Zero
  /// for any other viewer or in fallback mode.
  int get pendingCount {
    if (!isInviterView) return 0;
    return visiblePubkeys.where(isPendingForInviter).length;
  }

  bool _isHiddenByCurrentUserIgnore(String pubkey) =>
      pubkey == currentUserPubkey &&
      statusFor(pubkey) == CollaboratorStatus.ignored;

  @override
  List<Object?> get props => [
    taggedPubkeys,
    statusByPubkey,
    currentUserPubkey,
    creatorPubkey,
    _hasStatusPipeline,
  ];
}
