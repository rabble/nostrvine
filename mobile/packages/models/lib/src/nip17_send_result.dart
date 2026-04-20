// ABOUTME: Result model for NIP-17 encrypted message sending operations
// ABOUTME: Indicates success/failure with message event ID, recipient info,
// ABOUTME: and optional per-relay publish outcome (for reliability UX).

import 'package:nostr_sdk/relay/publish_outcome.dart';

/// Result of NIP-17 encrypted message sending.
///
/// Carries the canonical message identifiers on success and, when
/// available, the per-relay [PublishOutcome] so UI layers can drive
/// retry affordances via `PublishResultMapper`. [outcome] may be `null`
/// for pre-publish failures (signer unavailable, encryption failed) or
/// for codepaths that have not yet migrated to `publishEventWithRetry`.
class NIP17SendResult {
  const NIP17SendResult({
    required this.success,
    this.rumorEventId,
    this.messageEventId,
    this.recipientPubkey,
    this.error,
    this.timestamp,
    this.outcome,
  });

  /// Create success result.
  ///
  /// [outcome] is optional but strongly recommended for callers that went
  /// through a reliable publish path so the UI can tell whether the
  /// message was accepted by every relay vs. a partial-accept.
  factory NIP17SendResult.success({
    required String rumorEventId,
    required String messageEventId,
    required String recipientPubkey,
    PublishOutcome? outcome,
  }) => NIP17SendResult(
    success: true,
    rumorEventId: rumorEventId,
    messageEventId: messageEventId,
    recipientPubkey: recipientPubkey,
    timestamp: DateTime.now(),
    outcome: outcome,
  );

  /// Create failure result.
  ///
  /// [outcome] is populated when the failure came from a relay round-trip
  /// (zero accepts) — omit for pre-publish failures.
  factory NIP17SendResult.failure(String error, {PublishOutcome? outcome}) =>
      NIP17SendResult(success: false, error: error, outcome: outcome);

  final bool success;

  /// The rumor event ID (kind 14/15) — the canonical message identifier.
  /// Use this as the primary key when persisting sent messages.
  final String? rumorEventId;

  /// The recipient's gift wrap event ID (kind 1059).
  final String? messageEventId;

  final String? recipientPubkey;
  final String? error;
  final DateTime? timestamp;

  /// Per-relay publish outcome for the recipient gift wrap / kind-4 event.
  /// `null` when the failure occurred before the relay round-trip.
  final PublishOutcome? outcome;

  @override
  String toString() {
    if (success) {
      return 'NIP17SendResult(success: true, '
          'rumorEventId: $rumorEventId, '
          'messageEventId: $messageEventId, recipient: $recipientPubkey)';
    } else {
      return 'NIP17SendResult(success: false, error: $error)';
    }
  }
}
