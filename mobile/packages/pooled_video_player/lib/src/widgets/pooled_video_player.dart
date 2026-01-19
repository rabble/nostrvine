import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pooled_video_player/src/models/pooled_video.dart';
import 'package:pooled_video_player/src/services/video_controller_pool_manager.dart';
import 'package:video_player/video_player.dart';

typedef OnVideoReady = void Function(VideoPlayerController controller);

typedef OnVideoLoading = void Function();

typedef OnVideoError = void Function(Object error);

/// Headless video player that acquires controllers from [VideoControllerPoolManager].
class PooledVideoPlayer extends StatefulWidget {
  const PooledVideoPlayer({
    required this.video,
    required this.builder,
    this.autoPlay = false,
    this.onVideoReady,
    this.onVideoLoading,
    this.onVideoError,
    this.getCachedFile,
    super.key,
  });

  final PooledVideo video;

  final Widget Function(
    BuildContext context,
    VideoPlayerController? controller,
    Widget? child,
  )
  builder;

  final bool autoPlay;

  final OnVideoReady? onVideoReady;

  final OnVideoLoading? onVideoLoading;

  final OnVideoError? onVideoError;

  /// Optional cache lookup function for instant playback of cached videos.
  /// When provided, the pool manager will use local file controllers for
  /// cached videos instead of re-fetching from network.
  final File? Function(String videoId)? getCachedFile;

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

    // Synchronously check if controller already exists in pool (prewarmed).
    // This avoids the black frame that occurs when waiting for async callback.
    final existingController = _pool!.getController(widget.video.id);
    if (existingController != null && existingController.value.isInitialized) {
      // Controller already ready - set it directly before first build
      _controller = existingController;
      // Schedule callbacks for after first build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller != null) {
          widget.onVideoReady?.call(_controller!);
          if (widget.autoPlay) {
            unawaited(_controller!.play());
          }
        }
      });
    } else {
      // Not in pool or not initialized - request async
      _requestController();
    }
  }

  void _requestController() {
    widget.onVideoLoading?.call();

    unawaited(
      _pool!
          .acquireController(
            videoId: widget.video.id,
            videoUrl: widget.video.videoUrl,
            getCachedFile: widget.getCachedFile,
          )
          .then((PooledController? pooled) {
            if (pooled == null) {
              widget.onVideoError?.call(
                Exception('Failed to acquire video controller from pool'),
              );
              return;
            }
            _setController(pooled.controller);
          })
          .catchError((Object error) {
            widget.onVideoError?.call(error);
          }),
    );
  }

  void _setController(VideoPlayerController controller) {
    if (!mounted) return;
    if (controller == _controller) return;

    try {
      final _ = controller.value;
    } on Exception {
      widget.onVideoError?.call(
        StateError('Controller was disposed, requesting new one'),
      );
      return;
    }

    setState(() => _controller = controller);

    if (_controller!.value.isInitialized) {
      widget.onVideoReady?.call(_controller!);
      if (widget.autoPlay) {
        unawaited(_controller!.play());
      }
    }
  }

  void _onPoolStateChanged() {
    final controller = _pool?.getController(widget.video.id);
    if (controller != null) {
      _setController(controller);
    }
  }

  @override
  void didUpdateWidget(PooledVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.autoPlay != oldWidget.autoPlay && _controller != null) {
      if (widget.autoPlay && _controller!.value.isInitialized) {
        unawaited(_controller!.play());
      } else if (!widget.autoPlay && _controller!.value.isPlaying) {
        unawaited(_controller!.pause());
      }
    }

    if (widget.video.id != oldWidget.video.id) {
      // Check synchronously if new video's controller is already in pool
      final existingController = _pool?.getController(widget.video.id);
      if (existingController != null &&
          existingController.value.isInitialized) {
        setState(() => _controller = existingController);
        widget.onVideoReady?.call(existingController);
        if (widget.autoPlay) {
          unawaited(existingController.play());
        }
      } else {
        setState(() => _controller = null);
        _requestController();
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
