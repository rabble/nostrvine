// ABOUTME: Shared FFmpeg encoder utility for platform-specific video encoding
// ABOUTME: Provides hardware-first encoding with automatic software fallback

import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Utility class for FFmpeg video encoding operations.
///
/// Provides platform-specific encoder selection with hardware-first approach
/// and automatic fallback to software encoding when hardware fails.
///
/// Hardware encoders:
/// - iOS/macOS: h264_videotoolbox (VideoToolbox)
/// - Android: h264_mediacodec (MediaCodec)
///
/// Software encoder (fallback):
/// - All platforms: libx264 with appropriate presets
class FFmpegEncoder {
  FFmpegEncoder._();

  static bool _initialized = false;

  /// Initialize FFmpegKit with memory-efficient settings.
  ///
  /// Sets session history size to a small value to prevent memory buildup.
  /// Should be called once during app startup.
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Limit session history to 3 sessions to prevent memory buildup
      // Each session holds logs and output data that accumulates
      await FFmpegKitConfig.setSessionHistorySize(3);
      _initialized = true;
      Log.info(
        'FFmpegKit initialized with session history size: 3',
        name: 'FFmpegEncoder',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Failed to initialize FFmpegKit config: $e',
        name: 'FFmpegEncoder',
        category: LogCategory.system,
      );
    }
  }

  /// Clear all FFmpeg sessions to free memory.
  ///
  /// Should be called after encoding operations complete to prevent OOM.
  static Future<void> clearSessions() async {
    try {
      await FFmpegKitConfig.clearSessions();
      Log.info(
        'Cleared FFmpegKit sessions',
        name: 'FFmpegEncoder',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Failed to clear FFmpegKit sessions: $e',
        name: 'FFmpegEncoder',
        category: LogCategory.system,
      );
    }
  }

  /// Check if running on Android
  static bool get isAndroid => Platform.isAndroid;

  /// Check if running on Apple platform (iOS or macOS)
  static bool get isApplePlatform => Platform.isIOS || Platform.isMacOS;

  /// Get hardware encoder arguments for the current platform.
  ///
  /// Returns platform-specific hardware encoder:
  /// - iOS/macOS: h264_videotoolbox with 4Mbps bitrate
  /// - Android: Uses software encoder (libx264) because h264_mediacodec fails
  ///   with complex filter chains (concat + crop) on most devices
  /// - Other: Falls back to software encoder
  static String getHardwareEncoderArgs() {
    if (isApplePlatform) {
      return '-c:v h264_videotoolbox -b:v 4M';
    } else if (isAndroid) {
      // Use software encoding on Android - h264_mediacodec consistently fails
      // with "Error submitting video frame to the encoder" when using
      // filter_complex with concat + crop. Software encoding is more reliable
      // and avoids wasting time on failed hardware attempts.
      return getSoftwareEncoderArgs();
    }
    // Fallback to software for unknown platforms
    return getSoftwareEncoderArgs();
  }

  /// Get software encoder arguments (libx264).
  ///
  /// Uses ultrafast preset for speed during real-time operations.
  /// CRF 23 provides good quality/size balance.
  static String getSoftwareEncoderArgs() {
    return '-c:v libx264 -preset ultrafast -crf 23';
  }

  /// Inject format filter for encoder compatibility.
  ///
  /// Previously injected format=nv12 for Android MediaCodec, but since we now
  /// use libx264 on Android (MediaCodec fails with complex filter chains),
  /// no format injection is needed. This method is kept for API compatibility.
  ///
  /// Returns the existing filter unchanged.
  static String? injectFormatFilter(String? existingFilter) {
    // No format injection needed - we use libx264 on Android which handles
    // any input format, and h264_videotoolbox on Apple platforms works fine
    return existingFilter;
  }

  /// Build a complete FFmpeg command string.
  ///
  /// [input] - Input file path
  /// [output] - Output file path
  /// [videoFilter] - Optional video filter (e.g., crop, scale)
  /// [audioArgs] - Optional audio encoder arguments
  /// [extraArgs] - Optional extra arguments (e.g., -r 30 -vsync cfr)
  /// [useHardwareEncoder] - Whether to use hardware encoder (true) or software (false)
  /// [overwrite] - Whether to overwrite output file (adds -y flag)
  static String buildCommand({
    required String input,
    required String output,
    String? videoFilter,
    String? audioArgs,
    String? extraArgs,
    bool useHardwareEncoder = true,
    bool overwrite = true,
  }) {
    final parts = <String>[];

    // Overwrite flag
    if (overwrite) {
      parts.add('-y');
    }

    // Input file
    parts.add('-i "$input"');

    // Video filter (with format injection for Android hardware encoding)
    String? effectiveFilter = videoFilter;
    if (useHardwareEncoder && isAndroid && videoFilter != null) {
      effectiveFilter = injectFormatFilter(videoFilter);
    }
    if (effectiveFilter != null && effectiveFilter.isNotEmpty) {
      parts.add('-vf "$effectiveFilter"');
    }

    // Video encoder
    if (useHardwareEncoder) {
      parts.add(getHardwareEncoderArgs());
    } else {
      parts.add(getSoftwareEncoderArgs());
    }

    // Extra args (frame rate, vsync, etc.)
    if (extraArgs != null && extraArgs.isNotEmpty) {
      parts.add(extraArgs);
    }

    // Audio args
    if (audioArgs != null && audioArgs.isNotEmpty) {
      parts.add(audioArgs);
    }

    // Output file
    parts.add('"$output"');

    return parts.join(' ');
  }

  /// Execute FFmpeg command with hardware encoding, falling back to software if it fails.
  ///
  /// This method:
  /// 1. First attempts execution with hardware encoder (h264_mediacodec on Android)
  /// 2. If hardware encoding fails, automatically retries with software encoder (libx264)
  /// 3. Returns the successful session or throws if both fail
  ///
  /// [input] - Input file path
  /// [output] - Output file path
  /// [videoFilter] - Optional video filter chain
  /// [audioArgs] - Optional audio encoder arguments
  /// [extraArgs] - Optional extra arguments
  /// [logTag] - Tag for log messages
  static Future<FFmpegSession> executeWithFallback({
    required String input,
    required String output,
    String? videoFilter,
    String? audioArgs,
    String? extraArgs,
    String logTag = 'FFmpegEncoder',
  }) async {
    // Build hardware encoder command
    final hardwareCommand = buildCommand(
      input: input,
      output: output,
      videoFilter: videoFilter,
      audioArgs: audioArgs,
      extraArgs: extraArgs,
      useHardwareEncoder: true,
    );

    Log.info(
      'Attempting hardware encoding: $hardwareCommand',
      name: logTag,
      category: LogCategory.system,
    );

    // Try hardware encoding first
    final hardwareSession = await FFmpegKit.execute(hardwareCommand);
    final hardwareReturnCode = await hardwareSession.getReturnCode();

    if (ReturnCode.isSuccess(hardwareReturnCode)) {
      Log.info(
        'Hardware encoding succeeded',
        name: logTag,
        category: LogCategory.system,
      );
      // Clear sessions to free memory
      await clearSessions();
      return hardwareSession;
    }

    // Hardware encoding failed - log the error and try software
    final hardwareOutput = await hardwareSession.getOutput();
    Log.warning(
      'Hardware encoding failed (code: ${hardwareReturnCode?.getValue()}), falling back to software. Output: $hardwareOutput',
      name: logTag,
      category: LogCategory.system,
    );

    // Build software encoder command
    final softwareCommand = buildCommand(
      input: input,
      output: output,
      videoFilter: videoFilter,
      audioArgs: audioArgs,
      extraArgs: extraArgs,
      useHardwareEncoder: false,
    );

    Log.info(
      'Attempting software encoding: $softwareCommand',
      name: logTag,
      category: LogCategory.system,
    );

    // Try software encoding
    final softwareSession = await FFmpegKit.execute(softwareCommand);
    final softwareReturnCode = await softwareSession.getReturnCode();

    if (ReturnCode.isSuccess(softwareReturnCode)) {
      Log.info(
        'Software encoding succeeded (fallback)',
        name: logTag,
        category: LogCategory.system,
      );
      // Clear sessions to free memory
      await clearSessions();
      return softwareSession;
    }

    // Both failed - clear sessions and throw with details
    final softwareOutput = await softwareSession.getOutput();
    await clearSessions();
    throw FFmpegEncoderException(
      'Both hardware and software encoding failed',
      hardwareOutput: hardwareOutput,
      softwareOutput: softwareOutput,
    );
  }

  /// Execute a raw FFmpeg command string with hardware-to-software fallback.
  ///
  /// This is useful when you have a pre-built command that uses encoder placeholders.
  /// The method will replace encoder args and retry with software if hardware fails.
  ///
  /// [command] - The FFmpeg command with hardware encoder args
  /// [logTag] - Tag for log messages
  static Future<FFmpegSession> executeCommandWithFallback({
    required String command,
    String logTag = 'FFmpegEncoder',
  }) async {
    Log.info(
      'Executing with fallback: $command',
      name: logTag,
      category: LogCategory.system,
    );

    // Try the command as-is first (assumes hardware encoding)
    final hardwareSession = await FFmpegKit.execute(command);
    final hardwareReturnCode = await hardwareSession.getReturnCode();

    if (ReturnCode.isSuccess(hardwareReturnCode)) {
      Log.info('Command succeeded', name: logTag, category: LogCategory.system);
      // Clear sessions to free memory
      await clearSessions();
      return hardwareSession;
    }

    // Hardware failed - try software fallback on all platforms
    final hardwareOutput = await hardwareSession.getOutput();
    Log.warning(
      'Command failed (code: ${hardwareReturnCode?.getValue()}), attempting software fallback',
      name: logTag,
      category: LogCategory.system,
    );

    // Build software command by replacing encoder args
    String softwareCommand = command;

    // Replace Apple VideoToolbox encoder with libx264
    if (isApplePlatform) {
      softwareCommand = softwareCommand
          .replaceAll(
            '-c:v h264_videotoolbox -b:v 4M',
            getSoftwareEncoderArgs(),
          )
          .replaceAll('-c:v h264_videotoolbox', getSoftwareEncoderArgs())
          .replaceAll('h264_videotoolbox', 'libx264');
    }

    // On Android, replace h264_mediacodec with libx264
    // Replace the full h264_mediacodec encoder string with libx264
    // The hardware args are: -c:v h264_mediacodec -b:v 4M -g 30 -bf 0 -profile:v baseline -level 3.1
    // Replace with simpler libx264 args
    softwareCommand = softwareCommand.replaceAllMapped(
      RegExp(r'-c:v h264_mediacodec[^"]*?(?=-[a-z]|"|\s+-(?:c:|vf|i\s))'),
      (match) => '-c:v libx264 -preset ultrafast -crf 23 ',
    );

    // Fallback: simple replacement if regex didn't match
    if (softwareCommand.contains('h264_mediacodec')) {
      softwareCommand = softwareCommand
          .replaceAll(
            '-c:v h264_mediacodec -b:v 4M -g 30 -bf 0 -profile:v baseline -level 3.1',
            '-c:v libx264 -preset ultrafast -crf 23',
          )
          .replaceAll(
            '-c:v h264_mediacodec',
            '-c:v libx264 -preset ultrafast -crf 23',
          )
          .replaceAll('h264_mediacodec', 'libx264');
    }

    // Remove format=nv12 if present (not needed for libx264)
    final cleanedCommand = softwareCommand
        .replaceAll(',format=nv12', '')
        .replaceAll('format=nv12,', '')
        .replaceAll('-vf "format=nv12"', '');

    Log.info(
      'Retrying with software encoder: $cleanedCommand',
      name: logTag,
      category: LogCategory.system,
    );

    final softwareSession = await FFmpegKit.execute(cleanedCommand);
    final softwareReturnCode = await softwareSession.getReturnCode();

    if (ReturnCode.isSuccess(softwareReturnCode)) {
      Log.info(
        'Software encoding succeeded (fallback)',
        name: logTag,
        category: LogCategory.system,
      );
      // Clear sessions to free memory
      await clearSessions();
      return softwareSession;
    }

    // Both failed - clear sessions and throw with details
    final softwareOutput = await softwareSession.getOutput();
    await clearSessions();
    throw FFmpegEncoderException(
      'Both hardware and software encoding failed',
      hardwareOutput: hardwareOutput,
      softwareOutput: softwareOutput,
    );
  }
}

/// Exception thrown when FFmpeg encoding fails.
class FFmpegEncoderException implements Exception {
  FFmpegEncoderException(
    this.message, {
    this.hardwareOutput,
    this.softwareOutput,
  });

  final String message;
  final String? hardwareOutput;
  final String? softwareOutput;

  @override
  String toString() {
    final buffer = StringBuffer('FFmpegEncoderException: $message');
    if (hardwareOutput != null) {
      buffer.writeln('\nHardware output: $hardwareOutput');
    }
    if (softwareOutput != null) {
      buffer.writeln('\nSoftware output: $softwareOutput');
    }
    return buffer.toString();
  }
}
