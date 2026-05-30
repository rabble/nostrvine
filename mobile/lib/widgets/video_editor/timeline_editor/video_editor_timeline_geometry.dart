// ABOUTME: Pure geometry helpers for the video editor timeline.
// ABOUTME: Converts between playback positions and scroll offsets,
// ABOUTME: accounting for the 1-px gap between adjacent clip strips.

import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';

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
