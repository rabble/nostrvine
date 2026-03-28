import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:pooled_video_player/src/controllers/video_feed_controller.dart';
import 'package:pooled_video_player/src/models/video_index_state.dart';
import 'package:pooled_video_player/src/widgets/video_pool_provider.dart';

const _firstFrameRevealTimeout = Duration(seconds: 2);

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
      VideoController? videoController,
      Player? player,
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
  /// media_kit texture bleeding during PageView scroll transitions.
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
        final videoController = state.videoController;
        final player = state.player;
        final loadState = state.loadState;
        final overlay = overlayBuilder?.call(context, videoController, player);

        Widget content;

        if (loadState == LoadState.error) {
          content = Stack(
            fit: StackFit.expand,
            children: [
              errorBuilder?.call(
                    context,
                    () => feedController.onPageChanged(
                      feedController.currentIndex,
                    ),
                  ) ??
                  const _DefaultErrorState(),
              ?overlay,
            ],
          );
        } else if (videoController != null && player != null) {
          final loadingPlaceholder =
              loadingBuilder?.call(context) ??
              _DefaultLoadingState(thumbnailUrl: thumbnailUrl);
          final children = <Widget>[
            loadingPlaceholder,
            Opacity(
              opacity: isActive ? 1 : 0,
              child: _RevealVideoAfterFirstFrame(
                videoController: videoController,
                readyForFallback: loadState == LoadState.ready,
                child: videoBuilder(context, videoController, player),
              ),
            ),
            ?overlay,
          ];
          content = Stack(fit: StackFit.expand, children: children);
        } else {
          content = Stack(
            fit: StackFit.expand,
            children: [
              loadingBuilder?.call(context) ??
                  _DefaultLoadingState(thumbnailUrl: thumbnailUrl),
              ?overlay,
            ],
          );
        }

        if ((enableTapToPause || onTap != null || onDoubleTap != null) &&
            videoController != null &&
            loadState == LoadState.ready) {
          content = GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onTap != null || enableTapToPause
                ? () => _handleTap(feedController)
                : null,
            onDoubleTapDown: onDoubleTap,
            child: content,
          );
        }

        return content;
      },
    );
  }
}

class _RevealVideoAfterFirstFrame extends StatefulWidget {
  const _RevealVideoAfterFirstFrame({
    required this.videoController,
    required this.readyForFallback,
    required this.child,
  });

  final VideoController videoController;
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
  int _generation = 0;
  Timer? _firstFrameTimeout;

  /// Tracks the last known texture ID to detect Android surface recreation.
  ///
  /// On Android, when the app backgrounds/foregrounds or the GPU context is
  /// lost, `SurfaceProducer` destroys and recreates the surface. The new
  /// surface has uninitialized content (green in YUV color space). Since
  /// `waitUntilFirstFrameRendered` is a one-shot `Completer`, it stays
  /// completed after the initial load and never re-fires on surface
  /// recreation. This means `_hasRenderedFirstFrame` stays `true` and the
  /// green frame is visible.
  ///
  /// By tracking texture ID changes we can detect surface recreation and
  /// temporarily re-hide the video until a new frame is rendered.
  int? _lastTextureId;

  /// Whether we're waiting for the first frame after a surface recreation.
  bool _surfaceRecreating = false;
  Timer? _surfaceRecoveryTimer;

  @override
  void initState() {
    super.initState();
    _subscribeToFirstFrame();
    _syncFallbackTimer();
    _listenToTextureId();
  }

  @override
  void didUpdateWidget(covariant _RevealVideoAfterFirstFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.videoController, widget.videoController)) {
      _stopListeningToTextureId(oldWidget.videoController);
      _resetRevealState();
      _subscribeToFirstFrame();
      _listenToTextureId();
    }
    if (oldWidget.readyForFallback != widget.readyForFallback) {
      _syncFallbackTimer();
    }
  }

  void _resetRevealState() {
    _firstFrameTimeout?.cancel();
    _surfaceRecoveryTimer?.cancel();
    _hasRenderedFirstFrame = false;
    _revealedByTimeout = false;
    _surfaceRecreating = false;
    _lastTextureId = null;
  }

  void _listenToTextureId() {
    _lastTextureId = widget.videoController.id.value;
    widget.videoController.id.addListener(_onTextureIdChanged);
  }

  void _stopListeningToTextureId(VideoController controller) {
    controller.id.removeListener(_onTextureIdChanged);
    _surfaceRecoveryTimer?.cancel();
  }

  void _onTextureIdChanged() {
    final newId = widget.videoController.id.value;
    if (_lastTextureId != null &&
        newId != null &&
        newId != _lastTextureId &&
        _hasRenderedFirstFrame) {
      // Surface was recreated — hide texture until a new frame renders.
      // The `rect` notifier fires once mpv renders to the new surface,
      // but since dimensions may not change we use a timer as fallback.
      setState(() => _surfaceRecreating = true);
      _surfaceRecoveryTimer?.cancel();

      void reveal() {
        if (!mounted) return;
        setState(() => _surfaceRecreating = false);
      }

      // Listen for the next rect update as a "frame rendered" signal.
      void onRect() {
        _surfaceRecoveryTimer?.cancel();
        widget.videoController.rect.removeListener(onRect);
        reveal();
      }

      widget.videoController.rect.addListener(onRect);

      // Fallback: reveal after 500ms even if no rect update arrives.
      _surfaceRecoveryTimer = Timer(const Duration(milliseconds: 500), () {
        widget.videoController.rect.removeListener(onRect);
        reveal();
      });
    }
    _lastTextureId = newId;
  }

  void _subscribeToFirstFrame() {
    final generation = ++_generation;
    _firstFrameTimeout?.cancel();

    unawaited(
      widget.videoController.waitUntilFirstFrameRendered
          .then((_) {
            if (!mounted || generation != _generation) return;
            _firstFrameTimeout?.cancel();
            setState(() {
              _hasRenderedFirstFrame = true;
            });
          })
          .catchError((_) {
            if (!mounted || generation != _generation) return;
            _firstFrameTimeout?.cancel();
            setState(() {
              _hasRenderedFirstFrame = true;
            });
          }),
    );
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
    _stopListeningToTextureId(widget.videoController);
    _firstFrameTimeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shouldReveal =
        !_surfaceRecreating &&
        (_hasRenderedFirstFrame ||
            (widget.readyForFallback && _revealedByTimeout));

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
