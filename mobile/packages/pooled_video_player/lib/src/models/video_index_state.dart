import 'package:equatable/equatable.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

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
    this.videoController,
    this.player,
  });

  /// The loading state of the video.
  final LoadState loadState;

  /// The video controller for rendering, or null if not loaded.
  final VideoController? videoController;

  /// The player for controlling playback, or null if not loaded.
  final Player? player;

  /// Whether the video is ready for playback.
  bool get isReady => loadState == LoadState.ready;

  /// Whether the video encountered an error.
  bool get hasError => loadState == LoadState.error;

  /// Whether the video is currently loading.
  bool get isLoading => loadState == LoadState.loading;

  @override
  List<Object?> get props => [loadState, videoController, player];
}
