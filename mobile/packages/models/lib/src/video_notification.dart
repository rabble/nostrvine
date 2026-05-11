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
    this.videoAddressableId,
    this.commentText,
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
  ///
  /// May become stale after a metadata update (NIP-33 replacement).
  /// Prefer [videoAddressableId] for navigation when available.
  final String videoEventId;

  /// The NIP-33 addressable ID (`34236:pubkey:d-tag`) of the video.
  ///
  /// Stable across metadata updates. Use this for navigation instead of
  /// [videoEventId] whenever it is non-null.
  final String? videoAddressableId;

  /// Thumbnail URL of the referenced video, if available.
  final String? videoThumbnailUrl;

  /// Title of the referenced video, if available.
  final String? videoTitle;

  /// First N actors (newest-first) for stacked avatar display.
  final List<ActorInfo> actors;

  /// Total number of distinct actors who interacted (may exceed the length of
  /// [actors]).
  final int totalCount;

  /// Optional excerpt of the most recent comment when [type] is
  /// [NotificationKind.comment]. Truncated by the repository so a long
  /// comment doesn't blow out the row layout. Other kinds (like, repost,
  /// likeComment) leave this null because they have no associated body
  /// text.
  final String? commentText;

  /// Returns a copy with the given fields replaced.
  VideoNotification copyWith({
    String? id,
    NotificationKind? type,
    String? videoEventId,
    String? videoAddressableId,
    String? videoThumbnailUrl,
    String? videoTitle,
    List<ActorInfo>? actors,
    int? totalCount,
    DateTime? timestamp,
    bool? isRead,
    String? commentText,
  }) {
    return VideoNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      videoEventId: videoEventId ?? this.videoEventId,
      videoAddressableId: videoAddressableId ?? this.videoAddressableId,
      videoThumbnailUrl: videoThumbnailUrl ?? this.videoThumbnailUrl,
      videoTitle: videoTitle ?? this.videoTitle,
      actors: actors ?? this.actors,
      totalCount: totalCount ?? this.totalCount,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      commentText: commentText ?? this.commentText,
    );
  }

  @override
  List<Object?> get props => [
    id,
    type,
    videoEventId,
    videoAddressableId,
    videoThumbnailUrl,
    videoTitle,
    actors,
    totalCount,
    timestamp,
    isRead,
    commentText,
  ];
}
