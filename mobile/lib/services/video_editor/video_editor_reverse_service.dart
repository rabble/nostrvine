import 'dart:io';

import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:path/path.dart' as p;
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

/// Service for rendering a reversed clip to a new local file.
class VideoEditorReverseService {
  /// Renders the full clip in reverse.
  ///
  /// Callers keep trim bounds in state and derive the visible segment from the
  /// reversed source file instead of baking the trim into the output file.
  static Future<EditorVideo> reverseClip({
    required DivineVideoClip sourceClip,
    required String renderId,
  }) async {
    final documentsPath = await getDocumentsPath();
    final inputPath = await sourceClip.video.safeFilePath();
    final outputPath = p.join(
      documentsPath,
      '${sourceClip.id}_reversed.mp4',
    );

    // Defensive: refuse to render when the input path collides with the
    // output path. We delete the output file before rendering, so a collision
    // would destroy the source video in-place.
    if (p.equals(inputPath, outputPath)) {
      throw StateError(
        'Reverse render aborted: input path equals output path ($inputPath)',
      );
    }

    final outputFile = File(outputPath);

    Log.info(
      '🔄 Rendering reversed clip ${sourceClip.id} to $outputPath',
      name: 'VideoEditorReverseService',
      category: LogCategory.video,
    );

    try {
      try {
        await ProVideoEditor.instance.cancel(renderId);
      } catch (e) {
        Log.debug(
          '⏹️ Reverse cancel returned for $renderId: $e',
          name: 'VideoEditorReverseService',
          category: LogCategory.video,
        );
      }

      if (outputFile.existsSync()) {
        await outputFile.delete();
        Log.debug(
          '🗑️ Deleted stale reverse output: $outputPath',
          name: 'VideoEditorReverseService',
          category: LogCategory.video,
        );
      }

      await ProVideoEditor.instance.renderVideoToFile(
        outputPath,
        VideoRenderData(
          id: renderId,
          videoSegments: [
            VideoSegment(
              video: EditorVideo.file(inputPath),
              reverseVideo: true,
            ),
          ],
        ),
      );
    } catch (e) {
      if (outputFile.existsSync()) {
        try {
          await outputFile.delete();
        } catch (deleteError) {
          Log.warning(
            '⚠️ Failed to delete partial reverse output $outputPath: '
            '$deleteError',
            name: 'VideoEditorReverseService',
            category: LogCategory.video,
          );
        }
      }
      rethrow;
    }

    Log.info(
      '✅ Reverse render complete for ${sourceClip.id}',
      name: 'VideoEditorReverseService',
      category: LogCategory.video,
    );

    return EditorVideo.file(outputPath);
  }
}
