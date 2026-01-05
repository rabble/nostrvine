// ABOUTME: Service for exporting video clips with FFmpeg operations
// ABOUTME: Handles concatenation, text overlays, audio mixing, and thumbnail generation

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:models/models.dart' show AspectRatio;
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/models/text_overlay.dart';
import 'package:openvine/services/text_overlay_renderer.dart';
import 'package:openvine/utils/ffmpeg_encoder.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Export stages for progress reporting
enum ExportStage {
  concatenating,
  applyingTextOverlay,
  mixingAudio,
  generatingThumbnail,
  complete,
}

/// Result of video export operation
class ExportResult {
  const ExportResult({
    required this.videoPath,
    required this.duration,
    this.thumbnailPath,
  });

  final String videoPath;
  final String? thumbnailPath;
  final Duration duration;
}

/// Service for exporting video clips with FFmpeg operations
class VideoExportService {
  /// Build crop filter string for the given aspect ratio
  ///
  /// Handles any input orientation (landscape or portrait) by conditionally
  /// cropping width or height to achieve the target aspect ratio.
  String _buildCropFilter(AspectRatio aspectRatio) {
    switch (aspectRatio) {
      case AspectRatio.square:
        // Center crop to 1:1 (minimum dimension)
        return "crop=min(iw\\,ih):min(iw\\,ih):(iw-min(iw\\,ih))/2:(ih-min(iw\\,ih))/2";
      case AspectRatio.vertical:
        // Center crop to 9:16 (portrait) - handles both landscape and portrait inputs
        // If input is wider than 9:16: crop width, keep height
        // If input is taller than 9:16: keep width, crop height
        // Uses if(condition, true_val, false_val) to select crop dimensions
        return "crop=if(gt(iw/ih\\,9/16)\\,ih*9/16\\,iw):if(gt(iw/ih\\,9/16)\\,ih\\,iw*16/9):(iw-out_w)/2:(ih-out_h)/2";
    }
  }

  /// Get platform-appropriate video encoder arguments
  /// Uses FFmpegEncoder utility for consistent hardware/software selection
  String _getVideoEncoderArgs() {
    return FFmpegEncoder.getHardwareEncoderArgs();
  }

