import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pooled_video_player/src/models/pooled_video.dart';
import 'package:pooled_video_player/src/services/video_controller_pool_manager.dart';
import 'package:video_player/video_player.dart';

/// Callback for when a video controller is ready to play
typedef OnVideoReady = void Function(VideoPlayerController controller);

/// Callback for when a video controller is loading
typedef OnVideoLoading = void Function();

/// Callback for when a video controller fails to load
typedef OnVideoError = void Function(Object error);

/// Headless video player that acquires controllers from [VideoControllerPoolManager].
///
/// ```dart
/// PooledVideoPlayer(
///   video: myVideo,
///   autoPlay: true,
///   builder: (context, controller, child) {
///     if (controller == null) return CircularProgressIndicator();
///     return VideoPlayer(controller);
///   },
/// )
/// ```
class PooledVideoPlayer extends StatefulWidget {
  const PooledVideoPlayer({
    required this.video,
    required this.builder,
    this.autoPlay = false,
    this.onVideoReady,
    this.onVideoLoading,
    this.onVideoError,
    super.key,
  });

  /// Video to play (must implement PooledVideo)
  final PooledVideo video;

  /// Builder for UI. Controller is null while loading.
  final Widget Function(
    BuildContext context,
    VideoPlayerController? controller,
    Widget? child,
  )
  builder;

  /// Whether to auto-play when controller is ready
  final bool autoPlay;

  /// Callback when controller is ready to play
  final OnVideoReady? onVideoReady;

  /// Callback when controller is loading
  final OnVideoLoading? onVideoLoading;

  /// Callback when controller fails to load
  final OnVideoError? onVideoError;

  @override
  State<PooledVideoPlayer> createState() => _PooledVideoPlayerState();
}

class _PooledVideoPlayerState extends State<PooledVideoPlayer> {
  VideoPlayerController? _controller;
  VideoControllerPoolManager? _pool;
  VoidCallback? _unsubscribe;

  @override
  void initState() {
    super.initState();
    _initializePool();
  }

  void _initializePool() {
    if (!VideoControllerPoolManager.isInitialized) {
      widget.onVideoError?.call(
        StateError(
          'VideoControllerPoolManager not initialized. '
          'Call VideoControllerPoolManager.initialize() first.',
        ),
      );
      return;
    }

    _pool = VideoControllerPoolManager.instance;
    _unsubscribe = _pool!.addPoolChangeListener(_onPoolStateChanged);
    _requestController();
  }

  void _requestController() {
    widget.onVideoLoading?.call();

    unawaited(
      _pool!
          .acquireController(
            videoId: widget.video.id,
            videoUrl: widget.video.videoUrl,
          )
          .then((PooledController? pooled) {
            if (pooled == null) {
              widget.onVideoError?.call(
                Exception('Failed to acquire video controller from pool'),
              );
            }
            // Controller will be set via _onPoolStateChanged listener
          })
          .catchError((Object error) {
            widget.onVideoError?.call(error);
          }),
    );
  }

  void _onPoolStateChanged() {
    final controller = _pool?.getController(widget.video.id);
    if (controller != null && controller != _controller) {
      setState(() => _controller = controller);

      if (_controller!.value.isInitialized) {
        widget.onVideoReady?.call(_controller!);
        if (widget.autoPlay) {
          unawaited(_controller!.play());
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _controller, null);
  }

  @override
  void dispose() {
    _unsubscribe?.call();
    _pool?.releaseController(widget.video.id);
    super.dispose();
  }
}
