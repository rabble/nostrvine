// ABOUTME: Service for extracting thumbnails from video files
// ABOUTME: Generates preview frames for video posts to include in NIP-71 events

import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

/// Service for extracting thumbnail images from video files
class VideoThumbnailService {
  static const int _thumbnailQuality = 75;
  static const Size _thumbnailSize = Size.square(640);

  static final _proVideoEditor = ProVideoEditor.instance;

  /// Extract a thumbnail from a video file at a specific timestamp
  ///
  /// [videoPath] - Path to the video file
  /// [targetTimestamp] - Timestamp to extract thumbnail from (default: 210ms)
  /// [quality] - JPEG quality (1-100, default: 75)
  ///
  /// Returns a [ThumbnailFileResult] with the path and actual timestamp used
  static Future<ThumbnailFileResult?> extractThumbnail({
    required String videoPath,
    // Extract frame at 210ms by default
    Duration targetTimestamp = const Duration(milliseconds: 210),
    int quality = _thumbnailQuality,
  }) async {
    try {
      Log.debug(
        'Extracting thumbnail from video: $videoPath',
        name: 'VideoThumbnailService',
        category: LogCategory.video,
      );
      Log.debug(
        '⏱️ Timestamp: ${targetTimestamp.inMilliseconds}ms',
        name: 'VideoThumbnailService',
        category: LogCategory.video,
      );

      // Verify video file exists
      final videoFile = File(videoPath);
      if (!videoFile.existsSync()) {
        Log.error(
          'Video file not found: $videoPath',
          name: 'VideoThumbnailService',
          category: LogCategory.video,
        );
        return null;
      }

      final destPath =
          '${(await getTemporaryDirectory()).path}/'
          'thumbnail_${DateTime.now().millisecondsSinceEpoch}.jpg';

      try {
        Log.debug(
          'Trying pro_video_editor plugin',
          name: 'VideoThumbnailService',
          category: LogCategory.video,
        );

        // The pro_video_editor returns thumbnails only as in-memory Uint8List
        // and does not write files to disk.
        // Therefore, we persist the thumbnails to disk here.
        final thumbnailResult = await extractThumbnailBytes(
          videoPath: videoPath,
          timestamp: targetTimestamp,
          quality: quality,
        );

        if (thumbnailResult == null) {
          throw Exception('Failed to extract thumbnail bytes from video');
        }
        final thumbnailFile = File(destPath);
        await thumbnailFile.writeAsBytes(thumbnailResult.bytes);

        final thumbnailSize = await thumbnailFile.length();
        Log.info(
          'Thumbnail generated with pro_video_editor:',
          name: 'VideoThumbnailService',
          category: LogCategory.video,
        );
        Log.debug(
          '  📸 Path: $destPath',
          name: 'VideoThumbnailService',
          category: LogCategory.video,
        );
        Log.debug(
          '  📦 Size: ${(thumbnailSize / 1024).toStringAsFixed(2)}KB',
          name: 'VideoThumbnailService',
          category: LogCategory.video,
        );
        return ThumbnailFileResult(
          path: destPath,
          timestamp: thumbnailResult.timestamp,
        );
      } catch (e) {
        Log.error(
          'Failed to generate thumbnail: $e',
          name: 'VideoThumbnailService',
          category: LogCategory.video,
        );
        return null;
      }
    } catch (e, stackTrace) {
      Log.error(
        'Thumbnail extraction error: $e',
        name: 'VideoThumbnailService',
        category: LogCategory.video,
      );
      Log.verbose(
        '📱 Stack trace: $stackTrace',
        name: 'VideoThumbnailService',
        category: LogCategory.video,
      );
      return null;
    }
  }

