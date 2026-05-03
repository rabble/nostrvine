// ABOUTME: Result model for NIP-17 encrypted message sending operations
// ABOUTME: Indicates success/failure with message event ID and recipient info

/// Result of NIP-17 encrypted message sending.
///
/// NIP-17 send is two independent publishes to relays:
///
/// 1. The **recipient** gift wrap (kind 1059), encrypted to the
///    recipient's pubkey. Without this, the recipient never sees the
///    message — its publish status is the headline `success` field.
/// 2. The **self-addressed** gift wrap (kind 1059), encrypted to the
///    sender's own pubkey. Without this, the sender's other devices
///    never see the message they just sent: the recipient gets it but
///    the sender's own conversation history won't have it after a
///    reinstall, account swap, or fresh login on a second device.
///
/// Pre-existing callers only checked [success]. [selfWrapPublished]
/// surfaces partial delivery so a half-delivered send can be visibly
/// distinguished from a fully-delivered one. Acting on it (e.g.
/// retrying only the missing self-wrap publish without re-publishing
/// to the recipient) is left to future callers — the durable
/// outgoing-message queue tracked in #3909 is not yet on `main`.
class NIP17SendResult {
  const NIP17SendResult({
    required this.success,
    this.rumorEventId,
    this.messageEventId,
    this.recipientPubkey,
    this.error,
    this.timestamp,
    this.selfWrapPublished,
  });

  /// Create success result. [selfWrapPublished] defaults to `true` so
  /// existing call sites that don't yet care about per-wrap status are
  /// not affected. Pass `false` from the service layer when the
  /// self-addressed wrap could not be created or did not land on any
  /// relay.
  factory NIP17SendResult.success({
    required String rumorEventId,
    required String messageEventId,
    required String recipientPubkey,
    bool selfWrapPublished = true,
  }) => NIP17SendResult(
    success: true,
    rumorEventId: rumorEventId,
    messageEventId: messageEventId,
    recipientPubkey: recipientPubkey,
    timestamp: DateTime.now(),
    selfWrapPublished: selfWrapPublished,
  );

  /// Create failure result. [selfWrapPublished] is left `null` because
  /// the self-wrap is never attempted when the recipient publish
  /// fails — the type encodes "not applicable on this branch."
  factory NIP17SendResult.failure(String error) =>
      NIP17SendResult(success: false, error: error);

  /// Whether the recipient gift wrap (kind 1059, encrypted to the
  /// recipient) reached at least one relay. The headline send status.
  final bool success;

  /// The rumor event ID (kind 14/15) — the canonical message identifier.
  /// Use this as the primary key when persisting sent messages.
  final String? rumorEventId;

  /// The recipient's gift wrap event ID (kind 1059).
  final String? messageEventId;

  final String? recipientPubkey;
  final String? error;
  final DateTime? timestamp;

  /// Whether the **self-addressed** gift wrap (kind 1059, encrypted to
  /// the sender's own pubkey) reached at least one relay.
  ///
  /// Meaningful only when [success] is `true`. The three observable
  /// states:
  ///
  /// - `success: true, selfWrapPublished: true` — fully delivered. The
  ///   recipient sees the message, and the sender's other devices /
  ///   future installs will see it after relay re-fetch.
  /// - `success: true, selfWrapPublished: false` — partially delivered.
  ///   The recipient saw the message but the self-addressed wrap did
  ///   not land on any relay, so the sender will not see this message
  ///   after a reinstall or on a second device. Surfaced so callers
  ///   can persist enough state to act on it once retry handling
  ///   lands (see #3909). Re-publishing the recipient wrap on retry
  ///   would double-deliver, so any future retry must target only the
  ///   self-wrap.
  /// - `success: false` — recipient never received the message;
  ///   [selfWrapPublished] is `null` because the self-wrap is not
  ///   attempted when the recipient publish fails.
  final bool? selfWrapPublished;

  @override
  String toString() {
    if (success) {
      return 'NIP17SendResult(success: true, '
          'rumorEventId: $rumorEventId, '
          'messageEventId: $messageEventId, '
          'recipient: $recipientPubkey, '
          'selfWrapPublished: $selfWrapPublished)';
    } else {
      return 'NIP17SendResult(success: false, error: $error)';
    }
  }
}
