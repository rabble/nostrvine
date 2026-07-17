// ABOUTME: Extracts and caches per-clip audio waveforms for the timeline strip.
// ABOUTME: One notifier per clip; extractions are shared per source file.

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/clip_waveform.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

/// Extracts waveform data for the video file at [videoPath].
///
/// Injectable so tests can assert the manager's caching and lifecycle without
/// invoking the native extractor.
typedef ClipWaveformExtractor = Future<WaveformData> Function(String videoPath);

/// Manages waveform extraction for the clips currently on the timeline.
///
/// Each clip gets an independent [ValueNotifier] so only the affected tile
/// repaints when its waveform arrives. Extractions are keyed by source file
/// path, so the two halves of a trim-based split — which share one file —
/// resolve from a single pass, and undo/redo restores hit the cache.
class ClipWaveformManager {
  ClipWaveformManager({ClipWaveformExtractor? extractor})
    : _extract = extractor ?? _extractWithProVideoEditor;

  /// Sample density for extraction. At the timeline's maximum zoom a bar
  /// covers ~2px, so 200 samples/second still resolves more detail than the
  /// strip can draw — at ~8KB per minute of audio.
  static const WaveformResolution _resolution = WaveformResolution.high;

  /// Cached waveforms retained after their clip is gone, so undo/redo does not
  /// re-extract. Insertion-ordered for FIFO eviction.
  static const _maxCachedWaveforms = 32;

  static Future<WaveformData> _extractWithProVideoEditor(String videoPath) {
    return ProVideoEditor.instance.getWaveform(
      WaveformConfigs(
        video: EditorVideo.file(File(videoPath)),
        resolution: _resolution,
      ),
    );
  }

  final ClipWaveformExtractor _extract;

  final Map<String, ValueNotifier<ClipWaveform?>> _notifiers = {};

  /// Source file path each clip's current waveform was resolved against.
  /// A change means the clip was re-rendered (split, speed, reverse) and its
  /// waveform has to be re-extracted.
  final Map<String, String> _paths = {};

  final Map<String, ClipWaveform> _cache = {};
  final Set<String> _inFlight = {};

  /// Serializes extractions — the strip's thumbnail generator and the editor
  /// preview already compete for the same hardware decoders.
  Future<void> _queue = Future<void>.value();

  bool _disposed = false;

  /// Returns the waveform notifier for [clipId].
  ValueNotifier<ClipWaveform?> operator [](String clipId) =>
      _notifiers[clipId]!;

  /// Syncs waveforms with the current clip list — starts extraction for new
  /// clips and for clips whose source file changed, and cleans up removed ones.
  void sync({required List<DivineVideoClip> clips}) {
    if (_disposed) return;

    final currentIds = clips.map((c) => c.id).toSet();
    for (final id in _notifiers.keys.toList()) {
      if (currentIds.contains(id)) continue;
      _notifiers.remove(id)?.dispose();
      _paths.remove(id);
    }

    for (final clip in clips) {
      final notifier = _notifiers.putIfAbsent(
        clip.id,
        () => ValueNotifier(null),
      );

      final path = clip.video.file?.path;
      if (path == null) {
        // A clip whose source file isn't resolved yet (e.g. still rendering).
        _paths.remove(clip.id);
        notifier.value = null;
        continue;
      }

      if (_paths[clip.id] == path) continue;
      _paths[clip.id] = path;

      final cached = _cache[path];
      if (cached != null) {
        notifier.value = cached;
        continue;
      }
      // The previous waveform stays on screen until the new one lands —
      // clearing here would blink the bars away on every re-render swap.
      _enqueue(path);
    }
  }

  void _enqueue(String path) {
    if (!_inFlight.add(path)) return;
    _queue = _queue.then((_) => _extractFor(path));
  }

  Future<void> _extractFor(String path) async {
    try {
      if (_disposed || !_isReferenced(path)) return;
      final data = await _extract(path);
      if (_disposed) return;
      _publish(path, _reduce(data));
    } catch (e) {
      Log.warning(
        'Failed to extract clip waveform: $e',
        name: 'ClipWaveformManager',
        category: LogCategory.video,
      );
      if (_disposed) return;
      // Cache the miss: a file without a readable audio track would otherwise
      // be retried on every sync. The strip just renders no bars.
      _publish(path, const ClipWaveform.empty());
    } finally {
      _inFlight.remove(path);
    }
  }

  /// Whether any clip still points at [path]. A clip removed while its
  /// extraction was queued has nothing left to render.
  bool _isReferenced(String path) => _paths.values.contains(path);

  void _publish(String path, ClipWaveform waveform) {
    _cache[path] = waveform;
    if (_cache.length > _maxCachedWaveforms) {
      _cache.remove(_cache.keys.first);
    }
    for (final entry in _paths.entries) {
      if (entry.value == path) _notifiers[entry.key]?.value = waveform;
    }
  }

  ClipWaveform _reduce(WaveformData data) {
    final left = data.leftChannel;
    final right = data.rightChannel;
    final peaks = List<double>.filled(left.length, 0);
    var peak = 0.0;
    for (var i = 0; i < left.length; i++) {
      final l = left[i].abs();
      final r = right != null && i < right.length ? right[i].abs() : l;
      final sample = math.max(l, r).clamp(0.0, 1.0);
      peaks[i] = sample;
      peak = math.max(peak, sample);
    }
    return ClipWaveform(peaks: peaks, duration: data.duration, peak: peak);
  }

  /// Disposes every notifier and stops publishing queued extractions.
  void dispose() {
    _disposed = true;
    for (final notifier in _notifiers.values) {
      notifier.dispose();
    }
    _notifiers.clear();
    _paths.clear();
    _cache.clear();
    _inFlight.clear();
  }
}
