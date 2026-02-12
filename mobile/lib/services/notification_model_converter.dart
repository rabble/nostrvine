// ABOUTME: Converts RelayNotification from Divine Relay API to NotificationModel
// ABOUTME: Separates app-specific relay conversion from the pure data model

import 'package:models/models.dart';
import 'package:openvine/services/relay_notification_api_service.dart';

/// Convert a [RelayNotification] from the Divine Relay API to a
/// [NotificationModel] suitable for display in the app.
NotificationModel notificationModelFromRelayApi(
  RelayNotification relay, {
  String? actorName,
  String? actorPictureUrl,
  String? targetVideoUrl,
  String? targetVideoThumbnail,
}) {
  final type = _mapNotificationType(relay.notificationType);
  final message = _generateMessage(type, actorName, relay.content);

  return NotificationModel(
    id: relay.id,
    type: type,
    actorPubkey: relay.sourcePubkey,
    actorName: actorName,
    actorPictureUrl: actorPictureUrl,
    message: message,
    timestamp: relay.createdAt,
    isRead: relay.read,
    targetEventId: relay.referencedEventId,
    targetVideoUrl: targetVideoUrl,
    targetVideoThumbnail: targetVideoThumbnail,
    metadata: {
      'sourceEventId': relay.sourceEventId,
      'sourceKind': relay.sourceKind,
      if (relay.content != null) 'content': relay.content,
    },
  );
}

/// Map relay notification type string to [NotificationType] enum
NotificationType _mapNotificationType(String relayType) {
  switch (relayType.toLowerCase()) {
    case 'reaction':
      return NotificationType.like;
    case 'reply':
      return NotificationType.comment;
    case 'repost':
      return NotificationType.repost;
    case 'follow':
      return NotificationType.follow;
    case 'mention':
      return NotificationType.mention;
    case 'zap':
      return NotificationType.like; // Treat zaps as likes for now
    default:
      return NotificationType.system;
  }
}

/// Generate a human-readable message based on notification type
String _generateMessage(
  NotificationType type,
  String? actorName,
  String? content,
) {
  final name = actorName ?? 'Someone';
  switch (type) {
    case NotificationType.like:
      return '$name liked your video';
    case NotificationType.comment:
      if (content != null && content.isNotEmpty) {
        // Truncate long comments
        final truncated = content.length > 50
            ? '${content.substring(0, 47)}...'
            : content;
        return '$name commented: $truncated';
      }
      return '$name commented on your video';
    case NotificationType.follow:
      return '$name started following you';
    case NotificationType.mention:
      return '$name mentioned you';
    case NotificationType.repost:
      return '$name reposted your video';
    case NotificationType.system:
      return content ?? 'System notification';
  }
}
