// ABOUTME: Lazily renders one 60s-series segment into a standalone clip.
// ABOUTME: Backs the full-screen preview and cover picker for a single segment.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

/// Resolves segment [index] of the rendered clip as its own [DivineVideoClip].
///
/// The full-screen preview and cover picker play/scrub a real video file, so a
/// series segment must be rendered into its own file first — extracting a
/// window on the fly is not enough. Single-video recordings (one window) return
/// the shared rendered clip unchanged, avoiding a needless render.
///
/// Rendered files are kept alive per segment for the session so re-opening a
/// segment is instant; the family re-runs when the rendered clip changes.
final FutureProviderFamily<DivineVideoClip?, int> segmentClipProvider =
    FutureProvider.autoDispose.family<DivineVideoClip?, int>((
      ref,
      index,
    ) async {
      final clip = ref.watch(
        videoEditorProvider.select((s) => s.finalRenderedClip),
      );
      if (clip == null) return null;

      final windows = VideoEditorRenderService.computeSegmentWindows(
        totalDuration: clip.duration,
        maxSegmentDuration: VideoEditorConstants.maxDuration,
      );
      // Not a series (a single window) — the full clip is the segment.
      if (windows.length <= 1 || index < 0 || index >= windows.length) {
        return clip;
      }
      final window = windows[index];

      // Keep the entry alive before the first await so an off-screen
      // `ref.read(...future)` (from a preview/cover tap) can't dispose the
      // provider mid-render and cancel the work.
      ref.keepAlive();

      final sourcePath = await clip.video.safeFilePath();
      final segmentPath = await VideoEditorRenderService.renderSegmentToFile(
        sourcePath: sourcePath,
        start: window.start,
        end: window.end,
      );
      final thumbnail = await VideoThumbnailService.extractThumbnail(
        videoPath: segmentPath,
      );

      return clip.copyWith(
        video: EditorVideo.file(segmentPath),
        duration: window.end - window.start,
        thumbnailPath: thumbnail?.path ?? clip.thumbnailPath,
      );
    });
