// ABOUTME: Service for extracting thumbnails from video files
// ABOUTME: Generates preview frames for video posts to include in NIP-71 events

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';

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
      debugPrint('🎬 Extracting thumbnail from video: $videoPath');
      debugPrint('⏱️ Timestamp: ${timeMs}ms, Quality: $quality%');
      
      // Verify video file exists
      final videoFile = File(videoPath);
      if (!videoFile.existsSync()) {
        debugPrint('❌ Video file not found: $videoPath');
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
        debugPrint('❌ Failed to generate thumbnail');
        return null;
      }
      
      // Verify thumbnail was created
      final thumbnailFile = File(thumbnailPath);
      if (!thumbnailFile.existsSync()) {
        debugPrint('❌ Thumbnail file not created');
        return null;
      }
      
      final thumbnailSize = await thumbnailFile.length();
      debugPrint('✅ Thumbnail generated successfully:');
      debugPrint('  📸 Path: $thumbnailPath');
      debugPrint('  📦 Size: ${(thumbnailSize / 1024).toStringAsFixed(2)}KB');
      
      return thumbnailPath;
      
    } catch (e, stackTrace) {
      debugPrint('❌ Thumbnail extraction error: $e');
      debugPrint('📍 Stack trace: $stackTrace');
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
      debugPrint('🎬 Extracting thumbnail bytes from video: $videoPath');
      
      final uint8list = await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        maxHeight: _maxHeight,
        maxWidth: _maxWidth,
        timeMs: timeMs,
        quality: quality,
      );
      
      if (uint8list == null) {
        debugPrint('❌ Failed to generate thumbnail bytes');
        return null;
      }
      
      debugPrint('✅ Thumbnail bytes generated: ${(uint8list.length / 1024).toStringAsFixed(2)}KB');
      return uint8list;
      
    } catch (e) {
      debugPrint('❌ Thumbnail bytes extraction error: $e');
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
    
    debugPrint('📸 Generated ${thumbnails.length} thumbnails');
    return thumbnails;
  }
  
  /// Clean up temporary thumbnail files
  static Future<void> cleanupThumbnails(List<String> thumbnailPaths) async {
    for (final path in thumbnailPaths) {
      try {
        final file = File(path);
        if (file.existsSync()) {
          await file.delete();
          debugPrint('🗑️ Deleted thumbnail: $path');
        }
      } catch (e) {
        debugPrint('⚠️ Failed to delete thumbnail: $e');
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