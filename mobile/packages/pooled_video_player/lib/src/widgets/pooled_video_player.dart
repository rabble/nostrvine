import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:pooled_video_player/src/controllers/video_feed_controller.dart';
import 'package:pooled_video_player/src/models/video_load_error.dart';
import 'package:pooled_video_player/src/widgets/video_pool_provider.dart';

/// Builder for the video layer.
typedef VideoBuilder =
    Widget Function(
      BuildContext context,
      VideoController videoController,
      Player player,
    );

/// Builder for the overlay layer rendered on top of the video.
typedef OverlayBuilder =
    Widget Function(
      BuildContext context,
      VideoController videoController,
      Player player,
    );

/// Builder for the error state.
///
/// [onRetry] can be called to retry loading the failed video.
typedef ErrorBuilder =
    Widget Function(
      BuildContext context,
      VideoLoadError error,
      VoidCallback onRetry,
    );

/// Callback invoked when the video is ready to play.
typedef OnVideoReady =
    void Function(
      VideoController videoController,
      Player player,
    );

/// Callback invoked when the video starts loading.
typedef OnVideoLoading = void Function();

/// Callback invoked when a video error occurs.
typedef OnVideoError = void Function(VideoLoadError error);

/// Callback invoked when play/pause state changes.
typedef OnPlayPauseChanged = void Function({required bool isPlaying});

/// Video player widget that acquires controllers from [VideoFeedController].
class PooledVideoPlayer extends StatelessWidget {
  /// Creates a pooled video player widget.
  const PooledVideoPlayer({
    required this.index,
    required this.videoBuilder,
    this.controller,
    this.thumbnailUrl,
    this.loadingBuilder,
    this.errorBuilder,
    this.overlayBuilder,
    this.enableTapToPause = false,
    this.onTap,
    this.onVideoReady,
    this.onVideoLoading,
    this.onVideoError,
    this.onPlayPauseChanged,
    super.key,
  });

  /// Optional explicit controller. Falls back to [VideoPoolProvider].
  final VideoFeedController? controller;

  /// The index of this video in the feed.
  final int index;

  /// Optional thumbnail URL to display while video is loading.
  final String? thumbnailUrl;

  /// Builder for the video layer.
  final VideoBuilder videoBuilder;

  /// Builder for the loading state.
  final WidgetBuilder? loadingBuilder;

  /// Builder for the error state.
  ///
  /// If not provided, a default error UI with retry button is shown.
  final ErrorBuilder? errorBuilder;

  /// Builder for the overlay layer.
  final OverlayBuilder? overlayBuilder;

  /// Whether tapping toggles play/pause.
  final bool enableTapToPause;

  /// Custom tap handler. If provided, overrides enableTapToPause behavior.
  final VoidCallback? onTap;

  /// Called when the video is ready to play.
  final OnVideoReady? onVideoReady;

  /// Called when the video starts loading.
  final OnVideoLoading? onVideoLoading;

  /// Called when an error occurs.
  final OnVideoError? onVideoError;

  /// Called when play/pause state changes.
  final OnPlayPauseChanged? onPlayPauseChanged;

  void _handleTap(VideoFeedController ctrl) {
    if (onTap != null) {
      onTap!();
    } else if (enableTapToPause) {
      ctrl.togglePlayPause();
      onPlayPauseChanged?.call(isPlaying: !ctrl.isPaused);
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedController = controller ?? VideoPoolProvider.feedOf(context);

    return ListenableBuilder(
      listenable: feedController,
      builder: (context, _) {
        final videoController = feedController.getVideoController(index);
        final player = feedController.getPlayer(index);
        final isReady = feedController.isVideoReady(index);
        final preloadState = feedController.getPreloadState(index);
        final error = feedController.getError(index);

        Widget content;

        // Check for error state first
        if (preloadState == PreloadState.error && error != null) {
          onVideoError?.call(error);
          content =
              errorBuilder?.call(
                context,
                error,
                () => feedController.retryPreload(index),
              ) ??
              _DefaultErrorState(
                error: error,
                onRetry: () => feedController.retryPreload(index),
              );
        } else if (videoController != null && player != null && isReady) {
          content = Stack(
            fit: StackFit.expand,
            children: [
              videoBuilder(context, videoController, player),
              if (overlayBuilder != null)
                overlayBuilder!(context, videoController, player),
            ],
          );
        } else {
          content =
              loadingBuilder?.call(context) ??
              _DefaultLoadingState(thumbnailUrl: thumbnailUrl);
          onVideoLoading?.call();
        }

        if ((enableTapToPause || onTap != null) &&
            videoController != null &&
            player != null &&
            isReady) {
          content = GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => _handleTap(feedController),
            child: content,
          );
        }

        return content;
      },
    );
  }
}

/// Default loading state shown when video controller is not ready.
class _DefaultLoadingState extends StatelessWidget {
  const _DefaultLoadingState({this.thumbnailUrl});

  final String? thumbnailUrl;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (thumbnailUrl != null)
            Image.network(
              thumbnailUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
          const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Default error state shown when video loading fails.
class _DefaultErrorState extends StatelessWidget {
  const _DefaultErrorState({
    required this.error,
    required this.onRetry,
  });

  final VideoLoadError error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final config = VideoPoolProvider.maybePoolManager()?.config;
    final maxRetries = config?.maxRetryAttempts ?? 3;
    final canRetry = error.retryCount < maxRetries;

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white70,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to load video',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            if (canRetry) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text(
                  'Tap to retry',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
