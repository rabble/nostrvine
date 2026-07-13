// ABOUTME: One captured still in a stop-motion clip (image path + hold time)
// ABOUTME: Source-of-truth frame for a frames-based DivineVideoClip

import 'package:openvine/utils/path_resolver.dart';
import 'package:path/path.dart' as p;

/// A single captured still in a stop-motion clip, together with how long it is
/// held during playback.
///
/// Deliberately distinct from `pro_video_editor`'s `StopMotionFrame` (which
/// wraps an editor layer image): this is the persisted, source-of-truth frame
/// for a frames-based [DivineVideoClip]. Per-frame [duration] can vary; the
/// global "frames per image" control is a *default* that only rewrites frames
/// whose hold has not been set individually — see [holdOverridden].
class StopMotionClipFrame {
  const StopMotionClipFrame({
    required this.path,
    required this.duration,
    this.holdOverridden = false,
  });

  /// Absolute path to the captured JPEG still.
  final String path;

  /// How long this frame is held during playback.
  final Duration duration;

  /// Whether the user set this frame's hold individually. When `true`, the
  /// global frames-per-image control leaves it untouched; when `false`, the
  /// frame follows the global default.
  final bool holdOverridden;

  StopMotionClipFrame copyWith({
    String? path,
    Duration? duration,
    bool? holdOverridden,
  }) => StopMotionClipFrame(
    path: path ?? this.path,
    duration: duration ?? this.duration,
    holdOverridden: holdOverridden ?? this.holdOverridden,
  );

  /// Serializes to JSON, storing only the basename for iOS path stability
  /// (mirrors [DivineVideoClip.toJson]).
  ///
  /// The hold is stored in microseconds: frame holds are fractions of the
  /// output frame grid (2 frames @ 24fps = 83333µs) and a millisecond
  /// round-trip would silently shift them off the grid — and make history
  /// snapshots compare unequal to the live clip state on every sync.
  Map<String, dynamic> toJson() => {
    'path': p.basename(path),
    'durationUs': duration.inMicroseconds,
    'holdOverridden': holdOverridden,
  };

  /// Restores a frame, resolving [path] against [documentsPath] the same way
  /// [DivineVideoClip.fromJson] resolves clip file paths.
  factory StopMotionClipFrame.fromJson(
    Map<String, dynamic> json,
    String documentsPath, {
    bool useOriginalPath = false,
  }) {
    final durationUs = json['durationUs'] as int?;
    return StopMotionClipFrame(
      path: resolvePath(
        json['path'] as String,
        documentsPath,
        useOriginalPath: useOriginalPath,
      )!,
      duration: durationUs != null
          // Fallback: clips persisted before the microsecond key existed.
          ? Duration(microseconds: durationUs)
          : Duration(milliseconds: json['durationMs'] as int),
      // Absent for clips saved before per-frame holds existed → follows global.
      holdOverridden: json['holdOverridden'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is StopMotionClipFrame &&
      other.path == path &&
      other.duration == duration &&
      other.holdOverridden == holdOverridden;

  @override
  int get hashCode => Object.hash(path, duration, holdOverridden);

  @override
  String toString() =>
      'StopMotionClipFrame(path: $path, duration: $duration, '
      'holdOverridden: $holdOverridden)';
}
