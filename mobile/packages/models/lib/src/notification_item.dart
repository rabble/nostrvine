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
  likeComment,
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

  /// Returns a copy with the given fields replaced.
  GroupedNotification copyWith({
    String? id,
    NotificationKind? type,
    List<ActorInfo>? actors,
    int? totalCount,
    DateTime? timestamp,
    bool? isRead,
    String? targetEventId,
    String? videoTitle,
  }) {
    return GroupedNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      actors: actors ?? this.actors,
      totalCount: totalCount ?? this.totalCount,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      targetEventId: targetEventId ?? this.targetEventId,
      videoTitle: videoTitle ?? this.videoTitle,
    );
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
