// ABOUTME: Pre-renders a clip's trimmed body at its playbackSpeed into a plain
// ABOUTME: normal-rate file so the preview plays it at 1× instead of retiming live.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show EditorVideo, ProVideoEditor, VideoRenderData, VideoSegment;
import 'package:unified_logger/unified_logger.dart';

/// A clip body rendered to a plain, normal-rate file with its
/// [DivineVideoClip.playbackSpeed] baked in, so the preview plays it at 1×
/// (no live retiming — smoother on both Android and iOS).
class RenderedSpeedClip {
  const RenderedSpeedClip({required this.path, required this.duration});

  /// Path to the rendered normal-rate video.
  final String path;

  /// Playback duration of the rendered file (≈ the clip's `playbackDuration`).
  final Duration duration;
}

/// Renders and caches per-clip speed bodies. Cache keys include the clip's
/// file, trims and speed, so a trim/speed change naturally misses the cache and
/// re-renders; the preview keeps playing the live-retimed clip until the new
/// file lands.
///
/// Mirrors [TransitionSeamRenderService]: the preview plays the live-retimed
/// clip instantly (no wait), this renders the smooth normal-rate file in the
/// background, and the canvas swaps it in when ready. Volume is **not** baked in
/// (the player applies it per clip), so a mute toggle never re-renders.
class ClipSpeedRenderService {
  final _cache = <String, RenderedSpeedClip>{};
  final _inFlight = <String, Future<RenderedSpeedClip?>>{};

  /// Monotonic counter bumped on every cache mutation, so consumers can detect
  /// when the player composition needs rebuilding without diffing the cache.
  int _version = 0;
  int get version => _version;

  /// True while a speed body for this clip is being rendered.
  bool isRendering(DivineVideoClip clip) => _inFlight.containsKey(_key(clip));

  /// The already-rendered speed body for [clip], or `null` if it is not rendered
  /// yet or the clip plays at 1×. Pure cache lookup — never triggers a render.
  RenderedSpeedClip? cached(DivineVideoClip clip) {
    if (!_needsRender(clip)) return null;
    return _cache[_key(clip)];
  }

  /// Renders (or returns the cached / in-flight) normal-rate body for [clip].
  /// Returns `null` when the clip plays at 1× (nothing to render) or on failure.
  Future<RenderedSpeedClip?> render(DivineVideoClip clip) {
    if (!_needsRender(clip)) return Future<RenderedSpeedClip?>.value();
    final key = _key(clip);
    final cached = _cache[key];
    if (cached != null) return Future<RenderedSpeedClip?>.value(cached);
    return _inFlight[key] ??= _render(clip, key);
  }

  bool _needsRender(DivineVideoClip clip) {
    final speed = clip.playbackSpeed ?? 1.0;
    return speed > 0 && speed != 1.0 && clip.video.file != null;
  }

