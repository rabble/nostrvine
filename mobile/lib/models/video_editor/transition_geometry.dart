// ABOUTME: Pure geometry for clip transitions — how much of each adjacent clip
// ABOUTME: a transition consumes, the no-overlap clamp, and the rendered output
// ABOUTME: timeline. Shared by the render pipeline, seam preview, picker and the
// ABOUTME: timeline header so all of them agree on the same budget.

import 'package:openvine/models/divine_video_clip.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show ClipTransition, ClipTransitionType;
import 'package:unified_logger/unified_logger.dart';

const _logName = 'TransitionGeometry';

bool _isDip(ClipTransitionType type) =>
    type == ClipTransitionType.fadeToBlack ||
    type == ClipTransitionType.fadeToWhite;

/// Whether a transition shortens the timeline. Overlaps
/// (dissolve/slide/push/wipe) blend both clips at once, so the blend duration
/// is removed from the total. Dips (fadeToBlack/White) fade out then in
/// without overlapping, so the duration is unchanged.
bool _shortensTimeline(ClipTransitionType type) => !_isDip(type);

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

/// Maps each clip id to its outgoing transition, clamped so that **no clip is
/// consumed by transitions on both sides at once**. A clip's head (consumed by
/// the incoming boundary) plus its tail (consumed by the outgoing boundary)
/// can never exceed its playback length — the native compositor cannot render
/// two fully-overlapping dips of different colors, so overlap is prevented
/// rather than blended.
///
/// When the requested transitions would over-consume a shared clip, both
/// boundaries touching it are scaled down proportionally to their demand, so
/// each keeps a fair share and the clip is split between them (e.g. two 2s
/// dips on a 1s middle clip each render as 1s, the first half fading one way
/// and the second half the other). A single transition on a clip is never
/// reduced.
///
/// Returns `null` for the last clip (no following boundary) and whenever there
/// is no room for a transition. Keyed by clip id rather than index so it stays
/// correct even if the render pipeline reorders clips.
Map<String, ClipTransition?> clampTransitions(List<DivineVideoClip> clips) {
  final n = clips.length;

  // Per-boundary requested per-side consumption. demand[i] is the boundary
  // between clip i and clip i+1 (clip i's outgoing transition).
  final demand = List<Duration>.filled(n, Duration.zero);
  for (var i = 0; i < n - 1; i++) {
    final transition = clips[i].transition;
    if (transition != null) {
      demand[i] = transitionConsumedPerSide(
        clips[i].playbackDuration,
        clips[i + 1].playbackDuration,
        transition,
      );
    }
  }

  // Per-clip scale so the head + tail consumption fits the clip's playback
  // length. A clip touched by only one transition (or none) keeps scale 1.
  final scale = List<double>.filled(n, 1);
  for (var i = 0; i < n; i++) {
    final head = i > 0 ? demand[i - 1] : Duration.zero;
    final tail = i < n - 1 ? demand[i] : Duration.zero;
    final total = head + tail;
    final playback = clips[i].playbackDuration;
    if (total > playback && total > Duration.zero) {
      scale[i] = playback.inMicroseconds / total.inMicroseconds;
    }
  }

  // Each boundary is bounded by the tighter scale of the two clips it touches,
  // so neither clip is over-consumed.
  final clamped = <String, ClipTransition?>{};
  for (var i = 0; i < n; i++) {
    final transition = clips[i].transition;
    if (i >= n - 1 || transition == null || demand[i] <= Duration.zero) {
      clamped[clips[i].id] = null;
      continue;
    }
    final s = scale[i] < scale[i + 1] ? scale[i] : scale[i + 1];
    final finalConsumed = Duration(
      microseconds: (demand[i].inMicroseconds * s).round(),
    );
    if (finalConsumed <= Duration.zero) {
      clamped[clips[i].id] = null;
      continue;
    }
    final clampedDuration = transitionDurationForConsumed(
      finalConsumed,
      transition.type,
    );
    if (clampedDuration < transition.duration) {
      Log.debug(
        '✂️ Clamping transition ${transition.duration.inMilliseconds}ms '
        'to ${clampedDuration.inMilliseconds}ms (avoids overlap on a '
        'shared clip)',
        name: _logName,
        category: .video,
      );
      clamped[clips[i].id] = transition.copyWith(duration: clampedDuration);
    } else {
      clamped[clips[i].id] = transition;
    }
  }
  return clamped;
}

/// One overlap blend on the editor axis: the region
/// `[editorStart, editorStart + 2×blend]` (clips at full length) compresses to
/// `blend` of output. Dips are excluded — they don't shorten the timeline.
class _Blend {
  const _Blend({required this.editorStart, required this.blend});

