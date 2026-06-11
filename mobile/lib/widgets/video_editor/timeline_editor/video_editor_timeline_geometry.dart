// ABOUTME: Pure geometry helpers for the video editor timeline.
// ABOUTME: Converts between playback positions and scroll offsets,
// ABOUTME: accounting for the 1-px gap between adjacent clip strips.

import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';

/// Converts a [sourcePosition] inside one untrimmed clip to the matching
/// composite playback position on the full timeline.
///
/// Clip trim previews seek the native player in source time because the
/// preview player is temporarily switched to a single untrimmed clip.
/// Visual overlays, however, are keyed by composite timeline time. This helper
/// bridges those coordinate spaces while respecting clip trims and speed.
Duration? clipSourcePositionToTimelinePosition(
  List<DivineVideoClip> clips, {
  required String clipId,
  required Duration sourcePosition,
}) {
  var precedingDuration = Duration.zero;
  for (final clip in clips) {
    if (clip.id == clipId) {
      final relative = sourcePosition - clip.trimStart;
      if (relative < Duration.zero || relative > clip.trimmedDuration) {
        return null;
      }

      final speed = clip.playbackSpeed ?? 1.0;
      final relativePlayback = speed <= 0 || speed == 1.0
          ? relative
          : Duration(microseconds: (relative.inMicroseconds / speed).round());
      return precedingDuration + relativePlayback;
    }

    precedingDuration += clip.playbackDuration;
  }

  return null;
}

/// Returns the source offset and anchor state for an audio track after its
/// timeline start handle moves to [newStartTime].
///
/// Left-trimming a sound should consume or reveal audio source content rather
/// than sliding the same source frame to a new timeline position. Keeping this
/// offset in step with the timeline start also preserves the anchored-audio
/// alignment invariant used by [rebaseAnchoredAudioForClipState].
AudioLeftTrimResult audioLeftTrimResult(
  AudioEvent track, {
  required Duration newStartTime,
}) {
  final nextOffset = track.startOffset + (newStartTime - track.startTime);
  if (nextOffset < Duration.zero) {
    return const AudioLeftTrimResult(
      startOffset: Duration.zero,
      anchorStillValid: false,
    );
  }

  final duration = track.duration;
  if (duration == null) {
    return AudioLeftTrimResult(startOffset: nextOffset);
  }

  final maxOffset = Duration(milliseconds: (duration * 1000).round());
  if (nextOffset > maxOffset) {
    return AudioLeftTrimResult(startOffset: maxOffset, anchorStillValid: false);
  }
  return AudioLeftTrimResult(startOffset: nextOffset);
}

/// Result of applying a left trim to an audio track's source offset.
class AudioLeftTrimResult {
  const AudioLeftTrimResult({
    required this.startOffset,
    this.anchorStillValid = true,
  });

  /// Source offset to apply to the track.
  final Duration startOffset;

  /// Whether the requested timeline start can still be represented by the
  /// anchored-audio alignment invariant.
  final bool anchorStillValid;
}

/// Reprojects marker positions after clip order, trim, or speed changes.
///
/// Timeline markers are stored as absolute composition times because the
/// ruler, snapping, and painter all operate in timeline coordinates. The user
/// experience is clip-source based, though: a marker placed on source second 5
/// of clip B should follow clip B when reordered, and disappear if source
/// second 5 is trimmed out. This converts:
///
///   old absolute time -> old clip id + source position -> new absolute time
List<Duration> rebaseTimelineMarkersForClipState({
  required List<DivineVideoClip> oldClips,
  required List<DivineVideoClip> newClips,
  required List<Duration> markers,
}) {
  if (markers.isEmpty || oldClips.isEmpty || newClips.isEmpty) {
    return const [];
  }

  final newClipStarts = <String, Duration>{};
  final newClipsById = <String, DivineVideoClip>{};
  var newCursor = Duration.zero;
  for (final clip in newClips) {
    newClipStarts[clip.id] = newCursor;
    newClipsById[clip.id] = clip;
    newCursor += clip.playbackDuration;
  }

  final rebased = <Duration>{};
  for (final marker in markers) {
    final anchor = _timelineMarkerAnchorForPosition(oldClips, marker);
    if (anchor == null) continue;

    final newStart = newClipStarts[anchor.clipId];
    final newClip = newClipsById[anchor.clipId];
    if (newStart == null || newClip == null) continue;

    final playbackOffset = _sourcePositionToPlaybackOffset(
      newClip,
      anchor.sourcePosition,
    );
    if (playbackOffset == null) continue;

    rebased.add(newStart + playbackOffset);
  }

  return rebased.toList()..sort();
}

