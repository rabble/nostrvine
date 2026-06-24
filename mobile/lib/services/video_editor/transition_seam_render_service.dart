// ABOUTME: Renders the short transition "seam" between two adjacent clips so
// ABOUTME: the preview can play it as a plain clip instead of compositing live.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:divine_video_player/divine_video_player.dart' as player;
import 'package:flutter/foundation.dart';
import 'package:openvine/extensions/divine_video_clip_player_mapping.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show ClipTransition, ClipTransitionType, EditorVideo, ProVideoEditor;
import 'package:unified_logger/unified_logger.dart';

/// A rendered transition seam — a small clip that already contains the blended
/// transition between [DivineVideoClip] A's tail and clip B's head.
///
/// The preview plays clip A (trimmed by [tailConsumed]), then this seam, then
/// clip B (trimmed by [headConsumed]) as three plain clips with hard cuts; the
/// seam supplies the smooth transition so the user sees a continuous blend.
class TransitionSeam {
  const TransitionSeam({
    required this.path,
    required this.duration,
    required this.tailConsumed,
    required this.headConsumed,
  });

  /// Path to the rendered seam video.
  final String path;

  /// Playback duration of the rendered seam.
  final Duration duration;

  /// How much of clip A's visible tail was rendered into the seam (and must be
  /// trimmed off clip A's end in the preview).
  final Duration tailConsumed;

  /// How much of clip B's visible head was rendered into the seam (and must be
  /// trimmed off clip B's start in the preview).
  final Duration headConsumed;
}

/// Renders and caches transition seams. Cache keys include the clip pair,
/// their trims/speed and the transition, so a trim change (or reorder, which
/// changes adjacency) naturally misses the cache and re-renders.
///
/// The transition passed in is the **clamped** transition (see
/// [clampTransitions]) — the render-time duration that
/// guarantees no clip is consumed by transitions on both sides at once, so the
/// preview matches the export and a middle clip is never replayed.
class TransitionSeamRenderService {
  final _cache = <String, TransitionSeam>{};
  final _inFlight = <String, Future<TransitionSeam?>>{};

  /// Monotonic counter bumped on every cache mutation. Lets consumers (e.g. the
  /// editor canvas) cheaply detect when a [SeamTimeline] needs rebuilding
  /// without diffing the cache contents.
  int _version = 0;
  int get version => _version;

  /// True while a seam for this transition is being rendered (cache miss with a
  /// render in flight). Used to avoid double-counting concurrent render
  /// requests for the same boundary.
  bool isRendering(
    DivineVideoClip clipA,
    DivineVideoClip clipB,
    ClipTransition transition,
  ) => _inFlight.containsKey(_key(clipA, clipB, transition));

  /// Returns the already-rendered seam for this transition, or `null` if it is
  /// not rendered yet. Pure cache lookup — never triggers a render.
  TransitionSeam? cached(
    DivineVideoClip clipA,
    DivineVideoClip clipB,
    ClipTransition transition,
  ) => _cache[_key(clipA, clipB, transition)];

  /// Renders (or returns the cached / in-flight) seam for the transition out of
  /// [clipA] into [clipB]. Returns `null` on failure or when either clip is too
  /// short to contribute.
  Future<TransitionSeam?> render({
    required DivineVideoClip clipA,
    required DivineVideoClip clipB,
    required ClipTransition transition,
  }) {
    final key = _key(clipA, clipB, transition);
    final cached = _cache[key];
    if (cached != null) return Future.value(cached);
    return _inFlight[key] ??= _render(clipA, clipB, transition, key);
  }

