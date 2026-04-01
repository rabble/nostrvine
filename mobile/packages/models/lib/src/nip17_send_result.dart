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
  });

  /// Create success result
  factory NIP17SendResult.success({
    required String rumorEventId,
    required String messageEventId,
    required String recipientPubkey,
  }) => NIP17SendResult(
    success: true,
    rumorEventId: rumorEventId,
    messageEventId: messageEventId,
    recipientPubkey: recipientPubkey,
    timestamp: DateTime.now(),
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
