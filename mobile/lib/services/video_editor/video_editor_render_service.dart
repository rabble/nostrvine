// ABOUTME: Service for rendering final videos from multiple clips
// ABOUTME: Handles aspect ratio cropping, clip concatenation, and export transformation

import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

/// Service for rendering final video from multiple clips.
///
/// Handles video rendering with aspect ratio cropping and clip concatenation.
class VideoEditorRenderService {
  VideoEditorRenderService._();

  /// Renders multiple clips into a single video file with aspect ratio cropping.
  ///
  /// Returns the path to the rendered video file, or null if cancelled/failed.
  static Future<String?> renderVideo({
    required List<RecordingClip> clips,
    required model.AspectRatio aspectRatio,
    required bool enableAudio,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final outputPath =
          '${tempDir.path}/divine_${DateTime.now().microsecondsSinceEpoch}.mp4';

      Log.debug(
        '🎞️ Rendering ${clips.length} clip(s) to final video',
        name: 'VideoEditorRenderService',
        category: .video,
      );

      // Wait for all clips to finish processing
      for (final clip in clips) {
        await clip.processingCompleter?.future;
      }

      final videoSegments = clips
          .map((clip) => VideoSegment(video: clip.video))
          .toList();

      // Get metadata from first clip to determine resolution
      final metaData = await ProVideoEditor.instance.getMetadata(
        videoSegments.first.video,
      );
      final resolution = metaData.resolution;

      // Calculate crop parameters based on aspect ratio
      final cropParams = _calculateCropParameters(
        resolution: resolution,
        targetAspectRatio: aspectRatio,
      );

      Log.debug(
        '🎯 Crop: x=${cropParams.x}, y=${cropParams.y}, '
        'w=${cropParams.width}, h=${cropParams.height}',
        name: 'VideoEditorRenderService',
        category: .video,
      );

      final task = VideoRenderData(
        id: clips.first.id,
        videoSegments: videoSegments,
        endTime: VideoEditorConstants.maxDuration,
        enableAudio: enableAudio,
        shouldOptimizeForNetworkUse: true,
        transform: ExportTransform(
          x: cropParams.x,
          y: cropParams.y,
          width: cropParams.width,
          height: cropParams.height,
        ),
      );

      await ProVideoEditor.instance.renderVideoToFile(outputPath, task);

      Log.info(
        '✅ Video file rendered to: $outputPath',
        name: 'VideoEditorRenderService',
        category: .video,
      );

      return outputPath;
    } on RenderCanceledException {
      Log.info(
        '🚫 Video render cancelled by user',
        name: 'VideoEditorRenderService',
        category: .video,
      );
      return null;
    } catch (e) {
      Log.error(
        '❌ Video render failed: $e',
        name: 'VideoEditorRenderService',
        category: .video,
      );
      return null;
    }
  }

  static Future limitClipDuration({
    required RecordingClip clip,
    required Duration duration,
    required ValueChanged<bool> onComplete,
  }) async {
    try {
      final inputPath = await clip.video.safeFilePath();

      // Write to a new temporary file to avoid file locking issues
      final tempDir = await getTemporaryDirectory();
      final outputPath =
          '${tempDir.path}/trimmed_${DateTime.now().microsecondsSinceEpoch}.mp4';

      await ProVideoEditor.instance.renderVideoToFile(
        outputPath,
        VideoRenderData(video: clip.video, endTime: duration),
      );

      // Replace original file with trimmed version
      final inputFile = File(inputPath);
      final outputFile = File(outputPath);

      if (await outputFile.exists()) {
        await inputFile.delete();
        await outputFile.rename(inputPath);
      }

      onComplete(true);
    } catch (e, stack) {
      Log.error(
        '❌ Failed to limit clip duration: $e',
        name: 'VideoEditorRenderService',
        category: .video,
      );
      CrashReportingService.instance.recordError(
        e,
        stack,
        reason: 'limitClipDuration failed',
      );
      onComplete(false);
    }
  }

  /// Calculates crop parameters for the target aspect ratio.
  static ({int x, int y, int width, int height}) _calculateCropParameters({
    required Size resolution,
    required model.AspectRatio targetAspectRatio,
  }) {
    final double cropX, cropY, cropWidth, cropHeight;

    switch (targetAspectRatio) {
      case .square:
        // Center crop to 1:1 (minimum dimension)
        final minDimension = resolution.width < resolution.height
            ? resolution.width
            : resolution.height;
        cropWidth = minDimension;
        cropHeight = minDimension;
        cropX = (resolution.width - cropWidth) / 2;
        cropY = (resolution.height - cropHeight) / 2;

      case .vertical:
        // Center crop to 9:16 (portrait)
        final inputAspectRatio = resolution.width / resolution.height;
        const targetRatio = 9.0 / 16.0;

        if (inputAspectRatio > targetRatio) {
          // Input is wider than 9:16 - crop width, keep height
          cropHeight = resolution.height;
          cropWidth = cropHeight * targetRatio;
          cropX = (resolution.width - cropWidth) / 2;
          cropY = 0;
        } else {
          // Input is taller than 9:16 - keep width, crop height
          cropWidth = resolution.width;
          cropHeight = cropWidth / targetRatio;
          cropX = 0;
          cropY = (resolution.height - cropHeight) / 2;
        }
    }

    return (
      x: cropX.round(),
      y: cropY.round(),
      width: cropWidth.round(),
      height: cropHeight.round(),
    );
  }
}