  Future<RenderedSpeedClip?> _render(DivineVideoClip clip, String key) async {
    try {
      // Wait for a still-processing recording to finish before rendering.
      await clip.processingCompleter?.future;

      final hash = sha256.convert(utf8.encode(key)).toString();
      final persistentPath = await _persistentPath(hash);

      // Reuse a file rendered in a previous session; a truncated file left by a
      // kill mid-write is detected and dropped so it re-renders.
      if (File(persistentPath).existsSync()) {
        final existing = await _fromPersistedFile(persistentPath);
        if (existing != null) {
          _cache[key] = existing;
          _version++;
          return existing;
        }
      }

      final tempDir = await getTemporaryDirectory();
      final tempOutput =
          '${tempDir.path}/speed_${DateTime.now().microsecondsSinceEpoch}.mp4';

      // Render only the trimmed body at the target speed, with no crop/transform
      // — the preview player crops the texture itself, exactly as it does for
      // the raw live-retimed clip, so nothing is double-cropped.
      await VideoEditorRenderService.renderNativeVideoToFile(
        tempOutput,
        VideoRenderData(
          id: 'speed_$hash',
          videoSegments: [
            VideoSegment(
              video: clip.video,
              startTime: clip.trimStart == Duration.zero
                  ? null
                  : clip.trimStart,
              endTime: clip.trimStart + clip.trimmedDuration,
              playbackSpeed: clip.playbackSpeed,
            ),
          ],
          shouldOptimizeForNetworkUse: true,
        ),
      );

      // Publish atomically within the documents dir (temp→copy→rename) so a
      // crash mid-copy can only leave a stray `.tmp`, never a truncated keyed
      // file that would resolve to a corrupt render forever.
      final tempPath = '$persistentPath.tmp';
      await File(tempOutput).copy(tempPath);
      await File(tempPath).rename(persistentPath);
      await _deleteQuietly(tempOutput);

      final rendered = await _fromPersistedFile(persistentPath);
      if (rendered == null) return null;
      _cache[key] = rendered;
      _version++;
      Log.info(
        '🎬 Speed body rendered: ${clip.id} @${clip.playbackSpeed}× '
        '→ ${rendered.duration.inMilliseconds}ms',
        name: 'ClipSpeedRenderService',
        category: LogCategory.video,
      );
      return rendered;
    } catch (e, stackTrace) {
      Log.error(
        'Clip speed render failed',
        name: 'ClipSpeedRenderService',
        error: e,
        stackTrace: stackTrace,
        category: LogCategory.video,
      );
      return null;
    } finally {
      _inFlight.remove(key);
    }
  }

  /// Loads a previously-rendered file from [path], or `null` (deleting it) when
  /// it can't be read or has no duration — e.g. a truncated file from a kill
  /// mid-write. Deleting lets the caller re-render instead of resolving to the
  /// same corrupt file forever.
  Future<RenderedSpeedClip?> _fromPersistedFile(String path) async {
    try {
      final metadata = await ProVideoEditor.instance.getMetadata(
        EditorVideo.file(path),
      );
      if (metadata.duration <= Duration.zero) {
        await _deleteQuietly(path);
        return null;
      }
      return RenderedSpeedClip(path: path, duration: metadata.duration);
    } catch (e, stackTrace) {
      Log.warning(
        'Dropping unreadable rendered speed clip at $path',
        name: 'ClipSpeedRenderService',
        category: LogCategory.video,
      );
      Log.debug(
        'Rendered speed clip read failed: $e\n$stackTrace',
        name: 'ClipSpeedRenderService',
        category: LogCategory.video,
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

  /// Bumped whenever the render inputs baked into the file change shape, so
  /// files rendered by an older algorithm are re-rendered after an app upgrade
  /// instead of replayed stale (the keyed files live in the documents dir and
  /// survive upgrades).
  static const _cacheVersion = 1;

  String _key(DivineVideoClip clip) =>
      'v$_cacheVersion|${clip.id}:${clip.video.file?.path}:'
      '${clip.duration.inMicroseconds}:${clip.trimStart.inMicroseconds}:'
      '${clip.trimEnd.inMicroseconds}:${clip.playbackSpeed ?? 1.0}';

  /// Deterministic on-disk path for a rendered body, keyed by [hash] so the same
  /// clip + trims + speed reuse the file across editor sessions (like seams).
  Future<String> _persistentPath(String hash) async {
    final dir = await getApplicationDocumentsDirectory();
    final speedDir = Directory('${dir.path}/speed_clips');
    if (!speedDir.existsSync()) speedDir.createSync(recursive: true);
    return '${speedDir.path}/$hash.mp4';
  }

  /// Drops the in-memory cache (e.g. when the editor closes). On-disk files stay
  /// for the next session.
  void clear() {
    _cache.clear();
    _version++;
  }

  /// Seeds the cache directly so [buildSeamAwarePlayerClips] can be exercised
  /// without running the native render pipeline.
  @visibleForTesting
  void cacheForTest(DivineVideoClip clip, RenderedSpeedClip rendered) {
    _cache[_key(clip)] = rendered;
    _version++;
  }
}
