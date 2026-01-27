// ABOUTME: Service for extracting audio tracks from video files using ProVideoEditor
// ABOUTME: Used by the audio reuse feature to create separate audio files for publishing

import 'dart:io';

import 'package:openvine/utils/hash_util.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

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

  /// MIME type of the audio file (e.g., "audio/m4a").
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
/// Uses ProVideoEditor to extract the audio track from a video file and save it
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

  /// MIME type for M4A audio files.
  static const String _aacMimeType = 'audio/m4a';

  /// Tracks temporary audio files created by this service for cleanup.
  final List<String> _temporaryFiles = [];

  /// Extracts the audio track from a video file.
  ///
  /// The audio is extracted as an M4A.
  ///
  /// [videoPath] - Path to the source video file.
  ///
  /// Returns an [AudioExtractionResult] containing the path to the extracted
  /// audio file and metadata (duration, file size, SHA-256 hash, MIME type).
  ///
  /// Throws [AudioExtractionException] if:
  /// - The video file does not exist
  /// - The video has no audio track
  /// - Audio extraction fails
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

    Log.debug(
      'Extracting audio to: $outputPath',
      name: _logName,
      category: _logCategory,
    );
    try {
      await ProVideoEditor.instance.extractAudioToFile(
        outputPath,
        AudioExtractConfigs(
          video: EditorVideo.file(videoPath),
          format: AudioFormat.m4a,
        ),
      );
    } on AudioNoTrackException {
      throw const AudioExtractionException('Video has no audio track');
    } catch (e) {
      Log.error(
        'Audio extraction failed: $e',
        name: _logName,
        category: _logCategory,
      );
      throw AudioExtractionException('Failed to extract audio', cause: e);
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
  /// Uses ProVideoEditor to analyze the media and check for an audio track.
  Future<bool> _hasAudioStream(String videoPath) async {
    try {
      bool hasAudio = await ProVideoEditor.instance.hasAudioTrack(
        EditorVideo.file(videoPath),
      );

      return hasAudio;
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
  /// Uses ProVideoEditor to get media metadata and extract duration.
  Future<double?> _getAudioDuration(String videoPath) async {
    try {
      final metadata = await ProVideoEditor.instance.getMetadata(
        EditorVideo.file(videoPath),
      );

      return metadata.duration.inMilliseconds / 1000;
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
