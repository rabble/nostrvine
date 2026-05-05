// ABOUTME: Video-anchored notification — likes, comments, reposts on a
// ABOUTME: video. One row per (video × kind) regardless of actor count.

part of 'notification_item.dart';

/// A notification anchored to a video — likes, comments, or reposts.
///
/// One row per (video × kind) regardless of how many actors interacted.
/// The list of [actors] is capped for stacked-avatar display; [totalCount]
/// holds the full count.
@immutable
class VideoNotification extends NotificationItem {
  /// Creates a [VideoNotification].
  const VideoNotification({
    required super.id,
    required super.type,
    required this.videoEventId,
    required this.actors,
    required this.totalCount,
    required super.timestamp,
    super.isRead,
    this.videoThumbnailUrl,
    this.videoTitle,
  }) : assert(
         type == NotificationKind.like ||
             type == NotificationKind.likeComment ||
             type == NotificationKind.comment ||
             type == NotificationKind.repost,
         'VideoNotification only supports like, likeComment, comment, '
         'repost',
       ),
       assert(actors.length > 0, 'must have at least one actor'),
       assert(
         totalCount >= actors.length,
         'totalCount cannot be less than actors.length',
       ),
       super(targetEventId: videoEventId);

  /// The Nostr event id of the video that was acted on.
  final String videoEventId;

  /// Thumbnail URL of the referenced video, if available.
  final String? videoThumbnailUrl;

  /// Title of the referenced video, if available.
  final String? videoTitle;

  /// First N actors (newest-first) for stacked avatar display.
  final List<ActorInfo> actors;

  /// Total number of distinct actors who interacted (may exceed the length of
  /// [actors]).
  final int totalCount;

  /// Returns a copy with the given fields replaced.
  VideoNotification copyWith({
    String? id,
    NotificationKind? type,
    String? videoEventId,
    String? videoThumbnailUrl,
    String? videoTitle,
    List<ActorInfo>? actors,
    int? totalCount,
    DateTime? timestamp,
    bool? isRead,
  }) {
    return VideoNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      videoEventId: videoEventId ?? this.videoEventId,
      videoThumbnailUrl: videoThumbnailUrl ?? this.videoThumbnailUrl,
      videoTitle: videoTitle ?? this.videoTitle,
      actors: actors ?? this.actors,
      totalCount: totalCount ?? this.totalCount,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
    );
  }

  @override
  List<Object?> get props => [
    id,
    type,
    videoEventId,
    videoThumbnailUrl,
    videoTitle,
    actors,
    totalCount,
    timestamp,
    isRead,
  ];
}
