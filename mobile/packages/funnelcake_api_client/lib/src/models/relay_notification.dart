/// Raw notification from the Divine Relay REST API.
///
/// Represents a single notification event before enrichment or grouping.
/// Plain class (no Equatable) -- matches other DTOs in this package.
class RelayNotification {
  /// Creates a parsed relay notification model.
  const RelayNotification({
    required this.id,
    required this.sourcePubkey,
    required this.sourceEventId,
    required this.sourceKind,
    required this.notificationType,
    required this.createdAt,
    required this.read,
    this.referencedEventId,
    this.content,
  });

  /// Parses a notification payload from the FunnelCake API.
  factory RelayNotification.fromJson(Map<String, dynamic> json) {
    return RelayNotification(
      id: json['id'] as String? ?? '',
      sourcePubkey: json['source_pubkey'] as String? ?? '',
      sourceEventId: json['source_event_id'] as String? ?? '',
      sourceKind: json['source_kind'] as int? ?? 0,
      referencedEventId: json['referenced_event_id'] as String?,
      notificationType: json['notification_type'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        ((json['created_at'] as int?) ?? 0) * 1000,
      ),
      read: json['read'] as bool? ?? false,
      content: json['content'] as String?,
    );
  }

  /// The notification ID assigned by the relay.
  final String id;

  /// The public key of the actor who triggered the notification.
  final String sourcePubkey;

  /// The Nostr event ID that caused the notification.
  final String sourceEventId;

  /// The Nostr kind of the source event.
  final int sourceKind;

  /// The event ID that was referenced (e.g. the video that was liked).
  final String? referencedEventId;

  /// The notification type (e.g. 'reaction', 'reply', 'repost', 'zap').
  final String notificationType;

  /// When the notification was created.
  final DateTime createdAt;

  /// Whether the notification has been read.
  final bool read;

  /// Optional content from the source event (e.g. reaction emoji).
  final String? content;

  /// Stable dedup key -- falls back to sourceEventId if id is empty.
  String get dedupeKey => id.isNotEmpty ? id : sourceEventId;
}
