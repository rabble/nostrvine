// ABOUTME: Orchestrates downloading a video, applying a watermark overlay, and saving to gallery
// ABOUTME: Emits progress updates for UI feedback during the multi-step process

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:media_cache/media_cache.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:openvine/services/watermark_image_generator.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

/// Progress stages for watermark download.
enum WatermarkDownloadStage {
  /// Downloading/caching the video file.
  downloading,

  /// Generating watermark and rendering onto video.
  watermarking,

  /// Saving the watermarked video to gallery.
  saving,
}

/// Progress stages for saving original video (no watermark).
enum OriginalSaveStage {
  /// Downloading/caching the video file.
  downloading,

  /// Saving the video to gallery.
  saving,
}

/// Result of a watermark download operation.
sealed class WatermarkDownloadResult {
  const WatermarkDownloadResult();
}

/// Watermarked video was successfully saved to the gallery.
class WatermarkDownloadSuccess extends WatermarkDownloadResult {
  /// Creates a [WatermarkDownloadSuccess] with the output [filePath].
  const WatermarkDownloadSuccess(this.filePath);

  /// Path to the watermarked video file.
  final String filePath;
}

/// Watermark download failed.
class WatermarkDownloadFailure extends WatermarkDownloadResult {
  /// Creates a [WatermarkDownloadFailure] with the given [reason].
  const WatermarkDownloadFailure(this.reason);

  /// Human-readable failure reason.
  final String reason;
}

/// Gallery permission was denied — UI should offer to open Settings.
class WatermarkDownloadPermissionDenied extends WatermarkDownloadResult {
  /// Creates a [WatermarkDownloadPermissionDenied].
  const WatermarkDownloadPermissionDenied();
}

/// Service that downloads a video, applies a diVine watermark, and saves
/// the result to the device gallery.
class WatermarkDownloadService {
  /// Creates a [WatermarkDownloadService] with required dependencies.
  const WatermarkDownloadService({
    required MediaCacheManager mediaCache,
    required GallerySaveService gallerySaveService,
  }) : _mediaCache = mediaCache,
       _gallerySaveService = gallerySaveService;

  final MediaCacheManager _mediaCache;
  final GallerySaveService _gallerySaveService;

  static const _logName = 'WatermarkDownloadService';

  /// Downloads the video, applies a watermark, and saves to gallery.
  ///
  /// [video] is the video event to download and watermark.
  /// [username] is the display name to show in the watermark.
  /// [onProgress] is called as the operation moves through stages.
  ///
  /// Returns a [WatermarkDownloadResult] indicating success or failure.
  Future<WatermarkDownloadResult> downloadWithWatermark({
    required VideoEvent video,
    required String username,
    required ValueChanged<WatermarkDownloadStage> onProgress,
  }) async {
    String? tempOutputPath;

    try {
      // Stage 1: Download / cache the video file
      onProgress(WatermarkDownloadStage.downloading);

      final videoFile = await _getVideoFile(video);
      if (videoFile == null) {
        return const WatermarkDownloadFailure('Could not download video file');
      }

      // Stage 2: Generate watermark and render onto video
      onProgress(WatermarkDownloadStage.watermarking);

      // Read actual video dimensions from the file (not from Nostr metadata,
      // which may be missing or wrong — e.g. a square video defaults to
      // 1080x1920 and causes black letterboxing).
      final metadata = await ProVideoEditor.instance.getMetadata(
        EditorVideo.file(videoFile),
      );
      final videoWidth = metadata.resolution.width.round();
      final videoHeight = metadata.resolution.height.round();

      Log.debug(
        'Video dimensions from file: ${videoWidth}x$videoHeight',
        name: _logName,
        category: LogCategory.video,
      );

      final watermarkBytes = await WatermarkImageGenerator.generateWatermark(
        videoWidth: videoWidth,
        videoHeight: videoHeight,
        username: username,
      );

      tempOutputPath = await _renderWithWatermark(
        videoFile: videoFile,
        watermarkBytes: watermarkBytes,
        videoId: video.id,
      );

      if (tempOutputPath == null) {
        return const WatermarkDownloadFailure(
          'Failed to render watermarked video',
        );
      }

      // Stage 3: Save to gallery
      onProgress(WatermarkDownloadStage.saving);

      final saveResult = await _gallerySaveService.saveVideoToGallery(
        EditorVideo.file(File(tempOutputPath)),
      );

      if (saveResult is GallerySavePermissionDenied) {
        return const WatermarkDownloadPermissionDenied();
      }
      if (saveResult is GallerySaveFailure) {
        return WatermarkDownloadFailure(
          'Gallery save failed: ${saveResult.reason}',
        );
      }

      Log.info(
        'Watermarked video saved to gallery',
        name: _logName,
        category: LogCategory.video,
      );

      return WatermarkDownloadSuccess(tempOutputPath);
    } on WatermarkGenerationException catch (e) {
      Log.warning(
        'Watermark generation failed: ${e.message}',
        name: _logName,
        category: LogCategory.video,
      );
      return WatermarkDownloadFailure('Watermark error: ${e.message}');
    } catch (e) {
      Log.warning(
        'Watermark download failed: $e',
        name: _logName,
        category: LogCategory.video,
      );
      return WatermarkDownloadFailure('Unexpected error: $e');
    }
  }