/// Re-aligns anchored (extracted, not-yet-moved) audio tracks to their
/// source clips after a clip edit (trim, reorder, or ripple from an earlier
/// clip's trim).
///
/// For each [AudioEvent] whose [AudioEvent.anchorClipId] still resolves to a
/// clip in [clips], the audio is translated on the timeline so its source
/// content stays aligned with the clip's source content. This implements the
/// J-Cut behaviour: the audio keeps its [AudioEvent.startOffset] and its span
/// (so its full content survives — the head simply leads), while only its
/// [AudioEvent.startTime]/[AudioEvent.endTime] move. If that lead would start
/// before timeline zero, the impossible pre-roll is clipped by advancing
/// [AudioEvent.startOffset] and shortening the audible span.
///
/// The alignment invariant preserved is, for the anchored clip:
///
///   startTime == clipTimelineStart - clip.trimStart + audio.startOffset
///
/// [clipTimelineStart] is accumulated in playback time so earlier clip speed
/// changes still ripple anchored audio correctly. [AudioEvent.startOffset] and
/// [DivineVideoClip.trimStart] remain source-time values because extracted
/// audio is not tempo-adjusted; if extracted audio becomes speed-adjusted, this
/// conversion must be revisited.
///
/// Tracks with no anchor, or whose anchor clip was removed or split into new
/// clip IDs, are returned unchanged. The original list instance is returned
/// when nothing moved, so callers can cheaply detect a no-op via `identical`.
List<AudioEvent> rebaseAnchoredAudioForClipState(
  List<DivineVideoClip> clips,
  List<AudioEvent> audioTracks,
) {
  if (audioTracks.isEmpty) return audioTracks;

  final clipStarts = <String, Duration>{};
  final clipsById = <String, DivineVideoClip>{};
  var cursor = Duration.zero;
  for (final clip in clips) {
    clipStarts[clip.id] = cursor;
    clipsById[clip.id] = clip;
    cursor += clip.playbackDuration;
  }

  var changed = false;
  final result = <AudioEvent>[];
  for (final track in audioTracks) {
    final anchorId = track.anchorClipId;
    final clipStart = anchorId == null ? null : clipStarts[anchorId];
    final clip = anchorId == null ? null : clipsById[anchorId];
    if (clipStart == null || clip == null) {
      result.add(track);
      continue;
    }

    final span = (track.endTime ?? track.startTime) - track.startTime;
    final newStartRaw = clipStart + track.startOffset - clip.trimStart;
    var newStart = newStartRaw;
    var newStartOffset = track.startOffset;
    var newSpan = span;

    if (newStartRaw < Duration.zero) {
      final clippedLead = Duration.zero - newStartRaw;
      newStart = Duration.zero;
      newStartOffset += clippedLead;
      newSpan -= clippedLead;
      if (newSpan < Duration.zero) {
        newSpan = Duration.zero;
      }
    }

    final newEnd = track.endTime == null ? null : newStart + newSpan;

    if (newStart == track.startTime &&
        newEnd == track.endTime &&
        newStartOffset == track.startOffset) {
      result.add(track);
      continue;
    }
    changed = true;
    result.add(
      track.copyWith(
        startOffset: newStartOffset,
        startTime: newStart,
        endTime: newEnd,
      ),
    );
  }

  return changed ? result : audioTracks;
}

_TimelineMarkerAnchor? _timelineMarkerAnchorForPosition(
  List<DivineVideoClip> clips,
  Duration marker,
) {
  var cursor = Duration.zero;
  for (var i = 0; i < clips.length; i++) {
    final clip = clips[i];
    final duration = clip.playbackDuration;
    final end = cursor + duration;
    final isLast = i == clips.length - 1;

    if (marker < end || isLast) {
      return _TimelineMarkerAnchor(
        clip.id,
        _playbackOffsetToSourcePosition(
          clip,
          _clampDuration(marker - cursor, duration),
        ),
      );
    }

    cursor = end;
  }

  return null;
}

Duration _playbackOffsetToSourcePosition(
  DivineVideoClip clip,
  Duration playbackOffset,
) {
  final speed = clip.playbackSpeed ?? 1.0;
  final sourceOffset = speed <= 0 || speed == 1.0
      ? playbackOffset
      : Duration(microseconds: (playbackOffset.inMicroseconds * speed).round());

  return clip.trimStart + _clampDuration(sourceOffset, clip.trimmedDuration);
}

Duration? _sourcePositionToPlaybackOffset(
  DivineVideoClip clip,
  Duration sourcePosition,
) {
  final visibleStart = clip.trimStart;
  final visibleEnd = clip.duration - clip.trimEnd;
  if (sourcePosition < visibleStart || sourcePosition > visibleEnd) {
    return null;
  }

  final sourceOffset = sourcePosition - visibleStart;
  final speed = clip.playbackSpeed ?? 1.0;
  if (speed <= 0 || speed == 1.0) return sourceOffset;

  return Duration(microseconds: (sourceOffset.inMicroseconds / speed).round());
}

Duration _clampDuration(Duration value, Duration max) {
  if (value < Duration.zero) return Duration.zero;
  if (value > max) return max;
  return value;
}

class _TimelineMarkerAnchor {
  const _TimelineMarkerAnchor(this.clipId, this.sourcePosition);

