// ABOUTME: Overlay widget displaying subtitle text on video playback.
// ABOUTME: Uses subtitleCuesProvider for dual-fetch (REST embedded or relay).

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/subtitle_providers.dart';
import 'package:openvine/services/subtitle_service.dart';

/// Streams playback position into the shared caption pill renderer.
class SubtitleCueStreamPill extends StatelessWidget {
  const SubtitleCueStreamPill({
    required this.video,
    required this.positionStream,
    this.initialPosition = Duration.zero,
    super.key,
  });

  final VideoEvent video;
  final Stream<Duration> positionStream;
  final Duration initialPosition;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: positionStream,
      initialData: initialPosition,
      builder: (context, snapshot) {
        return SubtitleCuePositionPill(
          video: video,
          positionMs: snapshot.data?.inMilliseconds ?? 0,
        );
      },
    );
  }
}

/// Layout-neutral caption pill that retains short inter-cue gaps.
class SubtitleCuePositionPill extends ConsumerStatefulWidget {
  const SubtitleCuePositionPill({
    required this.video,
    required this.positionMs,
    super.key,
  });

  final VideoEvent video;
  final int positionMs;

  @override
  ConsumerState<SubtitleCuePositionPill> createState() =>
      _SubtitleCuePositionPillState();
}

class _SubtitleCuePositionPillState
    extends ConsumerState<SubtitleCuePositionPill> {
  SubtitleCue? _lastCue;
  int _prevPositionMs = 0;
  static const _gapBridgeMs = 300;

  @override
  void didUpdateWidget(covariant SubtitleCuePositionPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.id != widget.video.id) {
      _lastCue = null;
      _prevPositionMs = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = ref.watch(subtitleVisibilityProvider);
    if (!visible || !widget.video.hasSubtitles) return const SizedBox.shrink();

    final cuesAsync = ref.watch(
      subtitleCuesProvider(
        videoId: widget.video.id,
        textTrackRef: widget.video.textTrackRef,
        textTrackRefs: widget.video.textTrackRefs,
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
        return _CaptionPill(text: displayCue.text);
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
