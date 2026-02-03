import 'package:flutter/widgets.dart';

import 'package:pooled_video_player/src/controllers/player_pool.dart';
import 'package:pooled_video_player/src/controllers/video_feed_controller.dart';

/// Provides [PlayerPool] and [VideoFeedController] to the widget tree.
class VideoPoolProvider extends InheritedWidget {
  /// Creates a [VideoPoolProvider].
  const VideoPoolProvider({
    required super.child,
    this.pool,
    this.feedController,
    super.key,
  });

  /// The shared player pool.
  final PlayerPool? pool;

  /// The feed controller for this subtree.
  final VideoFeedController? feedController;

  /// Returns the [PlayerPool] from the nearest ancestor or the singleton.
  ///
  /// First checks the widget tree for a provider with a pool.
  /// If not found, returns [PlayerPool.instance].
  static PlayerPool poolOf(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<VideoPoolProvider>();
    if (provider?.pool != null) {
      return provider!.pool!;
    }
    // Fall back to singleton
    return PlayerPool.instance;
  }

  /// Returns the [VideoFeedController] from the nearest ancestor.
  ///
  /// Throws [StateError] if no provider with a feed controller is found.
  static VideoFeedController feedOf(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<VideoPoolProvider>();
    if (provider?.feedController != null) {
      return provider!.feedController!;
    }
    throw StateError(
      'No VideoPoolProvider with feedController found. '
      'Wrap your widget with VideoPoolProvider and provide a feedController.',
    );
  }

  /// Returns the [PlayerPool] if available, or null.
  static PlayerPool? maybePoolOf(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<VideoPoolProvider>();
    return provider?.pool;
  }

  /// Returns the [VideoFeedController] if available, or null.
  static VideoFeedController? maybeFeedOf(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<VideoPoolProvider>();
    return provider?.feedController;
  }

  @override
  bool updateShouldNotify(VideoPoolProvider oldWidget) =>
      pool != oldWidget.pool || feedController != oldWidget.feedController;
}
