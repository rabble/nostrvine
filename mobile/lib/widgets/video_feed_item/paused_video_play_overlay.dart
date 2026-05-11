import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:openvine/widgets/video_feed_item/center_playback_control.dart';
import 'package:openvine/widgets/video_feed_item/paused_affordance.dart';

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
      _previouslyPlaying = false;
      _pausedAt = null;
      _showUnpauseFeedback = false;
      _unpauseFeedbackOpacity = 1.0;
      _subscribeToPlayback();
    }
  }

  void _subscribeToPlayback() {
    _previouslyPlaying = widget.player.state.playing;
    _playingSubscription = widget.player.stream.playing.listen((isPlaying) {
      if (!mounted) return;
      final wasPlaying = _previouslyPlaying;
      _previouslyPlaying = isPlaying;

      if (!isPlaying && wasPlaying) {
        _pausedAt = clock.now();
      } else if (isPlaying && !wasPlaying && widget.isVisible) {
        final pauseDuration = _pausedAt != null
            ? clock.now().difference(_pausedAt!)
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
                return _PlaybackChrome(
                  isPlaying: isPlaying,
                  isBuffering: isBuffering,
                  showUnpauseFeedback: _showUnpauseFeedback,
                  unpauseFeedbackOpacity: _unpauseFeedbackOpacity,
                  unpauseFadeDuration: _unpauseFadeDuration,
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Renders the active child of the paused-video overlay (play affordance,
/// transient unpause pause icon, or nothing) with the shared fade-and-scale
/// [AnimatedSwitcher] transition.
///
/// Pure/stateless: all decisions derive from the props passed in by
/// [PausedVideoPlayOverlay], so this widget can be tested in isolation
/// without spinning up a [Player].
class _PlaybackChrome extends StatelessWidget {
  const _PlaybackChrome({
    required this.isPlaying,
    required this.isBuffering,
    required this.showUnpauseFeedback,
    required this.unpauseFeedbackOpacity,
    required this.unpauseFadeDuration,
  });

  final bool isPlaying;
  final bool isBuffering;
  final bool showUnpauseFeedback;
  final double unpauseFeedbackOpacity;
  final Duration unpauseFadeDuration;

  @override
  Widget build(BuildContext context) {
    final shouldShowPlay = !isPlaying && !isBuffering;
    final shouldShowUnpauseFeedback =
        showUnpauseFeedback && isPlaying && !shouldShowPlay;

    final Widget child;
    if (shouldShowPlay) {
      child = const PausedAffordance(key: ValueKey('paused-play'));
    } else if (shouldShowUnpauseFeedback) {
      // No ValueKey: AnimatedSwitcher already differentiates this
      // IgnorePointer from the Center-rooted play affordance and the
      // SizedBox.shrink hidden branch by runtime type.
      child = IgnorePointer(
        child: AnimatedOpacity(
          opacity: unpauseFeedbackOpacity,
          duration: unpauseFadeDuration,
          child: const CenterPlaybackControl(
            state: CenterPlaybackControlState.pause,
          ),
        ),
      );
    } else {
      child = const SizedBox.shrink();
    }

    return AnimatedSwitcher(
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
      child: child,
    );
  }
}
