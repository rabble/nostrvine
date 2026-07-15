// ABOUTME: Pure frame-list operations for a stop-motion DivineVideoClip
// ABOUTME: Keeps the frame list and the clip's cached duration in sync

import 'dart:io';

import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/services/video_editor/stop_motion_render_service.dart';

/// Frame-level operations for a stop-motion [DivineVideoClip].
///
/// A stop-motion clip stores its stills as [StopMotionClipFrame]s; each still is
/// held for a whole number of output frames ("frames per image") at
/// [StopMotionRenderService.defaultFrameRate]. These helpers rebuild the frame
/// list and keep the clip's cached [DivineVideoClip.duration] consistent with
/// it.
abstract class StopMotionFrameOps {
  StopMotionFrameOps._();

  /// Lowest number of output frames a still may be held for.
  static const int minFramesPerImage = 1;

  /// Highest number of output frames a still may be held for.
  static const int maxFramesPerImage = 300;

  /// Default hold for a freshly captured still: 1 output frame at 24fps.
  static const int defaultFramesPerImage = 1;

  /// Hold duration for a still shown for [framesPerImage] output frames at the
  /// default frame rate. [framesPerImage] is clamped to
  /// [minFramesPerImage]..[maxFramesPerImage].
  static Duration framesPerImageToDuration(int framesPerImage) {
    final clamped = framesPerImage.clamp(minFramesPerImage, maxFramesPerImage);
    return Duration(
      microseconds:
          (clamped *
                  Duration.microsecondsPerSecond /
                  StopMotionRenderService.defaultFrameRate)
              .round(),
    );
  }

  /// Inverse of [framesPerImageToDuration]: the number of output frames a still
  /// held for [duration] represents, rounded and clamped to the valid range.
  static int durationToFramesPerImage(Duration duration) {
    final raw =
        duration.inMicroseconds *
        StopMotionRenderService.defaultFrameRate /
        Duration.microsecondsPerSecond;
    return raw.round().clamp(minFramesPerImage, maxFramesPerImage);
  }

  /// Sum of every frame's hold time — the clip's playback duration.
  static Duration totalDuration(List<StopMotionClipFrame> frames) =>
      frames.fold(Duration.zero, (sum, frame) => sum + frame.duration);

  /// Index at which stills captured with the playhead at [position] should be
  /// inserted into [frames], so they land at that timeline position rather than
  /// at the end.
  ///
  /// The playhead sitting inside frame *i*'s hold inserts the new stills right
  /// after frame *i*. Clamped to `0..frames.length`, so a playhead at the start
  /// prepends and one at/after the end appends.
  static int insertIndexAtPosition(
    List<StopMotionClipFrame> frames,
    Duration position,
  ) {
    if (position <= Duration.zero) return 0;
    var acc = Duration.zero;
    for (var i = 0; i < frames.length; i++) {
      acc += frames[i].duration;
      if (position < acc) return i + 1;
    }
    return frames.length;
  }

  /// [frames] with [inserted] spliced in at [index] (clamped to the list
  /// bounds).
  static List<StopMotionClipFrame> insertFramesAt(
    List<StopMotionClipFrame> frames,
    int index,
    List<StopMotionClipFrame> inserted,
  ) {
    if (inserted.isEmpty) return frames;
    final at = index.clamp(0, frames.length);
    return [...frames.sublist(0, at), ...inserted, ...frames.sublist(at)];
  }

  /// [frames] with the still at [index] removed.
  ///
  /// Returns the list unchanged when [index] is out of range or removing it
  /// would empty the clip — a stop-motion clip must keep at least one still.
  static List<StopMotionClipFrame> removeFrame(
    List<StopMotionClipFrame> frames,
    int index,
  ) {
    if (index < 0 || index >= frames.length || frames.length <= 1) {
      return frames;
    }
    return [...frames]..removeAt(index);
  }

  /// [frames] with the stills at [indexes] removed.
  ///
  /// Returns the list unchanged when [indexes] is empty, contains an
  /// out-of-range index, or removing them would empty the clip — a
  /// stop-motion clip must keep at least one still.
  static List<StopMotionClipFrame> removeFrames(
    List<StopMotionClipFrame> frames,
    Set<int> indexes,
  ) {
    if (indexes.isEmpty ||
        indexes.any((index) => index < 0 || index >= frames.length) ||
        indexes.length >= frames.length) {
      return frames;
    }
    return [
      for (var i = 0; i < frames.length; i++)
        if (!indexes.contains(i)) frames[i],
    ];
  }

