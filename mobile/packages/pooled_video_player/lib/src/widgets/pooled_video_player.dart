import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:pooled_video_player/src/controllers/video_feed_controller.dart';
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
typedef ErrorBuilder =
    Widget Function(
      BuildContext context,
      VoidCallback onRetry,
    );

/// Video player widget that displays a video from [VideoFeedController].
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
    super.key,
  });

  /// Optional explicit controller. Falls back to [VideoPoolProvider].
  final VideoFeedController? controller;

  /// The index of this video in the feed.
  final int index;

  /// Optional thumbnail URL to display while loading.
  final String? thumbnailUrl;

  /// Builder for the video layer.
  final VideoBuilder videoBuilder;

  /// Builder for the loading state.
  final WidgetBuilder? loadingBuilder;

  /// Builder for the error state.
  final ErrorBuilder? errorBuilder;

  /// Builder for the overlay layer.
  final OverlayBuilder? overlayBuilder;

  /// Whether tapping toggles play/pause.
  final bool enableTapToPause;

  /// Custom tap handler.
  final VoidCallback? onTap;

  void _handleTap(VideoFeedController ctrl) {
    if (onTap != null) {
      onTap!();
    } else if (enableTapToPause) {
      ctrl.togglePlayPause();
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
        final loadState = feedController.getLoadState(index);

        Widget content;

        if (loadState == LoadState.error) {
          content =
              errorBuilder?.call(
                context,
                () => feedController.onPageChanged(feedController.currentIndex),
              ) ??
              const _DefaultErrorState();
        } else if (videoController != null &&
            player != null &&
            loadState == LoadState.ready) {
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
        }

        if ((enableTapToPause || onTap != null) &&
            videoController != null &&
            loadState == LoadState.ready) {
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

/// Default loading state.
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
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// Default error state.
class _DefaultErrorState extends StatelessWidget {
  const _DefaultErrorState();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.white70, size: 48),
            SizedBox(height: 16),
            Text(
              'Failed to load video',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
