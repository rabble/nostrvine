import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:openvine/widgets/video_feed_item/center_playback_control.dart';

/// Large centered play affordance shown when a pooled video is paused, plus a
/// brief "unpause" feedback that flashes the pause icon right after playback
/// resumes (mirrors the Figma spec for the center playback control).
class PausedVideoPlayOverlay extends StatefulWidget {
  const PausedVideoPlayOverlay({
    required this.player,
    this.firstFrameFuture,
    this.isVisible = true,
    super.key,
  });

  final Player player;
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

  /// Previous value from [Player.stream.playing], used to detect the
  /// paused -> playing transition that triggers the unpause feedback.
  bool _previouslyPlaying = false;

  /// Timestamp of the last paused -> playing transition's pause edge, used
  /// to filter out sub-frame loop-restart blips that would otherwise flash
  /// the feedback during normal looping playback.
  DateTime? _pausedAt;

  /// Whether the transient unpause pause-icon is currently visible.
  bool _showUnpauseFeedback = false;

  /// Animated opacity of the unpause feedback icon. Driven by [Timer]s to
  /// match the original fade-out behavior from `video_feed_item.dart`.
  double _unpauseFeedbackOpacity = 1.0;

  Timer? _unpauseFadeTimer;
  Timer? _unpauseHideTimer;

  /// Delay before the opacity is flipped to 0, letting [AnimatedOpacity]
  /// drive the fade.
  static const _unpauseFadeStartDelay = Duration(milliseconds: 50);

  /// [AnimatedOpacity] animation duration for the fade.
  static const _unpauseFadeDuration = Duration(milliseconds: 500);

  /// Total visible window of the feedback (fade start + fade duration,
  /// plus a small tail so we don't remove the widget mid-animation).
  static const _unpauseHideDelay = Duration(milliseconds: 550);

  /// Only treat a paused -> playing transition as a user-initiated unpause
  /// when the pause lasted at least this long. Filters out loop-restart
  /// and playlist-advance blips (both typically <50 ms).
  static const _minPauseForFeedback = Duration(milliseconds: 150);

  @override
  void initState() {
    super.initState();
    _subscribeToPlayback();
  }

  @override
  void didUpdateWidget(covariant PausedVideoPlayOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.player, widget.player)) {
      unawaited(_playingSubscription?.cancel());
      _cancelUnpauseFeedbackTimers();
      _hasStartedPlayback = false;
      _previouslyPlaying = false;
      _pausedAt = null;
      _showUnpauseFeedback = false;
      _unpauseFeedbackOpacity = 1.0;
      _subscribeToPlayback();
    }
  }

  void _subscribeToPlayback() {
    // Only latch when the overlay is visible (active video). During preload
    // the player is played muted for buffering then paused — that play must
    // not set the latch, otherwise the pause indicator flashes briefly when
    // the user arrives at the preloaded video (isBuffering=false before
    // isPlaying=true, amplified by the 180ms AnimatedSwitcher).
    final initialPlaying = widget.player.state.playing;
    _previouslyPlaying = initialPlaying;
    _hasStartedPlayback = widget.isVisible && initialPlaying;

    _playingSubscription = widget.player.stream.playing.listen((isPlaying) {
      if (!mounted) return;
      final wasPlaying = _previouslyPlaying;
      _previouslyPlaying = isPlaying;

      // Latch first playback of this player for this video.
      if (isPlaying && !_hasStartedPlayback && widget.isVisible) {
        setState(() {
          _hasStartedPlayback = true;
        });
        return;
      }

      if (!isPlaying && wasPlaying) {
        _pausedAt = DateTime.now();
      } else if (isPlaying &&
          !wasPlaying &&
          _hasStartedPlayback &&
          widget.isVisible) {
        final pauseDuration = _pausedAt != null
            ? DateTime.now().difference(_pausedAt!)
            : Duration.zero;
        _pausedAt = null;
        if (pauseDuration >= _minPauseForFeedback) {
          _triggerUnpauseFeedback();
        }
      }
    });
  }

  void _triggerUnpauseFeedback() {
    _cancelUnpauseFeedbackTimers();
    setState(() {
      _showUnpauseFeedback = true;
      _unpauseFeedbackOpacity = 1.0;
    });

    _unpauseFadeTimer = Timer(_unpauseFadeStartDelay, () {
      if (!mounted) return;
      setState(() {
        _unpauseFeedbackOpacity = 0.0;
      });
    });

    _unpauseHideTimer = Timer(_unpauseHideDelay, () {
      if (!mounted) return;
      setState(() {
        _showUnpauseFeedback = false;
        _unpauseFeedbackOpacity = 1.0;
      });
    });
  }

  void _cancelUnpauseFeedbackTimers() {
    _unpauseFadeTimer?.cancel();
    _unpauseHideTimer?.cancel();
    _unpauseFadeTimer = null;
    _unpauseHideTimer = null;
  }

  @override
  void dispose() {
    unawaited(_playingSubscription?.cancel());
    _cancelUnpauseFeedbackTimers();
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
          stream: widget.player.stream.buffering,
          initialData: widget.player.state.buffering,
          builder: (context, bufferingSnapshot) {
            final isBuffering = bufferingSnapshot.data ?? false;

            return StreamBuilder<bool>(
              stream: widget.player.stream.playing,
              initialData: widget.player.state.playing,
              builder: (context, playingSnapshot) {
                final isPlaying = playingSnapshot.data ?? false;
                final shouldShowPlay =
                    _hasStartedPlayback && !isPlaying && !isBuffering;
                final shouldShowUnpauseFeedback =
                    _showUnpauseFeedback && isPlaying && !shouldShowPlay;

                final Widget child;
                if (shouldShowPlay) {
                  child = const CenterPlaybackControl(
                    key: ValueKey('paused-play'),
                    state: CenterPlaybackControlState.play,
                    semanticsLabel: 'Play video',
                  );
                } else if (shouldShowUnpauseFeedback) {
                  child = AnimatedOpacity(
                    key: const ValueKey('unpause-feedback'),
                    opacity: _unpauseFeedbackOpacity,
                    duration: _unpauseFadeDuration,
                    child: const CenterPlaybackControl(
                      state: CenterPlaybackControlState.pause,
                    ),
                  );
                } else {
                  child = const SizedBox.shrink(key: ValueKey('paused-hidden'));
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
                          scale: Tween<double>(
                            begin: 0.92,
                            end: 1,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: child,
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