  Future<TransitionSeam?> _render(
    DivineVideoClip clipA,
    DivineVideoClip clipB,
    ClipTransition transition,
    String key,
  ) async {
    try {
      final (:consumed, :blend, :seamTransition) = computeSeamSpans(
        clipA,
        clipB,
        transition,
      );
      if (consumed <= Duration.zero) return null;

      // `consumed` is wall-clock (playback) time; convert it into each clip's
      // own source media time for trimming, honouring per-clip playbackSpeed
      // (clip A and clip B may run at different speeds).
      final tailConsumed = clipA.playbackDurationToSourceDuration(consumed);
      final headConsumed = clipB.playbackDurationToSourceDuration(consumed);

      // Persisted seam from a previous session — reuse it without re-rendering.
      // A file truncated by a kill mid-write (see the temp-then-rename publish
      // below) is detected and deleted here so the boundary re-renders instead
      // of resolving to the same corrupt file — a stuck hard cut — forever.
      final persistentPath = await _persistentSeamPath(key);
      if (File(persistentPath).existsSync()) {
        final seam = await _seamFromPersistedFile(
          persistentPath,
          tailConsumed: tailConsumed,
          headConsumed: headConsumed,
        );
        if (seam != null) {
          _cache[key] = seam;
          _version++;
          return seam;
        }
      }

      final tailClip = _tailClip(clipA, tailConsumed, seamTransition);
      final headClip = _headClip(clipB, headConsumed);

      // Leaving the default 6.3s export cap in place never truncates a seam:
      // `consumed` is bounded by the shorter adjacent clip, and two adjacent
      // clips sum to ≤ the 6.3s timeline cap (clip_manager trims to the
      // remaining budget), so the shorter clip is ≤ ~3.15s. Even a hard-cut
      // fallback seam (consumed×2) therefore stays ≤ 6.3s.
      final outputPath = await VideoEditorRenderService.renderVideo(
        clips: [tailClip, headClip],
        aspectRatio: clipA.targetAspectRatio,
      );
      if (outputPath == null) return null;
      // Publish atomically: outputPath is on the temp filesystem, so it can't
      // be renamed straight to the documents dir (cross-device rename fails).
      // Copy it next to the target, then rename within the documents dir —
      // a same-filesystem rename is atomic, so a crash mid-copy can't leave a
      // truncated file at the deterministic path (only a stray `.tmp`).
      final tempPath = '$persistentPath.tmp';
      await File(outputPath).copy(tempPath);
      await File(tempPath).rename(persistentPath);

      final metadata = await ProVideoEditor.instance.getMetadata(
        EditorVideo.file(persistentPath),
      );
      if (metadata.duration <= Duration.zero) {
        await _deleteQuietly(persistentPath);
        return null;
      }
      // A blended overlap seam is shorter than a hard-cut concatenation
      // (consumed×2). If output ≈ consumed×2 the overlap fell back to a cut.
      Log.info(
        '🎬 Seam rendered: ${transition.type.name} '
        'overlap=${_isOverlap(transition.type)} '
        'consumed=${consumed.inMilliseconds}ms blend=${blend.inMilliseconds}ms '
        '→ output=${metadata.duration.inMilliseconds}ms '
        '(hard-cut would be ${(consumed * 2).inMilliseconds}ms)',
        name: 'TransitionSeamRenderService',
        category: .video,
      );
      final seam = TransitionSeam(
        path: persistentPath,
        duration: metadata.duration,
        tailConsumed: tailConsumed,
        headConsumed: headConsumed,
      );
      _cache[key] = seam;
      _version++;
      return seam;
    } catch (e, stackTrace) {
      Log.error(
        'Transition seam render failed',
        name: 'TransitionSeamRenderService',
        error: e,
        stackTrace: stackTrace,
        category: .video,
      );
      return null;
    } finally {
      _inFlight.remove(key);
    }
  }