  /// Extract thumbnail as bytes (for direct upload without file)
  ///
  /// Includes automatic retry logic with delays to handle "cannot open" errors
  /// that occur when the video file is still being written or locked:
  /// 1. First attempt at the specified timestamp
  /// 2. If failed: Wait 100ms, then retry at the same timestamp
  /// 3. If failed again: Wait 200ms, then attempt at 50ms (fallback position)
  /// 4. If failed again: Wait 300ms, then attempt at video duration / 2
  ///
  /// Returns a [ThumbnailResult] containing the bytes and actual timestamp used.
  static Future<ThumbnailResult?> extractThumbnailBytes({
    required String videoPath,
    Duration timestamp = const Duration(milliseconds: 210),
    int quality = _thumbnailQuality,
  }) async {
    // Build list of retry attempts with increasing delays and fallback timestamps
    final attempts = <_ThumbnailAttempt>[
      _ThumbnailAttempt(timestamp: timestamp, delay: .zero),
      _ThumbnailAttempt(
        timestamp: timestamp,
        delay: const Duration(milliseconds: 100),
      ),
      _ThumbnailAttempt(
        timestamp: const Duration(milliseconds: 50),
        delay: const Duration(milliseconds: 200),
      ),
      _ThumbnailAttempt(
        timestamp: null, // Will use video duration / 2
        delay: const Duration(milliseconds: 300),
        logToCrashlytics: true,
      ),
    ];

    return _extractWithRetry(
      videoPath: videoPath,
      quality: quality,
      attempts: attempts,
    );
  }

  /// Recursively attempts thumbnail extraction with the given list of attempts.
  static Future<ThumbnailResult?> _extractWithRetry({
    required String videoPath,
    required int quality,
    required List<_ThumbnailAttempt> attempts,
  }) async {
    if (attempts.isEmpty) return null;

    final attempt = attempts.first;
    final remainingAttempts = attempts.sublist(1);
    final isLastAttempt = remainingAttempts.isEmpty;

    // Apply delay before this attempt (except for first attempt)
    if (attempt.delay > Duration.zero) {
      await Future<void>.delayed(attempt.delay);
    }

    // Resolve timestamp (null means use video duration / 2)
    Duration timestamp;
    if (attempt.timestamp != null) {
      timestamp = attempt.timestamp!;
    } else {
      try {
        final metadata = await _proVideoEditor.getMetadata(
          EditorVideo.file(videoPath),
        );
        timestamp = Duration(
          milliseconds: metadata.duration.inMilliseconds ~/ 2,
        );
      } catch (e) {
        Log.error(
          'Failed to get video metadata for middle timestamp: $e',
          name: 'VideoThumbnailService',
          category: LogCategory.video,
        );
        // Skip to next attempt if we can't get metadata
        return _extractWithRetry(
          videoPath: videoPath,
          quality: quality,
          attempts: remainingAttempts,
        );
      }
    }

    if (attempt.delay > Duration.zero) {
      Log.debug(
        'Retrying thumbnail extraction at timestamp: '
        '${timestamp.inMilliseconds}ms',
        name: 'VideoThumbnailService',
        category: LogCategory.video,
      );
    }

    final bytes = await _extractThumbnailBytesInternal(
      videoPath: videoPath,
      timestamp: timestamp,
      quality: quality,
      logToCrashlytics: attempt.logToCrashlytics && isLastAttempt,
    );

    if (bytes != null) {
      return ThumbnailResult(bytes: bytes, timestamp: timestamp);
    }

    // Recurse to next attempt
    return _extractWithRetry(
      videoPath: videoPath,
      quality: quality,
      attempts: remainingAttempts,
    );
  }

  /// Internal method for extracting thumbnail bytes without retry logic.
  static Future<Uint8List?> _extractThumbnailBytesInternal({
    required String videoPath,
    required Duration timestamp,
    required int quality,
    bool logToCrashlytics = false,
  }) async {
    try {
      Log.debug(
        'Extracting thumbnail bytes from video: $videoPath',
        name: 'VideoThumbnailService',
        category: LogCategory.video,
      );

      // Generate thumbnail file first
      final thumbnails = await _proVideoEditor.getThumbnails(
        ThumbnailConfigs(
          video: EditorVideo.file(videoPath),
          outputSize: _thumbnailSize,
          timestamps: [timestamp],
          outputFormat: .jpeg,
          jpegQuality: quality,
        ),
      );

      if (thumbnails.isEmpty) {
        Log.error(
          'Failed to generate thumbnail',
          name: 'VideoThumbnailService',
          category: LogCategory.video,
        );
        if (logToCrashlytics) {
          await CrashReportingService.instance.recordError(
            Exception('Thumbnail extraction failed - thumbnails list is empty'),
            StackTrace.current,
            reason:
                'VideoThumbnailService: Failed to extract thumbnail from '
                '$videoPath at timestamp: ${timestamp.inMilliseconds}ms',
          );
        }
        return null;
      }

      final thumbnail = thumbnails.first;

      Log.info(
        'Thumbnail bytes generated: '
        '${(thumbnail.lengthInBytes / 1024).toStringAsFixed(2)}KB',
        name: 'VideoThumbnailService',
        category: LogCategory.video,
      );
      return thumbnail;
    } catch (e, stackTrace) {
      Log.error(
        'Thumbnail bytes extraction error: $e',
        name: 'VideoThumbnailService',
        category: LogCategory.video,
      );
      if (logToCrashlytics) {
        await CrashReportingService.instance.recordError(
          e,
          stackTrace,
          reason:
              'VideoThumbnailService: Failed to extract thumbnail from '
              '$videoPath at timestamp: ${timestamp.inMilliseconds}ms',
        );
      }
      return null;
    }
  }

