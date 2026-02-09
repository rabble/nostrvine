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
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

/// Result of normalizing clips to a target aspect ratio.
class _NormalizationResult {
  const _NormalizationResult({
    required this.segments,
    required this.tempFilePaths,
    this.globalTransform,
  });

  /// The video segments ready for concatenation.
  final List<VideoSegment> segments;

  /// Paths to temporary files that should be cleaned up after rendering.
  final List<String> tempFilePaths;

  /// Global crop transform to apply during concatenation (if all clips match).
  final _CropParameters? globalTransform;
}

/// Analysis result for a single clip.
class _ClipAnalysisEntry {
  const _ClipAnalysisEntry({
    required this.clip,
    required this.resolution,
    required this.cropParams,
  });

  final RecordingClip clip;
  final Size resolution;
  final _CropParameters cropParams;
}

/// Analysis of all clips for optimal rendering strategy.
class _ClipAnalysis {
  const _ClipAnalysis({required this.entries});

  final List<_ClipAnalysisEntry> entries;

  /// True if all clips have identical crop parameters.
  bool get allSameCropParams {
    if (entries.isEmpty) return true;
    final first = entries.first.cropParams;
    return entries.every(
      (e) =>
          e.cropParams.x == first.x &&
          e.cropParams.y == first.y &&
          e.cropParams.width == first.width &&
          e.cropParams.height == first.height,
    );
  }
}