  /// [frames] with the still at [from] moved to [to].
  static List<StopMotionClipFrame> reorderFrame(
    List<StopMotionClipFrame> frames,
    int from,
    int to,
  ) {
    if (from < 0 ||
        from >= frames.length ||
        to < 0 ||
        to >= frames.length ||
        from == to) {
      return frames;
    }
    final next = [...frames];
    final moved = next.removeAt(from);
    next.insert(to, moved);
    return next;
  }

  /// [frames] with the still at [index] held for [framesPerImage] output
  /// frames, marked as an individual override so later global changes leave
  /// it untouched.
  static List<StopMotionClipFrame> setFrameHold(
    List<StopMotionClipFrame> frames,
    int index,
    int framesPerImage,
  ) {
    if (index < 0 || index >= frames.length) return frames;
    final updated = frames[index].copyWith(
      duration: framesPerImageToDuration(framesPerImage),
      holdOverridden: true,
    );
    // Re-selecting the current hold changes nothing; return the source instance
    // so the commit's `identical` no-op guard skips a redundant history entry.
    if (updated == frames[index]) return frames;
    final next = [...frames];
    next[index] = updated;
    return next;
  }

  /// [frames] with the selected stills' order reversed among their own slots:
  /// the indexes in [indexes] keep their positions, but the stills sitting on
  /// them swap into reverse order (frame multi-select "reverse").
  ///
  /// Returns the list unchanged when fewer than two stills are selected or an
  /// index is out of range.
  static List<StopMotionClipFrame> reverseFrames(
    List<StopMotionClipFrame> frames,
    Set<int> indexes,
  ) {
    if (indexes.length < 2 ||
        indexes.any((index) => index < 0 || index >= frames.length)) {
      return frames;
    }
    final slots = indexes.toList()..sort();
    final next = [...frames];
    for (var k = 0; k < slots.length; k++) {
      next[slots[k]] = frames[slots[slots.length - 1 - k]];
    }
    return next;
  }

  /// Moves the stills at [indexes] as one contiguous block (in their current
  /// relative order) to [insertSlot] — an insertion position within the list
  /// of *remaining* stills (`0..remaining.length`, clamped).
  ///
  /// Returns the list unchanged when the selection is empty or contains an
  /// out-of-range index.
  static List<StopMotionClipFrame> moveFrames(
    List<StopMotionClipFrame> frames,
    Set<int> indexes,
    int insertSlot,
  ) {
    if (indexes.isEmpty ||
        indexes.any((index) => index < 0 || index >= frames.length)) {
      return frames;
    }
    final selected = <StopMotionClipFrame>[];
    final remaining = <StopMotionClipFrame>[];
    for (var i = 0; i < frames.length; i++) {
      (indexes.contains(i) ? selected : remaining).add(frames[i]);
    }
    final slot = insertSlot.clamp(0, remaining.length);
    final result = [
      ...remaining.sublist(0, slot),
      ...selected,
      ...remaining.sublist(slot),
    ];
    // A move that lands everything back where it was is a no-op; return the
    // original instance so `identical` checks (edit commit, history) skip it.
    for (var i = 0; i < frames.length; i++) {
      if (!identical(result[i], frames[i])) return result;
    }
    return frames;
  }

  /// [frames] with every still at [indexes] held for [framesPerImage] output
  /// frames, each marked as an individual override (see [setFrameHold]).
  /// Out-of-range indexes are ignored.
  static List<StopMotionClipFrame> setFramesHold(
    List<StopMotionClipFrame> frames,
    Set<int> indexes,
    int framesPerImage,
  ) {
    if (indexes.isEmpty) return frames;
    final duration = framesPerImageToDuration(framesPerImage);
    final next = <StopMotionClipFrame>[];
    var changed = false;
    for (var i = 0; i < frames.length; i++) {
      if (indexes.contains(i)) {
        final updated = frames[i].copyWith(
          duration: duration,
          holdOverridden: true,
        );
        if (updated != frames[i]) changed = true;
        next.add(updated);
      } else {
        next.add(frames[i]);
      }
    }
    // No selected still actually changed hold: return the source instance so
    // the commit's `identical` no-op guard skips a redundant history entry.
    return changed ? next : frames;
  }

