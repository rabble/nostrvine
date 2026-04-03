import 'package:divine_video_player/divine_video_player.dart';
import 'package:equatable/equatable.dart';

import 'package:pooled_video_player/src/controllers/video_feed_controller.dart';

/// State of a video at a specific index in the feed.
///
/// Used by [VideoFeedController] to notify individual video player
/// widgets about their specific video's state changes, avoiding unnecessary
/// rebuilds of other video widgets.
class VideoIndexState extends Equatable {
  /// Creates a video index state.
  const VideoIndexState({
    this.loadState = LoadState.none,
    this.controller,
  });

  /// The loading state of the video.
  final LoadState loadState;

  /// The video player controller for playback and rendering, or null if
  /// not loaded.
  final DivineVideoPlayerController? controller;

  /// Whether the video is ready for playback.
  bool get isReady => loadState == LoadState.ready;

  /// Whether the video encountered an error.
  bool get hasError => loadState == LoadState.error;

  /// Whether the video is currently loading.
  bool get isLoading => loadState == LoadState.loading;

  @override
  List<Object?> get props => [loadState, controller];
}
