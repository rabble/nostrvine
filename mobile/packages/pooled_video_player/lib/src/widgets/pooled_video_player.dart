import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pooled_video_player/src/models/pooled_video.dart';
import 'package:pooled_video_player/src/services/video_controller_pool_manager.dart';
import 'package:pooled_video_player/src/widgets/video_pool_provider.dart';
import 'package:video_player/video_player.dart';

/// Callback invoked when the video controller is ready.
typedef OnVideoReady = void Function(VideoPlayerController controller);

/// Callback invoked when the video starts loading.
typedef OnVideoLoading = void Function();

/// Callback invoked when a video error occurs.
typedef OnVideoError = void Function(Object error);

/// Callback invoked when play/pause state changes.
typedef OnPlayPauseChanged = void Function({required bool isPlaying});

/// Builder for the video layer. Called once the controller is initialized.
///
/// The controller is guaranteed to be initialized (`isInitialized == true`).
///
/// Common usage pattern:
/// ```dart
/// videoBuilder: (context, controller) => AspectRatio(
///   aspectRatio: 9 / 16,
///   child: VideoPlayer(controller),
/// )
/// ```
typedef VideoBuilder =
    Widget Function(
      BuildContext context,
      VideoPlayerController controller,
    );

/// Builder for the overlay layer. Called when the controller is initialized.
///
/// Rendered on top of the video layer. Use this for UI elements like:
/// - Play/pause controls
/// - Progress indicators
/// - Author information
/// - Action buttons (like, share, comment)
///
/// Example:
/// ```dart
/// overlayBuilder: (context, controller) => Positioned(
///   bottom: 20,
///   right: 20,
///   child: IconButton(
///     icon: Icon(
///       controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
///     ),
///     onPressed: () => controller.value.isPlaying
///         ? controller.pause()
///         : controller.play(),
///   ),
/// )
/// ```
typedef OverlayBuilder =
    Widget Function(
      BuildContext context,
      VideoPlayerController controller,
    );

/// Headless video player that acquires controllers from
/// [VideoControllerPoolManager].
///
/// Uses specialized builders for clean UI composition:
/// - [videoBuilder]: Required builder for the video layer
///   (e.g., VideoPlayer widget)
/// - [loadingBuilder]: Optional builder for loading state
///   (defaults to black container)
/// - [overlayBuilder]: Optional builder for UI overlay
///   (e.g., controls, author info)
///
/// Example:
/// ```dart
/// PooledVideoPlayer(
///   video: video,
///   videoBuilder: (context, controller) => AspectRatio(
///     aspectRatio: 9 / 16,
///     child: VideoPlayer(controller),
///   ),
///   loadingBuilder: (context) => ThumbnailPlaceholder(),
///   overlayBuilder: (context, controller) => VideoOverlayUI(),
/// )
/// ```
class PooledVideoPlayer extends StatefulWidget {
  /// Creates a pooled video player widget.
  const PooledVideoPlayer({
    required this.video,
    required this.videoBuilder,
    this.loadingBuilder,
    this.overlayBuilder,
    this.autoPlay = false,
    this.looping = true,
    this.enableTapToPause = false,
    this.onVideoReady,
    this.onVideoLoading,
    this.onVideoError,
    this.onPlayPauseChanged,
    this.getCachedFile,
    super.key,
  });

  /// The video to play.
  final PooledVideo video;

  /// Builder for the video layer. Required.
  ///
  /// Called when the controller is initialized and ready to display video.
  final VideoBuilder videoBuilder;

  /// Builder for the loading state. Optional.
  ///
  /// Called when the controller is not yet initialized. If not provided,
  /// a default black container is shown.
  final WidgetBuilder? loadingBuilder;

  /// Builder for the overlay layer. Optional.
  ///
  /// Called when the controller is initialized. Rendered on top of the video.
  /// Use this for UI elements like controls, author info, action buttons, etc.
  final OverlayBuilder? overlayBuilder;

  /// Whether to automatically play when the controller is ready.
  final bool autoPlay;

  /// Whether the video should loop. Defaults to true.
  final bool looping;

  /// Enable tap-to-pause/play functionality.
  ///
  /// When enabled, tapping the video will toggle play/pause state.
  final bool enableTapToPause;

  /// Called when the video controller is ready.
  final OnVideoReady? onVideoReady;

  /// Called when the video starts loading.
  final OnVideoLoading? onVideoLoading;

  /// Called when an error occurs.
  final OnVideoError? onVideoError;

  /// Called when play/pause state changes.
  final OnPlayPauseChanged? onPlayPauseChanged;

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
    // Defer pool initialization to didChangeDependencies to access context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializePool();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize pool if not yet done (first call after initState)
    if (_pool == null) {
      _initializePool();
    }
  }

  void _initializePool() {
    // Already initialized
    if (_pool != null) return;

    // Try to get pool from widget tree first (testable), fall back to singleton
    _pool = VideoPoolProvider.maybeOf(context);

    if (_pool == null) {
      widget.onVideoError?.call(
        StateError(
          'VideoControllerPoolManager not initialized. '
          'Call VideoControllerPoolManager.initialize() first or wrap '
          'with VideoPoolProvider.',
        ),
      );
      return;
    }

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
          unawaited(_controller!.setLooping(widget.looping));
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
      controller.value;
      // coverage:ignore-start
    } on Exception {
      widget.onVideoError?.call(
        StateError('Controller was disposed, requesting new one'),
      );
      return;
    }
    // coverage:ignore-end

    setState(() => _controller = controller);

    if (_controller!.value.isInitialized) {
      unawaited(_controller!.setLooping(widget.looping));
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

    if (widget.looping != oldWidget.looping && _controller != null) {
      unawaited(_controller!.setLooping(widget.looping));
    }

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
        unawaited(existingController.setLooping(widget.looping));
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

  void _togglePlayPause() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (controller.value.isPlaying) {
      unawaited(controller.pause());
      widget.onPlayPauseChanged?.call(isPlaying: false);
    } else {
      unawaited(controller.play());
      widget.onPlayPauseChanged?.call(isPlaying: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final isInitialized = controller?.value.isInitialized ?? false;

    Widget content;

    if (isInitialized) {
      // Controller is ready - compose video layer + optional overlay
      content = Stack(
        fit: StackFit.expand,
        children: [
          // Layer 0: Video
          widget.videoBuilder(context, controller!),
          // Layer 1: Overlay (if provided)
          if (widget.overlayBuilder != null)
            widget.overlayBuilder!(context, controller),
        ],
      );
    } else {
      // Controller not ready - show loading state
      content =
          widget.loadingBuilder?.call(context) ?? const _DefaultLoadingState();
    }

    // Wrap with gesture detector if tap-to-pause is enabled
    if (widget.enableTapToPause && isInitialized) {
      content = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _togglePlayPause,
        child: content,
      );
    }

    return content;
  }

  @override
  void dispose() {
    _unsubscribe?.call();
    _pool?.releaseController(widget.video.id);
    super.dispose();
  }
}

/// Default loading state shown when video controller is not ready.
///
/// Displays a centered white circular progress indicator on a black background.
class _DefaultLoadingState extends StatelessWidget {
  const _DefaultLoadingState();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: CircularProgressIndicator(
          color: Colors.white,
        ),
      ),
    );
  }
}
