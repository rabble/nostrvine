import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/video_thumbnail_service.dart';

/// Signature of [VideoThumbnailService.generateStripThumbnails], injectable
/// so tests can assert pause/resume behaviour on the produced subscriptions
/// without touching the native extractor.
typedef StripThumbnailStreamFactory =
    Stream<List<StripThumbnail>> Function({
      required String videoPath,
      required String clipId,
      required Duration duration,
      required Size outputSize,
      required int thumbsPerSecond,
      List<Duration>? priorityTimestamps,
    });

/// Manages thumbnail loading and cleanup for a set of clips.
///
/// Each clip gets an independent [ValueNotifier] so only the affected
/// tile rebuilds when new thumbnails arrive.
class ClipThumbnailManager {
  ClipThumbnailManager({
    StripThumbnailStreamFactory? stripThumbnailStreamFactory,
  }) : _generateStripThumbnails =
           stripThumbnailStreamFactory ??
           VideoThumbnailService.generateStripThumbnails;

  final StripThumbnailStreamFactory _generateStripThumbnails;

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
  // Timestamp shift to apply to a seeded clip's thumbnails when its
  // rendered file path arrives. Seeded frames are kept in the *current*
  // clip's timebase so they display immediately; when the rendered file
  // rebases the clip's timeline (split end half: source-time →
  // zero-based), the same shift is applied here so the frames stay
  // aligned until fresh thumbnails replace them.
  final Map<String, Duration> _pendingRebase = {};

