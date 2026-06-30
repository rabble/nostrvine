// ABOUTME: Service for splitting video clips into separate segments
// ABOUTME: Handles video rendering, thumbnail extraction, and progress tracking via Completers

import 'dart:async';

import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:path/path.dart' as p;
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

/// Service for splitting video clips into two separate segments
class VideoEditorSplitService {
  static const minClipDuration = Duration(milliseconds: 30);

  /// Defensive cap on awaiting the preview thumbnail after the split settles.
  /// The native thumbnail decode has no watchdog of its own; without this a
  /// stalled decode would hold [splitClip] open and re-wedge the editor's
  /// loading state exactly like the render stall did (#4801).
  static const _thumbnailWatchdogTimeout = Duration(seconds: 30);

  /// Validates if the split position is valid for the given clip.
  ///
  /// [splitPosition] is relative to the trimmed clip (0 to trimmedDuration).
  /// Both resulting clips must meet the minimum duration requirement.
  static bool isValidSplitPosition(
    DivineVideoClip clip,
    Duration splitPosition,
  ) {
    return splitPosition >= minClipDuration &&
        clip.trimmedDuration - splitPosition >= minClipDuration;
  }

  /// Splits a clip at the specified position.
  ///
  /// This method:
  /// 1. Creates two new clip objects with completers for tracking processing
  /// 2. Generates output paths in the documents directory
  /// 3. Calls onClipsCreated callback to add clips to UI BEFORE rendering
  /// 4. Extracts the end clip's thumbnail in parallel with the split
  /// 5. Cuts the source into both halves with a single frame-accurate split
  ///
  /// Throws if the split fails/cancels or the split position is invalid.
  static Future<void> splitClip({
    required DivineVideoClip sourceClip,
    required Duration splitPosition,
    required void Function(DivineVideoClip startClip, DivineVideoClip endClip)?
    onClipsCreated,
    required void Function(DivineVideoClip clip, String thumbnailPath)?
    onThumbnailExtracted,
    required void Function(DivineVideoClip clip, EditorVideo video)?
    onClipRendered,
  }) async {
    if (!isValidSplitPosition(sourceClip, splitPosition)) {
      Log.error(
        '❌ Invalid split position: ${splitPosition.inSeconds}s '
        '(clip: ${sourceClip.trimmedDuration.inSeconds}s, '
        'min: ${minClipDuration.inMilliseconds}ms)',
        name: 'VideoEditorSplitService',
        category: .video,
      );
      throw ArgumentError(
        'Split position $splitPosition is invalid. '
        'Both clips must be at least $minClipDuration.',
      );
    }

    // splitPosition is relative to the trimmed clip (0 to trimmedDuration).
    // Convert to an absolute position within the full clip for rendering.
    final absoluteSplitPos = sourceClip.trimStart + splitPosition;

    Log.info(
      '✂️ Starting clip split at ${splitPosition.inSeconds}s '
      '(absolute: ${absoluteSplitPos.inSeconds}s, '
      'total: ${sourceClip.duration.inSeconds}s)',
      name: 'VideoEditorSplitService',
      category: .video,
    );

    final timestamp = DateTime.now();
    final timestampMs = timestamp.microsecondsSinceEpoch;
    final startClipId = '${timestampMs}_start';
    final endClipId = '${timestampMs}_end';

    // Start clip: keeps the original trimStart, no trimEnd needed
    // (the split point is the new end). The split point is a hard cut, so the
    // start half drops the source clip's outgoing transition — only the end
    // half inherits it (it now owns the boundary into the following clip).
    final startClip = sourceClip.copyWith(
      id: startClipId,
      duration: absoluteSplitPos,
      trimEnd: Duration.zero,
      processingCompleter: Completer<bool>(),
      clearTransition: true,
    );
    // End clip preview: while rendering, this still points at the original
    // source video, so keep source-time trimStart at the split point. It keeps
    // the source clip's transition into the next clip.
    final previewEndClip = sourceClip.copyWith(
      id: endClipId,
      duration: sourceClip.duration,
      trimStart: absoluteSplitPos,
      processingCompleter: Completer<bool>(),
    );
    final renderedEndClip = previewEndClip.copyWith(
      duration: sourceClip.duration - absoluteSplitPos,
      trimStart: Duration.zero,
    );

    final documentsPath = await getDocumentsPath();
    // startClipId / endClipId already carry the `_start` / `_end` suffix, so
    // the filename is just `<id>.mp4` — appending another suffix produced the
    // doubled `_start_start.mp4` / `_end_end.mp4` names.
    final startClipPath = p.join(documentsPath, '$startClipId.mp4');
    final endClipPath = p.join(documentsPath, '$endClipId.mp4');

    Log.debug(
      '📁 Created split clips - Start: ${splitPosition.inSeconds}s, '
      'End: ${previewEndClip.trimmedDuration.inSeconds}s',
      name: 'VideoEditorSplitService',
      category: .video,
    );

    // Notify that clips are created (so they can be added to UI before
    // rendering)
    onClipsCreated?.call(startClip, previewEndClip);

    // Extract the preview thumbnail for the end clip in parallel with the
    // split, so the preview frame can appear while the re-encode runs. It owns
    // its error handling internally, so awaiting it later never throws.
    final thumbnailFuture = _extractThumbnailForClip(
      sourceClip,
      absoluteSplitPos,
      previewEndClip,
      onThumbnailExtracted,
    );

    Log.debug(
      '🎬 Splitting source clip at absolute ${absoluteSplitPos.inSeconds}s',
      name: 'VideoEditorSplitService',
      category: .video,
    );

    // One frame-accurate native split instead of two full render passes. The
    // two halves are exactly the previous segment renders: start covers the
    // source from 0 → split, end covers split → end. Unlike the render
    // pipeline, this primitive cannot hang (per-export watchdog + Dart-side
    // timeout), so a stalled export can never wedge the editor again (#4801).
    try {
      final outPaths = await VideoEditorRenderService.splitNativeVideoToFile(
        inputPath: await sourceClip.video.safeFilePath(),
        splitPosition: absoluteSplitPos,
        startOutputPath: startClipPath,
        endOutputPath: endClipPath,
      );

      startClip.processingCompleter?.complete(true);
      onClipRendered?.call(startClip, EditorVideo.file(outPaths[0]));

      renderedEndClip.processingCompleter?.complete(true);
      onClipRendered?.call(renderedEndClip, EditorVideo.file(outPaths[1]));

      Log.info(
        '✅ Split complete - created 2 clips from ${sourceClip.id}',
        name: 'VideoEditorSplitService',
        category: .video,
      );
    } on RenderCanceledException {
      Log.info(
        '🚫 Split cancelled for ${sourceClip.id}',
        name: 'VideoEditorSplitService',
        category: .video,
      );
      startClip.processingCompleter?.complete(false);
      renderedEndClip.processingCompleter?.complete(false);
      rethrow;
    } catch (e) {
      Log.error(
        '❌ Split failed for ${sourceClip.id}: $e',
        name: 'VideoEditorSplitService',
        category: .video,
      );
      startClip.processingCompleter?.complete(false);
      renderedEndClip.processingCompleter?.complete(false);
      rethrow;
    } finally {
      // Bound the wait so a stalled native thumbnail decode can't hold
      // splitClip open and re-wedge the editor (#4801). The thumbnail owns its
      // error handling internally, so this await only ever completes or times
      // out — it never throws.
      await thumbnailFuture.timeout(
        _thumbnailWatchdogTimeout,
        onTimeout: () {},
      );
    }
  }

  /// Extract a thumbnail for the split clip at the specified timestamp.
  static Future<void> _extractThumbnailForClip(
    DivineVideoClip sourceClip,
    Duration timestamp,
    DivineVideoClip targetClip,
    void Function(DivineVideoClip clip, String thumbnailPath)?
    onThumbnailExtracted,
  ) async {
    try {
      Log.debug(
        '🖼️ Extracting thumbnail at ${timestamp.inSeconds}s for ${targetClip.id}',
        name: 'VideoEditorSplitService',
        category: .video,
      );
      final thumbnailResult = await VideoThumbnailService.extractThumbnail(
        videoPath: await sourceClip.video.safeFilePath(),
        targetTimestamp: timestamp,
      );
      if (thumbnailResult != null) {
        onThumbnailExtracted?.call(targetClip, thumbnailResult.path);
        Log.debug(
          '✅ Thumbnail extracted: ${thumbnailResult.path}',
          name: 'VideoEditorSplitService',
          category: .video,
        );
      }
    } catch (e) {
      Log.warning(
        '⚠️ Failed to extract thumbnail for ${targetClip.id}: $e',
        name: 'VideoEditorSplitService',
        category: .video,
      );
    }
  }
}
