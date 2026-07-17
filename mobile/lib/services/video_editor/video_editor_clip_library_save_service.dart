// ABOUTME: Flattens one timeline clip into a standalone file for the clip library
// ABOUTME: Bakes trim/speed/volume plus the overlays over it into a fresh documents-dir clip

import 'dart:typed_data';

import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/editor_overlay_snapshot.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:pro_image_editor/pro_image_editor.dart' show CompleteParameters;
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;
import 'package:unified_logger/unified_logger.dart';

/// Service for saving a single timeline clip to the persistent clip library.
class VideoEditorClipLibrarySaveService {
  /// Renders [clip]'s trim window into a standalone file and returns it as a
  /// fresh [DivineVideoClip] ready to hand to the clip library.
  ///
  /// Unlike the editor's own trim-based split (which keeps both halves on the
  /// shared source file), a library clip must outlive the editing session that
  /// produced it and be insertable into an unrelated project. So this re-encodes
  /// rather than carrying a trim window: the output holds *only* the selected
  /// section, and the returned clip carries no residual trim/speed/volume — the
  /// [VideoEditorRenderService.renderVideo] pipeline bakes all three in. That is
  /// what lets the user reuse a moment from a long video without dragging the
  /// whole source along (#5322).
  ///
  /// `reversed` is deliberately dropped rather than copied: a reversed clip's
  /// `video` already points at reversed content, so the flattened file is
  /// reversed too and re-flagging it would double-apply on the next render.
  ///
  /// The render is uncapped (`maxOutputDuration: null`) because a library clip
  /// is an intermediate clip the user can still trim, not a final export — the
  /// same reasoning as `VideoEditorMergeService.mergeClips`.
  ///
  /// [overlays] are the layers/filters/tune/blur that were over *this clip*,
  /// already windowed and rebased to start at zero by
  /// [EditorOverlaySnapshot.windowedTo]. They get baked into the output too, so
  /// the saved clip looks the way it looked on the timeline. Pass `null` (or an
  /// empty snapshot) to render the bare video.
  ///
  /// [renderId] keys the native progress/cancel stream.
  ///
  /// Returns `null` when the render is cancelled or fails — both already
  /// surface as a `null` output path from [VideoEditorRenderService.renderVideo].
  static Future<DivineVideoClip?> flattenClipForLibrary({
    required DivineVideoClip clip,
    required String renderId,
    EditorOverlaySnapshot? overlays,
  }) async {
    Log.info(
      '💾 Flattening clip ${clip.id} for the clip library '
      '(${overlays?.capturedLayers.length ?? 0} layer(s), '
      '${overlays?.filterStates.length ?? 0} filter(s))',
      name: 'VideoEditorClipLibrarySaveService',
      category: LogCategory.video,
    );

    // usePersistentStorage writes into the documents dir, which the library
    // requires: it persists only a basename and resolves it back against
    // getDocumentsPath(), so a temp-dir file would save and then dangle.
    final outputPath = await VideoEditorRenderService.renderVideo(
      // A transition describes a boundary with the *next* clip, which this
      // render doesn't have — leaving it on would blend the clip into nothing.
      clips: [clip.copyWith(clearTransition: true)],
      usePersistentStorage: true,
      taskId: renderId,
      maxOutputDuration: null,
      parameters: _renderParameters(overlays),
    );

    if (outputPath == null) return null;

    final thumbnail = await _extractThumbnail(outputPath);

    return DivineVideoClip(
      id: 'clip_library_${DateTime.now().microsecondsSinceEpoch}',
      video: EditorVideo.file(outputPath),
      duration: clip.playbackDuration,
      recordedAt: clip.recordedAt,
      targetAspectRatio: clip.targetAspectRatio,
      originalAspectRatio: clip.originalAspectRatio,
      // Fall back to the source clip's frame when extraction fails; a library
      // card without any thumbnail is worse than a slightly-off one.
      thumbnailPath: thumbnail?.path ?? clip.thumbnailPath,
      thumbnailTimestamp: thumbnail?.timestamp,
      lensMetadata: clip.lensMetadata,
    );
  }

  /// Wraps [overlays] in the [CompleteParameters] shape the render pipeline
  /// reads, or `null` when there is nothing to bake.
  ///
  /// Only the overlay fields are populated. Geometry (crop / rotate / flip) is
  /// deliberately left at its defaults: a clip's own spatial transform is
  /// already baked into its file by the transform action, and the aspect-ratio
  /// crop comes from the clip's `targetAspectRatio` inside `renderVideo`.
  static CompleteParameters? _renderParameters(
    EditorOverlaySnapshot? overlays,
  ) {
    if (overlays == null || overlays.isEmpty) return null;

    return CompleteParameters(
      blur: overlays.blur,
      capturedLayers: overlays.capturedLayers,
      filterStates: overlays.filterStates,
      tuneAdjustments: overlays.tuneAdjustments,
      bodySize: overlays.bodySize,
      // The render pipeline reads none of the below for overlays; they are
      // required constructor args, so they carry inert defaults.
      matrixFilterList: const [],
      matrixTuneAdjustmentsList: const [],
      startTime: null,
      endTime: null,
      cropWidth: null,
      cropHeight: null,
      rotateTurns: 0,
      cropX: null,
      cropY: null,
      flipX: false,
      flipY: false,
      image: Uint8List(0),
      isTransformed: false,
      layers: const [],
      originalImageSize: null,
      temporaryDecodedImageSize: null,
      editorSize: null,
    );
  }

  /// Extracts a representative frame from the freshly rendered [videoPath].
  ///
  /// The source clip's own thumbnail can point at a frame the trim window
  /// excludes, and its timestamp is measured against the source timeline — both
  /// meaningless for the flattened file, which starts at zero.
  static Future<ThumbnailFileResult?> _extractThumbnail(
    String videoPath,
  ) async {
    try {
      return await VideoThumbnailService.extractThumbnail(videoPath: videoPath);
    } catch (e, stackTrace) {
      Log.error(
        '❌ Failed to extract library-clip thumbnail: $e',
        name: 'VideoEditorClipLibrarySaveService',
        category: LogCategory.video,
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}
