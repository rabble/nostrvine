import 'dart:async';

import 'package:flutter/material.dart';
import 'package:openvine/widgets/video_feed_item/center_playback_control.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

/// Large centered play affordance shown when a pooled video is paused.
class PausedVideoPlayOverlay extends StatefulWidget {
  const PausedVideoPlayOverlay({
    required this.controller,
    this.firstFrameFuture,
    this.isVisible = true,
    super.key,
  });

  final DivineVideoPlayerController controller;
  final Future<void>? firstFrameFuture;
  final bool isVisible;

  @override
  State<PausedVideoPlayOverlay> createState() => _PausedVideoPlayOverlayState();
}

class _PausedVideoPlayOverlayState extends State<PausedVideoPlayOverlay> {
  StreamSubscription<bool>? _pauseSubscription;

  /// Latching flag: set once this widget's player transitions to playing
  /// for the *current* video. Reset when the player identity changes
  /// (recycled for a new video) via [didUpdateWidget].
  bool _hasStartedPlayback = false;

  /// Whether the play icon should be shown. Updated via debounced
  /// subscription to avoid flashing during transient state changes.
  bool _shouldShow = false;

  /// Debounce timer: delays the show transition so transient pauses
  /// (e.g. buffering glitches) don't flash the play icon.
  Timer? _showDebounce;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant PausedVideoPlayOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      _dispose();
      _hasStartedPlayback = false;
      _shouldShow = false;
      _subscribe();
    } else if (!oldWidget.isVisible && widget.isVisible) {
      // Swiping back to this video: reset so the play button doesn't
      // flash before playback resumes.
      _showDebounce?.cancel();
      _hasStartedPlayback = false;
      _shouldShow = false;
    }
  }

  void _subscribe() {
    _hasStartedPlayback = widget.isVisible && widget.controller.state.isPlaying;

    _pauseSubscription = widget.controller.stateStream
        .map((s) {
          final isPlaying = s.isPlaying;
          final isBuffering = s.status == PlaybackStatus.buffering;
          // Latch _hasStartedPlayback on first play while visible.
          if (isPlaying && !_hasStartedPlayback && widget.isVisible) {
            _hasStartedPlayback = true;
          }
          return _hasStartedPlayback && !isPlaying && !isBuffering;
        })
        .distinct()
        .listen(_onShouldShowChanged);
  }

  void _onShouldShowChanged(bool wantShow) {
    _showDebounce?.cancel();
    if (wantShow) {
      // Delay showing the icon so transient pauses (<200ms) are ignored.
      _showDebounce = Timer(const Duration(milliseconds: 200), () {
        if (mounted && !_shouldShow) {
          setState(() => _shouldShow = true);
        }
      });
    } else {
      // Hide immediately — no debounce needed.
      if (mounted && _shouldShow) {
        setState(() => _shouldShow = false);
      }
    }
  }

  void _dispose() {
    _showDebounce?.cancel();
    unawaited(_pauseSubscription?.cancel());
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
              child: child,
            ),
          );
        },
        child: _shouldShow
            ? const CenterPlaybackControl(
                key: ValueKey('paused-play'),
                state: CenterPlaybackControlState.play,
                semanticsLabel: 'Play video',
              )
            : const SizedBox.shrink(key: ValueKey('paused-hidden')),
      ),
    );
  }
}
