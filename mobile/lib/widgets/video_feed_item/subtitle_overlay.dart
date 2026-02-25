// ABOUTME: Overlay widget displaying subtitle text on video playback.
// ABOUTME: Uses subtitleCuesProvider for dual-fetch (REST embedded or relay).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/subtitle_providers.dart';
import 'package:openvine/services/subtitle_service.dart';

/// Overlay that displays subtitle text synced to video playback position.
class SubtitleOverlay extends ConsumerWidget {
  const SubtitleOverlay({
    required this.video,
    required this.positionMs,
    required this.visible,
    this.bottomOffset = 80,
    super.key,
  });

  final VideoEvent video;
  final int positionMs;
  final bool visible;

  /// Distance from the bottom of the parent Stack.
  final double bottomOffset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!visible || !video.hasSubtitles) {
      return const SizedBox.shrink();
    }

    final cuesAsync = ref.watch(
      subtitleCuesProvider(
        videoId: video.id,
        textTrackRef: video.textTrackRef,
        textTrackContent: video.textTrackContent,
        sha256: video.sha256,
      ),
    );

    return cuesAsync.when(
      data: (cues) {
        final currentCue = _findCurrentCue(cues, positionMs);
        if (currentCue == null) return const SizedBox.shrink();

        return Positioned(
          bottom: bottomOffset,
          left: 16,
          right: 80,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                currentCue.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
      loading: SizedBox.shrink,
      error: (error, stack) => const SizedBox.shrink(),
    );
  }

  SubtitleCue? _findCurrentCue(List<SubtitleCue> cues, int positionMs) {
    for (final cue in cues) {
      if (positionMs >= cue.start && positionMs <= cue.end) {
        return cue;
      }
    }
    return null;
  }
}
