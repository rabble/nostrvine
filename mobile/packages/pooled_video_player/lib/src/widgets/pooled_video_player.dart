import 'dart:async';

import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/material.dart';
import 'package:pooled_video_player/src/controllers/video_feed_controller.dart';
import 'package:pooled_video_player/src/models/video_index_state.dart';
import 'package:pooled_video_player/src/widgets/video_pool_provider.dart';

const _firstFrameRevealTimeout = Duration(seconds: 2);

/// Builder for the video layer.
typedef VideoBuilder =
    Widget Function(
      BuildContext context,
      DivineVideoPlayerController controller,
    );

/// Builder for the overlay layer rendered on top of the video.
typedef OverlayBuilder =
    Widget Function(
      BuildContext context,
      DivineVideoPlayerController? controller,
    );

/// Builder for the error state.
typedef ErrorBuilder =
    Widget Function(BuildContext context, VoidCallback onRetry);

/// Video player widget that displays a video from [VideoFeedController].
class PooledVideoPlayer extends StatelessWidget {
  /// Creates a pooled video player widget.
  const PooledVideoPlayer({
    required this.index,
    required this.videoBuilder,
    this.controller,
    this.isActive = true,
    this.thumbnailUrl,
    this.loadingBuilder,
    this.errorBuilder,
    this.overlayBuilder,
    this.enableTapToPause = false,
    this.onTap,
    this.onDoubleTap,
    super.key,
  });

  /// Optional explicit controller. Falls back to [VideoPoolProvider].
  final VideoFeedController? controller;

  /// Whether this item is the currently active (visible) page.
  ///
  /// When `false` the native [Texture] is kept in the widget tree so that
  /// preloading continues, but it is hidden via [Opacity] to prevent
  /// texture bleeding during PageView scroll transitions.
  final bool isActive;

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

  /// Custom double-tap handler with tap position details.
  final ValueChanged<TapDownDetails>? onDoubleTap;

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

    return ValueListenableBuilder<VideoIndexState>(
      valueListenable: feedController.getIndexNotifier(index),
      builder: (context, state, _) {
        final controller = state.controller;
        final loadState = state.loadState;
        final overlay = overlayBuilder?.call(context, controller);

        final isReady = controller != null && loadState == .ready;

        return GestureDetector(
          behavior: .translucent,
          onTap: isReady && (onTap != null || enableTapToPause)
              ? () => _handleTap(feedController)
              : null,
          onDoubleTapDown: isReady ? onDoubleTap : null,
          child: Stack(
            fit: .expand,
            children: [
              /// Error state or loading + video layers.
              if (loadState == .error)
                errorBuilder?.call(
                      context,
                      () => feedController.onPageChanged(
                        feedController.currentIndex,
                      ),
                    ) ??
                    const _DefaultErrorState()
              else ...[
                /// Thumbnail / spinner shown until the first frame.
                loadingBuilder?.call(context) ??
                    _DefaultLoadingState(thumbnailUrl: thumbnailUrl),

                /// Video texture revealed after the first frame is decoded.
                if (controller != null)
                  _RevealVideoAfterFirstFrame(
                    controller: controller,
                    readyForFallback: loadState == LoadState.ready,
                    child: videoBuilder(context, controller),
                  ),
              ],

              /// Consumer-provided overlay (controls, progress bar, etc.).
              ?overlay,
            ],
          ),
        );
      },
    );
  }
}

class _RevealVideoAfterFirstFrame extends StatefulWidget {
  const _RevealVideoAfterFirstFrame({
    required this.controller,
    required this.readyForFallback,
    required this.child,
  });

  final DivineVideoPlayerController controller;
  final bool readyForFallback;
  final Widget child;

  @override
  State<_RevealVideoAfterFirstFrame> createState() =>
      _RevealVideoAfterFirstFrameState();
}

