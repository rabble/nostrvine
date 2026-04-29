// ABOUTME: State for FullscreenFeedBloc
// ABOUTME: Tracks videos, current index, and loading state

part of 'fullscreen_feed_bloc.dart';

/// Status of the fullscreen feed.
enum FullscreenFeedStatus {
  /// Waiting for initial data.
  initial,

  /// Videos loaded and ready.
  ready,

  /// The last visible video was just removed (deletion / block / mute).
  /// The screen reacts by popping the route — there is nothing to show.
  emptyAfterRemoval,

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
    this.removedVideoIds = const <String>{},
    this.pendingSkipTarget,
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

  /// Event IDs confirmed missing for this session. Owned by the BLoC — the
  /// UI must never mutate this set directly. Once an ID is added it stays
  /// removed for the lifetime of this BLoC so repeated player errors for
  /// the same asset don't trigger duplicate HEAD checks or skip animations.
  final Set<String> removedVideoIds;

  /// When non-null, signals the UI to animate the feed to this index after
  /// a confirmed removal. The UI must dispatch
  /// [FullscreenFeedSkipAcknowledged] once it has consumed the signal so a
  /// subsequent removal can produce a new skip.
  final int? pendingSkipTarget;

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

  /// Metadata-sensitive signature for detecting updates to videos that keep
  /// the same IDs and order but change user-visible fields like loop counts.
  List<String> get videoUpdateSignature => videos
      .map(
        (video) => [
          video.id,
          video.stableId,
          video.videoUrl ?? '',
          video.thumbnailUrl ?? '',
          '${video.originalLoops ?? ''}',
          video.rawTags['views'] ?? '',
        ].join('|'),
      )
      .toList(growable: false);

  /// Whether we have pooled videos ready for playback.
  bool get hasPooledVideos => pooledVideos.isNotEmpty;

  /// Create a copy with updated values. [pendingSkipTarget] accepts
  /// `null` explicitly via [clearPendingSkipTarget] — the default
  /// copy-on-null-preserves behavior would otherwise prevent clearing it.
  FullscreenFeedState copyWith({
    FullscreenFeedStatus? status,
    List<VideoEvent>? videos,
    int? currentIndex,
    bool? isLoadingMore,
    bool? canLoadMore,
    Set<String>? removedVideoIds,
    int? pendingSkipTarget,
    bool clearPendingSkipTarget = false,
  }) {
    return FullscreenFeedState(
      status: status ?? this.status,
      videos: videos ?? this.videos,
      currentIndex: currentIndex ?? this.currentIndex,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      canLoadMore: canLoadMore ?? this.canLoadMore,
      removedVideoIds: removedVideoIds ?? this.removedVideoIds,
      pendingSkipTarget: clearPendingSkipTarget
          ? null
          : (pendingSkipTarget ?? this.pendingSkipTarget),
    );
  }

  @override
  List<Object?> get props => [
    status,
    videos,
    videoUpdateSignature,
    currentIndex,
    isLoadingMore,
    canLoadMore,
    removedVideoIds,
    pendingSkipTarget,
  ];
}
