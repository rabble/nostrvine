// ABOUTME: State for HashtagFeedBloc - hashtag video feed
// ABOUTME: Tracks videos, loading state, pagination, and current hashtag

part of 'hashtag_feed_bloc.dart';

/// Status of the hashtag feed.
enum HashtagFeedStatus {
  /// Currently loading videos.
  loading,

  /// Videos loaded successfully.
  success,

  /// An error occurred while loading videos.
  failure,
}

/// State for the HashtagFeedBloc.
///
/// Contains:
/// - [videos]: The list of video events for the current hashtag
/// - [status]: The current loading status
/// - [hashtag]: The active hashtag being viewed
/// - [hasMore]: Whether more videos can be loaded
/// - [isLoadingMore]: Whether pagination is in progress
final class HashtagFeedState extends Equatable {
  const HashtagFeedState({
    this.status = HashtagFeedStatus.loading,
    this.videos = const [],
    this.hashtag = '',
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  /// The current loading status.
  final HashtagFeedStatus status;

  /// The list of videos for the current hashtag.
  final List<VideoEvent> videos;

  /// The active hashtag being viewed (without #).
  final String hashtag;

  /// Whether more videos can be loaded via pagination.
  final bool hasMore;

  /// Whether a load-more operation is in progress.
  final bool isLoadingMore;

  /// Whether the state is currently loading initial data.
  bool get isLoading => status == HashtagFeedStatus.loading;

  /// Whether the feed is empty after successful load.
  bool get isEmpty => status == HashtagFeedStatus.success && videos.isEmpty;

  /// Create a copy with updated values.
  HashtagFeedState copyWith({
    HashtagFeedStatus? status,
    List<VideoEvent>? videos,
    String? hashtag,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return HashtagFeedState(
      status: status ?? this.status,
      videos: videos ?? this.videos,
      hashtag: hashtag ?? this.hashtag,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [status, videos, hashtag, hasMore, isLoadingMore];
}
