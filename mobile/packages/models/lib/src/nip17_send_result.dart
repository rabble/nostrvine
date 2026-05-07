// ABOUTME: Result model for NIP-17 encrypted message sending operations
// ABOUTME: Indicates success/failure with message event ID and recipient info

/// Result of NIP-17 encrypted message sending
class NIP17SendResult {
  const NIP17SendResult({
    required this.success,
    this.rumorEventId,
    this.messageEventId,
    this.recipientPubkey,
    this.error,
    this.timestamp,
    this.selfWrapPublished = true,
  });

  /// Create success result.
  ///
  /// [selfWrapPublished] indicates whether the sender's self-addressed gift
  /// wrap (NIP-17) was also delivered to relays. When `false`, the recipient
  /// got the message but the sender's other devices won't see it on a
  /// relay-only restore. The send is still considered a success because the
  /// recipient was reached.
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

  /// Create failure result
  factory NIP17SendResult.failure(String error) =>
      NIP17SendResult(success: false, error: error);

  final bool success;

  /// The rumor event ID (kind 14/15) — the canonical message identifier.
  /// Use this as the primary key when persisting sent messages.
  final String? rumorEventId;

  /// The recipient's gift wrap event ID (kind 1059).
  final String? messageEventId;

  final String? recipientPubkey;
  final String? error;
  final DateTime? timestamp;

  /// Whether the sender's self-addressed gift wrap reached relays.
  ///
  /// When `success` is `true` and this is `false`, the message was delivered
  /// to the recipient but cross-device sync for the sender is degraded. UI
  /// can surface this as a partial-delivery state distinct from a full
  /// failure. Defaults to `true` for failure results and for callers that
  /// do not yet track this signal.
  final bool selfWrapPublished;

  @override
  String toString() {
    if (success) {
      return 'NIP17SendResult(success: true, '
          'rumorEventId: $rumorEventId, '
          'messageEventId: $messageEventId, recipient: $recipientPubkey, '
          'selfWrapPublished: $selfWrapPublished)';
    } else {
      return 'NIP17SendResult(success: false, error: $error)';
    }
  }
}
