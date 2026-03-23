// ABOUTME: State for FullscreenFeedBloc
// ABOUTME: Tracks videos, current index, and loading state

part of 'fullscreen_feed_bloc.dart';

/// Status of the fullscreen feed.
enum FullscreenFeedStatus {
  /// Waiting for initial data.
  initial,

  /// Videos loaded and ready.
  ready,

  /// An error occurred.
  failure,
}

/// State for the FullscreenFeedBloc.
final class FullscreenFeedState extends Equatable {
  const FullscreenFeedState({
    this.status = FullscreenFeedStatus.initial,
    this.videos = const [],
    this.currentIndex = 0,
    this.isLoadingMore = false,
    this.canLoadMore = false,
  });

  /// The current status.
  final FullscreenFeedStatus status;

  /// The list of videos from the source.
  final List<VideoEvent> videos;

  /// The currently displayed video index.
  final int currentIndex;

  /// Whether a load more operation is in progress.
  final bool isLoadingMore;

  /// Whether this feed supports pagination.
  final bool canLoadMore;

  /// The current video, if available.
  VideoEvent? get currentVideo =>
      currentIndex >= 0 && currentIndex < videos.length
      ? videos[currentIndex]
      : null;

  /// Whether we have videos to display.
  bool get hasVideos => videos.isNotEmpty;

  /// Videos converted to [VideoItem] for the pooled video player.
  ///
  /// Filters out videos without URLs and maps to the format needed by
  /// [VideoFeedController].
  List<VideoItem> get pooledVideos => videos.toPooledVideoItems();

  /// Whether we have pooled videos ready for playback.
  bool get hasPooledVideos => pooledVideos.isNotEmpty;

  /// Create a copy with updated values.
  FullscreenFeedState copyWith({
    FullscreenFeedStatus? status,
    List<VideoEvent>? videos,
    int? currentIndex,
    bool? isLoadingMore,
    bool? canLoadMore,
  }) {
    return FullscreenFeedState(
      status: status ?? this.status,
      videos: videos ?? this.videos,
      currentIndex: currentIndex ?? this.currentIndex,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      canLoadMore: canLoadMore ?? this.canLoadMore,
    );
  }

  @override
  List<Object?> get props => [
    status,
    videos,
    currentIndex,
    isLoadingMore,
    canLoadMore,
  ];
}
