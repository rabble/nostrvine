// ABOUTME: Pure geometry for clip transitions — how much of each adjacent clip
// ABOUTME: a transition consumes. Shared by the render clamp, seam preview and
// ABOUTME: the picker so all three agree on the no-overlap budget.

import 'package:pro_video_editor/pro_video_editor.dart'
    show ClipTransition, ClipTransitionType;

bool _isDip(ClipTransitionType type) =>
    type == ClipTransitionType.fadeToBlack ||
    type == ClipTransitionType.fadeToWhite;

/// Per-side playback duration a [transition] consumes at the boundary between
/// clips of playback durations [a] and [b].
///
/// An overlap (dissolve/slide/push/wipe) blends both clips at once and consumes
/// 2× its duration per side; a dip (fadeToBlack/White) fades out then in,
/// consuming half its duration per side. Clamped to the shorter clip so a
/// transition can never overrun a clip.
Duration transitionConsumedPerSide(
  Duration a,
  Duration b,
  ClipTransition transition,
) {
  final shorter = a < b ? a : b;
  final requested = _isDip(transition.type)
      ? Duration(microseconds: transition.duration.inMicroseconds ~/ 2)
      : transition.duration * 2;
  return requested < shorter ? requested : shorter;
}

/// Inverse of [transitionConsumedPerSide]: the longest transition duration of
/// [type] whose per-side consumption fits in [consumed]. Returns
/// [Duration.zero] when there is no room.
Duration transitionDurationForConsumed(
  Duration consumed,
  ClipTransitionType type,
) {
  if (consumed <= Duration.zero) return Duration.zero;
  return _isDip(type)
      ? consumed * 2
      : Duration(microseconds: consumed.inMicroseconds ~/ 2);
}