class _RevealVideoAfterFirstFrameState
    extends State<_RevealVideoAfterFirstFrame> {
  bool _hasRenderedFirstFrame = false;
  bool _revealedByTimeout = false;

  /// Latching flag: set to `true` once the player's position advances past
  /// zero, meaning the decoder has produced at least one frame.
  bool _hasDecodedFrames = false;
  int _generation = 0;
  Timer? _firstFrameTimeout;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<bool>? _firstFrameSubscription;

  @override
  void initState() {
    super.initState();
    _subscribeToFirstFrame();
    _subscribeToPosition();
    _syncFallbackTimer();
  }

  @override
  void didUpdateWidget(covariant _RevealVideoAfterFirstFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      _resetRevealState();
      _subscribeToFirstFrame();
      _subscribeToPosition();
    }
    if (oldWidget.readyForFallback != widget.readyForFallback) {
      _syncFallbackTimer();
    }
  }

  void _resetRevealState() {
    _firstFrameTimeout?.cancel();
    unawaited(_positionSubscription?.cancel());
    _positionSubscription = null;
    unawaited(_firstFrameSubscription?.cancel());
    _firstFrameSubscription = null;
    _hasRenderedFirstFrame = false;
    _revealedByTimeout = false;
    _hasDecodedFrames = false;
  }

  void _subscribeToPosition() {
    unawaited(_positionSubscription?.cancel());
    _hasDecodedFrames = widget.controller.state.position > Duration.zero;
    if (_hasDecodedFrames) return;
    _positionSubscription = widget.controller.stateStream
        .map((s) => s.position)
        .distinct()
        .listen((pos) {
          if (!mounted || _hasDecodedFrames) return;
          if (pos > Duration.zero) {
            unawaited(_positionSubscription?.cancel());
            _positionSubscription = null;
            setState(() => _hasDecodedFrames = true);
          }
        });
  }

  void _subscribeToFirstFrame() {
    ++_generation;
    _firstFrameTimeout?.cancel();
    unawaited(_firstFrameSubscription?.cancel());

    // Check if already rendered.
    if (widget.controller.state.isFirstFrameRendered) {
      _hasRenderedFirstFrame = true;
      return;
    }

    // Listen on stateStream so we catch first-frame regardless of
    // whether the Completer behind `firstFrameRendered` was reset
    // by a concurrent setSource call.
    final generation = _generation;
    _firstFrameSubscription = widget.controller.stateStream
        .map((s) => s.isFirstFrameRendered)
        .distinct()
        .listen((rendered) {
          if (!mounted || generation != _generation || !rendered) return;
          unawaited(_firstFrameSubscription?.cancel());
          _firstFrameSubscription = null;
          _firstFrameTimeout?.cancel();
          setState(() => _hasRenderedFirstFrame = true);
        });
  }

  void _syncFallbackTimer() {
    _firstFrameTimeout = Timer(_firstFrameRevealTimeout, () {
      if (!mounted || _hasRenderedFirstFrame || !widget.readyForFallback) {
        return;
      }
      setState(() {
        _revealedByTimeout = true;
      });
    });

    if (!widget.readyForFallback || _hasRenderedFirstFrame) {
      _firstFrameTimeout?.cancel();
      _revealedByTimeout = false;
      return;
    }
  }

  @override
  void dispose() {
    _firstFrameTimeout?.cancel();
    unawaited(_positionSubscription?.cancel());
    unawaited(_firstFrameSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Always require _hasDecodedFrames (position > 0) as a hard
    // condition. This proves the *current* media has produced frames.
    // Without it, the fallback timeout can reveal a recycled player's
    // stale texture (last frame of the previous video) before the new
    // content has decoded.
    final shouldReveal =
        widget.readyForFallback &&
        _hasDecodedFrames &&
        (_hasRenderedFirstFrame || _revealedByTimeout);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      opacity: shouldReveal ? 1 : 0,
      child: widget.child,
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
      color: const Color(0xFF000000),
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
            child: CircularProgressIndicator(color: Color(0xFFFFFFFF)),
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
      color: Color(0xFF000000),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Color(0xB3FFFFFF), size: 48),
            SizedBox(height: 16),
            Text(
              'Failed to load video',
              style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
