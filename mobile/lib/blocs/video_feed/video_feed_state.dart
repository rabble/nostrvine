// ABOUTME: State for VideoFeedBloc - unified feed with mode switching
// ABOUTME: Tracks videos, loading state, pagination, and current feed mode

part of 'video_feed_bloc.dart';

/// Feed modes for the unified video feed.
enum FeedMode {
  /// Personalized recommended videos.
  forYou,

  /// Videos from users the current user follows.
  following,

  /// Legacy persisted restore value. Home no longer exposes this mode.
  latest,
}

/// Typed source for the home video feed.
enum VideoFeedSourceType {
  /// Personalized recommended videos.
  forYou,

  /// Videos from followed creators.
  following,

  /// Videos from one subscribed curated list.
  subscribedList,
}

/// Source selection for [VideoFeedBloc].
final class VideoFeedSource extends Equatable {
  /// Personalized recommended videos.
  const VideoFeedSource.forYou()
    : type = VideoFeedSourceType.forYou,
      listId = null,
      listName = null;

  /// Videos from followed creators.
  const VideoFeedSource.following()
    : type = VideoFeedSourceType.following,
      listId = null,
      listName = null;

  /// Videos from a subscribed curated list.
  const VideoFeedSource.subscribedList({
    required String this.listId,
    required String this.listName,
  }) : type = VideoFeedSourceType.subscribedList;

  /// Compatibility conversion for legacy mode-based callers.
  factory VideoFeedSource.fromMode(FeedMode mode) => switch (mode) {
    FeedMode.following => const VideoFeedSource.following(),
    FeedMode.forYou || FeedMode.latest => const VideoFeedSource.forYou(),
  };

  /// The source type.
  final VideoFeedSourceType type;

  /// Selected curated list ID when [type] is subscribedList.
  final String? listId;

  /// Selected curated list name when [type] is subscribedList.
  final String? listName;

  /// Legacy mode projection for compatibility.
  FeedMode get mode => switch (type) {
    VideoFeedSourceType.forYou => FeedMode.forYou,
    VideoFeedSourceType.following ||
    VideoFeedSourceType.subscribedList => FeedMode.following,
  };

  /// Label fallback for UI surfaces that do not have localized copy.
  String get labelFallback => switch (type) {
    VideoFeedSourceType.forYou => FeedMode.forYou.name,
    VideoFeedSourceType.following => FeedMode.following.name,
    VideoFeedSourceType.subscribedList => listName ?? '',
  };

  /// SharedPreferences value for this source.
  String get persistenceValue => switch (type) {
    VideoFeedSourceType.forYou => FeedMode.forYou.name,
    VideoFeedSourceType.following => FeedMode.following.name,
    VideoFeedSourceType.subscribedList => 'list:$listId',
  };

  @override
  List<Object?> get props => [type, listId, listName];
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
final class VideoFeedBlocState extends Equatable {
  const VideoFeedBlocState({
    this.status = VideoFeedStatus.loading,
    this.videos = const [],
    FeedMode mode = FeedMode.forYou,
    VideoFeedSource? source,
    this.subscribedLists = const [],
    this.hasMore = true,
    this.isLoadingMore = false,
    this.error,
    this.videoListSources = const {},
    this.listOnlyVideoIds = const {},
    this.creatorProfiles = const {},
  }) : source =
           source ??
           (mode == FeedMode.following
               ? const VideoFeedSource.following()
               : const VideoFeedSource.forYou());

  /// The current loading status.
  final VideoFeedStatus status;

  /// The list of videos for the current feed mode.
  final List<VideoEvent> videos;

  /// The active feed source.
  final VideoFeedSource source;

  /// Subscribed curated lists available to Home.
  final List<CuratedList> subscribedLists;

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

  /// Legacy mode projection for compatibility with existing callers.
  FeedMode get mode => source.mode;

  /// Human-readable title for the active feed context.
  String get feedContextTitle => source.labelFallback;

  /// Whether a subscribed curated list is currently selected.
  bool get isSubscribedListSelected =>
      source.type == VideoFeedSourceType.subscribedList;

  /// Create a copy with updated values.
  VideoFeedBlocState copyWith({
    VideoFeedStatus? status,
    List<VideoEvent>? videos,
    FeedMode? mode,
    VideoFeedSource? source,
    List<CuratedList>? subscribedLists,
    bool? hasMore,
    bool? isLoadingMore,
    VideoFeedError? error,
    bool clearError = false,
    Map<String, Set<String>>? videoListSources,
    Set<String>? listOnlyVideoIds,
    Map<String, UserProfile>? creatorProfiles,
  }) {
    return VideoFeedBlocState(
      status: status ?? this.status,
      videos: videos ?? this.videos,
      source:
          source ??
          (mode != null ? VideoFeedSource.fromMode(mode) : this.source),
      subscribedLists: subscribedLists ?? this.subscribedLists,
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
    source,
    subscribedLists,
    hasMore,
    isLoadingMore,
    error,
    videoListSources,
    listOnlyVideoIds,
    creatorProfiles,
  ];
}
