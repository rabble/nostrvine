import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

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
    _hasStartedPlayback = widget.player.state.playing;
    _playingSubscription = widget.player.stream.playing.listen((isPlaying) {
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
                        ? const _PausedPlayAffordance(
                            key: ValueKey('paused-play'),
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

class _PausedPlayAffordance extends StatelessWidget {
  const _PausedPlayAffordance({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 112,
        height: 112,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: VineTheme.surfaceContainer55,
          border: Border.all(
            color: VineTheme.borderWhite25,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: VineTheme.backgroundColor.withValues(alpha: 0.24),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Semantics(
          identifier: 'play_button',
          container: true,
          explicitChildNodes: true,
          label: 'Play video',
          child: const Center(
            child: Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(
                Icons.play_arrow_rounded,
                size: 72,
                color: VineTheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