  /// Applies [framesPerImage] as the global default: every still that has *not*
  /// been individually overridden ([StopMotionClipFrame.holdOverridden]) is set
  /// to that hold; overridden stills keep their own hold.
  static List<StopMotionClipFrame> setGlobalHold(
    List<StopMotionClipFrame> frames,
    int framesPerImage,
  ) {
    final duration = framesPerImageToDuration(framesPerImage);
    final next = <StopMotionClipFrame>[];
    var changed = false;
    for (final frame in frames) {
      if (frame.holdOverridden) {
        next.add(frame);
      } else {
        final updated = frame.copyWith(duration: duration);
        if (updated != frame) changed = true;
        next.add(updated);
      }
    }
    // No non-overridden still actually changed hold: return the source instance
    // so the commit's `identical` no-op guard skips a redundant history entry.
    return changed ? next : frames;
  }

  /// The global-default frames-per-image: the value shared by every
  /// *non-overridden* still. When there are no non-overridden stills or they
  /// disagree (merged sets, all stills individually overridden), falls back to
  /// the most common hold across *all* stills — ties broken by first
  /// occurrence — so the global control always displays a value.
  static int globalDefaultFramesPerImage(List<StopMotionClipFrame> frames) {
    int? shared;
    var agree = true;
    final counts = <int, int>{};
    for (final frame in frames) {
      final framesPerImage = durationToFramesPerImage(frame.duration);
      counts[framesPerImage] = (counts[framesPerImage] ?? 0) + 1;
      if (frame.holdOverridden) continue;
      if (shared == null) {
        shared = framesPerImage;
      } else if (shared != framesPerImage) {
        agree = false;
      }
    }
    if (shared != null && agree) return shared;
    var best = defaultFramesPerImage;
    var bestCount = 0;
    for (final entry in counts.entries) {
      if (entry.value > bestCount) {
        best = entry.key;
        bestCount = entry.value;
      }
    }
    return best;
  }

  /// [clip] with its stop-motion [frames] replaced and its cached [duration]
  /// recomputed from the new frame holds.
  static DivineVideoClip clipWithFrames(
    DivineVideoClip clip,
    List<StopMotionClipFrame> frames,
  ) {
    return clip.copyWith(
      stopMotionFrames: frames,
      duration: totalDuration(frames),
    );
  }

  /// [frames] whose image file still exists on disk and is non-empty.
  ///
  /// Captured stills can go missing (file cleanup) or corrupt (an interrupted
  /// capture leaves an empty file); such frames render as broken tiles and
  /// fail the publish render, so session-entry points filter them out.
  static List<StopMotionClipFrame> existingFrames(
    List<StopMotionClipFrame> frames,
  ) {
    return [
      for (final frame in frames)
        if (_isReadableImage(frame.path)) frame,
    ];
  }

  static bool _isReadableImage(String path) {
    try {
      final file = File(path);
      return file.existsSync() && file.lengthSync() > 0;
    } on FileSystemException {
      return false;
    }
  }

  /// [clip] with unreadable stills dropped (see [existingFrames]), or `null`
  /// when no readable still remains. Normal video clips pass through
  /// unchanged.
  static DivineVideoClip? sanitizedClip(DivineVideoClip clip) {
    // A materialized clip has a rendered mp4; its stills are no longer the
    // source of truth, so don't drop it for missing (already-cleaned) stills.
    if (clip.video != null) return clip;
    final frames = clip.stopMotionFrames;
    if (frames == null) return clip;
    final readable = existingFrames(frames);
    if (readable.length == frames.length) return clip;
    if (readable.isEmpty) return null;
    return clipWithFrames(clip, readable);
  }

  /// Collapses multiple stop-motion [clips] into one frames clip — the first
  /// clip with every set's stills concatenated in selection order (and the
  /// duration recomputed).
  ///
  /// The frame-first editor (strip, preview, hold controls) edits exactly one
  /// frames clip, the same shape a recorder session produces, so a multi-set
  /// library selection must enter the editor as a single clip. Returns `null`
  /// when merging does not apply: fewer than two clips, or any normal video
  /// clip in the list.
  static DivineVideoClip? mergeClips(List<DivineVideoClip> clips) {
    if (clips.length < 2) return null;
    if (!clips.every((clip) => clip.isStopMotion)) return null;
    return clipWithFrames(clips.first, [
      for (final clip in clips) ...clip.stopMotionFrames!,
    ]);
  }
}

/// Whether every clip in [clips] is a frames-only stop-motion clip, so the
/// editor should switch to frame-first editing.
bool isStopMotionComposition(List<DivineVideoClip> clips) =>
    clips.isNotEmpty && clips.every((clip) => clip.isStopMotion);