  /// When true, newly started subscriptions begin paused and existing ones are
  /// held. See [pauseAll].
  bool _paused = false;

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
      _pendingRebase.remove(id);
      final notifier = _notifiers.remove(id);
      if (notifier != null) {
        // Files borrowed by seeded clips (split halves) stay alive; only
        // files no other notifier references are deleted.
        _deleteUnreferencedFiles(notifier.value);
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
        if (isSeeded) {
          // Skip auto-loading for seeded clips — their notifier already
          // shows the right frames borrowed from the source clip.
          if (newPath == null || newPath == currentPath) continue;
          // The rendered (trimmed) file path arrived — start the real
          // subscription. The seeded frames stay visible (rebased into
          // the rendered file's timebase where needed) until the first
          // fresh batch replaces them; their files are deleted then.
          _seeded.remove(clip.id);
          _rebaseThumbnails(clip.id);
        }
        _loadThumbnails(
          clip,
          devicePixelRatio,
          priorityTimestamps: priorityTimestamps[clip.id],
        );
      } else if (newPath != null && newPath != currentPath) {
        // Source file of an already-subscribed clip changed (e.g. it was
        // re-rendered to a trimmed file). Restart against the new file
        // but keep the current frames on screen — clearing them here
        // would flash black until the first fresh batch arrives. The old
        // files are deleted once the new subscription replaces them.
        //
        // Seeded split halves never reach this branch: they carry no
        // subscription until their rendered path arrives via the
        // !hasSubscription branch above, which is where _seeded and any
        // pending rebase are consumed.
        _subscriptions.remove(clip.id)?.cancel();
        _loadThumbnails(
          clip,
          devicePixelRatio,
          priorityTimestamps: priorityTimestamps[clip.id],
        );
      }
    }
  }

  /// Pre-populates the notifier for [targetClipId] by borrowing
  /// thumbnails from another clip ([sourceClipId]) whose timestamps
  /// fall within [sourceRange]. By default timestamps are shifted by
  /// `-sourceRange.start` so they map to the new clip's local timeline.
  /// Pass [timestampOffset] to use a different source-to-target mapping.
  ///
  /// The seeded entries reference the source clip's thumbnail *files*
  /// directly (no copy) so the image cache entries decoded for the
  /// source tile repaint instantly — a copied file would be a cold
  /// decode that flashes black. Cleanup protects borrowed files: they
  /// are only deleted once no notifier references them anymore.
  ///
  /// The clip is marked as "seeded" so [sync] will not auto-load a
  /// fresh subscription against the still-un-trimmed source video
  /// — that would overwrite these correct frames with the wrong
  /// range. The real subscription starts once the rendered file
  /// path arrives via the path-change branch in [sync]; the seeded
  /// frames stay visible until its first batch lands.
  ///
  /// [rebaseOnPathChange] is subtracted from every seeded timestamp
  /// when the rendered file path arrives. Use it when the rendered
  /// file rebases the clip's timeline (split end half: the preview
  /// clip is source-timed, the rendered file starts at zero).
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
    Duration rebaseOnPathChange = Duration.zero,
  }) {
    final source = _notifiers[sourceClipId];
    if (source == null) return;
    final shift = timestampOffset ?? sourceRange.start;
    final seeded = <StripThumbnail>[
      for (final thumbnail in source.value)
        if (thumbnail.timestamp >= sourceRange.start &&
            thumbnail.timestamp < sourceRange.end)
          StripThumbnail(
            path: thumbnail.path,
            timestamp: thumbnail.timestamp - shift,
          ),
    ];
    final notifier = _notifiers.putIfAbsent(
      targetClipId,
      () => ValueNotifier(const []),
    );
    notifier.value = seeded;
    _videoPaths[targetClipId] = currentSourcePath;
    _seeded.add(targetClipId);
    if (rebaseOnPathChange == Duration.zero) {
      _pendingRebase.remove(targetClipId);
    } else {
      _pendingRebase[targetClipId] = rebaseOnPathChange;
    }
  }

  /// Applies the pending timestamp rebase recorded by [seedFromSource]
  /// when the clip's rendered file path arrives.
  void _rebaseThumbnails(String clipId) {
    final shift = _pendingRebase.remove(clipId);
    if (shift == null || shift == Duration.zero) return;
    final notifier = _notifiers[clipId];
    if (notifier == null) return;
    notifier.value = List.unmodifiable([
      for (final thumbnail in notifier.value)
        StripThumbnail(
          path: thumbnail.path,
          timestamp: thumbnail.timestamp - shift,
        ),
    ]);
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

    final subscription =
        _generateStripThumbnails(
          videoPath: videoPath,
          clipId: clip.id,
          duration: clip.duration,
          outputSize: outputSize,
          thumbsPerSecond: thumbsPerSecond,
          priorityTimestamps: priorityTimestamps,
        ).listen((thumbnails) {
          final notifier = _notifiers[clip.id];
          if (notifier == null) return;
          final replaced = notifier.value;
          notifier.value = thumbnails;
          if (replaced.isEmpty) return;
          // Frames carried over across a restart (seeded split frames,
          // pre-render frames) are superseded now — delete their files
          // unless another clip still shows them. Each batch is a
          // superset of the previous (the generator accumulates), so in
          // steady state every replaced path is still in [thumbnails];
          // filtering to the genuinely dropped paths first skips the
          // cross-notifier scan on every normal accumulation batch.
          final currentPaths = {for (final thumb in thumbnails) thumb.path};
          _deleteUnreferencedFiles([
            for (final thumb in replaced)
              if (!currentPaths.contains(thumb.path)) thumb,
          ]);
        });
    // If the owner paused while this clip was (re)synced, keep the new
    // subscription paused too so it doesn't start extracting off-screen.
    if (_paused) subscription.pause();
    _subscriptions[clip.id] = subscription;
  }

  /// Pauses all in-flight thumbnail subscriptions — e.g. while the editor is
  /// obscured by another route — so the native frame extraction stops
  /// contending for hardware decoders and CPU. Lossless: the batch stream
  /// generators suspend at the next batch boundary and continue on [resumeAll].
  void pauseAll() {
    _paused = true;
    for (final sub in _subscriptions.values) {
      if (!sub.isPaused) sub.pause();
    }
  }

  /// Resumes thumbnail extraction paused by [pauseAll].
  void resumeAll() {
    _paused = false;
    for (final sub in _subscriptions.values) {
      if (sub.isPaused) sub.resume();
    }
  }

  /// Deletes the files of [thumbnails] that no current notifier value
  /// references anymore. Seeded clips borrow the source clip's files,
  /// so a plain delete would pull decoded frames out from under a
  /// live tile.
  void _deleteUnreferencedFiles(List<StripThumbnail> thumbnails) {
    if (thumbnails.isEmpty) return;
    final live = <String>{
      for (final notifier in _notifiers.values)
        for (final thumbnail in notifier.value) thumbnail.path,
    };
    for (final thumb in thumbnails) {
      if (live.contains(thumb.path)) continue;
      try {
        File(thumb.path).deleteSync();
      } catch (_) {}
    }
  }

  static void _deleteFiles(List<StripThumbnail> thumbnails) {
    for (final thumb in thumbnails) {
      try {
        File(thumb.path).deleteSync();
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
    _pendingRebase.clear();
  }
}

/// Inclusive-exclusive duration range `[start, end)`.
class DurationRange {
  const DurationRange({required this.start, required this.end});

  final Duration start;
  final Duration end;
}
