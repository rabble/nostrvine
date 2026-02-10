import 'package:equatable/equatable.dart';
import 'package:media_kit/media_kit.dart';

import 'package:pooled_video_player/src/models/video_item.dart';

/// Resolves a video to its media source (cached file path or original URL).
///
/// Return `null` to use the original [VideoItem.url].
typedef MediaSourceResolver = String? Function(VideoItem video);

/// Called when a video becomes ready for playback.
typedef VideoReadyCallback = void Function(int index, Player player);

/// Called periodically with position updates for the active video.
typedef PositionCallback = void Function(int index, Duration position);

/// Configuration for video pool and preloading.
class VideoPoolConfig extends Equatable {
  /// Creates a video pool configuration.
  const VideoPoolConfig({
    this.maxPlayers = 5,
    this.preloadAhead = 2,
    this.preloadBehind = 1,
    this.mediaSourceResolver,
    this.onVideoReady,
    this.positionCallback,
    this.positionCallbackInterval = const Duration(milliseconds: 200),
  }) : assert(maxPlayers >= 1, 'maxPlayers must be at least 1'),
       assert(preloadAhead >= 0, 'preloadAhead must be non-negative'),
       assert(preloadBehind >= 0, 'preloadBehind must be non-negative');

  /// Maximum number of players in the pool.
  final int maxPlayers;

  /// Number of videos to preload ahead of current.
  final int preloadAhead;

  /// Number of videos to preload behind current.
  final int preloadBehind;

  /// Hook: Resolve video URL to actual media source (file path or URL).
  ///
  /// Used for cache integration — return a cached file path if available,
  /// or `null` to use the original [VideoItem.url].
  final MediaSourceResolver? mediaSourceResolver;

  /// Hook: Called when a video is ready to play.
  ///
  /// Used for triggering background caching, analytics, etc.
  final VideoReadyCallback? onVideoReady;

  /// Hook: Called periodically with position updates.
  ///
  /// Used for loop enforcement, progress tracking, etc.
  /// The interval is controlled by [positionCallbackInterval].
  final PositionCallback? positionCallback;

  /// Interval for [positionCallback] invocations.
  ///
  /// Defaults to 200ms.
  final Duration positionCallbackInterval;

  @override
  List<Object?> get props => [
    maxPlayers,
    preloadAhead,
    preloadBehind,
    mediaSourceResolver,
    onVideoReady,
    positionCallback,
    positionCallbackInterval,
  ];
}
