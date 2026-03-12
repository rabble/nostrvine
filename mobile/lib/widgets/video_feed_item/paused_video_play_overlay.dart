import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:openvine/widgets/video_feed_item/center_playback_control.dart';

/// Large centered play affordance shown when a pooled video is paused.
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
  static final Expando<bool> _playerPlaybackSeen = Expando<bool>(
    'playerPlaybackSeen',
  );

  StreamSubscription<bool>? _playingSubscription;
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
      _subscribeToPlayback();
    }
  }

  void _subscribeToPlayback() {
    final playerIsPlaying = widget.player.state.playing;
    _hasStartedPlayback =
        playerIsPlaying || (_playerPlaybackSeen[widget.player] ?? false);
    if (playerIsPlaying) {
      _playerPlaybackSeen[widget.player] = true;
    }
    _playingSubscription = widget.player.stream.playing.listen((isPlaying) {
      if (isPlaying) {
        _playerPlaybackSeen[widget.player] = true;
      }
      if (isPlaying && !_hasStartedPlayback && mounted) {
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

            return StreamBuilder<bool>(
              stream: widget.player.stream.playing,
              initialData: widget.player.state.playing,
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