  /// Loads a previously-rendered seam from [path], or `null` (deleting the
  /// file) when it can't be read or has no duration — e.g. a truncated file
  /// left by a kill mid-write in a prior session. Deleting lets the caller
  /// re-render instead of resolving to the same corrupt file forever.
  Future<TransitionSeam?> _seamFromPersistedFile(
    String path, {
    required Duration tailConsumed,
    required Duration headConsumed,
  }) async {
    try {
      final metadata = await ProVideoEditor.instance.getMetadata(
        EditorVideo.file(path),
      );
      if (metadata.duration <= Duration.zero) {
        await _deleteQuietly(path);
        return null;
      }
      return TransitionSeam(
        path: path,
        duration: metadata.duration,
        tailConsumed: tailConsumed,
        headConsumed: headConsumed,
      );
    } catch (e, stackTrace) {
      Log.warning(
        'Dropping unreadable persisted seam at $path',
        name: 'TransitionSeamRenderService',
        category: .video,
      );
      Log.debug(
        'Persisted seam read failed: $e\n$stackTrace',
        name: 'TransitionSeamRenderService',
        category: .video,
      );
      await _deleteQuietly(path);
      return null;
    }
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    } catch (_) {
      // Best-effort cleanup; a failed delete just re-renders next time.
    }
  }

  /// The wall-clock (playback) span consumed from each side, the actual blend
  /// (overlap or dip) duration, and the transition to apply when rendering the
  /// seam. Everything here is in playback time so the math lines up with the
  /// picker ceiling and the export-side clamp (all keyed on
  /// [DivineVideoClip.playbackDuration] via [transitionConsumedPerSide]);
  /// `_render` converts [consumed] back into each clip's own source time for
  /// trimming.
  ///
  /// For overlaps the blend is always half the consumed span, guaranteeing a
  /// solo lead-in/out on each side (a segment equal to the blend degenerates
  /// into a hard cut).
  @visibleForTesting
  ({Duration consumed, Duration blend, ClipTransition seamTransition})
  computeSeamSpans(
    DivineVideoClip clipA,
    DivineVideoClip clipB,
    ClipTransition transition,
  ) {
    final consumed = transitionConsumedPerSide(
      clipA.playbackDuration,
      clipB.playbackDuration,
      transition,
    );
    if (_isOverlap(transition.type)) {
      final blend = _half(consumed);
      return (
        consumed: consumed,
        blend: blend,
        seamTransition: transition.copyWith(duration: blend),
      );
    }
    final dip = _min(transition.duration, consumed * 2);
    return (
      consumed: consumed,
      blend: dip,
      seamTransition: transition.duration == dip
          ? transition
          : transition.copyWith(duration: dip),
    );
  }

  /// Clip A trimmed to play only its last [tailLen], carrying the transition.
  DivineVideoClip _tailClip(
    DivineVideoClip clip,
    Duration tailLen,
    ClipTransition transition,
  ) {
    final visibleEnd = clip.duration - clip.trimEnd;
    return clip.copyWith(
      trimStart: visibleEnd - tailLen,
      transition: transition,
    );
  }

  /// Clip B trimmed to play only its first [headLen], with no transition.
  DivineVideoClip _headClip(DivineVideoClip clip, Duration headLen) {
    return clip.copyWith(
      trimEnd: clip.duration - (clip.trimStart + headLen),
      clearTransition: true,
    );
  }

  /// Bumped whenever the seam-composition math ([computeSeamSpans] /
  /// [_tailClip] / [_headClip]) or the transition that reaches the seam changes.
  /// It prefixes [_key], so persisted seams rendered by an older algorithm under
  /// `transition_seams/` are no longer key-matched and get re-rendered after an
  /// app upgrade instead of replayed stale (the keyed files live in the
  /// documents dir and survive upgrades).
  ///
  /// v4: seams now render the no-overlap-clamped transition, not the raw one.
  static const _seamCacheVersion = 4;

  String _key(
    DivineVideoClip clipA,
    DivineVideoClip clipB,
    ClipTransition transition,
  ) {
    // The played file path is part of the key: reversing a clip swaps `video`
    // to the physically-reversed file (and any crop/transform re-render swaps
    // it too), so this invalidates the seam even when the trims are symmetric
    // (e.g. an untrimmed clip, where reverse leaves trimStart == trimEnd).
    // `volume` and `targetAspectRatio` are baked into the rendered seam (audio
    // gain and crop), so changing either after caching must re-render — without
    // them a mute/crop change would keep playing the stale seam. `duration` is
    // included because `_tailClip`/`_headClip` read it and it can be trimmed
    // independently of the file (clip_manager caps a clip on add).
    String clipKey(DivineVideoClip c) =>
        '${c.id}:${c.video.file?.path}:${c.duration.inMicroseconds}:'
        '${c.trimStart.inMicroseconds}:${c.trimEnd.inMicroseconds}:'
        '${c.playbackSpeed ?? 1.0}:${c.volume}:${c.targetAspectRatio.name}';
    final t =
        '${transition.type.name}:${transition.duration.inMicroseconds}:'
        '${transition.curve.name}:${transition.direction.name}';
    return 'v$_seamCacheVersion|${clipKey(clipA)}|${clipKey(clipB)}|$t';
  }

  bool _isOverlap(ClipTransitionType type) =>
      type != ClipTransitionType.fadeToBlack &&
      type != ClipTransitionType.fadeToWhite;

  Duration _half(Duration d) => Duration(microseconds: d.inMicroseconds ~/ 2);

  Duration _min(Duration a, Duration b) => a < b ? a : b;

  /// Deterministic on-disk path for a seam, keyed by [key] so the same clip
  /// pair + trims + transition reuse the rendered file across editor sessions
  /// (like thumbnails). Only the in-memory cache is dropped on [clear]; the
  /// files persist for reuse.
  Future<String> _persistentSeamPath(String key) async {
    final dir = await getApplicationDocumentsDirectory();
    final seamDir = Directory('${dir.path}/transition_seams');
    if (!seamDir.existsSync()) seamDir.createSync(recursive: true);
    final hash = sha256.convert(utf8.encode(key)).toString();
    return '${seamDir.path}/$hash.mp4';
  }

  /// Drops the in-memory cache (e.g. when the editor closes). On-disk seams
  /// stay for the next session.
  void clear() {
    _cache.clear();
    _version++;
  }

  /// Seeds the cache directly so [buildSeamAwarePlayerClips] can be exercised
  /// without running the native render pipeline.
  @visibleForTesting
  void cacheSeamForTest(
    DivineVideoClip clipA,
    DivineVideoClip clipB,
    ClipTransition transition,
    TransitionSeam seam,
  ) {
    _cache[_key(clipA, clipB, transition)] = seam;
    _version++;
  }
}

