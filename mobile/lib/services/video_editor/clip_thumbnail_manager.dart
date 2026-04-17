import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/video_thumbnail_service.dart';

/// Manages thumbnail loading and cleanup for a set of clips.
///
/// Each clip gets an independent [ValueNotifier] so only the affected
/// tile rebuilds when new thumbnails arrive.
class ClipThumbnailManager {
  final Map<String, ValueNotifier<List<StripThumbnail>>> _notifiers = {};
  final Map<String, StreamSubscription<List<StripThumbnail>>> _subscriptions =
      {};

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
      final notifier = _notifiers.remove(id);
      if (notifier != null) {
        _deleteFiles(notifier.value);
        notifier.dispose();
      }
    }

    // Ensure notifiers exist and start loading for new clips.
    for (final clip in clips) {
      _notifiers.putIfAbsent(clip.id, () => ValueNotifier(const []));
      if (!_subscriptions.containsKey(clip.id)) {
        _loadThumbnails(
          clip,
          devicePixelRatio,
          priorityTimestamps: priorityTimestamps[clip.id],
        );
      }
    }
  }

  void _loadThumbnails(
    DivineVideoClip clip,
    double devicePixelRatio, {
    List<Duration>? priorityTimestamps,
  }) {
    final videoPath = clip.video.file?.path;
    if (videoPath == null) return;

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
  }
}
