import 'dart:async';

import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/material.dart';
import 'package:openvine/widgets/video_feed_item/center_playback_control.dart';

class PausedVideoOverlay extends StatefulWidget {
  const PausedVideoOverlay({
    required this.controller,
    this.isVisible = true,
    super.key,
  });

  final DivineVideoPlayerController controller;
  final bool isVisible;

  @override
  State<PausedVideoOverlay> createState() => _PausedVideoOverlayState();
}

class _PausedVideoOverlayState extends State<PausedVideoOverlay> {
  StreamSubscription<DivineVideoPlayerState>? _subscription;

  /// Latching flag: set once this player emits a [PlaybackStatus.playing]
  /// state while [PausedVideoOverlay.isVisible] is true.  Reset when
  /// [DivineVideoPlayerState.isFirstFrameRendered] becomes false (new
  /// clips loaded), so a swipe to a fresh video never inherits the
  /// latch from the previous playback session.
  bool _hasStartedPlaying = false;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant PausedVideoOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      unawaited(_subscription?.cancel());
      _hasStartedPlaying = false;
      _subscribe();
    }
  }

  void _subscribe() {
    _subscription = widget.controller.stateStream.listen(_onState);
  }

  void _onState(DivineVideoPlayerState state) {
    if (!mounted) return;
    if (!state.isFirstFrameRendered) {
      // New video loading — reset so the latch must be re-earned.
      if (_hasStartedPlaying) setState(() => _hasStartedPlaying = false);
      return;
    }
    if (state.status == PlaybackStatus.playing && widget.isVisible) {
      if (!_hasStartedPlaying) setState(() => _hasStartedPlaying = true);
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: widget.controller.stateStream
          .map((s) => s.isPaused && s.isFirstFrameRendered)
          .distinct(),
      builder: (context, snapshot) {
        final shouldShow =
            widget.isVisible && _hasStartedPlaying && (snapshot.data ?? false);

        return IgnorePointer(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(
                    begin: 0.92,
                    end: 1,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: shouldShow
                ? const CenterPlaybackControl(
                    state: .play,
                    semanticsLabel: 'Play video',
                  )
                : const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
