// ABOUTME: Overlay widget displaying subtitle text on video playback.
// ABOUTME: Uses subtitleCuesProvider for dual-fetch (REST embedded or relay).

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/subtitle_providers.dart';
import 'package:openvine/services/subtitle_service.dart';

/// Inline caption pill for the home feed overlay.
///
/// Renders the Figma-specified caption block (scrim-65 background, 12px
/// border-radius, Chivo Mono Light, 16 px / 24 px leading) or
/// [SizedBox.shrink] when there is no active cue for [positionMs].
///
/// Caller is responsible for showing/hiding based on user preference and
/// for positioning within the layout.
class SubtitleCuePill extends ConsumerWidget {
  const SubtitleCuePill({
    required this.video,
    required this.positionMs,
    super.key,
  });

  final VideoEvent video;
  final int positionMs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!video.hasSubtitles) return const SizedBox.shrink();

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
        return _CaptionPill(text: currentCue.text);
      },
      loading: SizedBox.shrink,
      error: (_, _) => const SizedBox.shrink(),
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

class _CaptionPill extends StatelessWidget {
  const _CaptionPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: VineTheme.scrim65,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: VineTheme.captionPillFont().copyWith(
          shadows: const [Shadow(blurRadius: 4, color: VineTheme.shadow25)],
        ),
      ),
    );
  }
}

/// Legacy positioned overlay used by [video_feed_item.dart] and
/// [video_player_subtitle_layer.dart].
///
/// Prefer [SubtitleCuePill] for new placements that control their own layout.
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
                color: VineTheme.scrim50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                currentCue.text,
                style: const TextStyle(
                  color: VineTheme.whiteText,
                  fontSize: 16,
                  shadows: [Shadow(blurRadius: 4)],
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