/// Maps positions between the preview player's composite timeline (trimmed clip
/// bodies + spliced seams, shorter than the editor timeline) and the editor
/// timeline (clips at full length). Clip bodies map 1:1; each seam maps to the
/// region straddling its clip boundary, so the on-screen transition lines up
/// with the editor playhead. Identity when no seam is spliced.
class SeamTimeline {
  SeamTimeline(List<DivineVideoClip> clips, TransitionSeamRenderService seams) {
    final clamped = clampTransitions(clips);
    var composite = Duration.zero;
    var editor = Duration.zero; // start of the current clip on the editor line
    // Last editor position handed to a segment. Clamping each segment's editor
    // extent to this cursor keeps the axis non-decreasing; it is a no-op
    // whenever clips aren't over-consumed (which the clamp also prevents).
    var editorCursor = Duration.zero;
    for (var i = 0; i < clips.length; i++) {
      final clip = clips[i];
      final clipDuration = clip.playbackDuration;

      var headPb = Duration.zero;
      final prevTransition = i > 0 ? clamped[clips[i - 1].id] : null;
      if (prevTransition != null) {
        final seam = seams.cached(clips[i - 1], clip, prevTransition);
        if (seam != null) {
          headPb = clip.sourceDurationToPlaybackDuration(seam.headConsumed);
        }
      }

      TransitionSeam? outgoing;
      var tailPb = Duration.zero;
      final transition = clamped[clip.id];
      if (i + 1 < clips.length && transition != null) {
        outgoing = seams.cached(clip, clips[i + 1], transition);
        if (outgoing != null) {
          tailPb = clip.sourceDurationToPlaybackDuration(outgoing.tailConsumed);
        }
      }

      final bodyEditorStart = editor + headPb;
      final bodyEditorEnd = editor + clipDuration - tailPb;
      if (bodyEditorEnd > bodyEditorStart) {
        final bodyComposite = bodyEditorEnd - bodyEditorStart;
        final editorStart = _maxDur(bodyEditorStart, editorCursor);
        final editorEnd = _maxDur(bodyEditorEnd, editorStart);
        _segments.add(
          _Segment(
            composite,
            composite + bodyComposite,
            editorStart,
            editorEnd,
          ),
        );
        composite += bodyComposite;
        editorCursor = editorEnd;
      }

      if (outgoing != null) {
        final boundary = editor + clipDuration;
        final nextHeadPb = clips[i + 1].sourceDurationToPlaybackDuration(
          outgoing.headConsumed,
        );
        final editorStart = _maxDur(boundary - tailPb, editorCursor);
        final editorEnd = _maxDur(boundary + nextHeadPb, editorStart);
        _segments.add(
          _Segment(
            composite,
            composite + outgoing.duration,
            editorStart,
            editorEnd,
          ),
        );
        composite += outgoing.duration;
        editorCursor = editorEnd;
      }

      editor += clipDuration;
    }
  }

