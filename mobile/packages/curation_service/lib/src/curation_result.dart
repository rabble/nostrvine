// ABOUTME: Result type for CurationService.publishCuration surfacing the
// ABOUTME: per-relay outcome and user feedback for reliable publishing.

import 'package:nostr_client/nostr_client.dart';

/// Result of a [CurationService.publishCuration] call.
///
/// Exposes the per-relay [PublishOutcome] and the mapped
/// [PublishUserFeedback] so the UI can render retry-able failure snackbars.
/// [duplicate] distinguishes a short-circuited "already publishing" result
/// from a genuine relay-level failure — the latter populates [outcome] and
/// [feedback] while the former leaves them null.
class CurationResult {
  const CurationResult({
    required this.success,
    this.outcome,
    this.feedback,
    this.eventId,
    this.duplicate = false,
  });

  /// Whether the curation publish is durable (at least one relay accepted).
  final bool success;

  /// Per-relay outcome. `null` when no publish was attempted (duplicate,
  /// unauthenticated signer, event creation failed).
  final PublishOutcome? outcome;

  /// Mapped user feedback. `null` iff [outcome] is `null`.
  final PublishUserFeedback? feedback;

  /// Event id of the signed event (present when the publish reached the
  /// relay round-trip, even if every relay rejected).
  final String? eventId;

  /// `true` when the publish was skipped because another publish of the
  /// same curation id is already in flight. Callers typically ignore these
  /// results and let the in-flight publish finish.
  final bool duplicate;

  /// A "duplicate" failure result — emitted when another publish of the
  /// same curation id is already in flight.
  const CurationResult.duplicate()
    : success = false,
      outcome = null,
      feedback = null,
      eventId = null,
      duplicate = true;

  /// Pre-flight failure — auth, signing, or event construction failed.
  const CurationResult.preFlight()
    : success = false,
      outcome = null,
      feedback = null,
      eventId = null,
      duplicate = false;

  /// Build a [CurationResult] from a per-relay [PublishOutcome].
  factory CurationResult.fromOutcome({
    required PublishOutcome outcome,
    required PublishUserFeedback feedback,
    required String eventId,
  }) => CurationResult(
    success: outcome.acceptedByAny,
    outcome: outcome,
    feedback: feedback,
    eventId: eventId,
  );
}
