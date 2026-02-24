// ABOUTME: State for FullscreenFeedBloc
// ABOUTME: Tracks videos, current index, loading state, and seek commands

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

/// Command for widget to execute a seek operation.
///
/// Emitted by bloc when loop enforcement is triggered.
/// Widget should execute the seek and dispatch [FullscreenFeedSeekCommandHandled].
class SeekCommand extends Equatable {
  const SeekCommand({required this.index, required this.position});

  /// Index of the video to seek.
  final int index;

  /// Position to seek to.
  final Duration position;

  @override
  List<Object?> get props => [index, position];
}

/// State for the FullscreenFeedBloc.
final class FullscreenFeedState extends Equatable {
  const FullscreenFeedState({
    this.status = FullscreenFeedStatus.initial,
    this.videos = const [],
    this.currentIndex = 0,
    this.isLoadingMore = false,
    this.canLoadMore = false,
    this.seekCommand,
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

  /// Seek command for widget to execute.
  ///
  /// When not null, widget should execute the seek operation and dispatch
  /// [FullscreenFeedSeekCommandHandled] to clear this.
  final SeekCommand? seekCommand;

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
  List<VideoItem> get pooledVideos => videos
      .where((v) => v.videoUrl != null)
      .map((e) => VideoItem(id: e.id, url: e.videoUrl!))
      .toList();

  /// Whether we have pooled videos ready for playback.
  bool get hasPooledVideos => pooledVideos.isNotEmpty;

  /// Create a copy with updated values.
  FullscreenFeedState copyWith({
    FullscreenFeedStatus? status,
    List<VideoEvent>? videos,
    int? currentIndex,
    bool? isLoadingMore,
    bool? canLoadMore,
    SeekCommand? seekCommand,
    bool clearSeekCommand = false,
  }) {
    return FullscreenFeedState(
      status: status ?? this.status,
      videos: videos ?? this.videos,
      currentIndex: currentIndex ?? this.currentIndex,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      canLoadMore: canLoadMore ?? this.canLoadMore,
      seekCommand: clearSeekCommand ? null : (seekCommand ?? this.seekCommand),
    );
  }

  @override
  List<Object?> get props => [
    status,
    videos,
    currentIndex,
    isLoadingMore,
    canLoadMore,
    seekCommand,
  ];
}