  final List<_Segment> _segments = [];

  /// True when at least one seam compresses the timeline (otherwise both
  /// directions are the identity).
  bool get hasSeams =>
      _segments.any((s) => s.compositeDuration != s.editorDuration);

  /// Composite (player) position → editor timeline position.
  Duration compositeToTimeline(Duration composite) =>
      _map(composite, fromComposite: true);

  /// Editor timeline position → composite (player) position.
  Duration timelineToComposite(Duration timeline) =>
      _map(timeline, fromComposite: false);

  Duration _map(Duration value, {required bool fromComposite}) {
    if (_segments.isEmpty) return value;
    final clamped = value < Duration.zero ? Duration.zero : value;
    for (var i = 0; i < _segments.length; i++) {
      final seg = _segments[i];
      final fromStart = fromComposite ? seg.compositeStart : seg.editorStart;
      final fromEnd = fromComposite ? seg.compositeEnd : seg.editorEnd;
      final toStart = fromComposite ? seg.editorStart : seg.compositeStart;
      final toEnd = fromComposite ? seg.editorEnd : seg.compositeEnd;
      final isLast = i == _segments.length - 1;
      if (clamped < fromEnd || isLast) {
        final span = fromEnd - fromStart;
        if (span <= Duration.zero) return toStart;
        final frac = (clamped - fromStart).inMicroseconds / span.inMicroseconds;
        return toStart +
            Duration(
              microseconds: (frac * (toEnd - toStart).inMicroseconds).round(),
            );
      }
    }
    return _segments.last.editorEnd;
  }
}

class _Segment {
  const _Segment(
    this.compositeStart,
    this.compositeEnd,
    this.editorStart,
    this.editorEnd,
  );

  final Duration compositeStart;
  final Duration compositeEnd;
  final Duration editorStart;
  final Duration editorEnd;

  Duration get compositeDuration => compositeEnd - compositeStart;
  Duration get editorDuration => editorEnd - editorStart;
}

Duration _maxDur(Duration a, Duration b) => a > b ? a : b;

/// Builds the preview player's clip list for [clips], splicing in any
/// already-rendered transition seams. Each clip plays only its body (minus the
/// tail/head consumed by adjacent rendered seams), with the seam clip inserted
/// between neighbours. Transitions whose seam is not rendered yet simply play
/// as a hard cut until the seam arrives.
///
/// Transitions are taken from [clampTransitions] so the
/// preview consumes exactly what the export will, and a clip touched by
/// transitions on both sides is split between them rather than replayed.
List<player.VideoClip> buildSeamAwarePlayerClips(
  List<DivineVideoClip> clips,
  TransitionSeamRenderService seams,
) {
  final clamped = clampTransitions(clips);
  final result = <player.VideoClip>[];
  for (var i = 0; i < clips.length; i++) {
    final clip = clips[i];

    var headConsumed = Duration.zero;
    final prevTransition = i > 0 ? clamped[clips[i - 1].id] : null;
    if (prevTransition != null) {
      headConsumed =
          seams.cached(clips[i - 1], clip, prevTransition)?.headConsumed ??
          Duration.zero;
    }

    TransitionSeam? outgoingSeam;
    var tailConsumed = Duration.zero;
    final transition = clamped[clip.id];
    if (i + 1 < clips.length && transition != null) {
      outgoingSeam = seams.cached(clip, clips[i + 1], transition);
      tailConsumed = outgoingSeam?.tailConsumed ?? Duration.zero;
    }

    final bodyStart = clip.trimStart + headConsumed;
    final bodyEnd = clip.duration - clip.trimEnd - tailConsumed;
    if (bodyEnd > bodyStart) {
      final bodyClip = clip.toPlayerVideoClip(start: bodyStart, end: bodyEnd);
      if (bodyClip != null) result.add(bodyClip);
    }

    if (outgoingSeam != null) {
      result.add(player.VideoClip.file(outgoingSeam.path));
    }
  }
  return result;
}
