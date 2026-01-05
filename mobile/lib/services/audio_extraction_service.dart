// ABOUTME: Service for extracting audio tracks from video files using FFmpeg
// ABOUTME: Used by the audio reuse feature to create separate audio files for publishing

import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:openvine/utils/ffmpeg_encoder.dart';
import 'package:openvine/utils/hash_util.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:path_provider/path_provider.dart';

/// Result of an audio extraction operation.
///
/// Contains the path to the extracted audio file along with metadata
/// needed for Blossom upload and Nostr event creation.
class AudioExtractionResult {
  /// Creates a new [AudioExtractionResult].
  const AudioExtractionResult({
    required this.audioFilePath,
    required this.duration,
    required this.fileSize,
    required this.sha256Hash,
    required this.mimeType,
  });

  /// Path to the extracted audio file.
  final String audioFilePath;

  /// Duration of the audio in seconds.
  final double duration;

  /// File size in bytes.
  final int fileSize;

  /// SHA-256 hash of the audio file (hex string).
  final String sha256Hash;

  /// MIME type of the audio file (e.g., "audio/aac").
  final String mimeType;

  @override
  String toString() {
    return 'AudioExtractionResult('
        'duration: ${duration.toStringAsFixed(2)}s, '
        'size: ${(fileSize / 1024).toStringAsFixed(2)}KB, '
        'mimeType: $mimeType'
        ')';
  }
}

/// Exception thrown when audio extraction fails.
class AudioExtractionException implements Exception {
  /// Creates a new [AudioExtractionException].
  const AudioExtractionException(this.message, {this.cause});

  /// Human-readable error message.
  final String message;

  /// The underlying cause of the exception, if any.
  final Object? cause;

  @override
  String toString() {
    if (cause != null) {
      return 'AudioExtractionException: $message (caused by: $cause)';
    }
    return 'AudioExtractionException: $message';
  }
}

/// Service for extracting audio tracks from video files.
///
/// Uses FFmpeg to extract the audio track from a video file and save it
/// as a separate AAC file. This is used by the audio reuse feature when
/// a user publishes a video with "Allow others to use this audio" enabled.
///
/// Usage:
/// ```dart
/// final service = AudioExtractionService();
/// try {
///   final result = await service.extractAudio('/path/to/video.mp4');
///   print('Audio extracted: ${result.audioFilePath}');
///   print('Duration: ${result.duration}s');
///   print('Hash: ${result.sha256Hash}');
/// } on AudioExtractionException catch (e) {
///   print('Failed: $e');
/// }
/// ```
class AudioExtractionService {
  static const String _logName = 'AudioExtractionService';
  static const LogCategory _logCategory = LogCategory.video;

  /// Default audio codec for extraction.
  static const String _audioCodec = 'aac';

  /// Default audio bitrate.
  static const String _audioBitrate = '128k';

  /// MIME type for AAC audio files.
  static const String _aacMimeType = 'audio/aac';

  /// Tracks temporary audio files created by this service for cleanup.
  final List<String> _temporaryFiles = [];

  /// Extracts the audio track from a video file.
  ///
  /// The audio is extracted as an AAC file at 128kbps bitrate.
  ///
  /// [videoPath] - Path to the source video file.
  ///
  /// Returns an [AudioExtractionResult] containing the path to the extracted
  /// audio file and metadata (duration, file size, SHA-256 hash, MIME type).
  ///
  /// Throws [AudioExtractionException] if:
  /// - The video file does not exist
  /// - The video has no audio track
  /// - FFmpeg fails to extract the audio
  Future<AudioExtractionResult> extractAudio(String videoPath) async {
    Log.info(
      'Starting audio extraction from: $videoPath',
      name: _logName,
      category: _logCategory,
    );

    // Verify video file exists
    final videoFile = File(videoPath);
    if (!await videoFile.exists()) {
      Log.error(
        'Video file not found: $videoPath',
        name: _logName,
        category: _logCategory,
      );
      throw const AudioExtractionException('Video file not found');
    }

    // Check if video has an audio stream
    final hasAudio = await _hasAudioStream(videoPath);
    if (!hasAudio) {
      Log.warning(
        'Video has no audio track: $videoPath',
        name: _logName,
        category: _logCategory,
      );
      throw const AudioExtractionException('Video has no audio track');
    }

    // Get duration from the video before extraction
    final videoDuration = await _getAudioDuration(videoPath);
    if (videoDuration == null || videoDuration <= 0) {
      Log.warning(
        'Could not determine audio duration for: $videoPath',
        name: _logName,
        category: _logCategory,
      );
      throw const AudioExtractionException(
        'Could not determine audio duration',
      );
    }

    // Generate output path
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outputPath = '${tempDir.path}/extracted_audio_$timestamp.aac';

    // Extract audio using FFmpeg
    // -vn: No video (audio only)
    // -c:a aac: Use AAC codec
    // -b:a 128k: 128kbps bitrate
    final command =
        '-y -i "$videoPath" -vn -c:a $_audioCodec -b:a $_audioBitrate "$outputPath"';

    Log.debug(
      'FFmpeg audio extraction command: ffmpeg $command',
      name: _logName,
      category: _logCategory,
    );

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    // Clear sessions to free memory
    await FFmpegEncoder.clearSessions();

    if (!ReturnCode.isSuccess(returnCode)) {
      final output = await session.getOutput();
      Log.error(
        'FFmpeg audio extraction failed: $output',
        name: _logName,
        category: _logCategory,
      );
      throw AudioExtractionException(
        'FFmpeg failed to extract audio',
        cause: output,
      );
    }

    // Verify output file exists
    final audioFile = File(outputPath);
    if (!await audioFile.exists()) {
      Log.error(
        'Audio file was not created: $outputPath',
        name: _logName,
        category: _logCategory,
      );
      throw const AudioExtractionException('Audio file was not created');
    }

    // Track this file for potential cleanup
    _temporaryFiles.add(outputPath);

    // Calculate hash and get file size using streaming (memory efficient)
    Log.debug(
      'Calculating SHA-256 hash for audio file',
      name: _logName,
      category: _logCategory,
    );
    final hashResult = await HashUtil.sha256File(audioFile);

    Log.info(
      'Audio extraction complete: $outputPath',
      name: _logName,
      category: _logCategory,
    );
    Log.debug(
      'Audio details: duration=${videoDuration.toStringAsFixed(2)}s, '
      'size=${(hashResult.size / 1024).toStringAsFixed(2)}KB, '
      'hash=${hashResult.hash}',
      name: _logName,
      category: _logCategory,
    );

    return AudioExtractionResult(
      audioFilePath: outputPath,
      duration: videoDuration,
      fileSize: hashResult.size,
      sha256Hash: hashResult.hash,
      mimeType: _aacMimeType,
    );
  }

