// ABOUTME: Overlay widget displaying subtitle text on video playback.
// ABOUTME: Uses subtitleCuesProvider for dual-fetch (REST embedded or relay).

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/subtitle_providers.dart';
import 'package:openvine/services/subtitle_service.dart';

/// Overlay that displays subtitle text synced to video playback position.
///
/// Retains the last visible cue during inter-cue gaps to avoid flickering.
/// The retained cue is cleared when [positionMs] resets to 0.
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

        final content = Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: VineTheme.scrim50,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              displayCue.text,
              style: const TextStyle(
                color: VineTheme.whiteText,
                fontSize: 16,
                shadows: [Shadow(blurRadius: 4)],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
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
