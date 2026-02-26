// ABOUTME: Service for splitting video clips into separate segments
// ABOUTME: Handles video rendering, thumbnail extraction, and progress tracking via Completers

import 'dart:async';

import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:path/path.dart' as p;
import 'package:pro_video_editor/pro_video_editor.dart';

/// Result of a clip split operation containing both resulting clips
class SplitClipResult {
  const SplitClipResult({
    required this.startClip,
    required this.endClip,
    required this.startClipPath,
    required this.endClipPath,
  });

  final RecordingClip startClip;
  final RecordingClip endClip;
  final String startClipPath;
  final String endClipPath;
}

/// Service for splitting video clips into two separate segments
class VideoEditorSplitService {
  static const minClipDuration = Duration(milliseconds: 30);

  /// Validates if the split position is valid for the given clip.
  ///
  /// Both resulting clips must meet the minimum duration requirement.
  static bool isValidSplitPosition(RecordingClip clip, Duration splitPosition) {
    return splitPosition >= minClipDuration &&
        clip.duration - splitPosition >= minClipDuration;
  }

  /// Splits a clip at the specified position and returns both resulting clips
  ///
  /// This method:
  /// 1. Creates two new clip objects with completers for tracking processing
  /// 2. Generates output paths in the cache directory
  /// 3. Calls onClipsCreated callback to add clips to UI BEFORE rendering
  /// 4. Extracts thumbnail for the end clip
  /// 5. Renders both clips in parallel
  ///
  /// Throws if rendering fails or split position is invalid
  static Future<SplitClipResult> splitClip({
    required RecordingClip sourceClip,
    required Duration splitPosition,
    required void Function(RecordingClip startClip, RecordingClip endClip)?
    onClipsCreated,
    required void Function(RecordingClip clip, String thumbnailPath)?
    onThumbnailExtracted,
    required void Function(RecordingClip clip, EditorVideo video)?
    onClipRendered,
  }) async {
    if (!isValidSplitPosition(sourceClip, splitPosition)) {
      Log.error(
        '❌ Invalid split position: ${splitPosition.inSeconds}s '
        '(clip: ${sourceClip.duration.inSeconds}s, '
        'min: ${minClipDuration.inMilliseconds}ms)',
        name: 'VideoEditorSplitService',
        category: .video,
      );
      throw ArgumentError(
        'Split position $splitPosition is invalid. '
        'Both clips must be at least $minClipDuration.',
      );
    }

    Log.info(
      '✂️ Starting clip split at ${splitPosition.inSeconds}s '
      '(total: ${sourceClip.duration.inSeconds}s)',
      name: 'VideoEditorSplitService',
      category: .video,
    );

    final timestamp = DateTime.now();
    final timestampMs = timestamp.microsecondsSinceEpoch;
    final startClipId = '${timestampMs}_start';
    final endClipId = '${timestampMs}_end';

    final startClip = sourceClip.copyWith(
      id: startClipId,
      duration: splitPosition,
      processingCompleter: Completer<bool>(),
    );
    final endClip = sourceClip.copyWith(
      id: endClipId,
      duration: sourceClip.duration - splitPosition,
      processingCompleter: Completer<bool>(),
    );

    final documentsPath = await getDocumentsPath();
    final startClipPath = p.join(documentsPath, '${startClipId}_start.mp4');
    final endClipPath = p.join(documentsPath, '${endClipId}_end.mp4');

    Log.debug(
      '📁 Created split clips - Start: ${splitPosition.inSeconds}s, '
      'End: ${endClip.duration.inSeconds}s',
      name: 'VideoEditorSplitService',
      category: .video,
    );

    // Notify that clips are created (so they can be added to UI before
    // rendering)
    onClipsCreated?.call(startClip, endClip);

    // Extract thumbnail for the end clip
    await _extractThumbnailForClip(
      sourceClip,
      splitPosition,
      endClip,
      onThumbnailExtracted,
    );

    Log.debug(
      '🎬 Starting parallel render of both clips',
      name: 'VideoEditorSplitService',
      category: .video,
    );
    // Render both clips in parallel
    await Future.wait([
      _renderSplitClip(
        clip: startClip,
        outputPath: startClipPath,
        sourceVideo: sourceClip.video,
        renderData: VideoRenderData(
          id: startClip.id,
          video: sourceClip.video,
          endTime: splitPosition,
        ),
        onClipRendered: onClipRendered,
      ),
      _renderSplitClip(
        clip: endClip,
        outputPath: endClipPath,
        sourceVideo: sourceClip.video,
        renderData: VideoRenderData(
          id: endClip.id,
          video: sourceClip.video,
          startTime: splitPosition,
        ),
        onClipRendered: onClipRendered,
      ),
    ]);

    Log.info(
      '✅ Split complete - created 2 clips from ${sourceClip.id}',
      name: 'VideoEditorSplitService',
      category: .video,
    );

    return SplitClipResult(
      startClip: startClip,
      endClip: endClip,
      startClipPath: startClipPath,
      endClipPath: endClipPath,
    );
  }

  /// Extract a thumbnail for the split clip at the specified timestamp.
  static Future<void> _extractThumbnailForClip(
    RecordingClip sourceClip,
    Duration timestamp,
    RecordingClip targetClip,
    void Function(RecordingClip clip, String thumbnailPath)?
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

  /// Render a single split clip segment to file.
  static Future<void> _renderSplitClip({
    required RecordingClip clip,
    required String outputPath,
    required EditorVideo sourceVideo,
    required VideoRenderData renderData,
    required void Function(RecordingClip clip, EditorVideo video)?
    onClipRendered,
  }) async {
    try {
      Log.debug(
        '🎞️ Rendering ${clip.id} (${clip.duration.inSeconds}s) to $outputPath',
        name: 'VideoEditorSplitService',
        category: .video,
      );

      await Future.wait([
        ProVideoEditor.instance.renderVideoToFile(outputPath, renderData),
        // On newer devices, the split operation completes extremely fast. For
        // that we add a short delay to ensure the progress animation shows
        // to complete to the user. Without that it will look like a
        // flickering issue.
        Future.delayed(const Duration(milliseconds: 300)),
      ]);

      Log.info(
        '✅ Render complete: ${clip.id}',
        name: 'VideoEditorSplitService',
        category: .video,
      );

      clip.processingCompleter?.complete(true);
      onClipRendered?.call(clip, EditorVideo.file(outputPath));
    } on RenderCanceledException {
      Log.info(
        '🚫 Render cancelled: ${clip.id}',
        name: 'VideoEditorSplitService',
        category: .video,
      );
      clip.processingCompleter?.complete(false);
      rethrow;
    } catch (e) {
      Log.error(
        '❌ Render failed for ${clip.id}: $e',
        name: 'VideoEditorSplitService',
        category: .video,
      );
      clip.processingCompleter?.complete(false);
      rethrow;
    }
  }
}
