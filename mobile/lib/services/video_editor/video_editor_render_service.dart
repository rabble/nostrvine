// ABOUTME: Service for rendering final videos from multiple clips
// ABOUTME: Handles aspect ratio cropping, clip concatenation, and export transformation

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/aspect_ratio_extensions.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/services/native_proofmode_service.dart';
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

  final DivineVideoClip clip;
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

    final double cropX;
    final double cropY;
    final double cropWidth;
    final double cropHeight;

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

  /// Renders multiple clips into a [DivineVideoClip] ready for publishing.
  ///
  /// This is a convenience wrapper around [renderVideo] that also extracts
  /// metadata, generates ProofMode attestation, and creates a [DivineVideoClip].
  ///
  /// Returns a record containing:
  /// - The rendered [DivineVideoClip]
  /// - The proofManifestJson (or null if ProofMode unavailable)
  ///
  /// Returns null if rendering failed/cancelled.
  static Future<(DivineVideoClip, String? proofManifestJson)?>
  renderVideoToClip({
    required List<DivineVideoClip> clips,
    required Map<String, dynamic> editorStateHistory,
    double originalAudioVolume = 1.0,
    double customAudioVolume = 1.0,
    bool aiTrainingOptOut = true,
    CompleteParameters? parameters,
    String? taskId,
  }) async {
    if (clips.isEmpty) return null;

    Log.debug(
      '🎬 renderVideoToClip: clips=${clips.length}, '
      'originalAudioVolume=$originalAudioVolume, '
      'customAudioVolume=$customAudioVolume, '
      'parameters=${parameters?.toMap()}',
      name: _logName,
      category: LogCategory.video,
    );

    final outputPath = await renderVideo(
      clips: clips,
      aspectRatio: clips.first.targetAspectRatio,
      originalAudioVolume: originalAudioVolume,
      customAudioVolume: customAudioVolume,
      usePersistentStorage: true,
      parameters: parameters,
      taskId: taskId,
    );

    if (outputPath == null) return null;

    final metaData = await ProVideoEditor.instance.getMetadata(
      EditorVideo.file(outputPath),
    );

    // Generate ProofMode attestation
    Log.debug(
      '🔐 Generating proofmode attestation for video',
      name: _logName,
      category: LogCategory.video,
    );

    // Ensure all clips have proof attestations before generating the
    // final combined proof. Clips recorded before the feature was added
    // or where proof generation failed will be attested now.
    final attestedClips = await _ensureClipProofs(
      clips,
      aiTrainingOptOut: aiTrainingOptOut,
    );

    final proofData = await NativeProofModeService.proofFile(
      File(outputPath),
      aiTrainingOptOut: aiTrainingOptOut,
      clips: attestedClips,
      editorStateHistory: editorStateHistory,
    );
    final String? proofManifestJson = proofData != null
        ? jsonEncode(proofData)
        : null;

    if (proofManifestJson != null) {
      Log.info(
        '✅ Proofmode attestation generated',
        name: _logName,
        category: LogCategory.video,
      );
    } else {
      Log.warning(
        '⚠️ No proofmode data available',
        name: _logName,
        category: LogCategory.video,
      );
    }

    final clip = DivineVideoClip(
      id: 'clip-${DateTime.now()}',
      video: EditorVideo.file(outputPath),
      duration: metaData.duration,
      recordedAt: DateTime.now(),
      originalAspectRatio: clips.first.originalAspectRatio,
      targetAspectRatio: clips.first.targetAspectRatio,
      thumbnailPath: clips.first.thumbnailPath,
    );

    return (clip, proofManifestJson);
  }

  /// Ensures every clip has a [proofManifestJson].
  ///
  /// Clips that already have proof data are returned as-is. For clips without
  /// proof, [NativeProofModeService.proofFile] is called on the clip's video
  /// file and the clip is updated with the result.
  static Future<List<DivineVideoClip>> _ensureClipProofs(
    List<DivineVideoClip> clips, {
    required bool aiTrainingOptOut,
  }) async {
    final result = <DivineVideoClip>[];
    for (final clip in clips) {
      if (clip.proofManifestJson != null) {
        result.add(clip);
        continue;
      }

      final videoFile = clip.video.file;
      if (videoFile == null) {
        result.add(clip);
        continue;
      }

      Log.debug(
        '🔐 Generating missing proof for clip ${clip.id}',
        name: _logName,
        category: LogCategory.video,
      );

      final proofData = await NativeProofModeService.proofFile(
        File(videoFile.path),
        aiTrainingOptOut: aiTrainingOptOut,
      );

      if (proofData != null) {
        result.add(
          clip.copyWith(proofManifestJson: jsonEncode(proofData)),
        );
        Log.info(
          '✅ Backfilled proof for clip ${clip.id}',
          name: _logName,
          category: LogCategory.video,
        );
      } else {
        Log.warning(
          '⚠️ Could not generate proof for clip ${clip.id}',
          name: _logName,
          category: LogCategory.video,
        );
        result.add(clip);
      }
    }
    return result;
  }

  /// Renders multiple clips into a single video file with aspect ratio cropping.
  ///
  /// When [customAudioPath] is provided, the custom audio track is mixed into
  /// the output. Use [originalAudioVolume] (default 1.0) and
  /// [customAudioVolume] (default 1.0) to control relative levels.
  /// Set [originalAudioVolume] to 0.0 to mute the original audio entirely
  /// (e.g. when recording lip-sync without headphones).
  ///
  /// When [imageBytes] is provided (PNG with transparency), it is composited
  /// on top of the video as a watermark overlay.
  ///
  /// Returns the path to the rendered video file, or null if cancelled/failed.
  ///
  /// If [usePersistentStorage] is true, the output file will be saved to the
  /// documents directory instead of the temporary directory. Use this when
  /// the rendered video should persist across app restarts.
  static Future<String?> renderVideo({
    required List<DivineVideoClip> clips,
    double originalAudioVolume = 1.0,
    double customAudioVolume = 1.0,
    bool usePersistentStorage = false,
    model.AspectRatio? aspectRatio,
    CompleteParameters? parameters,
    String? taskId,
  }) async {
    final cacheDir = await getTemporaryDirectory();
    final outputDir = usePersistentStorage
        ? await getApplicationDocumentsDirectory()
        : cacheDir;
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

      // Intermediate normalized clips always go to cache (they get deleted)
      final result = await _normalizeClipsToAspectRatio(
        clips: clips,
        aspectRatio: aspectRatio ?? clips.first.targetAspectRatio,
        cacheDir: cacheDir,
        parameters: parameters,
      );
      tempFilePaths = result.tempFilePaths;

      final outputPath = await _concatenateSegments(
        segments: result.segments,
        taskId: taskId ?? clips.first.id,
        outputDir: outputDir,
        globalTransform: result.globalTransform,
        aspectRatio: aspectRatio ?? clips.first.targetAspectRatio,
        originalAudioVolume: originalAudioVolume,
        customAudioVolume: customAudioVolume,
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
    required DivineVideoClip clip,
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

      final taskId = DateTime.now().microsecondsSinceEpoch.toString();
      await _cancelAndRender(
        outputPath,
        VideoRenderData(
          id: taskId,
          videoSegments: [VideoSegment(video: clip.video)],
          endTime: duration,
        ),
      );

      // Replace original file with trimmed version
      final inputFile = File(inputPath);
      final outputFile = File(outputPath);

      if (outputFile.existsSync()) {
        await inputFile.delete();
        await outputFile.rename(inputPath);
      }

      onComplete(true);
    } on RenderCanceledException {
      Log.info(
        '🚫 Clip duration limit cancelled',
        name: 'VideoEditorRenderService',
        category: .video,
      );
      onComplete(false);
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
      return video.safeFilePath();
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
      videoSegments: [VideoSegment(video: video)],
      enableAudio: enableAudio,
      shouldOptimizeForNetworkUse: true,
      transform: cropParams.toExportTransform(),
    );

    await _cancelAndRender(outputPath, task);

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
    required List<DivineVideoClip> clips,
    required model.AspectRatio aspectRatio,
    required Directory cacheDir,
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
          tempDir: cacheDir,
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
    List<DivineVideoClip> clips,
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
    required DivineVideoClip clip,
    required int index,
    required _CropParameters cropParams,
    required Directory tempDir,
    required CompleteParameters? parameters,
  }) async {
    final outputPath = path.join(
      tempDir.path,
      'normalized_${index}_${DateTime.now().microsecondsSinceEpoch}.mp4',
    );

    final task = VideoRenderData(
      id: '${clip.id}_normalized',
      videoSegments: [VideoSegment(video: clip.video)],
      shouldOptimizeForNetworkUse: true,
      imageLayers: parameters?.layers.isNotEmpty == true
          ? [
              ImageLayer(
                image: EditorLayerImage.memory(parameters!.image),
              ),
            ]
          : null,
      blur: parameters?.blur,
      colorFilters: (parameters?.colorFilters ?? [])
          .map((matrix) => ColorFilter(matrix: matrix))
          .toList(),
      imageBytesWithCropping: true,
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

    await _cancelAndRender(outputPath, task);

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
  /// If [globalTransform] is provided, applies it to all segments in a single
  /// pass.
  static Future<String> _concatenateSegments({
    required List<VideoSegment> segments,
    required String taskId,
    required Directory outputDir,
    required CompleteParameters? parameters,
    required model.AspectRatio aspectRatio,
    _CropParameters? globalTransform,
    double originalAudioVolume = 1.0,
    double customAudioVolume = 1.0,
  }) async {
    final outputPath = path.join(
      outputDir.path,
      'divine_${DateTime.now().microsecondsSinceEpoch}.mp4',
    );

    final hasCustomAudio =
        customAudioVolume > 0 && parameters?.customAudioTrack != null;

    final audioTracks = <VideoAudioTrack>[];
    if (hasCustomAudio) {
      final audioPath = await parameters?.customAudioTrack?.audio
          .safeFilePath();
      if (audioPath != null) {
        audioTracks.add(
          VideoAudioTrack(
            path: audioPath,
            volume: customAudioVolume,
            audioStartTime: parameters?.customAudioTrack?.startTime,
          ),
        );
      }
    }

    final volumeSegments = segments
        .map((s) => s.copyWith(volume: originalAudioVolume))
        .toList();

    final task = VideoRenderData(
      id: taskId,
      videoSegments: volumeSegments,
      endTime: VideoEditorConstants.maxDuration,
      shouldOptimizeForNetworkUse: true,
      audioTracks: audioTracks,
      enableAudio: originalAudioVolume > 0 || hasCustomAudio,
      imageLayers: parameters?.layers.isNotEmpty == true
          ? [
              ImageLayer(
                image: EditorLayerImage.memory(parameters!.image),
              ),
            ]
          : null,
      blur: parameters?.blur,
      colorFilters: (parameters?.colorFilters ?? [])
          .map((matrix) => ColorFilter(matrix: matrix))
          .toList(),
      imageBytesWithCropping: true,
      qualityConfig: VideoQualityConfig.custom(
        bitrate: VideoEditorConstants.quality.bitrate,
        resolution: VideoEditorConstants.quality.resolutionForAspectRatio(
          aspectRatio,
        ),
      ),
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

    await _cancelAndRender(outputPath, task);

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

  /// Cancels any in-progress render for [task], then renders to [outputPath].
  static Future<void> _cancelAndRender(
    String outputPath,
    VideoRenderData task,
  ) async {
    await cancelTask(task.id);
    await ProVideoEditor.instance.renderVideoToFile(outputPath, task);
  }

  static Future<void> cancelTask(String id) async {
    try {
      Log.info(
        '⏹️ Cancelling video render',
        name: 'VideoEditorNotifier',
        category: .video,
      );
      await ProVideoEditor.instance.cancel(id);
      Log.info(
        '✅ Video render cancelled',
        name: 'VideoEditorNotifier',
        category: .video,
      );
    } catch (e) {
      // May fail if render already completed or was cancelled - not an error
      Log.debug(
        '⏹️ Cancel video render returned: $e',
        name: 'VideoEditorNotifier',
        category: .video,
      );
    }
  }
}
