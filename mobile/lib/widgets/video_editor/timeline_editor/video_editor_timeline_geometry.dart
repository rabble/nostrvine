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
