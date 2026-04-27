// ABOUTME: Converts RelayNotification from Divine Relay API to NotificationModel
// ABOUTME: Separates app-specific relay conversion from the pure data model

import 'package:models/models.dart';
import 'package:openvine/services/relay_notification_api_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// Convert a [RelayNotification] from the Divine Relay API to a
/// [NotificationModel] suitable for display in the app.
NotificationModel notificationModelFromRelayApi(
  RelayNotification relay, {
  String? actorName,
  String? actorPictureUrl,
  String? targetVideoUrl,
  String? targetVideoThumbnail,
}) {
  final type = _mapNotificationType(relay.notificationType, relay.sourceKind);
  final message = _generateMessage(
    type,
    actorName,
    relay.sourcePubkey,
    relay.content,
    hasTargetEvent: relay.referencedEventId != null,
  );

  // For mentions, the relay sometimes leaves `referenced_event_id` empty
  // (e.g. mentions inside a NIP-22 comment). Fall back to the source event so
  // navigation has a target to resolve — `NotificationTargetResolver` walks
  // its `E` / `e` tags back to the root video. Without this, mention taps
  // route to the mentioner's profile (#3168).
  final targetEventId = type == NotificationType.mention
      ? (relay.referencedEventId ?? _nonEmpty(relay.sourceEventId))
      : relay.referencedEventId;

  return NotificationModel(
    id: relay.id,
    type: type,
    actorPubkey: relay.sourcePubkey,
    actorName: actorName,
    actorPictureUrl: actorPictureUrl,
    message: message,
    timestamp: relay.sourceCreatedAt ?? relay.createdAt,
    isRead: relay.read,
    targetEventId: targetEventId,
    targetVideoUrl: targetVideoUrl,
    targetVideoThumbnail: targetVideoThumbnail,
    metadata: _buildMetadata(relay, type),
  );
}

String? _nonEmpty(String value) => value.isEmpty ? null : value;

/// Map relay notification type string to [NotificationType] enum
NotificationType _mapNotificationType(String relayType, int sourceKind) {
  switch (relayType.trim().toLowerCase()) {
    case 'reaction':
    case 'like':
    case 'liked':
    case 'zap':
    case 'zapped':
      return NotificationType.like;
    case 'reply':
    case 'comment':
    case 'commented':
      return NotificationType.comment;
    case 'repost':
    case 'reposted':
      return NotificationType.repost;
    case 'follow':
    case 'followed':
      return NotificationType.follow;
    case 'mention':
    case 'mentioned':
      return NotificationType.mention;
    default:
      final fallbackType = _mapNotificationTypeFromSourceKind(sourceKind);
      if (fallbackType != null) {
        Log.warning(
          'Unknown relay notification type "$relayType"; '
          'using source_kind=$sourceKind fallback to $fallbackType',
          name: 'NotificationModelConverter',
          category: LogCategory.system,
        );
        return fallbackType;
      }
      Log.warning(
        'Unknown relay notification type "$relayType"; '
        'falling back to system (source_kind=$sourceKind)',
        name: 'NotificationModelConverter',
        category: LogCategory.system,
      );
      return NotificationType.system;
  }
}

NotificationType? _mapNotificationTypeFromSourceKind(int sourceKind) {
  switch (sourceKind) {
    case 3:
      return NotificationType.follow;
    case 6:
    case 16:
      return NotificationType.repost;
    case 7:
      return NotificationType.like;
    case 1111:
      return NotificationType.comment;
    default:
      return null;
  }
}

/// Generate a human-readable message based on notification type
String _generateMessage(
  NotificationType type,
  String? actorName,
  String actorPubkey,
  String? content, {
  required bool hasTargetEvent,
}) {
  final name = switch (type) {
    NotificationType.follow =>
      actorName ?? UserProfile.defaultDisplayNameFor(actorPubkey),
    _ => actorName ?? 'Someone',
  };
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
      return _generateSystemMessage(
        actorName: actorName,
        content: content,
        hasTargetEvent: hasTargetEvent,
      );
  }
}

Map<String, dynamic> _buildMetadata(
  RelayNotification relay,
  NotificationType type,
) {
  final metadata = <String, dynamic>{
    'sourceEventId': relay.sourceEventId,
    'sourceKind': relay.sourceKind,
    'relayNotificationType': relay.notificationType,
  };

  final trimmedContent = relay.content?.trim();
  if (trimmedContent == null || trimmedContent.isEmpty) {
    return metadata;
  }

  metadata['content'] = relay.content;
  switch (type) {
    case NotificationType.comment:
      metadata['comment'] = trimmedContent;
    case NotificationType.mention:
      metadata['text'] = trimmedContent;
    case NotificationType.like:
    case NotificationType.follow:
    case NotificationType.repost:
    case NotificationType.system:
      break;
  }

  return metadata;
}

String _generateSystemMessage({
  required String? actorName,
  required String? content,
  required bool hasTargetEvent,
}) {
  final trimmedContent = content?.trim();
  if (_isMeaningfulSystemContent(trimmedContent, actorName: actorName)) {
    return trimmedContent!;
  }

  if (actorName != null) {
    if (hasTargetEvent) {
      return '$actorName interacted with your video';
    }
    return '$actorName sent you an update';
  }

  return 'You have a new update';
}

bool _isMeaningfulSystemContent(String? content, {required String? actorName}) {
  if (content == null || content.isEmpty) return false;

  final normalizedContent = _normalizeWhitespace(content);
  if (<String>{
    'notification',
    'system notification',
    'new notification',
  }.contains(normalizedContent)) {
    return false;
  }

  if (actorName != null &&
      normalizedContent == '${_normalizeWhitespace(actorName)} notification') {
    return false;
  }

  return true;
}

String _normalizeWhitespace(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
