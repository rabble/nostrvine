// ABOUTME: Data model for OpenVine notifications with different types and metadata
// ABOUTME: Supports likes, comments, follows, mentions, and system notifications

import 'package:equatable/equatable.dart';

enum NotificationType {
  like,
  comment,
  follow,
  mention,
  repost,
  system,
}

class NotificationModel extends Equatable {
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
  final Map<String, dynamic>? metadata; // Additional data

  const NotificationModel({
    required this.id,
    required this.type,
    required this.actorPubkey,
    this.actorName,
    this.actorPictureUrl,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.targetEventId,
    this.targetVideoUrl,
    this.targetVideoThumbnail,
    this.metadata,
  });

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
  }) {
    return NotificationModel(
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
  }

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

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
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
  }

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