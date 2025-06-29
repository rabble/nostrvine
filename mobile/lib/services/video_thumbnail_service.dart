// ABOUTME: Service for extracting thumbnails from video files
// ABOUTME: Generates preview frames for video posts to include in NIP-71 events

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/unified_logger.dart';

/// Service for extracting thumbnail images from video files
class VideoThumbnailService {
  static const int _thumbnailQuality = 75;
  static const int _maxWidth = 640;
  static const int _maxHeight = 640;
  
  /// Extract a thumbnail from a video file at a specific timestamp
  /// 
  /// [videoPath] - Path to the video file
  /// [timeMs] - Timestamp in milliseconds to extract thumbnail from (default: 100ms)
  /// [quality] - JPEG quality (1-100, default: 75)
  /// 
  /// Returns the path to the generated thumbnail file
  static Future<String?> extractThumbnail({
    required String videoPath,
    int timeMs = 100, // Extract frame at 100ms by default
    int quality = _thumbnailQuality,
  }) async {
    try {
      Log.debug('Extracting thumbnail from video: $videoPath', name: 'VideoThumbnailService', category: LogCategory.video);
      Log.debug('⏱️ Timestamp: ${timeMs}ms, Quality: $quality%', name: 'VideoThumbnailService', category: LogCategory.video);
      
      // Verify video file exists
      final videoFile = File(videoPath);
      if (!videoFile.existsSync()) {
        Log.error('Video file not found: $videoPath', name: 'VideoThumbnailService', category: LogCategory.video);
        return null;
      }
      
      // Generate thumbnail
      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.JPEG,
        maxHeight: _maxHeight,
        maxWidth: _maxWidth,
        timeMs: timeMs,
        quality: quality,
      );
      
      if (thumbnailPath == null) {
        Log.error('Failed to generate thumbnail', name: 'VideoThumbnailService', category: LogCategory.video);
        return null;
      }
      
      // Verify thumbnail was created
      final thumbnailFile = File(thumbnailPath);
      if (!thumbnailFile.existsSync()) {
        Log.error('Thumbnail file not created', name: 'VideoThumbnailService', category: LogCategory.video);
        return null;
      }
      
      final thumbnailSize = await thumbnailFile.length();
      Log.info('Thumbnail generated successfully:', name: 'VideoThumbnailService', category: LogCategory.video);
      Log.debug('  📸 Path: $thumbnailPath', name: 'VideoThumbnailService', category: LogCategory.video);
      Log.debug('  📦 Size: ${(thumbnailSize / 1024).toStringAsFixed(2)}KB', name: 'VideoThumbnailService', category: LogCategory.video);
      
      return thumbnailPath;
      
    } catch (e, stackTrace) {
      Log.error('Thumbnail extraction error: $e', name: 'VideoThumbnailService', category: LogCategory.video);
      Log.verbose('� Stack trace: $stackTrace', name: 'VideoThumbnailService', category: LogCategory.video);
      return null;
    }
  }
  
  /// Extract thumbnail as bytes (for direct upload without file)
  static Future<Uint8List?> extractThumbnailBytes({
    required String videoPath,
    int timeMs = 100,
    int quality = _thumbnailQuality,
  }) async {
    try {
      Log.debug('Extracting thumbnail bytes from video: $videoPath', name: 'VideoThumbnailService', category: LogCategory.video);
      
      final uint8list = await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        maxHeight: _maxHeight,
        maxWidth: _maxWidth,
        timeMs: timeMs,
        quality: quality,
      );
      
      if (uint8list == null) {
        Log.error('Failed to generate thumbnail bytes', name: 'VideoThumbnailService', category: LogCategory.video);
        return null;
      }
      
      Log.info('Thumbnail bytes generated: ${(uint8list.length / 1024).toStringAsFixed(2)}KB', name: 'VideoThumbnailService', category: LogCategory.video);
      return uint8list;
      
    } catch (e) {
      Log.error('Thumbnail bytes extraction error: $e', name: 'VideoThumbnailService', category: LogCategory.video);
      return null;
    }
  }
  
  /// Generate multiple thumbnails at different timestamps
  /// Useful for selecting the best frame
  static Future<List<String>> extractMultipleThumbnails({
    required String videoPath,
    List<int>? timestamps,
    int quality = _thumbnailQuality,
  }) async {
    // Default to extracting at 0ms, 500ms, and 1000ms
    final timesToExtract = timestamps ?? [0, 500, 1000];
    final thumbnails = <String>[];
    
    for (final timeMs in timesToExtract) {
      final thumbnail = await extractThumbnail(
        videoPath: videoPath,
        timeMs: timeMs,
        quality: quality,
      );
      
      if (thumbnail != null) {
        thumbnails.add(thumbnail);
      }
    }
    
    Log.debug('� Generated ${thumbnails.length} thumbnails', name: 'VideoThumbnailService', category: LogCategory.video);
    return thumbnails;
  }
  
  /// Clean up temporary thumbnail files
  static Future<void> cleanupThumbnails(List<String> thumbnailPaths) async {
    for (final path in thumbnailPaths) {
      try {
        final file = File(path);
        if (file.existsSync()) {
          await file.delete();
          Log.debug('�️ Deleted thumbnail: $path', name: 'VideoThumbnailService', category: LogCategory.video);
        }
      } catch (e) {
        Log.error('Failed to delete thumbnail: $e', name: 'VideoThumbnailService', category: LogCategory.video);
      }
    }
  }
  
  /// Get optimal thumbnail timestamp based on video duration
  static int getOptimalTimestamp(Duration videoDuration) {
    // Extract thumbnail from 10% into the video
    // This usually avoids black frames at the start
    final tenPercent = (videoDuration.inMilliseconds * 0.1).round();
    
    // But ensure it's at least 100ms and not more than 1 second
    return tenPercent.clamp(100, 1000);
  }
}