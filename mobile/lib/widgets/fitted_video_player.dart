import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/material.dart';

/// Sizes a [DivineVideoPlayer] to its video dimensions inside a [FittedBox].
///
/// Prefers stable metadata dimensions (from the Nostr event) over the
/// native player state, which temporarily resets to 0 during source
/// switches and would cause visible layout jumps.
///
/// When no metadata is available, falls back to a [StreamBuilder] that
/// filters out zero-dimension events from the native player.
class FittedVideoPlayer extends StatelessWidget {
  const FittedVideoPlayer({
    required this.controller,
    this.isPortrait = true,
    this.metadataWidth,
    this.metadataHeight,
    super.key,
  });

  final DivineVideoPlayerController controller;
  final bool isPortrait;

  /// Known width from the Nostr event metadata (pixels).
  final int? metadataWidth;

  /// Known height from the Nostr event metadata (pixels).
  final int? metadataHeight;

  @override
  Widget build(BuildContext context) {
    final boxFit = isPortrait ? BoxFit.cover : BoxFit.contain;

    final mw = metadataWidth ?? 0;
    final mh = metadataHeight ?? 0;

    if (mw > 0 && mh > 0) {
      return SizedBox.expand(
        child: FittedBox(
          fit: boxFit,
          child: SizedBox(
            width: mw.toDouble(),
            height: mh.toDouble(),
            child: DivineVideoPlayer(controller: controller),
          ),
        ),
      );
    }

    // No metadata dimensions — wait for the native player to report them,
    // ignoring transient 0×0 resets from source switches.
    return StreamBuilder<({int w, int h})>(
      stream: controller.stateStream
          .map((s) => (w: s.videoWidth, h: s.videoHeight))
          .where((d) => d.w > 0 && d.h > 0)
          .distinct(),
      builder: (context, snapshot) {
        final dims = snapshot.data;

        if (dims == null) {
          return SizedBox.expand(
            child: DivineVideoPlayer(controller: controller),
          );
        }

        return SizedBox.expand(
          child: FittedBox(
            fit: boxFit,
            child: SizedBox(
              width: dims.w.toDouble(),
              height: dims.h.toDouble(),
              child: DivineVideoPlayer(controller: controller),
            ),
          ),
        );
      },
    );
  }
}
