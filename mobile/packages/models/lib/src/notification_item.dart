// ABOUTME: Sealed notification domain model for the BLoC-based notification
// ABOUTME: system. Supports single and grouped notifications with exhaustive
// ABOUTME: pattern matching.

import 'package:equatable/equatable.dart';
import 'package:models/src/actor_info.dart';

/// Notification types matching the Figma design spec.
///
/// Named `NotificationKind` to avoid conflict with the legacy
/// `NotificationType` enum in `notification_model.dart`.
enum NotificationKind {
  like,
  comment,
  reply,
  follow,
  repost,
  mention,
  system,
}

/// Base for all displayable notifications.
/// Sealed so the UI can exhaustively switch on subtypes.
sealed class NotificationItem extends Equatable {
  const NotificationItem({
    required this.id,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.targetEventId,
    this.videoTitle,
  });

  /// Unique notification identifier.
  final String id;

  /// The kind of notification (like, comment, follow, etc.).
  final NotificationKind type;

  /// When the notification was created.
  final DateTime timestamp;

  /// Whether the user has seen this notification.
  final bool isRead;

  /// The event ID this notification refers to (video, comment, etc.).
  final String? targetEventId;

  /// Title of the target video, if applicable.
  final String? videoTitle;

  /// Human-readable message for display.
  ///
  /// Note: Type icon and formatted timestamp are presentation concerns.
  /// Use DivineIcon from divine_ui for type icons in the widget layer.
  /// Use a time formatter for relative timestamps.
  String get message;
}

/// A notification from a single actor.
class SingleNotification extends NotificationItem {
  const SingleNotification({
    required super.id,
    required super.type,
    required this.actor,
    required super.timestamp,
    super.isRead,
    super.targetEventId,
    super.videoTitle,
    this.commentText,
    this.isFollowingBack = false,
  });

  /// The actor who triggered this notification.
  final ActorInfo actor;

  /// Comment body text, populated for comment/reply notifications.
  final String? commentText;

  /// Whether the current user is already following this actor back.
  final bool isFollowingBack;

  @override
  String get message {
    final name = actor.displayName;
    final title = videoTitle;
    return switch (type) {
      NotificationKind.like when title != null =>
        '$name liked your video $title',
      NotificationKind.like => '$name liked your video',
      NotificationKind.comment when title != null =>
        '$name commented on your video $title',
      NotificationKind.comment => '$name commented on your video',
      NotificationKind.reply => '$name replied to your comment',
      NotificationKind.follow => '$name started following you',
      NotificationKind.repost when title != null =>
        '$name reposted your video $title',
      NotificationKind.repost => '$name reposted your video',
      NotificationKind.mention => '$name mentioned you',
      NotificationKind.system => 'You have a new update',
    };
  }

  /// Returns a copy with the given fields replaced.
  SingleNotification copyWith({
    String? id,
    NotificationKind? type,
    ActorInfo? actor,
    DateTime? timestamp,
    bool? isRead,
    String? targetEventId,
    String? videoTitle,
    String? commentText,
    bool? isFollowingBack,
  }) {
    return SingleNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      actor: actor ?? this.actor,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      targetEventId: targetEventId ?? this.targetEventId,
      videoTitle: videoTitle ?? this.videoTitle,
      commentText: commentText ?? this.commentText,
      isFollowingBack: isFollowingBack ?? this.isFollowingBack,
    );
  }

  @override
  List<Object?> get props => [
    id,
    type,
    actor,
    timestamp,
    isRead,
    targetEventId,
    videoTitle,
    commentText,
    isFollowingBack,
  ];
}

/// Grouped notification — "alice and 93 others liked your video".
class GroupedNotification extends NotificationItem {
  const GroupedNotification({
    required super.id,
    required super.type,
    required this.actors,
    required this.totalCount,
    required super.timestamp,
    super.isRead,
    super.targetEventId,
    super.videoTitle,
  });

  /// First few actors for stacked avatar display (max 3).
  final List<ActorInfo> actors;

  /// Total number of actors in this group.
  final int totalCount;

  @override
  String get message {
    if (actors.isEmpty) return 'Someone liked your video';
    final name = actors.first.displayName;
    final othersCount = totalCount - 1;
    final title = videoTitle;
    if (othersCount <= 0) {
      return title != null
          ? '$name liked your video $title'
          : '$name liked your video';
    }
    final others = '$othersCount ${othersCount == 1 ? 'other' : 'others'}';
    return title != null
        ? '$name and $others liked your video $title'
        : '$name and $others liked your video';
  }

  @override
  List<Object?> get props => [
    id,
    type,
    actors,
    totalCount,
    timestamp,
    isRead,
    targetEventId,
    videoTitle,
  ];
}