  /// Concatenates multiple video segments into a single video with optional aspect ratio crop
  ///
  /// If [aspectRatio] is provided, applies the crop filter to the final output.
  /// If not provided but any clip has [needsCrop] = true, uses that clip's aspectRatio.
  /// This supports deferred encoding on Android where crop is skipped during capture.
  /// If [muteAudio] is true, strips all audio from the output.
  /// Otherwise uses lossless copy mode.
  Future<String> concatenateSegments(
    List<RecordingClip> clips, {
    AspectRatio? aspectRatio,
    bool muteAudio = false,
  }) async {
    if (clips.isEmpty) {
      throw ArgumentError('Cannot concatenate empty clip list');
    }

    // Check if any clip needs deferred cropping (Android deferred encoding)
    final clipsNeedingCrop = clips.where((c) => c.needsCrop).toList();
    AspectRatio? effectiveAspectRatio = aspectRatio;

    if (effectiveAspectRatio == null && clipsNeedingCrop.isNotEmpty) {
      // Use the aspect ratio from the first clip that needs cropping
      effectiveAspectRatio = clipsNeedingCrop.first.aspectRatio;
      Log.info(
        'Deferred crop detected: ${clipsNeedingCrop.length}/${clips.length} clips need cropping, '
        'using aspectRatio=${effectiveAspectRatio?.name ?? "default"}',
        name: 'VideoExportService',
        category: LogCategory.system,
      );
    }

    // If only one clip and no processing needed, return it directly
    // If crop or mute is needed, we still need to process even a single clip
    if (clips.length == 1 && effectiveAspectRatio == null && !muteAudio) {
      Log.info(
        'Single clip detected, no processing needed, skipping FFmpeg',
        name: 'VideoExportService',
        category: LogCategory.system,
      );
      return clips.first.filePath;
    }

    try {
      Log.info(
        'Processing ${clips.length} clips${effectiveAspectRatio != null ? " with ${effectiveAspectRatio.name} crop" : ""}${muteAudio ? " (muted)" : ""}',
        name: 'VideoExportService',
        category: LogCategory.system,
      );

      // Get temp directory for concat list file
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final listFilePath = '${tempDir.path}/concat_list_$timestamp.txt';
      final outputPath = '${tempDir.path}/concatenated_$timestamp.mp4';

      // Create concat list file
      final sortedClips = List<RecordingClip>.from(clips)
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

      final listContent = sortedClips
          .map((clip) => "file '${clip.filePath}'")
          .join('\n');

      await File(listFilePath).writeAsString(listContent);

      Log.info(
        'Created concat list file: $listFilePath',
        name: 'VideoExportService',
        category: LogCategory.system,
      );

      // Build FFmpeg command - with or without crop filter and audio
      final audioArgs = muteAudio ? '-an' : '-c:a aac';

      // Always re-encode when there are multiple clips to fix timestamp discontinuities
      // Clips from library or different recording sessions have non-continuous timestamps
      // which causes issues with -c copy mode (Non-monotonous DTS warnings, lost content)
      final bool needsCrop = effectiveAspectRatio != null;
      final bool needsReencode = needsCrop || sortedClips.length > 1;

      if (needsReencode) {
        // Build crop filter only if aspect ratio is specified
        final String? cropFilter = needsCrop
            ? _buildCropFilter(effectiveAspectRatio)
            : null;

        // For single clip with crop, use simple -vf filter
        if (sortedClips.length == 1 && cropFilter != null) {
          final inputPath = sortedClips.first.filePath;
          // Limit output to 6.3 seconds max (Vine-style limit)
          final simpleCommand =
              '-y -i "$inputPath" -vf "$cropFilter" -t 6.3 $audioArgs ${_getVideoEncoderArgs()} "$outputPath"';

          Log.info(
            'Single clip crop (simple -vf): $simpleCommand',
            name: 'VideoExportService',
            category: LogCategory.system,
          );

          await FFmpegEncoder.executeCommandWithFallback(
            command: simpleCommand,
            logTag: 'VideoExportService',
          );

          // Cleanup temp files
          try {
            await File(listFilePath).delete();
          } catch (_) {}

          return outputPath;
        }

        // For multiple clips: re-encode each individually (with optional crop), then concat
        // This fixes timestamp discontinuities and avoids filter_complex issues on macOS
        Log.info(
          'Multi-clip re-encode: processing ${sortedClips.length} clips individually${needsCrop ? " with crop" : ""}',
          name: 'VideoExportService',
          category: LogCategory.system,
        );

        // Use software encoding (libx264) on macOS to avoid VideoToolbox resource accumulation
        // that can block the UI thread when running many sequential encode operations
        final useSoftwareEncoder = Platform.isMacOS;
        final encoderArgs = useSoftwareEncoder
            ? FFmpegEncoder.getSoftwareEncoderArgs()
            : _getVideoEncoderArgs();

        if (useSoftwareEncoder) {
          Log.info(
            'Using software encoder (libx264) on macOS for multi-clip',
            name: 'VideoExportService',
            category: LogCategory.system,
          );
        }

        final processedPaths = <String>[];
        for (var i = 0; i < sortedClips.length; i++) {
          final clip = sortedClips[i];
          final processedPath = '${tempDir.path}/processed_${timestamp}_$i.mp4';

          // Build command with optional crop filter
          final filterArg = cropFilter != null ? '-vf "$cropFilter"' : '';
          final processCommand =
              '-y -i "${clip.filePath}" $filterArg -c:a aac $encoderArgs "$processedPath"';

          Log.info(
            'Processing clip $i: $processCommand',
            name: 'VideoExportService',
            category: LogCategory.system,
          );

          await FFmpegEncoder.executeCommandWithFallback(
            command: processCommand,
            logTag: 'VideoExportService',
          );

          // Explicitly clear sessions after each encode to release encoder resources
          await FFmpegEncoder.clearSessions();

          processedPaths.add(processedPath);
        }

        // Concat processed clips using simple concat demuxer
        // Timestamps are now continuous since we re-encoded each clip
        final processedListContent = processedPaths
            .map((p) => "file '$p'")
            .join('\n');
        final processedListPath =
            '${tempDir.path}/processed_list_$timestamp.txt';
        await File(processedListPath).writeAsString(processedListContent);

        final concatAudioArgs = muteAudio ? '-an' : '-c:a copy';
        // Limit output to 6.3 seconds max (Vine-style limit)
        final concatCommand =
            '-y -f concat -safe 0 -i "$processedListPath" -t 6.3 -c:v copy $concatAudioArgs "$outputPath"';

        Log.info(
          'Concatenating processed clips: $concatCommand',
          name: 'VideoExportService',
          category: LogCategory.system,
        );

        final concatSession = await FFmpegKit.execute(concatCommand);
        final concatReturnCode = await concatSession.getReturnCode();
        await FFmpegEncoder.clearSessions();

        if (!ReturnCode.isSuccess(concatReturnCode)) {
          final output = await concatSession.getOutput();
          throw Exception('Concat failed: $output');
        }

        // Cleanup temp files
        try {
          await File(listFilePath).delete();
          await File(processedListPath).delete();
          for (final path in processedPaths) {
            await File(path).delete();
          }
        } catch (_) {}

        Log.info(
          'Successfully processed clips to: $outputPath',
          name: 'VideoExportService',
          category: LogCategory.system,
        );

        return outputPath;
      }

      // No encoding needed - just copy (single clip, no crop, no mute)
      // Still apply 6.3s max limit
      String command;
      if (muteAudio) {
        // No crop but muting: need to process to strip audio
        command =
            '-y -f concat -safe 0 -i "$listFilePath" -t 6.3 -c:v copy $audioArgs "$outputPath"';
      } else {
        // Without crop or mute: lossless copy
        command =
            '-y -f concat -safe 0 -i "$listFilePath" -t 6.3 -c copy "$outputPath"';
      }

      Log.info(
        'Running FFmpeg copy: $command',
        name: 'VideoExportService',
        category: LogCategory.system,
      );

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      // Clear sessions to free memory
      await FFmpegEncoder.clearSessions();

      if (ReturnCode.isSuccess(returnCode)) {
        Log.info(
          'Successfully processed clips to: $outputPath',
          name: 'VideoExportService',
          category: LogCategory.system,
        );

        // Clean up list file
        await File(listFilePath).delete();

        return outputPath;
      } else {
        final output = await session.getOutput();
        throw Exception('FFmpeg processing failed: $output');
      }
    } catch (e, stackTrace) {
      Log.error(
        'Failed to process clips: $e',
        name: 'VideoExportService',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Applies a text overlay PNG image to a video
  ///
  /// Uses FFmpeg overlay filter to composite the PNG on the video.
  /// The PNG should contain all text rendered by TextOverlayRenderer.
  /// If the overlay is smaller than the video (for memory reasons),
  /// FFmpeg will scale it up to match.
  Future<String> applyTextOverlay(
    String videoPath,
    Uint8List textOverlayImage,
  ) async {
    try {
      Log.info(
        'Applying text overlay to video: $videoPath',
        name: 'VideoExportService',
        category: LogCategory.system,
      );

      // Get temp directory for overlay PNG and output
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final overlayPngPath = '${tempDir.path}/overlay_$timestamp.png';
      final outputPath = '${tempDir.path}/with_overlay_$timestamp.mp4';

      // Write overlay PNG to temp file
      await File(overlayPngPath).writeAsBytes(textOverlayImage);

      Log.info(
        'Saved overlay PNG to: $overlayPngPath (${textOverlayImage.length} bytes)',
        name: 'VideoExportService',
        category: LogCategory.system,
      );

      // Run FFmpeg overlay command
      // Use scale2ref to scale the overlay PNG to match the video dimensions
      // This handles cases where overlay was rendered at lower resolution for memory safety
      // [0:v] is the video, [1:v] is the overlay PNG
      // scale2ref scales the second input to match the first input's dimensions
      // shortest=1 in overlay filter stops when video ends (more efficient than -shortest)
      // eof_action=endall terminates filter immediately when video reaches EOF
      final overlayFilter =
          '[1:v][0:v]scale2ref[scaled][video];[video][scaled]overlay=0:0:shortest=1:eof_action=endall';
      final effectiveFilter = FFmpegEncoder.isAndroid
          ? '$overlayFilter,format=nv12'
          : overlayFilter;
      final encoderArgs = _getVideoEncoderArgs();
      // -y flag to overwrite output (needed for fallback retry)
      // -loop 1 loops the PNG overlay (single frame) to match video duration
      final command =
          '-y -i "$videoPath" -loop 1 -i "$overlayPngPath" -filter_complex "$effectiveFilter" $encoderArgs -c:a copy "$outputPath"';

      Log.info(
        'Running FFmpeg overlay: $command',
        name: 'VideoExportService',
        category: LogCategory.system,
      );

      // Use fallback mechanism for hardware-to-software encoding
      try {
        await FFmpegEncoder.executeCommandWithFallback(
          command: command,
          logTag: 'VideoExportService',
        );

        Log.info(
          'Successfully applied overlay to: $outputPath',
          name: 'VideoExportService',
          category: LogCategory.system,
        );

        // Clean up overlay PNG
        await File(overlayPngPath).delete();

        return outputPath;
      } on FFmpegEncoderException catch (e) {
        throw Exception('FFmpeg overlay failed: ${e.message}');
      }
    } catch (e, stackTrace) {
      Log.error(
        'Failed to apply text overlay: $e',
        name: 'VideoExportService',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Mixes external audio with video for "use this sound" recording flows.
  ///
  /// This method handles post-recording audio mixing for lip-sync mode,
  /// where users record video to an external audio track.
  ///
  /// [videoPath] - Path to the recorded video file (may have original audio or be muted)
  /// [externalAudioPath] - Path to the external audio file (from Kind 1063 audio event)
  /// [voiceTrackPath] - Optional path to voice recording (when headphones enabled voice-over)
  ///
  /// Returns the path to the mixed video file.
  ///
  /// Cases handled:
  /// - Video + external audio only (lip sync mode, no voice)
  ///   Command: `ffmpeg -i video.mp4 -i audio.aac -c:v copy -map 0:v -map 1:a -shortest output.mp4`
  /// - Video + external audio + voice (voice-over mode with headphones)
  ///   Command: `ffmpeg -i video.mp4 -i external.aac -i voice.aac \
  ///            -filter_complex "[1:a][2:a]amix=inputs=2:duration=shortest[a]" \
  ///            -c:v copy -map 0:v -map "[a]" output.mp4`
  ///
  /// The original video's audio track is always replaced (not mixed),
  /// since in lip-sync mode the video is recorded with mic muted.
  Future<String> mixExternalAudio(
    String videoPath,
    String externalAudioPath, {
    String? voiceTrackPath,
  }) async {
    try {
      Log.info(
        'Mixing external audio with video: external=$externalAudioPath, '
        'voice=${voiceTrackPath ?? "none"}, video=$videoPath',
        name: 'VideoExportService',
        category: LogCategory.system,
      );

      // Get temp directory for output
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${tempDir.path}/mixed_audio_$timestamp.mp4';

      // Resolve external audio path (may be a file:// URL)
      String resolvedExternalPath = externalAudioPath;
      if (externalAudioPath.startsWith('file://')) {
        resolvedExternalPath = externalAudioPath.replaceFirst('file://', '');
      }

      // Verify external audio file exists
      final externalAudioFile = File(resolvedExternalPath);
      if (!await externalAudioFile.exists()) {
        throw Exception('External audio file not found: $resolvedExternalPath');
      }

      String command;

      if (voiceTrackPath != null) {
        // Case: Video + external audio + voice (voice-over mode)
        // Mix external audio with voice track using amix filter
        String resolvedVoicePath = voiceTrackPath;
        if (voiceTrackPath.startsWith('file://')) {
          resolvedVoicePath = voiceTrackPath.replaceFirst('file://', '');
        }

        // Verify voice file exists
        final voiceFile = File(resolvedVoicePath);
        if (!await voiceFile.exists()) {
          throw Exception('Voice track file not found: $resolvedVoicePath');
        }

        Log.info(
          'Mixing with voice track: $resolvedVoicePath',
          name: 'VideoExportService',
          category: LogCategory.system,
        );

        // FFmpeg command for mixing external audio + voice:
        // -i video.mp4 (input 0) - video file
        // -i external.aac (input 1) - external audio from sound library
        // -i voice.aac (input 2) - recorded voice track
        // [1:a][2:a]amix=inputs=2:duration=shortest - mix audio streams
        // -c:v copy - copy video stream without re-encoding
        // -map 0:v - use video from input 0
        // -map "[a]" - use mixed audio
        command =
            '-y -i "$videoPath" -i "$resolvedExternalPath" -i "$resolvedVoicePath" '
            '-filter_complex "[1:a][2:a]amix=inputs=2:duration=shortest[a]" '
            '-c:v copy -map 0:v -map "[a]" -c:a aac "$outputPath"';
      } else {
        // Case: Video + external audio only (lip sync mode)
        // Simple audio replacement without mixing
        // -c:v copy - copy video stream without re-encoding
        // -map 0:v - use video from first input
        // -map 1:a - use audio from second input
        // -shortest - finish when shortest stream ends
        command =
            '-y -i "$videoPath" -i "$resolvedExternalPath" '
            '-c:v copy -map 0:v -map 1:a -c:a aac -shortest "$outputPath"';
      }

      Log.info(
        'Running FFmpeg external audio mix: $command',
        name: 'VideoExportService',
        category: LogCategory.system,
      );

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      // Clear sessions to free memory
      await FFmpegEncoder.clearSessions();

      if (ReturnCode.isSuccess(returnCode)) {
        Log.info(
          'Successfully mixed external audio to: $outputPath',
          name: 'VideoExportService',
          category: LogCategory.system,
        );

        return outputPath;
      } else {
        final output = await session.getOutput();
        throw Exception('FFmpeg external audio mix failed: $output');
      }
    } catch (e, stackTrace) {
      Log.error(
        'Failed to mix external audio: $e',
        name: 'VideoExportService',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Mixes background audio with video
  ///
  /// For bundled assets, copies from Flutter assets to temp file.
  /// For custom sounds (file paths), uses the file directly.
  /// Runs: `ffmpeg -i video.mp4 -i audio.mp3 -c:v copy -c:a aac -map 0:v:0 -map 1:a:0 -shortest output.mp4`
  Future<String> mixAudio(String videoPath, String audioPath) async {
    try {
      Log.info(
        'Mixing audio: $audioPath with video: $videoPath',
        name: 'VideoExportService',
        category: LogCategory.system,
      );

      // Get temp directory for output
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${tempDir.path}/with_audio_$timestamp.mp4';

      String audioFilePath;

      // Check if it's a file path (custom sound) or asset path (bundled sound)
      if (audioPath.startsWith('/') || audioPath.startsWith('file://')) {
        // Custom sound - use file path directly
        audioFilePath = audioPath.replaceFirst('file://', '');
        Log.info(
          'Using custom sound file: $audioFilePath',
          name: 'VideoExportService',
          category: LogCategory.system,
        );
      } else {
        // Bundled asset - copy to temp file
        audioFilePath = '${tempDir.path}/audio_$timestamp.mp3';
        final audioBytes = await rootBundle.load(audioPath);
        await File(audioFilePath).writeAsBytes(audioBytes.buffer.asUint8List());
        Log.info(
          'Copied asset to: $audioFilePath',
          name: 'VideoExportService',
          category: LogCategory.system,
        );
      }

      // Run FFmpeg audio mixing command
      // -y = overwrite output file
      // -c:v copy = copy video codec (no re-encoding)
      // -c:a aac = encode audio to AAC
      // -map 0:v:0 = use video from first input
      // -map 1:a:0 = use audio from second input
      // -shortest = finish when shortest stream ends
      final command =
          '-y -i "$videoPath" -i "$audioFilePath" -c:v copy -c:a aac -map 0:v:0 -map 1:a:0 -shortest "$outputPath"';

      Log.info(
        'Running FFmpeg audio mix: $command',
        name: 'VideoExportService',
        category: LogCategory.system,
      );

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      // Clear sessions to free memory
      await FFmpegEncoder.clearSessions();

      if (ReturnCode.isSuccess(returnCode)) {
        Log.info(
          'Successfully mixed audio to: $outputPath',
          name: 'VideoExportService',
          category: LogCategory.system,
        );

        // Clean up temp audio file only if we copied from assets
        if (!audioPath.startsWith('/') && !audioPath.startsWith('file://')) {
          await File(audioFilePath).delete();
        }

        return outputPath;
      } else {
        final output = await session.getOutput();
        throw Exception('FFmpeg audio mix failed: $output');
      }
    } catch (e, stackTrace) {
      Log.error(
        'Failed to mix audio: $e',
        name: 'VideoExportService',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Generates a thumbnail from a video file
  ///
  /// Extracts a frame from the middle of the video
  Future<String?> generateThumbnail(String videoPath) async {
    try {
      Log.info(
        'Generating thumbnail from video: $videoPath',
        name: 'VideoExportService',
        category: LogCategory.system,
      );

      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 640,
        quality: 85,
      );

      if (thumbnailPath != null) {
        Log.info(
          'Generated thumbnail: $thumbnailPath',
          name: 'VideoExportService',
          category: LogCategory.system,
        );
      } else {
        Log.warning(
          'Failed to generate thumbnail for: $videoPath',
          name: 'VideoExportService',
          category: LogCategory.system,
        );
      }

      return thumbnailPath;
    } catch (e, stackTrace) {
      Log.error(
        'Failed to generate thumbnail: $e',
        name: 'VideoExportService',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Exports video clips with optional text overlays and audio mixing
  ///
  /// Full pipeline:
  /// 1. Concatenate segments (if multiple clips)
  /// 2. Apply text overlay (if textOverlays provided)
  /// 3. Mix audio (if soundId provided)
  /// 4. Generate thumbnail
  ///
  /// Progress is reported through [onProgress] callback with stage and progress (0.0-1.0)
  Future<ExportResult> export({
    required List<RecordingClip> clips,
    List<TextOverlay>? textOverlays,
    String? soundId,
    required void Function(ExportStage, double) onProgress,
  }) async {
    if (clips.isEmpty) {
      throw ArgumentError('Cannot export empty clip list');
    }

    try {
      Log.info(
        'Starting export pipeline: ${clips.length} clips, ${textOverlays?.length ?? 0} overlays, sound: ${soundId != null ? "yes" : "no"}',
        name: 'VideoExportService',
        category: LogCategory.system,
      );

      String currentVideoPath;

      // Step 1: Concatenate segments
      onProgress(ExportStage.concatenating, 0.0);
      currentVideoPath = await concatenateSegments(clips);
      onProgress(ExportStage.concatenating, 1.0);

      // Step 2: Apply text overlay (if provided)
      if (textOverlays != null && textOverlays.isNotEmpty) {
        onProgress(ExportStage.applyingTextOverlay, 0.0);

        // Render text overlays to PNG
        final renderer = TextOverlayRenderer();
        final overlayImage = await renderer.renderOverlays(
          textOverlays,
          const Size(1080, 1920), // Standard 9:16 vertical video
        );

        final previousPath = currentVideoPath;
        currentVideoPath = await applyTextOverlay(
          currentVideoPath,
          overlayImage,
        );

        // Clean up previous file if it was a temp file
        if (previousPath != clips.first.filePath) {
          await File(previousPath).delete();
        }

        onProgress(ExportStage.applyingTextOverlay, 1.0);
      }

      // Step 3: Mix audio (if provided)
      if (soundId != null) {
        onProgress(ExportStage.mixingAudio, 0.0);

        // Audio asset path should be provided or looked up from SoundLibraryService
        // For now, assume soundId is the asset path
        final audioAssetPath = soundId;

        final previousPath = currentVideoPath;
        currentVideoPath = await mixAudio(currentVideoPath, audioAssetPath);

        // Clean up previous file if it was a temp file
        if (previousPath != clips.first.filePath) {
          await File(previousPath).delete();
        }

        onProgress(ExportStage.mixingAudio, 1.0);
      }

      // Step 4: Generate thumbnail
      onProgress(ExportStage.generatingThumbnail, 0.0);
      final thumbnailPath = await generateThumbnail(currentVideoPath);
      onProgress(ExportStage.generatingThumbnail, 1.0);

      // Calculate total duration
      final totalDuration = clips.fold<Duration>(
        Duration.zero,
        (sum, clip) => sum + clip.duration,
      );

      onProgress(ExportStage.complete, 1.0);

      Log.info(
        'Export complete: $currentVideoPath (${totalDuration.inSeconds}s)',
        name: 'VideoExportService',
        category: LogCategory.system,
      );

      return ExportResult(
        videoPath: currentVideoPath,
        thumbnailPath: thumbnailPath,
        duration: totalDuration,
      );
    } catch (e, stackTrace) {
      Log.error(
        'Export failed: $e',
        name: 'VideoExportService',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