  /// Downloads the original video (no watermark) and saves to gallery.
  ///
  /// [video] is the video event to download.
  /// [onProgress] is called as the operation moves through stages.
  ///
  /// Returns a [WatermarkDownloadResult] indicating success or failure.
  Future<WatermarkDownloadResult> downloadOriginal({
    required VideoEvent video,
    required ValueChanged<OriginalSaveStage> onProgress,
  }) async {
    try {
      // Stage 1: Download / cache the video file
      onProgress(OriginalSaveStage.downloading);

      final videoFile = await _getVideoFile(video);
      if (videoFile == null) {
        return const WatermarkDownloadFailure('Could not download video file');
      }

      // Stage 2: Save directly to gallery (no watermark)
      onProgress(OriginalSaveStage.saving);

      final saveResult = await _gallerySaveService.saveVideoToGallery(
        EditorVideo.file(videoFile),
      );

      if (saveResult is GallerySavePermissionDenied) {
        return const WatermarkDownloadPermissionDenied();
      }
      if (saveResult is GallerySaveFailure) {
        return WatermarkDownloadFailure(
          'Gallery save failed: ${saveResult.reason}',
        );
      }

      Log.info(
        'Original video saved to gallery',
        name: _logName,
        category: LogCategory.video,
      );

      return WatermarkDownloadSuccess(videoFile.path);
    } catch (e) {
      Log.warning(
        'Original video save failed: $e',
        name: _logName,
        category: LogCategory.video,
      );
      return WatermarkDownloadFailure('Unexpected error: $e');
    }
  }

  /// Downloads or retrieves the cached video file.
  Future<File?> _getVideoFile(VideoEvent video) async {
    // Check cache first
    final cachedFile = _mediaCache.getCachedFileSync(video.id);
    if (cachedFile != null && cachedFile.existsSync()) {
      Log.debug(
        'Using cached video file',
        name: _logName,
        category: LogCategory.video,
      );
      return cachedFile;
    }

    // Resolve the playable URL and download
    final videoUrl = await video.getPlayableUrl();
    if (videoUrl == null || videoUrl.isEmpty) {
      Log.warning(
        'No video URL available',
        name: _logName,
        category: LogCategory.video,
      );
      return null;
    }

    final file = await _mediaCache.cacheFile(videoUrl, key: video.id);

    return file;
  }

  /// Renders the video with the watermark overlay.
  Future<String?> _renderWithWatermark({
    required File videoFile,
    required Uint8List watermarkBytes,
    required String videoId,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final outputPath =
          '${tempDir.path}/watermarked_${DateTime.now().microsecondsSinceEpoch}.mp4';

      final task = VideoRenderData(
        id: '${videoId}_watermark',
        video: EditorVideo.file(videoFile),
        shouldOptimizeForNetworkUse: true,
        imageBytes: watermarkBytes,
      );

      await ProVideoEditor.instance.renderVideoToFile(outputPath, task);

      Log.debug(
        'Watermarked video rendered to: $outputPath',
        name: _logName,
        category: LogCategory.video,
      );

      return outputPath;
    } catch (e) {
      Log.error(
        'Failed to render watermarked video: $e',
        name: _logName,
        category: LogCategory.video,
      );
      return null;
    }
  }
}
