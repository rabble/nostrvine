// ABOUTME: Result class for video recording operations
// ABOUTME: Contains path, duration, and metadata of recorded video

import 'dart:io';

import 'package:equatable/equatable.dart';

/// Result of a video recording operation.
class VideoRecordingResult extends Equatable {
  /// Creates a new video recording result.
  const VideoRecordingResult({
    required this.filePath,
    this.durationMs,
    this.width,
    this.height,
  });

  /// Creates a [VideoRecordingResult] from a map.
  factory VideoRecordingResult.fromMap(Map<dynamic, dynamic> map) {
    return VideoRecordingResult(
      filePath: map['filePath'] as String,
      durationMs: map['durationMs'] as int?,
      width: map['width'] as int?,
      height: map['height'] as int?,
    );
  }

  /// The path to the recorded video file.
  final String filePath;

  /// The duration of the recorded video in milliseconds.
  final int? durationMs;

  /// The width of the recorded video in pixels.
  final int? width;

  /// The height of the recorded video in pixels.
  final int? height;

  /// Returns the video file.
  File get file => File(filePath);

  /// Returns the duration as a [Duration] object.
  Duration? get duration =>
      durationMs != null ? Duration(milliseconds: durationMs!) : null;

  /// Converts this result to a map.
  Map<String, dynamic> toMap() {
    return {
      'filePath': filePath,
      'durationMs': durationMs,
      'width': width,
      'height': height,
    };
  }

  @override
  String toString() {
    return 'VideoRecordingResult(filePath: $filePath, durationMs: $durationMs, '
        'width: $width, height: $height)';
  }

  @override
  List<Object?> get props => [filePath, durationMs, width, height];
}
