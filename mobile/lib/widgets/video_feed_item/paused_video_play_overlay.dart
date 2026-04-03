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
  StreamSubscription<bool>? _playingSubscription;

  /// Latching flag: set once this widget's player transitions to playing
  /// for the *current* video. Reset when the player identity changes
  /// (recycled for a new video) via [didUpdateWidget].
  bool _hasStartedPlayback = false;

  @override
  void initState() {
    super.initState();
    _subscribeToPlayback();
  }

  @override
  void didUpdateWidget(covariant PausedVideoPlayOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      unawaited(_playingSubscription?.cancel());
      _hasStartedPlayback = false;
      _subscribeToPlayback();
    }
  }

  void _subscribeToPlayback() {
    // Only latch when the overlay is visible (active video). During preload
    // the player is played muted for buffering then paused — that play must
    // not set the latch, otherwise the pause indicator flashes briefly when
    // the user arrives at the preloaded video (isBuffering=false before
    // isPlaying=true, amplified by the 180ms AnimatedSwitcher).
    _hasStartedPlayback = widget.isVisible && widget.controller.state.isPlaying;
    _playingSubscription = widget.controller.stateStream
        .map((s) => s.isPlaying)
        .distinct()
        .listen((isPlaying) {
          if (isPlaying &&
              !_hasStartedPlayback &&
              widget.isVisible &&
              mounted) {
            setState(() {
              _hasStartedPlayback = true;
            });
          }
        });
  }

  @override
  void dispose() {
    unawaited(_playingSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<void>(
      future: widget.firstFrameFuture,
      builder: (context, firstFrameSnapshot) {
        final hasRenderedFirstFrame =
            widget.firstFrameFuture == null ||
            firstFrameSnapshot.connectionState == ConnectionState.done;

        if (!hasRenderedFirstFrame) {
          return const SizedBox.shrink();
        }

        return StreamBuilder<bool>(
          stream: widget.controller.stateStream
              .map((s) => s.status == PlaybackStatus.buffering)
              .distinct(),
          initialData:
              widget.controller.state.status == PlaybackStatus.buffering,
          builder: (context, bufferingSnapshot) {
            final isBuffering = bufferingSnapshot.data ?? false;

            return StreamBuilder<bool>(
              stream: widget.controller.stateStream
                  .map((s) => s.isPlaying)
                  .distinct(),
              initialData: widget.controller.state.isPlaying,
              builder: (context, playingSnapshot) {
                final isPlaying = playingSnapshot.data ?? false;
                final shouldShow =
                    _hasStartedPlayback && !isPlaying && !isBuffering;

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
                            key: ValueKey('paused-play'),
                            state: CenterPlaybackControlState.play,
                            semanticsLabel: 'Play video',
                          )
                        : const SizedBox.shrink(
                            key: ValueKey('paused-hidden'),
                          ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
