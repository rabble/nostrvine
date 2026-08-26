// ABOUTME: Failure type for a kind-5 DM retraction that no relay accepted.
// ABOUTME: Carries the publish outcome as facts; classification lives above.

import 'package:nostr_sdk/relay/publish_outcome.dart';

/// Thrown by `DmRepository.deleteMessageForEveryone` when the kind-5
/// retraction was accepted by no relay at all.
///
/// The local soft-delete is deliberately skipped in that case: hiding the
/// message would tell the sender a retraction happened that did not, while
/// the recipient still holds the message (#8165). Leaving the row untouched
/// also keeps `isDeleted` false, so tapping Delete again re-runs the whole
/// path — the retry affordance is the existing menu item, not a new button.
///
/// Carries [outcome] verbatim and draws no conclusions from it. Whether a
/// rejection means the account is restricted is Divine policy, and belongs in
/// the app layer — see `lib/utils/relay_rejection_classifier.dart`.
class DmDeletionNotConfirmed implements Exception {
  /// Records that [rumorId]'s retraction ended with [outcome].
  const DmDeletionNotConfirmed(this.rumorId, this.outcome);

  /// Rumor id of the message the retraction targeted.
  final String rumorId;

  /// Per-relay result of the publish that failed to land.
  final PublishOutcome outcome;

  @override
  String toString() => 'DmDeletionNotConfirmed($rumorId): ${outcome.summary}';
}