/// Crop parameters for aspect ratio transformation.
class _CropParameters {
  const _CropParameters({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  /// Creates crop parameters for the given aspect ratio.
  factory _CropParameters.forAspectRatio({
    required Size resolution,
    required model.AspectRatio aspectRatio,
  }) {
    return switch (aspectRatio) {
      model.AspectRatio.square => _CropParameters.squareCrop(resolution),
      model.AspectRatio.vertical => _CropParameters.verticalCrop(resolution),
    };
  }

  /// Creates crop parameters from a resolution for a centered square crop.
  factory _CropParameters.squareCrop(Size resolution) {
    final minDimension = resolution.width < resolution.height
        ? resolution.width
        : resolution.height;

    return _CropParameters(
      x: ((resolution.width - minDimension) / 2).round(),
      y: ((resolution.height - minDimension) / 2).round(),
      width: minDimension.round(),
      height: minDimension.round(),
    );
  }

  /// Creates crop parameters from a resolution for a centered 9:16 vertical crop.
  factory _CropParameters.verticalCrop(Size resolution) {
    final inputAspectRatio = resolution.width / resolution.height;
    const targetRatio = 9.0 / 16.0;

    final double cropX, cropY, cropWidth, cropHeight;

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

    return _CropParameters(
      x: cropX.round(),
      y: cropY.round(),
      width: cropWidth.round(),
      height: cropHeight.round(),
    );
  }

  /// Horizontal offset for cropping.
  final int x;

  /// Vertical offset for cropping.
  final int y;

  /// Width of the cropped area.
  final int width;

  /// Height of the cropped area.
  final int height;

  /// Whether cropping is needed based on the original resolution.
  bool needsCropping(Size resolution) {
    return x != 0 ||
        y != 0 ||
        width != resolution.width.round() ||
        height != resolution.height.round();
  }

  /// Converts to [ExportTransform] for video rendering.
  ExportTransform toExportTransform() {
    return ExportTransform(x: x, y: y, width: width, height: height);
  }

  @override
  String toString() => '($x, $y, ${width}x$height)';
}

/// Service for rendering final video from multiple clips.
///
/// Handles video rendering with aspect ratio cropping and clip concatenation.
class VideoEditorRenderService {
  VideoEditorRenderService._();

  static const _logName = 'VideoEditorRenderService';

  // ─────────────────────────────────────────────────────────────────────────
  // Public API
  // ─────────────────────────────────────────────────────────────────────────

  /// Renders multiple clips into a single video file with aspect ratio cropping.
  ///
  /// Returns the path to the rendered video file, or null if cancelled/failed.
  static Future<String?> renderVideo({
    required List<RecordingClip> clips,
    model.AspectRatio? aspectRatio,
    bool enableAudio = true,
    CompleteParameters? parameters,
    String? taskId,
  }) async {
    final tempDir = await getTemporaryDirectory();
    var tempFilePaths = <String>[];

    try {
      Log.debug(
        '🎞️ Rendering ${clips.length} clip(s) to final video',
        name: _logName,
        category: .video,
      );

      // Wait all clips finish processing
      for (final clip in clips) {
        await clip.processingCompleter?.future;
      }

      final result = await _normalizeClipsToAspectRatio(
        clips: clips,
        aspectRatio: aspectRatio ?? clips.first.targetAspectRatio,
        enableAudio: enableAudio,
        tempDir: tempDir,
        parameters: parameters,
      );
      tempFilePaths = result.tempFilePaths;

      final outputPath = await _concatenateSegments(
        segments: result.segments,
        taskId: taskId ?? clips.first.id,
        enableAudio: enableAudio,
        tempDir: tempDir,
        globalTransform: result.globalTransform,
        parameters: parameters,
      );

      // Fire-and-forget: temp cleanup is non-critical and handles
      // errors internally
      unawaited(_cleanupTempFiles(tempFilePaths));

      Log.info(
        '✅ Video file rendered to: $outputPath',
        name: _logName,
        category: .video,
      );

      return outputPath;
    } on RenderCanceledException {
      Log.info(
        '🚫 Video render cancelled by user',
        name: _logName,
        category: .video,
      );
      unawaited(_cleanupTempFiles(tempFilePaths));
      return null;
    } catch (e) {
      Log.error('❌ Video render failed: $e', name: _logName, category: .video);
      unawaited(_cleanupTempFiles(tempFilePaths));
      return null;
    }
  }

  /// Limits a clip's duration to a specified length.
  static Future limitClipDuration({
    required RecordingClip clip,
    required Duration duration,
    required ValueChanged<bool> onComplete,
  }) async {
    try {
      final inputPath = await clip.video.safeFilePath();

      // Write to a new temporary file to avoid file locking issues
      final tempDir = await getTemporaryDirectory();
      final outputPath = path.join(
        tempDir.path,
        'trimmed_${DateTime.now().microsecondsSinceEpoch}.mp4',
      );

      await ProVideoEditor.instance.renderVideoToFile(
        outputPath,
        VideoRenderData(video: clip.video, endTime: duration),
      );

      // Replace original file with trimmed version
      final inputFile = File(inputPath);
      final outputFile = File(outputPath);

      if (outputFile.existsSync()) {
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

  /// Crops a video to the specified aspect ratio.
  ///
  /// Returns the path to the cropped video file, or the original path if no
  /// cropping is needed.
  static Future<String> cropToAspectRatio({
    required EditorVideo video,
    required model.AspectRatio aspectRatio,
    bool enableAudio = true,
    VideoMetadata? metadata,
  }) async {
    metadata ??= await ProVideoEditor.instance.getMetadata(video);
    final resolution = metadata.resolution;
    final cropParams = _CropParameters.forAspectRatio(
      resolution: resolution,
      aspectRatio: aspectRatio,
    );

    // No cropping needed if video already matches target aspect ratio
    if (!cropParams.needsCropping(resolution)) {
      Log.debug(
        '⏭️ Video already matches target aspect ratio - no crop needed',
        name: _logName,
        category: .video,
      );
      return await video.safeFilePath();
    }

    Log.debug(
      '✂️ Cropping video from ${resolution.width.round()}x${resolution.height.round()} '
      'to ${cropParams.width}x${cropParams.height}',
      name: _logName,
      category: .video,
    );

    final tempDir = await getTemporaryDirectory();
    final outputPath = path.join(
      tempDir.path,
      'cropped_${DateTime.now().microsecondsSinceEpoch}.mp4',
    );

    final task = VideoRenderData(
      video: video,
      enableAudio: enableAudio,
      shouldOptimizeForNetworkUse: true,
      transform: cropParams.toExportTransform(),
    );

    await ProVideoEditor.instance.renderVideoToFile(outputPath, task);

    Log.debug(
      '✅ Video cropped to: $outputPath',
      name: _logName,
      category: .video,
    );

    return outputPath;
  }

  /// Normalizes all clips to the target aspect ratio.
  ///
  /// Optimizes rendering by:
  /// - Using a single global transform if all clips have the same resolution
  /// - Only pre-rendering clips that differ from the majority
  ///
  /// Returns video segments ready for concatenation and temp file paths for cleanup.
  static Future<_NormalizationResult> _normalizeClipsToAspectRatio({
    required List<RecordingClip> clips,
    required model.AspectRatio aspectRatio,
    required bool enableAudio,
    required Directory tempDir,
    required CompleteParameters? parameters,
  }) async {
    // Analyze all clips first to determine the optimal rendering strategy
    final clipAnalysis = await _analyzeClips(clips, aspectRatio);

    // If all clips have the same crop params, use global transform (most efficient)
    if (clipAnalysis.allSameCropParams) {
      Log.debug(
        '⚡ All ${clips.length} clips have identical resolution - using global transform',
        name: _logName,
        category: .video,
      );
      return _NormalizationResult(
        segments: clips.map((c) => VideoSegment(video: c.video)).toList(),
        tempFilePaths: [],
        globalTransform:
            clipAnalysis.entries.first.cropParams.needsCropping(
              clipAnalysis.entries.first.resolution,
            )
            ? clipAnalysis.entries.first.cropParams
            : null,
      );
    }

    // Mixed resolutions: normalize clips that differ from the target
    Log.debug(
      '🔄 Mixed resolutions detected - normalizing individual clips',
      name: _logName,
      category: .video,
    );

    final segments = <VideoSegment>[];
    final tempFilePaths = <String>[];

    for (int i = 0; i < clips.length; i++) {
      final entry = clipAnalysis.entries[i];
      final needsCrop = entry.cropParams.needsCropping(entry.resolution);

      Log.debug(
        '🎯 Clip ${entry.clip.id}: ${entry.resolution.width.round()}x${entry.resolution.height.round()}, '
        'crop: ${entry.cropParams}, needsCrop: $needsCrop',
        name: _logName,
        category: .video,
      );

      if (!needsCrop) {
        segments.add(VideoSegment(video: entry.clip.video));
      } else {
        final normalizedPath = await _renderNormalizedClip(
          clip: entry.clip,
          index: i,
          cropParams: entry.cropParams,
          enableAudio: enableAudio,
          tempDir: tempDir,
          parameters: parameters,
        );
        tempFilePaths.add(normalizedPath);
        segments.add(
          VideoSegment(video: EditorVideo.file(File(normalizedPath))),
        );
      }
    }

    return _NormalizationResult(
      segments: segments,
      tempFilePaths: tempFilePaths,
    );
  }

  /// Analyzes all clips to determine their crop parameters.
  static Future<_ClipAnalysis> _analyzeClips(
    List<RecordingClip> clips,
    model.AspectRatio aspectRatio,
  ) async {
    final entries = <_ClipAnalysisEntry>[];

    for (final clip in clips) {
      final metaData = await ProVideoEditor.instance.getMetadata(clip.video);
      final resolution = metaData.resolution;
      final cropParams = _CropParameters.forAspectRatio(
        resolution: resolution,
        aspectRatio: aspectRatio,
      );
      entries.add(
        _ClipAnalysisEntry(
          clip: clip,
          resolution: resolution,
          cropParams: cropParams,
        ),
      );
    }

    return _ClipAnalysis(entries: entries);
  }

  /// Renders a single clip with crop transform to normalize its aspect ratio.
  static Future<String> _renderNormalizedClip({
    required RecordingClip clip,
    required int index,
    required _CropParameters cropParams,
    required bool enableAudio,
    required Directory tempDir,
    required CompleteParameters? parameters,
  }) async {
    final outputPath =
        '${tempDir.path}/normalized_${index}_${DateTime.now().microsecondsSinceEpoch}.mp4';

    final task = VideoRenderData(
      id: '${clip.id}_normalized',
      video: clip.video,
      enableAudio: enableAudio,
      shouldOptimizeForNetworkUse: true,
      imageBytes: parameters?.layers.isNotEmpty == true
          ? parameters?.image
          : null,
      blur: parameters?.blur,
      colorMatrixList: parameters?.colorFilters ?? [],
      transform: ExportTransform(
        x: cropParams.x,
        y: cropParams.y,
        width: cropParams.width,
        height: cropParams.height,
        flipX: parameters?.flipX ?? false,
        flipY: parameters?.flipY ?? false,
        rotateTurns: parameters?.rotateTurns ?? 0,
      ),
    );

    await ProVideoEditor.instance.renderVideoToFile(outputPath, task);

    Log.debug(
      '✅ Clip ${clip.id} normalized to: $outputPath',
      name: _logName,
      category: .video,
    );

    return outputPath;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Video Concatenation
  // ─────────────────────────────────────────────────────────────────────────

  /// Concatenates all video segments into a final output file.
  ///
  /// If [globalTransform] is provided, applies it to all segments in a single pass.
  static Future<String> _concatenateSegments({
    required List<VideoSegment> segments,
    required String taskId,
    required bool enableAudio,
    required Directory tempDir,
    _CropParameters? globalTransform,
    required CompleteParameters? parameters,
  }) async {
    final outputPath =
        '${tempDir.path}/divine_${DateTime.now().microsecondsSinceEpoch}.mp4';

    final task = VideoRenderData(
      id: taskId,
      videoSegments: segments,
      endTime: VideoEditorConstants.maxDuration,
      enableAudio: enableAudio,
      shouldOptimizeForNetworkUse: true,
      imageBytes: parameters?.layers.isNotEmpty == true
          ? parameters?.image
          : null,
      blur: parameters?.blur,
      colorMatrixList: parameters?.colorFilters ?? [],
      transform: globalTransform != null
          ? ExportTransform(
              x: globalTransform.x,
              y: globalTransform.y,
              width: globalTransform.width,
              height: globalTransform.height,
              flipX: parameters?.flipX ?? false,
              flipY: parameters?.flipY ?? false,
              rotateTurns: parameters?.rotateTurns ?? 0,
            )
          : null,
    );

    await ProVideoEditor.instance.renderVideoToFile(outputPath, task);

    return outputPath;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Cleanup
  // ─────────────────────────────────────────────────────────────────────────

  /// Cleans up temporary normalized clip files.
  static Future<void> _cleanupTempFiles(List<String> paths) async {
    for (final path in paths) {
      try {
        final file = File(path);
        if (file.existsSync()) {
          await file.delete();
          Log.debug(
            '🗑️ Deleted temp file: $path',
            name: _logName,
            category: .video,
          );
        }
      } catch (e) {
        Log.warning(
          '⚠️ Failed to delete temp file: $path - $e',
          name: _logName,
          category: .video,
        );
      }
    }
  }
}
