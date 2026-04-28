import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:path/path.dart' as p;

/// Manages thumbnail loading and cleanup for a set of clips.
///
/// Each clip gets an independent [ValueNotifier] so only the affected
/// tile rebuilds when new thumbnails arrive.
class ClipThumbnailManager {
  final Map<String, ValueNotifier<List<StripThumbnail>>> _notifiers = {};
  final Map<String, StreamSubscription<List<StripThumbnail>>> _subscriptions =
      {};
  // Tracks the video path each subscription was started with so we can
  // detect when a clip's underlying source file changes (e.g. after a
  // split renders the trimmed segment to a new file) and restart
  // thumbnail generation against the new file.
  final Map<String, String> _videoPaths = {};
  // IDs whose notifier has been pre-populated from another clip's
  // thumbnails (e.g. split). For these we suppress auto-loading until
  // the rendered file path arrives — otherwise the seeded frames would
  // be immediately overwritten by a fresh subscription against the
  // (still un-trimmed) source video.
  final Set<String> _seeded = {};

  /// Returns the thumbnail notifier for the given [clipId].
  ValueNotifier<List<StripThumbnail>> operator [](String clipId) =>
      _notifiers[clipId]!;

  /// Syncs thumbnails with the current clip list — starts loading for
  /// new clips and cleans up removed ones.
  ///
  /// [priorityTimestamps] maps clip IDs to the exact timestamps
  /// that the currently visible slots need. New clips whose ID is
  /// in this map will generate those frames first before filling
  /// the full-density set.
  void sync({
    required List<DivineVideoClip> clips,
    required double devicePixelRatio,
    Map<String, List<Duration>> priorityTimestamps = const {},
  }) {
    final currentIds = clips.map((c) => c.id).toSet();

    // Remove stale entries.
    final staleIds = _notifiers.keys
        .where((id) => !currentIds.contains(id))
        .toList();
    for (final id in staleIds) {
      _subscriptions.remove(id)?.cancel();
      _videoPaths.remove(id);
      _seeded.remove(id);
      final notifier = _notifiers.remove(id);
      if (notifier != null) {
        _deleteFiles(notifier.value);
        notifier.dispose();
      }
    }

    // Ensure notifiers exist and start (or restart) loading.
    for (final clip in clips) {
      _notifiers.putIfAbsent(clip.id, () => ValueNotifier(const []));
      final newPath = clip.video.file?.path;
      final currentPath = _videoPaths[clip.id];
      final hasSubscription = _subscriptions.containsKey(clip.id);
      final isSeeded = _seeded.contains(clip.id);

      if (!hasSubscription) {
        // Skip auto-loading for seeded clips — their notifier already
        // shows the right frames borrowed from the source clip. The
        // real subscription kicks in once the rendered (trimmed) file
        // path arrives via the path-change branch below.
        if (isSeeded && newPath == currentPath) continue;
        _loadThumbnails(
          clip,
          devicePixelRatio,
          priorityTimestamps: priorityTimestamps[clip.id],
        );
      } else if (newPath != null && newPath != currentPath) {
        // Source file changed (e.g. clip was rendered to a trimmed
        // file after a split). Restart against the new file so the
        // thumbnails reflect the actual segment content.
        _subscriptions.remove(clip.id)?.cancel();
        _seeded.remove(clip.id);
        final notifier = _notifiers[clip.id];
        if (notifier != null) {
          _deleteFiles(notifier.value);
          notifier.value = const [];
        }
        _loadThumbnails(
          clip,
          devicePixelRatio,
          priorityTimestamps: priorityTimestamps[clip.id],
        );
      } else if (isSeeded && newPath != null && newPath == currentPath) {
        // Seeded clip is still pointing at the source video (render
        // hasn't finished yet) — keep the seeded frames visible.
        continue;
      }
    }
  }

