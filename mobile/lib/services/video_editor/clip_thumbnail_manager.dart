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
  // IDs whose subscription has delivered its final batch — the strip is at
  // full density and only a source-file change warrants re-extraction.
  final Set<String> _complete = {};
  // Strips of recently removed clips, kept (files included) for an instant
  // restore when the same id returns — undo re-adds the pre-split clip,
  // redo re-adds the split halves. Without this the returning clip starts
  // with an empty notifier: every slot falls back to the poster frame and
  // the whole strip re-extracts from scratch. Insertion-ordered for FIFO
  // eviction.
  final Map<String, _RetiredStrip> _retired = {};
  static const _maxRetiredStrips = 8;

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

    // Retire stale entries — the strip is kept for an instant restore if
    // the id returns (undo re-adds the pre-split clip, redo the halves).
    final staleIds = _notifiers.keys
        .where((id) => !currentIds.contains(id))
        .toList();
    for (final id in staleIds) {
      _subscriptions.remove(id)?.cancel();
      final videoPath = _videoPaths.remove(id);
      final wasSeeded = _seeded.remove(id);
      _pendingRebase.remove(id);
      final wasComplete = _complete.remove(id);
      final notifier = _notifiers.remove(id);
      if (notifier == null) continue;
      final frames = notifier.value;
      notifier.dispose();
      // Seeded strips are not retired: their frames are borrowed from the
      // (retired) source strip and carry a pending rebase that is lost
      // here — restoring them later would misalign timestamps. The
      // unreferenced check keeps the borrowed files alive through the
      // source's retired entry.
      if (frames.isEmpty || videoPath == null || wasSeeded) {
        _deleteUnreferencedFiles(frames);
        continue;
      }
      _retire(
        id,
        _RetiredStrip(
          videoPath: videoPath,
          frames: frames,
          complete: wasComplete,
        ),
      );
    }

    // Ensure notifiers exist and start (or restart) loading.
    for (final clip in clips) {
      final notifier = _notifiers.putIfAbsent(
        clip.id,
        () => ValueNotifier(const []),
      );
      final newPath = clip.video.file?.path;
      final hasSubscription = _subscriptions.containsKey(clip.id);
      final isSeeded = _seeded.contains(clip.id);

      // Instant restore for a returning clip id (undo/redo): reuse the
      // retired strip instead of flashing posters and re-extracting.
      if (!hasSubscription && !isSeeded && notifier.value.isEmpty) {
        final retired = _retired.remove(clip.id);
        if (retired != null) {
          if (newPath != null && newPath == retired.videoPath) {
            notifier.value = retired.frames;
            _videoPaths[clip.id] = newPath;
            if (retired.complete) {
              _complete.add(clip.id);
              continue;
            }
            // Partial strip (removed mid-extraction): fall through so a
            // fresh subscription fills the gaps — the restored frames
            // stay visible as gap-fillers via the batch merge.
          } else {
            // Same id but a different source file — the frames would show
            // stale content, so drop them (borrowed files stay protected).
            _deleteUnreferencedFiles(retired.frames);
          }
        }
      }

      final currentPath = _videoPaths[clip.id];

      if (!hasSubscription) {
        if (isSeeded) {
          // Skip auto-loading for seeded clips — their notifier already
          // shows the right frames borrowed from the source clip.
          if (newPath == null || newPath == currentPath) continue;
          // The rendered (trimmed) file path arrived — start the real
          // subscription. The seeded frames stay visible (rebased into
          // the rendered file's timebase where needed) until fresh
          // frames cover their spots; their files are deleted then.
          _seeded.remove(clip.id);
          _rebaseThumbnails(clip.id);
        } else if (_complete.contains(clip.id)) {
          // Restored from the retired cache at full density — only a
          // source-file change warrants re-extraction.
          if (newPath == null || newPath == currentPath) continue;
          _complete.remove(clip.id);
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
        // frames are merged out progressively as fresh batches cover
        // their spots (see [_mergeCarriedFrames]); their files are
        // deleted as they drop out.
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
  /// frames stay visible as gap-fillers until fresh frames cover
  /// their spots (see [_mergeCarriedFrames]).
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
    _complete.remove(clip.id);

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

    // A carried frame (seeded split frame, pre-restart frame) is kept as a
    // gap-filler until a fresh frame lands within half the generator's final
    // frame spacing — at full density every spot is covered, so all carried
    // frames are pruned by then (the onDone sweep catches any residue).
    final keepDistance = Duration(
      milliseconds: (1000 / thumbsPerSecond / 2).round(),
    );
    // Latest accumulated fresh batch, for the onDone carried-frame sweep.
    var latestFresh = const <StripThumbnail>[];
    // Set when the generator hits a native extraction failure mid-stream:
    // the stream errors and closes with only a partial set delivered.
    var truncated = false;

    final subscription =
        _generateStripThumbnails(
          videoPath: videoPath,
          clipId: clip.id,
          duration: clip.duration,
          outputSize: outputSize,
          thumbsPerSecond: thumbsPerSecond,
          priorityTimestamps: priorityTimestamps,
        ).listen(
          (thumbnails) {
            latestFresh = thumbnails;
            final notifier = _notifiers[clip.id];
            if (notifier == null) return;
            final replaced = notifier.value;
            // Merge instead of replacing wholesale: early batches are sparse
            // (a handful of frames), while the carried frames are dense.
            // Dropping the carried frames here would collapse the strip to a
            // few frames + poster fallbacks and visibly reshuffle it while
            // batches stream in (worst after a split, where the carried
            // frames already show the correct content).
            final merged = _mergeCarriedFrames(
              fresh: thumbnails,
              previous: replaced,
              clipDuration: clip.duration,
              keepDistance: keepDistance,
            );
            notifier.value = merged;
            if (replaced.isEmpty) return;
            // Delete files of frames that dropped out of the merged strip,
            // unless another clip still shows them.
            final currentPaths = {for (final thumb in merged) thumb.path};
            _deleteUnreferencedFiles([
              for (final thumb in replaced)
                if (!currentPaths.contains(thumb.path)) thumb,
            ]);
          },
          onError: (Object error, StackTrace stackTrace) {
            // Already logged by the generator. Marking the truncation is
            // enough: the onDone below then keeps the carried gap-fillers
            // and leaves the clip un-complete, so a later retire/restore
            // starts a fresh subscription that fills the missing frames.
            truncated = true;
          },
          onDone: () {
            final notifier = _notifiers[clip.id];
            if (notifier == null || truncated || latestFresh.isEmpty) return;
            _complete.add(clip.id);
            // Long clips cap the generator's frame count, so the final
            // spacing can exceed [keepDistance] and leave carried frames
            // behind — sweep them now that the fresh set is complete.
            final freshPaths = {for (final thumb in latestFresh) thumb.path};
            final dropped = [
              for (final thumb in notifier.value)
                if (!freshPaths.contains(thumb.path)) thumb,
            ];
            if (dropped.isEmpty) return;
            notifier.value = latestFresh;
            _deleteUnreferencedFiles(dropped);
          },
        );
    // If the owner paused while this clip was (re)synced, keep the new
    // subscription paused too so it doesn't start extracting off-screen.
    if (_paused) subscription.pause();
    _subscriptions[clip.id] = subscription;
  }

  /// Merges carried-over frames into a fresh accumulated batch.
  ///
  /// Fresh frames win; a carried frame from [previous] survives only while
  /// its timestamp is inside the clip and no fresh frame sits within
  /// [keepDistance] of it. As batches accumulate, fresh frames blanket the
  /// timeline and the carried set shrinks to empty on its own.
  static List<StripThumbnail> _mergeCarriedFrames({
    required List<StripThumbnail> fresh,
    required List<StripThumbnail> previous,
    required Duration clipDuration,
    required Duration keepDistance,
  }) {
    if (previous.isEmpty) return fresh;
    if (fresh.isEmpty) return previous;
    final freshPaths = {for (final thumb in fresh) thumb.path};
    final carried = <StripThumbnail>[
      for (final thumb in previous)
        if (!freshPaths.contains(thumb.path) &&
            thumb.timestamp >= Duration.zero &&
            thumb.timestamp <= clipDuration &&
            !_hasFrameNear(fresh, thumb.timestamp, keepDistance))
          thumb,
    ];
    if (carried.isEmpty) return fresh;
    final merged = [...fresh, ...carried]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return List.unmodifiable(merged);
  }

  /// Whether [frames] (sorted by timestamp) contains a frame within
  /// [distance] of [timestamp].
  static bool _hasFrameNear(
    List<StripThumbnail> frames,
    Duration timestamp,
    Duration distance,
  ) {
    var lo = 0;
    var hi = frames.length;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (frames[mid].timestamp < timestamp) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    if (lo < frames.length &&
        (frames[lo].timestamp - timestamp).abs() <= distance) {
      return true;
    }
    return lo > 0 && (timestamp - frames[lo - 1].timestamp).abs() <= distance;
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

  /// Parks a removed clip's strip in the retired cache, evicting the
  /// oldest entries beyond [_maxRetiredStrips]. Evicted files are only
  /// deleted when nothing else references them.
  void _retire(String clipId, _RetiredStrip strip) {
    _retired
      ..remove(clipId)
      ..[clipId] = strip;
    while (_retired.length > _maxRetiredStrips) {
      final evicted = _retired.remove(_retired.keys.first);
      if (evicted != null) _deleteUnreferencedFiles(evicted.frames);
    }
  }

  /// Deletes the files of [thumbnails] that no current notifier value
  /// and no retired strip references anymore. Seeded clips borrow the
  /// source clip's files, so a plain delete would pull decoded frames
  /// out from under a live tile; retired strips keep borrowing them
  /// for undo/redo restores.
  void _deleteUnreferencedFiles(List<StripThumbnail> thumbnails) {
    if (thumbnails.isEmpty) return;
    final live = <String>{
      for (final notifier in _notifiers.values)
        for (final thumbnail in notifier.value) thumbnail.path,
      for (final strip in _retired.values)
        for (final thumbnail in strip.frames) thumbnail.path,
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
    for (final strip in _retired.values) {
      _deleteFiles(strip.frames);
    }
    _subscriptions.clear();
    _notifiers.clear();
    _videoPaths.clear();
    _seeded.clear();
    _pendingRebase.clear();
    _complete.clear();
    _retired.clear();
  }
}

/// A removed clip's strip, parked for an instant restore when the same
/// clip id returns with the same source file (undo/redo).
class _RetiredStrip {
  const _RetiredStrip({
    required this.videoPath,
    required this.frames,
    required this.complete,
  });

  /// Source video path the frames were extracted from (or borrowed for).
  final String videoPath;

  final List<StripThumbnail> frames;

  /// Whether the strip's subscription had delivered its final batch, i.e.
  /// the frames are at full density and need no re-extraction on restore.
  final bool complete;
}

/// Inclusive-exclusive duration range `[start, end)`.
class DurationRange {
  const DurationRange({required this.start, required this.end});

  final Duration start;
  final Duration end;
}