  /// Checks if a video file has an audio stream.
  ///
  /// Uses FFprobe to analyze the media streams and look for an audio track.
  Future<bool> _hasAudioStream(String videoPath) async {
    try {
      final session = await FFprobeKit.getMediaInformation(videoPath);
      final mediaInfo = session.getMediaInformation();

      if (mediaInfo == null) {
        Log.warning(
          'Could not get media information for: $videoPath',
          name: _logName,
          category: _logCategory,
        );
        return false;
      }

      final streams = mediaInfo.getStreams();
      for (final stream in streams) {
        if (stream.getType() == 'audio') {
          Log.debug(
            'Found audio stream: codec=${stream.getCodec()}, '
            'sampleRate=${stream.getSampleRate()}, '
            'channelLayout=${stream.getChannelLayout()}',
            name: _logName,
            category: _logCategory,
          );
          return true;
        }
      }

      return false;
    } catch (e) {
      Log.error(
        'Error checking audio stream: $e',
        name: _logName,
        category: _logCategory,
      );
      return false;
    }
  }

  /// Gets the audio duration from a video file in seconds.
  ///
  /// Uses FFprobe to get media information and extract duration.
  Future<double?> _getAudioDuration(String videoPath) async {
    try {
      final session = await FFprobeKit.getMediaInformation(videoPath);
      final mediaInfo = session.getMediaInformation();

      if (mediaInfo == null) {
        return null;
      }

      // Try to get duration from format info first (more reliable)
      final durationStr = mediaInfo.getDuration();
      if (durationStr != null && durationStr.isNotEmpty) {
        final duration = double.tryParse(durationStr);
        if (duration != null && duration > 0) {
          return duration;
        }
      }

      // Fallback: try to get duration from audio stream
      final streams = mediaInfo.getStreams();
      for (final stream in streams) {
        if (stream.getType() == 'audio') {
          final streamDuration = stream.getStringProperty('duration');
          if (streamDuration != null && streamDuration.isNotEmpty) {
            return double.tryParse(streamDuration);
          }
        }
      }

      return null;
    } catch (e) {
      Log.error(
        'Error getting audio duration: $e',
        name: _logName,
        category: _logCategory,
      );
      return null;
    }
  }

  /// Cleans up temporary audio files created by this service.
  ///
  /// Call this method when you no longer need the extracted audio files
  /// (e.g., after uploading to Blossom server).
  ///
  /// [paths] - Optional list of specific paths to clean up. If not provided,
  /// cleans up all temporary files tracked by this service instance.
  Future<void> cleanupTemporaryFiles([List<String>? paths]) async {
    final filesToDelete = paths ?? List<String>.from(_temporaryFiles);

    Log.debug(
      'Cleaning up ${filesToDelete.length} temporary audio files',
      name: _logName,
      category: _logCategory,
    );

    for (final path in filesToDelete) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
          Log.debug(
            'Deleted temporary file: $path',
            name: _logName,
            category: _logCategory,
          );
        }
        _temporaryFiles.remove(path);
      } catch (e) {
        Log.warning(
          'Failed to delete temporary file: $path ($e)',
          name: _logName,
          category: _logCategory,
        );
      }
    }
  }

  /// Cleans up a single audio file.
  ///
  /// [audioPath] - Path to the audio file to delete.
  Future<void> cleanupAudioFile(String audioPath) async {
    await cleanupTemporaryFiles([audioPath]);
  }
}
