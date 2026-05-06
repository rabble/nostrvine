// ABOUTME: Actor-anchored notification — follows, mentions, system. No
// ABOUTME: video reference; one row per event.

part of 'notification_item.dart';

/// A notification anchored to an actor (follow, mention, system).
///
/// No video reference; one row per event.
@immutable
class ActorNotification extends NotificationItem {
  /// Creates an [ActorNotification].
  const ActorNotification({
    required super.id,
    required super.type,
    required this.actor,
    required super.timestamp,
    super.isRead,
    this.commentText,
    this.isFollowingBack = false,
  }) : assert(
         type == NotificationKind.follow ||
             type == NotificationKind.mention ||
             type == NotificationKind.system ||
             type == NotificationKind.likeComment,
         'ActorNotification only supports follow, mention, system, '
         'likeComment',
       );

  /// The actor who triggered this notification.
  final ActorInfo actor;

  /// Optional text body (e.g. mention's surrounding text).
  final String? commentText;

  /// Whether the current user already follows this actor back.
  final bool isFollowingBack;

  /// Returns a copy with the given fields replaced.
  ActorNotification copyWith({
    String? id,
    NotificationKind? type,
    ActorInfo? actor,
    DateTime? timestamp,
    bool? isRead,
    String? commentText,
    bool? isFollowingBack,
  }) {
    return ActorNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      actor: actor ?? this.actor,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
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
    commentText,
    isFollowingBack,
  ];
}
