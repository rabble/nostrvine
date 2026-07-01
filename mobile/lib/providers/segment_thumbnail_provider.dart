// ABOUTME: Per-segment cover frames for a 60s series before it is split.
// ABOUTME: Pulls a frame from the shared rendered clip at each segment window.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/providers/series_metadata_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:openvine/services/video_thumbnail_service.dart';

/// Resolves the cover-image path for series segment [index].
///
/// Segments are not rendered into separate files until publish, so each
/// segment's cover is a frame pulled from the shared rendered clip at the
/// segment's own time window. Segment 0 reuses the clip's existing thumbnail
/// (the frame the renderer already produced). A user-picked
/// [SegmentMetadata.thumbnailTimestamp] (offset within the segment) overrides
/// the default first-frame position.
///
/// Keyed by segment index and kept alive on success so switching back to a tab
/// shows its cover instantly. Re-runs when the rendered clip changes.
final FutureProviderFamily<String?, int> segmentThumbnailProvider =
    FutureProvider.autoDispose.family<String?, int>((ref, index) async {
      final clip = ref.watch(
        videoEditorProvider.select((s) => s.finalRenderedClip),
      );
      if (clip == null) return null;

      final windows = VideoEditorRenderService.computeSegmentWindows(
        totalDuration: clip.duration,
        maxSegmentDuration: VideoEditorConstants.maxDuration,
      );
      if (index < 0 || index >= windows.length) return null;
      final window = windows[index];

      final pickedOffset = ref.watch(
        seriesMetadataProvider.select(
          (s) => index < s.segments.length
              ? s.segments[index].thumbnailTimestamp
              : null,
        ),
      );

      // Segment 0 with no custom pick reuses the renderer's own thumbnail.
      if (index == 0 && pickedOffset == null) return clip.thumbnailPath;

      final frameOffset =
          pickedOffset ?? VideoEditorConstants.defaultThumbnailExtractTime;
      final target = window.start + frameOffset;

      final videoPath = await clip.video.safeFilePath();
      final result = await VideoThumbnailService.extractThumbnail(
        videoPath: videoPath,
        targetTimestamp: target,
      );

      final path = result?.path ?? clip.thumbnailPath;
      if (path != null) ref.keepAlive();
      return path;
    });
