// ABOUTME: Failure types for video render operations
// ABOUTME: Keeps render error telemetry stable across service refactors

/// Why a render produced no output.
enum VideoRenderFailureReason {
  emptyClips('empty_clips'),
  stopMotionAssembly('stop_motion_assembly'),
  nativeRender('native_render'),
  canceled('canceled');

  const VideoRenderFailureReason(this.traceValue);

  /// Stable telemetry value, independent of enum names.
  final String traceValue;
}

/// Thrown when a render finished without producing a video.
class VideoRenderFailedException implements Exception {
  const VideoRenderFailedException(this.reason, {this.cause});

  final VideoRenderFailureReason reason;
  final Object? cause;

  /// Compact telemetry label, e.g. `native_render:PlatformException`.
  String get traceValue => cause == null
      ? reason.traceValue
      : '${reason.traceValue}:${cause.runtimeType}';

  @override
  String toString() =>
      'VideoRenderFailedException(${reason.traceValue})'
      '${cause == null ? '' : ': $cause'}';
}