  final Duration editorStart;
  final Duration blend;
}

/// Precomputed piecewise-linear map between the editor timeline (clips at full
/// length) and the rendered output timeline. Build once with
/// [TransitionTimelineMap.fromClips], then map any number of positions in
/// either direction without re-running [clampTransitions] per call — the
/// timeline ruler maps every visible tick on each scroll frame.
///
/// Each overlap boundary blends both clips for its duration, so the
/// `2×duration`-wide editor region around the boundary compresses to
/// `duration` of output; positions outside any blend map 1:1. The no-overlap
/// clamp guarantees adjacent blend regions never touch, so the mapping is
/// strictly monotonic and invertible.
class TransitionTimelineMap {
  TransitionTimelineMap._(
    this._blends, {
    required this.editorDuration,
    required this.outputDuration,
  });

  factory TransitionTimelineMap.fromClips(List<DivineVideoClip> clips) {
    final clamped = clampTransitions(clips);
    var editorTotal = Duration.zero;
    for (final clip in clips) {
      editorTotal += clip.playbackDuration;
    }

    final blends = <_Blend>[];
    var boundary = Duration.zero;
    var removed = Duration.zero;
    for (var i = 0; i < clips.length - 1; i++) {
      boundary += clips[i].playbackDuration;
      final transition = clamped[clips[i].id];
      if (transition == null || !_shortensTimeline(transition.type)) continue;
      final blend = transition.duration;
      blends.add(_Blend(editorStart: boundary - blend, blend: blend));
      removed += blend;
    }

    return TransitionTimelineMap._(
      blends,
      editorDuration: editorTotal,
      outputDuration: editorTotal - removed,
    );
  }

  /// Length of the editor timeline — clips laid out at full length.
  final Duration editorDuration;

  /// Length of the rendered output — [editorDuration] minus every overlap
  /// blend. This is what the final export lasts.
  final Duration outputDuration;

  final List<_Blend> _blends;

  /// Null-safe [editorToOutput]: maps [position] onto the output axis, or
  /// returns `null` when [position] is `null` (a layer/effect with no explicit
  /// time anchor — e.g. one that spans the whole video).
  Duration? editorToOutputOrNull(Duration? position) =>
      position == null ? null : editorToOutput(position);

  /// Maps an editor-axis [position] onto the output axis.
  Duration editorToOutput(Duration position) {
    var removed = Duration.zero;
    for (final b in _blends) {
      final blendEnd = b.editorStart + b.blend * 2;
      if (position >= blendEnd) {
        removed += b.blend;
      } else if (position > b.editorStart) {
        // Linear inside the 2×blend-wide region → removes half the offset.
        removed += Duration(
          microseconds: (position - b.editorStart).inMicroseconds ~/ 2,
        );
      }
    }
    final output = position - removed;
    return output.isNegative ? Duration.zero : output;
  }

  /// Inverse of [editorToOutput]: maps an output-axis [position] back to the
  /// editor axis. Inside a blend the editor advances at twice the output rate.
  Duration outputToEditor(Duration position) {
    if (position.isNegative) return Duration.zero;
    var removed = Duration.zero;
    for (final b in _blends) {
      final outBlendStart = b.editorStart - removed;
      final outBlendEnd = outBlendStart + b.blend;
      if (position >= outBlendEnd) {
        removed += b.blend;
      } else if (position > outBlendStart) {
        return b.editorStart + (position - outBlendStart) * 2;
      } else {
        return position + removed;
      }
    }
    return position + removed;
  }
}

/// The duration of the rendered output for [clips] — the sum of clip playback
/// lengths minus the blend each overlap transition removes (after the
/// no-overlap clamp). Dips don't shorten the timeline, so they don't count.
///
/// This is what the final export lasts, which differs from the editor
/// timeline length (`ClipEditorState.totalDuration`, clips at full length)
/// whenever an overlap transition is used.
Duration renderedOutputDuration(List<DivineVideoClip> clips) =>
    TransitionTimelineMap.fromClips(clips).outputDuration;

/// Maps an editor-timeline [position] (clips at full length) onto the rendered
/// output timeline. Lets the header show where the playhead sits in the final
/// video, not the editor.
Duration editorToOutputPosition(
  List<DivineVideoClip> clips,
  Duration position,
) => TransitionTimelineMap.fromClips(clips).editorToOutput(position);

/// Inverse of [editorToOutputPosition]: maps an output-timeline [position] back
/// onto the editor axis. Lets the ruler place an output-time tick at the editor
/// pixel where the clips actually sit, so it stays aligned with the strip.
Duration outputToEditorPosition(
  List<DivineVideoClip> clips,
  Duration position,
) => TransitionTimelineMap.fromClips(clips).outputToEditor(position);
