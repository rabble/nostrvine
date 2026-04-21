import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:media_kit/media_kit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_feed_item/center_playback_control.dart';

/// Large centered play affordance shown when a pooled video is paused.
class PausedVideoPlayOverlay extends StatefulWidget {
  const PausedVideoPlayOverlay({
    required this.player,
    required this.onToggleMuteState,
    this.firstFrameFuture,
    this.isVisible = true,
    super.key,
  });

  final Player player;
  final Future<void>? firstFrameFuture;
  final bool isVisible;
  final VoidCallback onToggleMuteState;

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
    if (!identical(oldWidget.player, widget.player)) {
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
    _hasStartedPlayback = widget.isVisible && widget.player.state.playing;
    _playingSubscription = widget.player.stream.playing.listen((isPlaying) {
      if (isPlaying && !_hasStartedPlayback && widget.isVisible && mounted) {
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
          stream: widget.player.stream.buffering,
          initialData: widget.player.state.buffering,
          builder: (context, bufferingSnapshot) {
            final isBuffering = bufferingSnapshot.data ?? false;

            return StreamBuilder<double>(
              stream: widget.player.stream.volume,
              initialData: widget.player.state.volume,
              builder: (context, volumeSnapshot) {
                // Icon state is driven by the player's volume stream
                // (not VideoVolumeCubit) deliberately: the player is the
                // source of truth for what the user is hearing right now.
                // Using context.select on the cubit would lag by a few
                // frames while setVolume propagates to the player.
                final isMuted = volumeSnapshot.data == 0;

                return StreamBuilder<bool>(
                  stream: widget.player.stream.playing,
                  initialData: widget.player.state.playing,
                  builder: (context, playingSnapshot) {
                    final isPlaying = playingSnapshot.data ?? false;
                    final shouldShow =
                        _hasStartedPlayback && !isPlaying && !isBuffering;

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
                                          ? .speakerSimpleX
                                          : .speakerHigh,
                                      size: .small,
                                      type: .ghost,
                                      semanticLabel: isMuted
                                          ? context.l10n.videoPlayerUnmute
                                          : context.l10n.videoPlayerMute,
                                      onPressed: () {
                                        widget.onToggleMuteState();
                                        SemanticsService.sendAnnouncement(
                                          View.of(context),
                                          isMuted
                                              ? context.l10n.videoPlayerUnmute
                                              : context.l10n.videoPlayerMute,
                                          Directionality.of(context),
                                        );
                                      },
                                    ),
                                  IgnorePointer(
                                    child: CenterPlaybackControl(
                                      key: const ValueKey('paused-play'),
                                      state: CenterPlaybackControlState.play,
                                      semanticsLabel:
                                          context.l10n.videoPlayerPlayVideo,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(
                              key: ValueKey('paused-hidden'),
                            ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