  /// Generates multiple thumbnails from a video at different timestamps.
  ///
  /// Useful for presenting several candidate frames, such as for preview
  /// selection or cover image picking.
  ///
  /// If [timestamps] is not provided, thumbnails are extracted at **500ms,
  /// 1000ms, and 1500ms** by default. Extraction intentionally does not start
  /// at 0ms because many MP4 videos have no decodable frame at the beginning.
  /// The first keyframe typically appears after ~210ms.
  static Future<List<Uint8List>> extractMultipleThumbnails({
    required String videoPath,
    List<Duration>? timestamps,
    int quality = _thumbnailQuality,
  }) async {
    final timesToExtract =
        timestamps ??
        const [
          Duration(milliseconds: 500),
          Duration(milliseconds: 1000),
          Duration(milliseconds: 1500),
        ];

    final thumbnails = await _proVideoEditor.getThumbnails(
      ThumbnailConfigs(
        video: EditorVideo.file(videoPath),
        outputSize: _thumbnailSize,
        timestamps: timesToExtract,
        outputFormat: .jpeg,
        jpegQuality: quality,
      ),
    );

    Log.debug(
      '📱 Generated ${thumbnails.length} thumbnails',
      name: 'VideoThumbnailService',
      category: LogCategory.video,
    );
    return thumbnails;
  }

  /// Clean up temporary thumbnail files
  static Future<void> cleanupThumbnails(List<String> thumbnailPaths) async {
    for (final path in thumbnailPaths) {
      try {
        final file = File(path);
        if (file.existsSync()) {
          await file.delete();
          Log.debug(
            '📱️ Deleted thumbnail: $path',
            name: 'VideoThumbnailService',
            category: LogCategory.video,
          );
        }
      } catch (e) {
        Log.error(
          'Failed to delete thumbnail: $e',
          name: 'VideoThumbnailService',
          category: LogCategory.video,
        );
      }
    }
  }

  /// Get optimal thumbnail timestamp based on video duration
  static Duration getOptimalTimestamp(Duration videoDuration) {
    // Extract thumbnail from 10% into the video
    // This usually avoids black frames at the start
    final tenPercent = (videoDuration.inMilliseconds * 0.1).round();

    // But ensure it's at least 100ms and not more than 1 second
    return Duration(milliseconds: tenPercent.clamp(100, 1000));
  }
}

/// Configuration for a single thumbnail extraction attempt.
class _ThumbnailAttempt {
  const _ThumbnailAttempt({
    required this.timestamp,
    required this.delay,
    this.logToCrashlytics = false,
  });

  /// The timestamp to extract the thumbnail from.
  /// If null, the middle of the video (duration / 2) will be used.
  final Duration? timestamp;

  /// Delay to wait before this attempt.
  final Duration delay;

  /// Whether to log failures to Crashlytics (typically only for the last attempt).
  final bool logToCrashlytics;
}

/// Result of a thumbnail extraction containing the bytes and actual timestamp used.
class ThumbnailResult {
  const ThumbnailResult({required this.bytes, required this.timestamp});

  /// The thumbnail image bytes.
  final Uint8List bytes;

  /// The actual video timestamp where the thumbnail was extracted from.
  /// May differ from the requested timestamp due to retry logic.
  final Duration timestamp;
}

/// Result of a thumbnail file extraction containing the path and actual timestamp used.
class ThumbnailFileResult {
  const ThumbnailFileResult({required this.path, required this.timestamp});

  /// The path to the generated thumbnail file.
  final String path;

  /// The actual video timestamp where the thumbnail was extracted from.
  /// May differ from the requested timestamp due to retry logic.
  final Duration timestamp;
}
