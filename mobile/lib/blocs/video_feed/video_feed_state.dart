// ABOUTME: State for VideoFeedBloc - unified feed with mode switching
// ABOUTME: Tracks videos, loading state, pagination, and current feed mode

part of 'video_feed_bloc.dart';

/// Feed modes for the unified video feed.
enum FeedMode {
  /// Personalized recommended videos.
  forYou,

  /// Videos from users the current user follows.
  following,

  /// All videos sorted by creation time (newest first).
  latest,
}

/// Status of the video feed.
enum VideoFeedStatus {
  /// Currently loading videos.
  loading,

  /// Videos loaded successfully.
  success,

  /// An error occurred while loading videos.
  failure,
}

/// Error types for l10n-friendly error handling.
enum VideoFeedError {
  /// Failed to load videos from network.
  loadFailed,

  /// No followed users (home feed is empty by design).
  noFollowedUsers,
}

/// State for the VideoFeedBloc.
///
/// Contains:
/// - [videos]: The list of video events for the current mode
/// - [status]: The current loading status
/// - [mode]: The active feed mode (forYou, following, latest)
/// - [hasMore]: Whether more videos can be loaded
/// - [isLoadingMore]: Whether pagination is in progress
/// - [error]: Any error that occurred
final class VideoFeedState extends Equatable {
  const VideoFeedState({
    this.status = VideoFeedStatus.loading,
    this.videos = const [],
    this.mode = FeedMode.forYou,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.error,
    this.videoListSources = const {},
    this.listOnlyVideoIds = const {},
    this.creatorProfiles = const {},
  });

  /// The current loading status.
  final VideoFeedStatus status;

  /// The list of videos for the current feed mode.
  final List<VideoEvent> videos;

  /// The active feed mode.
  final FeedMode mode;

  /// Whether more videos can be loaded via pagination.
  final bool hasMore;

  /// Whether a load-more operation is in progress.
  final bool isLoadingMore;

  /// Error that occurred during loading, if any.
  final VideoFeedError? error;

  /// Maps videoId to the set of curated list IDs that reference it.
  ///
  /// Populated when the home feed includes videos from subscribed lists.
  /// Empty for non-home modes and when no lists are subscribed.
  final Map<String, Set<String>> videoListSources;

  /// Video IDs present only because of list subscriptions.
  ///
  /// These videos are not from followed authors — the UI shows
  /// list attribution for them (Phase 4).
  final Set<String> listOnlyVideoIds;

  /// Creator profiles keyed by pubkey.
  ///
  /// Populated by batch-fetching profiles for video creators after
  /// videos load. Warms the repository's Drift cache so individual
  /// profile lookups are instant hits.
  final Map<String, UserProfile> creatorProfiles;

  /// Whether data has been successfully loaded.
  bool get isLoaded => status == VideoFeedStatus.success;

  /// Whether the state is currently loading initial data.
  bool get isLoading => status == VideoFeedStatus.loading;

  /// Whether the feed is empty after successful load.
  bool get isEmpty => status == VideoFeedStatus.success && videos.isEmpty;

  /// Create a copy with updated values.
  VideoFeedState copyWith({
    VideoFeedStatus? status,
    List<VideoEvent>? videos,
    FeedMode? mode,
    bool? hasMore,
    bool? isLoadingMore,
    VideoFeedError? error,
    bool clearError = false,
    Map<String, Set<String>>? videoListSources,
    Set<String>? listOnlyVideoIds,
    Map<String, UserProfile>? creatorProfiles,
  }) {
    return VideoFeedState(
      status: status ?? this.status,
      videos: videos ?? this.videos,
      mode: mode ?? this.mode,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      videoListSources: videoListSources ?? this.videoListSources,
      listOnlyVideoIds: listOnlyVideoIds ?? this.listOnlyVideoIds,
      creatorProfiles: creatorProfiles ?? this.creatorProfiles,
    );
  }

  @override
  List<Object?> get props => [
    status,
    videos,
    mode,
    hasMore,
    isLoadingMore,
    error,
    videoListSources,
    listOnlyVideoIds,
    creatorProfiles,
  ];
}