  final String clipId;
  final Duration sourcePosition;
}

/// Converts a composite playback [position] to the corresponding scroll
/// offset in the timeline content, accounting for the
/// [TimelineConstants.clipGap]-wide gap between adjacent clip strips.
///
/// Without this correction the scroll target is up to
/// `(clipsPassedCount × clipGap)` pixels short of the trim-handle
/// marker's actual visual position.
double timelinePositionToScrollOffset(
  List<DivineVideoClip> clips,
  Duration position,
  double pixelsPerSecond,
) {
  var acc = Duration.zero;
  var gapPixels = 0.0;
  for (var i = 0; i < clips.length; i++) {
    final clip = clips[i];
    if (acc + clip.playbackDuration > position) break;
    acc += clip.playbackDuration;
    if (i < clips.length - 1) {
      gapPixels += TimelineConstants.clipGap;
    }
  }
  return position.inMicroseconds / 1_000_000.0 * pixelsPerSecond + gapPixels;
}

/// Converts a timeline [scrollOffset] to the corresponding playback
/// position — the exact inverse of [timelinePositionToScrollOffset].
///
/// The result is clamped to `[Duration.zero, totalDuration]`.
Duration timelineScrollOffsetToPosition(
  List<DivineVideoClip> clips,
  double scrollOffset,
  double pixelsPerSecond,
  Duration totalDuration,
) {
  var acc = Duration.zero;
  var gapPixels = 0.0;
  for (var i = 0; i < clips.length; i++) {
    final clip = clips[i];
    final clipEndPx =
        (acc + clip.playbackDuration).inMicroseconds /
            1_000_000.0 *
            pixelsPerSecond +
        gapPixels;
    if (scrollOffset <= clipEndPx) break;
    final gapEndPx = clipEndPx + TimelineConstants.clipGap;
    if (i < clips.length - 1 && scrollOffset < gapEndPx) {
      return acc + clip.playbackDuration;
    }
    acc += clip.playbackDuration;
    if (i < clips.length - 1) {
      gapPixels += TimelineConstants.clipGap;
    }
  }
  final seconds = (scrollOffset - gapPixels) / pixelsPerSecond;
  final ms = (seconds * 1000).round().clamp(0, totalDuration.inMilliseconds);
  return Duration(milliseconds: ms);
}

/// Converts an overlay-item edge at [positionMs] to its pixel offset in
/// the overlay layer, accounting for the [TimelineConstants.clipGap]
/// between adjacent clips.
///
/// Overlay strips share the clip strip's coordinate space, so an edge
/// must include the cumulative gap pixels of every clip boundary at or
/// before [positionMs]. Without this correction an overlay drifts left
/// of the matching clip end by `(clipsPassed × clipGap)` px — a drift
/// that grows with the number of clips, so layers can never be snapped
/// exactly to a clip end on a busy timeline.
///
/// [clipEdgesMs] is the cumulative clip-boundary list `[0, e1, …, eN]`
/// (gap-free milliseconds), matching `_computeEdges` in the timeline
/// body. This is the edge-based counterpart of
/// [timelinePositionToScrollOffset] and shares its boundary convention:
/// a position exactly on a clip boundary maps to the start of the next
/// clip (the gap is included).
double timelineMsToOverlayOffset(
  List<int> clipEdgesMs,
  int positionMs,
  double pixelsPerSecond,
) {
  var gapPixels = 0.0;
  // clipEdgesMs[i] is the end of clip (i-1). A gap follows every clip
  // except the last, i.e. internal boundaries e1…e(N-1).
  for (var i = 1; i < clipEdgesMs.length - 1; i++) {
    if (clipEdgesMs[i] > positionMs) break;
    gapPixels += TimelineConstants.clipGap;
  }
  return positionMs / 1000.0 * pixelsPerSecond + gapPixels;
}

/// Converts an overlay-layer pixel [offset] back to milliseconds — the
/// exact inverse of [timelineMsToOverlayOffset].
///
/// Offsets that fall inside a clip gap clamp to the preceding clip
/// boundary. The result is clamped to `[0, totalDurationMs]`.
int timelineOverlayOffsetToMs(
  List<int> clipEdgesMs,
  double offset,
  double pixelsPerSecond,
  int totalDurationMs,
) {
  var gapPixels = 0.0;
  for (var i = 1; i < clipEdgesMs.length; i++) {
    final clipEndPx = clipEdgesMs[i] / 1000.0 * pixelsPerSecond + gapPixels;
    if (offset <= clipEndPx) break;
    final isInternal = i < clipEdgesMs.length - 1;
    if (isInternal && offset < clipEndPx + TimelineConstants.clipGap) {
      return clipEdgesMs[i];
    }
    if (isInternal) gapPixels += TimelineConstants.clipGap;
  }
  final ms = ((offset - gapPixels) / pixelsPerSecond * 1000).round();
  return ms.clamp(0, totalDurationMs);
}
