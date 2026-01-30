import 'package:flutter/widgets.dart';
import 'package:pooled_video_player/src/services/video_controller_pool_manager.dart';

/// Provides [VideoControllerPoolManager] to the widget tree.
///
/// This widget enables dependency injection of the pool manager,
/// improving testability and allowing scoped pool instances.
///
/// If not provided in the widget tree, widgets will fall back to the
/// singleton [VideoControllerPoolManager.instance].
///
/// Example usage:
/// ```dart
/// VideoPoolProvider(
///   pool: VideoControllerPoolManager.instance,
///   child: PooledVideoFeed(videos: videos, itemBuilder: itemBuilder),
/// )
/// ```
///
/// For testing, you can provide a mock pool manager:
/// ```dart
/// VideoPoolProvider(
///   pool: mockPoolManager,
///   child: PooledVideoPlayer(video: video, videoBuilder: videoBuilder),
/// )
/// ```
class VideoPoolProvider extends InheritedWidget {
  /// Creates a [VideoPoolProvider] with the given pool manager.
  const VideoPoolProvider({
    required this.pool,
    required super.child,
    super.key,
  });

  /// The pool manager to provide to descendants.
  final VideoControllerPoolManager pool;

  /// Returns the pool manager from the nearest [VideoPoolProvider] ancestor.
  ///
  /// If no [VideoPoolProvider] is found in the widget tree, falls back to
  /// the singleton [VideoControllerPoolManager.instance].
  ///
  /// Throws [StateError] if the singleton is also not initialized.
  static VideoControllerPoolManager of(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<VideoPoolProvider>();
    if (provider != null) {
      return provider.pool;
    }
    // Fall back to singleton for backward compatibility
    return VideoControllerPoolManager.instance;
  }

  /// Returns the pool manager if available in the widget tree.
  ///
  /// Returns `null` if no [VideoPoolProvider] ancestor exists AND the
  /// singleton [VideoControllerPoolManager] is not initialized.
  ///
  /// Use this method when you want to handle missing pool gracefully
  /// without throwing an exception.
  static VideoControllerPoolManager? maybeOf(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<VideoPoolProvider>();
    if (provider != null) {
      return provider.pool;
    }
    // Try singleton, but don't throw if not initialized
    if (VideoControllerPoolManager.isInitialized) {
      return VideoControllerPoolManager.instance;
    }
    return null;
  }

  @override
  bool updateShouldNotify(VideoPoolProvider oldWidget) =>
      pool != oldWidget.pool;
}
