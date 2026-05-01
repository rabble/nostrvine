import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_feed_item/center_playback_control.dart';

class PausedVideoOverlay extends StatefulWidget {
  const PausedVideoOverlay({
    required this.controller,
    this.isVisible = true,
    this.onVolumeToggle,
    super.key,
  });

  final DivineVideoPlayerController controller;
  final bool isVisible;

  /// Called when the user taps the mute/unmute button.
  /// Receives the new volume (0.0 or 1.0). Route this to
  /// [InfiniteVideoFeedState.setVolume] so the feed tracks the value.
  final void Function(double volume)? onVolumeToggle;

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
      return;
    }
    // Reset the latch on visibility transitions so the overlay doesn't
    // flash when swiping back to an already-loaded video that is briefly
    // paused before playback resumes.
    if (oldWidget.isVisible != widget.isVisible && _hasStartedPlaying) {
      setState(() => _hasStartedPlaying = false);
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
    return StreamBuilder<
      ({bool isFirstFrameRendered, bool isMuted, bool isPaused})
    >(
      stream: widget.controller.stateStream
          .map(
            (s) => (
              isPaused: s.isPaused,
              isFirstFrameRendered: s.isFirstFrameRendered,
              isMuted: s.volume == 0,
            ),
          )
          .distinct(),
      builder: (context, snapshot) {
        final isFirstFrameRendered =
            snapshot.data?.isFirstFrameRendered ?? false;
        final isPaused = snapshot.data?.isPaused ?? false;
        final isMuted = snapshot.data?.isMuted ?? false;

        final shouldShow =
            widget.isVisible &&
            _hasStartedPlaying &&
            isPaused &&
            isFirstFrameRendered;

        return AnimatedSwitcher(
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
              ? Center(
                  child: Column(
                    mainAxisSize: .min,
                    spacing: 16,
                    children: [
                      if (!kIsWeb)
                        DivineIconButton(
                          icon: isMuted
                              ? DivineIconName.speakerSimpleX
                              : DivineIconName.speakerHigh,
                          size: DivineIconButtonSize.small,
                          type: DivineIconButtonType.ghost,
                          semanticLabel: isMuted
                              ? context.l10n.videoPlayerUnmute
                              : context.l10n.videoPlayerMute,
                          onPressed: () {
                            final newVolume = isMuted ? 1.0 : 0.0;
                            if (widget.onVolumeToggle != null) {
                              widget.onVolumeToggle!(newVolume);
                            } else {
                              widget.controller.setVolume(newVolume);
                            }
                            SemanticsService.sendAnnouncement(
                              View.of(context),
                              isMuted
                                  ? context.l10n.videoPlayerUnmute
                                  : context.l10n.videoPlayerMute,
                              Directionality.of(context),
                            );
                          },
                        ),
                      const CenterPlaybackControl(
                        state: .play,
                        semanticsLabel: 'Play video',
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        );
      },
    );
  }
}
