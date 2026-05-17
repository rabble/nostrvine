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
    super.targetEventId,
    super.sourceEventIds,
    super.notificationIds,
    this.commentText,
    this.isFollowingBack = false,
    this.videoAddressableId,
  }) : assert(
         type == NotificationKind.follow ||
             type == NotificationKind.mention ||
             type == NotificationKind.system ||
             type == NotificationKind.likeComment ||
             type == NotificationKind.reply,
         'ActorNotification only supports follow, mention, system, '
         'likeComment, reply',
       );

  /// The actor who triggered this notification.
  final ActorInfo actor;

  /// Optional text body (e.g. mention's surrounding text).
  final String? commentText;

  /// Whether the current user already follows this actor back.
  final bool isFollowingBack;

  /// Stable NIP-33 addressable ID (`34236:pubkey:d-tag`) of the video
  /// context for [NotificationKind.likeComment] and
  /// [NotificationKind.reply] notifications, when the server provided
  /// the `d_tag` in the notification payload.
  ///
  /// When set, the tap handler navigates directly to the video using
  /// this ID without a relay round-trip through the resolver.
  /// Falls back to the resolver when null.
  final String? videoAddressableId;

  /// Returns a copy with the given fields replaced.
  ActorNotification copyWith({
    String? id,
    NotificationKind? type,
    ActorInfo? actor,
    DateTime? timestamp,
    bool? isRead,
    String? commentText,
    bool? isFollowingBack,
    String? targetEventId,
    List<String>? sourceEventIds,
    List<String>? notificationIds,
    String? videoAddressableId,
  }) {
    return ActorNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      actor: actor ?? this.actor,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      commentText: commentText ?? this.commentText,
      isFollowingBack: isFollowingBack ?? this.isFollowingBack,
      targetEventId: targetEventId ?? this.targetEventId,
      sourceEventIds: sourceEventIds ?? this.sourceEventIds,
      notificationIds: notificationIds ?? this.notificationIds,
      videoAddressableId: videoAddressableId ?? this.videoAddressableId,
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
    targetEventId,
    sourceEventIds,
    notificationIds,
    videoAddressableId,
  ];
}
