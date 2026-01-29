import 'package:flutter/widgets.dart';

import 'package:pooled_video_player/src/controllers/player_pool_manager.dart';
import 'package:pooled_video_player/src/controllers/video_feed_controller.dart';

/// Provides [VideoFeedController] and access to [PlayerPoolManager] to the
/// widget tree.
///
/// This widget enables dependency injection of the feed controller,
/// improving testability and allowing scoped controller instances.
///
/// Example usage:
/// ```dart
/// VideoPoolProvider(
///   feedController: myFeedController,
///   child: PooledVideoPlayer(
///     index: 0,
///     videoBuilder: (context, videoController, player) => Video(...),
///   ),
/// )
/// ```
class VideoPoolProvider extends InheritedWidget {
  /// Creates a [VideoPoolProvider].
  ///
  /// The [feedController] provides access to a specific feed's state.
  const VideoPoolProvider({
    required super.child,
    this.feedController,
    super.key,
  });

  /// The feed controller to provide to descendants.
  final VideoFeedController? feedController;

  /// Returns the [PlayerPoolManager] singleton.
  ///
  /// Throws [StateError] if not initialized.
  static PlayerPoolManager get poolManager => PlayerPoolManager.instance;

  /// Returns the [VideoFeedController] from the nearest [VideoPoolProvider]
  /// ancestor.
  ///
  /// Throws [StateError] if no provider with a feed controller is found.
  static VideoFeedController feedOf(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<VideoPoolProvider>();
    if (provider?.feedController != null) {
      return provider!.feedController!;
    }
    throw StateError(
      'No VideoPoolProvider with feedController found in the widget tree. '
      'Wrap your widget with VideoPoolProvider and provide a feedController.',
    );
  }

  /// Returns the [VideoFeedController] if available, or null.
  static VideoFeedController? maybeFeedOf(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<VideoPoolProvider>();
    return provider?.feedController;
  }

  /// Returns the [PlayerPoolManager] if initialized, or null.
  static PlayerPoolManager? maybePoolManager() {
    if (PlayerPoolManager.isInitialized) {
      return PlayerPoolManager.instance;
    }
    return null;
  }

  @override
  bool updateShouldNotify(VideoPoolProvider oldWidget) =>
      feedController != oldWidget.feedController;
}
