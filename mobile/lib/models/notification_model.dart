// ABOUTME: Data model for divine notifications with different types and metadata
// ABOUTME: Supports likes, comments, follows, mentions, and system notifications

import 'package:equatable/equatable.dart';
import 'package:openvine/services/relay_notification_api_service.dart';

enum NotificationType { like, comment, follow, mention, repost, system }

class NotificationModel extends Equatable {
  // Additional data

  const NotificationModel({
    required this.id,
    required this.type,
    required this.actorPubkey,
    required this.message,
    required this.timestamp,
    this.actorName,
    this.actorPictureUrl,
    this.isRead = false,
    this.targetEventId,
    this.targetVideoUrl,
    this.targetVideoThumbnail,
    this.metadata,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      NotificationModel(
        id: json['id'] as String,
        type: NotificationType.values[json['type'] as int],
        actorPubkey: json['actorPubkey'] as String,
        actorName: json['actorName'] as String?,
        actorPictureUrl: json['actorPictureUrl'] as String?,
        message: json['message'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        isRead: json['isRead'] as bool? ?? false,
        targetEventId: json['targetEventId'] as String?,
        targetVideoUrl: json['targetVideoUrl'] as String?,
        targetVideoThumbnail: json['targetVideoThumbnail'] as String?,
        metadata: json['metadata'] as Map<String, dynamic>?,
      );

  /// Create a NotificationModel from a RelayNotification (Divine Relay API)
  factory NotificationModel.fromRelayApi(
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

  /// Map relay notification type string to NotificationType enum
  static NotificationType _mapNotificationType(String relayType) {
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
  static String _generateMessage(
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

  final String id;
  final NotificationType type;
  final String actorPubkey;
  final String? actorName;
  final String? actorPictureUrl;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final String? targetEventId; // For likes, comments, reposts
  final String? targetVideoUrl; // For quick preview
  final String? targetVideoThumbnail;
  final Map<String, dynamic>? metadata;

  NotificationModel copyWith({
    String? id,
    NotificationType? type,
    String? actorPubkey,
    String? actorName,
    String? actorPictureUrl,
    String? message,
    DateTime? timestamp,
    bool? isRead,
    String? targetEventId,
    String? targetVideoUrl,
    String? targetVideoThumbnail,
    Map<String, dynamic>? metadata,
  }) => NotificationModel(
    id: id ?? this.id,
    type: type ?? this.type,
    actorPubkey: actorPubkey ?? this.actorPubkey,
    actorName: actorName ?? this.actorName,
    actorPictureUrl: actorPictureUrl ?? this.actorPictureUrl,
    message: message ?? this.message,
    timestamp: timestamp ?? this.timestamp,
    isRead: isRead ?? this.isRead,
    targetEventId: targetEventId ?? this.targetEventId,
    targetVideoUrl: targetVideoUrl ?? this.targetVideoUrl,
    targetVideoThumbnail: targetVideoThumbnail ?? this.targetVideoThumbnail,
    metadata: metadata ?? this.metadata,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.index,
    'actorPubkey': actorPubkey,
    'actorName': actorName,
    'actorPictureUrl': actorPictureUrl,
    'message': message,
    'timestamp': timestamp.toIso8601String(),
    'isRead': isRead,
    'targetEventId': targetEventId,
    'targetVideoUrl': targetVideoUrl,
    'targetVideoThumbnail': targetVideoThumbnail,
    'metadata': metadata,
  };

  String get typeIcon {
    switch (type) {
      case NotificationType.like:
        return '❤️';
      case NotificationType.comment:
        return '💬';
      case NotificationType.follow:
        return '👤';
      case NotificationType.mention:
        return '@';
      case NotificationType.repost:
        return '🔄';
      case NotificationType.system:
        return '📱';
    }
  }

  String get formattedTimestamp {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  /// Get the navigation action for this notification
  String get navigationAction {
    switch (type) {
      case NotificationType.like:
        // Likes navigate to the liker's profile
        return 'open_profile';
      case NotificationType.comment:
      case NotificationType.repost:
        return targetEventId != null ? 'open_video' : 'open_profile';
      case NotificationType.follow:
      case NotificationType.mention:
        return 'open_profile';
      case NotificationType.system:
        return 'none';
    }
  }

  /// Get the primary navigation target (video ID or actor pubkey)
  String? get navigationTarget {
    switch (type) {
      case NotificationType.like:
        // Likes navigate to the liker's profile
        return actorPubkey;
      case NotificationType.comment:
      case NotificationType.repost:
        return targetEventId ?? actorPubkey;
      case NotificationType.follow:
      case NotificationType.mention:
        return actorPubkey;
      case NotificationType.system:
        return null;
    }
  }

  @override
  List<Object?> get props => [
    id,
    type,
    actorPubkey,
    actorName,
    actorPictureUrl,
    message,
    timestamp,
    isRead,
    targetEventId,
    targetVideoUrl,
    targetVideoThumbnail,
    metadata,
  ];
}
