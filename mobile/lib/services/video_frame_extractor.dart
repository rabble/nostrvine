// ABOUTME: Video frame extraction service using FFmpeg
// ABOUTME: Converts video files to individual frame images for GIF creation

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

/// Service for extracting frames from video files using FFmpeg
class VideoFrameExtractor {
  /// Extract frames from a video file
  /// 
  /// [videoPath] - Path to the input video file
  /// [targetFrameCount] - Number of frames to extract (default: 30 for 6-second 5fps GIF)
  /// [width] - Target width for extracted frames (default: 640)
  /// [height] - Target height for extracted frames (default: 480)
  /// 
  /// Returns a list of frame image data as Uint8List
  static Future<List<Uint8List>> extractFrames({
    required String videoPath,
    int targetFrameCount = 30,
    int width = 640,
    int height = 480,
  }) async {
    try {
      debugPrint('🎬 Starting FFmpeg frame extraction from: $videoPath');
      
      // Create temporary directory for frame images
      final tempDir = await getTemporaryDirectory();
      final framesDir = Directory('${tempDir.path}/frames_${DateTime.now().millisecondsSinceEpoch}');
      await framesDir.create(recursive: true);
      
      // Calculate frame extraction rate
      // For 6-second video -> 30 frames = extract every 0.2 seconds
      final frameRate = targetFrameCount / 6.0; // frames per second to extract
      
      // FFmpeg command to extract frames
      final outputPattern = '${framesDir.path}/frame_%03d.png';
      final command = [
        '-i', videoPath,
        '-vf', 'fps=$frameRate,scale=$width:$height',
        '-y', // Overwrite output files
        outputPattern,
      ].join(' ');
      
      debugPrint('🔧 FFmpeg command: ffmpeg $command');
      
      // Execute FFmpeg command
      final session = await FFmpegKit.execute('ffmpeg $command');
      final returnCode = await session.getReturnCode();
      
      if (!ReturnCode.isSuccess(returnCode)) {
        final failStackTrace = await session.getFailStackTrace();
        final logs = await session.getAllLogsAsString();
        debugPrint('❌ FFmpeg failed with return code: $returnCode');
        debugPrint('📋 FFmpeg logs: $logs');
        debugPrint('🔍 Stack trace: $failStackTrace');
        throw Exception('FFmpeg frame extraction failed: $returnCode');
      }
      
      debugPrint('✅ FFmpeg frame extraction completed successfully');
      
      // Read extracted frame files
      final frameFiles = framesDir
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.png'))
          .toList();
      
      // Sort files by name to maintain order
      frameFiles.sort((a, b) => a.path.compareTo(b.path));
      
      debugPrint('📸 Found ${frameFiles.length} extracted frames');
      
      // Read frame data
      final frames = <Uint8List>[];
      for (final file in frameFiles) {
        try {
          final frameData = await file.readAsBytes();
          frames.add(frameData);
        } catch (e) {
          debugPrint('⚠️ Failed to read frame file ${file.path}: $e');
        }
      }
      
      // Cleanup temporary files
      try {
        await framesDir.delete(recursive: true);
        debugPrint('🧹 Cleaned up temporary frame files');
      } catch (e) {
        debugPrint('⚠️ Failed to cleanup frame files: $e');
      }
      
      debugPrint('🎯 Successfully extracted ${frames.length} frames');
      return frames;
      
    } catch (e) {
      debugPrint('❌ Video frame extraction failed: $e');
      rethrow;
    }
  }
  
  /// Get video information using FFprobe
  /// 
  /// [videoPath] - Path to the video file
  /// 
  /// Returns a map with video metadata
  static Future<Map<String, dynamic>> getVideoInfo(String videoPath) async {
    try {
      debugPrint('📊 Getting video info for: $videoPath');
      
      // FFprobe command to get video information in JSON format
      final command = [
        '-v', 'quiet',
        '-print_format', 'json',
        '-show_format',
        '-show_streams',
        videoPath,
      ].join(' ');
      
      final session = await FFmpegKit.execute('ffprobe $command');
      final returnCode = await session.getReturnCode();
      
      if (!ReturnCode.isSuccess(returnCode)) {
        final logs = await session.getAllLogsAsString();
        debugPrint('❌ FFprobe failed: $logs');
        throw Exception('FFprobe failed to get video info: $returnCode');
      }
      
      final output = await session.getOutput();
      debugPrint('📋 Video info extracted successfully');
      
      // For now, return basic info - in a full implementation, 
      // we'd parse the JSON output to extract specific metadata
      return {
        'success': true,
        'raw_output': output,
      };
      
    } catch (e) {
      debugPrint('❌ Failed to get video info: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}