  /// Pre-populates the notifier for [targetClipId] by borrowing
  /// thumbnails from another clip ([sourceClipId]) whose timestamps
  /// fall within [sourceRange]. By default timestamps are shifted by
  /// `-sourceRange.start` so they map to the new clip's local timeline.
  /// Pass [timestampOffset] to use a different source-to-target mapping.
  ///
  /// The clip is marked as "seeded" so [sync] will not auto-load a
  /// fresh subscription against the still-un-trimmed source video
  /// — that would overwrite these correct frames with the wrong
  /// range. The real subscription starts once the rendered file
  /// path arrives via the path-change branch in [sync].
  ///
  /// [currentSourcePath] is the video path the target clip currently
  /// points at (typically the source video). Recording it lets
  /// [sync] detect when the rendered file path arrives and swap the
  /// subscription.
  void seedFromSource({
    required String sourceClipId,
    required String targetClipId,
    required DurationRange sourceRange,
    required String currentSourcePath,
    Duration? timestampOffset,
  }) {
    final source = _notifiers[sourceClipId];
    if (source == null) return;
    final shift = timestampOffset ?? sourceRange.start;
    final seeded = <StripThumbnail>[];
    for (var i = 0; i < source.value.length; i++) {
      final thumbnail = source.value[i];
      if (thumbnail.timestamp < sourceRange.start ||
          thumbnail.timestamp >= sourceRange.end) {
        continue;
      }
      seeded.add(
        StripThumbnail(
          path: _copySeededThumbnailFile(thumbnail.path, targetClipId, i),
          timestamp: thumbnail.timestamp - shift,
        ),
      );
    }
    final notifier = _notifiers.putIfAbsent(
      targetClipId,
      () => ValueNotifier(const []),
    );
    notifier.value = seeded;
    _videoPaths[targetClipId] = currentSourcePath;
    _seeded.add(targetClipId);
  }

  static String _copySeededThumbnailFile(
    String sourcePath,
    String targetClipId,
    int index,
  ) {
    final sourceFile = File(sourcePath);
    if (!sourceFile.existsSync()) return sourcePath;

    final extension = p.extension(sourcePath);
    final destinationPath = p.join(
      p.dirname(sourcePath),
      'seed_${targetClipId}_${DateTime.now().microsecondsSinceEpoch}_'
      '$index$extension',
    );

    try {
      return sourceFile.copySync(destinationPath).path;
    } catch (_) {
      return sourcePath;
    }
  }

  void _loadThumbnails(
    DivineVideoClip clip,
    double devicePixelRatio, {
    List<Duration>? priorityTimestamps,
  }) {
    final videoPath = clip.video.file?.path;
    if (videoPath == null) return;

    _videoPaths[clip.id] = videoPath;

    final outputSize = Size(
      TimelineConstants.thumbnailWidth * devicePixelRatio,
      TimelineConstants.thumbnailStripHeight * devicePixelRatio,
    );

    // Generate enough thumbnails to fill every slot at maximum zoom.
    // ceil(maxPixelsPerSecond / thumbnailWidth) = ceil(600 / 48) = 13
    final thumbsPerSecond =
        (TimelineConstants.maxPixelsPerSecond /
                TimelineConstants.thumbnailWidth)
            .ceil();

    _subscriptions[clip.id] =
        VideoThumbnailService.generateStripThumbnails(
          videoPath: videoPath,
          clipId: clip.id,
          duration: clip.duration,
          outputSize: outputSize,
          thumbsPerSecond: thumbsPerSecond,
          priorityTimestamps: priorityTimestamps,
        ).listen((thumbnails) {
          _notifiers[clip.id]?.value = thumbnails;
        });
  }

  static Future<void> _deleteFiles(List<StripThumbnail> thumbnails) async {
    for (final thumb in thumbnails) {
      try {
        await File(thumb.path).delete();
      } catch (_) {}
    }
  }

  /// Cancels all subscriptions and disposes all notifiers.
  void dispose() {
    for (final sub in _subscriptions.values) {
      sub.cancel();
    }
    for (final notifier in _notifiers.values) {
      _deleteFiles(notifier.value);
      notifier.dispose();
    }
    _subscriptions.clear();
    _notifiers.clear();
    _videoPaths.clear();
    _seeded.clear();
  }
}

/// Inclusive-exclusive duration range `[start, end)`.
class DurationRange {
  const DurationRange({required this.start, required this.end});

  final Duration start;
  final Duration end;
}
