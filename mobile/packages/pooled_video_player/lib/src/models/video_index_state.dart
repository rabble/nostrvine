import 'package:equatable/equatable.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:pooled_video_player/src/controllers/video_feed_controller.dart';

/// Classifies a video playback error into an actionable type.
///
/// Set by [VideoFeedController] when a video fails to load. The consuming
/// UI reads this to decide which icon, message, and actions to show.
enum VideoErrorType {
  /// 401 Unauthorized — age-gated content.
  ageRestricted,

  /// 403 Forbidden — moderation-restricted content.
  forbidden,

  /// 404 Not Found — may or may not be moderation-related.
  notFound,

  /// Any other playback failure.
  generic,
}

/// State of a video at a specific index in the feed.
///
/// Used by [VideoFeedController] to notify individual video player
/// widgets about their specific video's state changes, avoiding unnecessary
/// rebuilds of other video widgets.
class VideoIndexState extends Equatable {
  /// Creates a video index state.
  const VideoIndexState({
    this.loadState = LoadState.none,
    this.videoController,
    this.player,
    this.isSlowLoad = false,
    this.errorType,
  });

  /// The loading state of the video.
  final LoadState loadState;

  /// The video controller for rendering, or null if not loaded.
  final VideoController? videoController;

  /// The player for controlling playback, or null if not loaded.
  final Player? player;

  /// Whether this video's load time has exceeded the slow-load threshold.
  ///
  /// Set once during loading and cleared when the video finishes loading
  /// or is released. The UI can use this to show a slow-loading indicator
  /// or skip action for externally hosted videos.
  final bool isSlowLoad;

  /// The classified error type when [loadState] is [LoadState.error].
  ///
  /// Set by [VideoFeedController] based on the raw error string from
  /// media_kit (e.g. HTTP status codes like "403", "forbidden").
  final VideoErrorType? errorType;

  /// Whether the video is ready for playback.
  bool get isReady => loadState == LoadState.ready;

  /// Whether the video encountered an error.
  bool get hasError => loadState == LoadState.error;

  /// Whether the video is currently loading.
  bool get isLoading => loadState == LoadState.loading;

  @override
  List<Object?> get props => [
    loadState,
    videoController,
    player,
    isSlowLoad,
    errorType,
  ];
}
