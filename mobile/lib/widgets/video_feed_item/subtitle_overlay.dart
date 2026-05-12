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

/// Overlay that displays subtitle text synced to video playback position.
///
/// Retains the last visible cue during inter-cue gaps to avoid flickering.
/// The retained cue is cleared when [positionMs] resets to 0.
///
/// Prefer [SubtitleCuePill] for new placements that control their own layout.
class SubtitleOverlay extends ConsumerStatefulWidget {
  const SubtitleOverlay({
    required this.video,
    required this.positionMs,
    required this.visible,
    this.enablePositioned = true,
    this.bottomOffset = 80,
    super.key,
  });

  final VideoEvent video;
  final int positionMs;
  final bool visible;
  final bool enablePositioned;

  /// Distance from the bottom of the parent Stack.
  final double bottomOffset;

  @override
  ConsumerState<SubtitleOverlay> createState() => _SubtitleOverlayState();
}

class _SubtitleOverlayState extends ConsumerState<SubtitleOverlay> {
  SubtitleCue? _lastCue;
  int _prevPositionMs = 0;
  static const _gapBridgeMs = 300;

  @override
  Widget build(BuildContext context) {
    if (!widget.visible || !widget.video.hasSubtitles) {
      return const SizedBox.shrink();
    }

    final cuesAsync = ref.watch(
      subtitleCuesProvider(
        videoId: widget.video.id,
        textTrackRef: widget.video.textTrackRef,
        textTrackContent: widget.video.textTrackContent,
        sha256: widget.video.sha256,
      ),
    );

    return cuesAsync.when(
      data: (cues) {
        final currentCue = _findCurrentCue(cues, widget.positionMs);

        final didSeekBackward = widget.positionMs < _prevPositionMs;
        _prevPositionMs = widget.positionMs;

        if (currentCue != null) {
          _lastCue = currentCue;
        } else if (_lastCue != null &&
            (didSeekBackward ||
                widget.positionMs > _lastCue!.end + _gapBridgeMs)) {
          _lastCue = null;
        }

        final displayCue = _lastCue;
        if (displayCue == null) return const SizedBox.shrink();

        // Match the inline caption pill style introduced in PR #4087 so
        // captions render identically across every surface (home feed
        // overlay, fullscreen feed, and legacy callers that use this
        // gap-bridging widget).
        final content = Center(child: _CaptionPill(text: displayCue.text));
        if (!widget.enablePositioned) return content;

        return Positioned(
          bottom: widget.bottomOffset,
          left: 16,
          right: 80,
          child: content,
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
