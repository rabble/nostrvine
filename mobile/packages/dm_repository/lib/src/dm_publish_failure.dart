// ABOUTME: Exception signalling that a DM-related publish (NIP-09 kind 5
// ABOUTME: deletion in particular) failed at the relay layer.
// ABOUTME: Carries the PublishOutcome and mapped PublishUserFeedback so
// ABOUTME: UI layers can drive retry affordances without re-mapping.

import 'package:nostr_client/nostr_client.dart';

/// Thrown by DmRepository methods that MUST confirm a relay write
/// before updating local state (e.g. "delete for everyone") when every
/// targeted relay rejected or timed out.
///
/// Local state mutations are gated on [PublishOutcome.acceptedByAny] —
/// the caller should catch this exception and surface [feedback] (via
/// `feedback.retryable`, `feedback.firstRejectionReason`, etc.) to the
/// UI. The local row is intentionally left unchanged so the user can
/// retry without losing context.
class DmPublishFailure implements Exception {
  /// Creates a failure with the raw relay [outcome] and the mapped
  /// user-facing [feedback].
  DmPublishFailure({
    required this.message,
    required this.outcome,
    required this.feedback,
  });

  /// Short human-readable summary for logs. Not user-facing — the UI
  /// should consume [feedback] instead.
  final String message;

  /// Per-relay outcome that triggered the failure.
  final PublishOutcome outcome;

  /// Localization-ready feedback mapped via `PublishResultMapper`.
  final PublishUserFeedback feedback;

  @override
  String toString() => 'DmPublishFailure($message, outcome: $outcome)';
}
