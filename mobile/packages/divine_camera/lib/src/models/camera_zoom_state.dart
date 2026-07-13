// ABOUTME: Zoom state actually applied by the platform camera after a set
// ABOUTME: Carries the read-back zoom plus the live available zoom range

/// Result of a `setZoomLevel` call: what the camera actually applied.
///
/// [zoomLevel] is read back from the device after the assignment rather
/// than echoing the request — on iOS virtual multi-camera devices the
/// system restricts `min/maxAvailableVideoZoomFactor` at runtime (e.g.
/// while recording or with video stabilization active) and silently
/// clamps out-of-range assignments instead of throwing.
/// [minZoomLevel] / [maxZoomLevel] carry that live range so callers can
/// surface honest bounds instead of the configure-time snapshot.
class CameraZoomState {
  /// Creates a zoom state.
  const CameraZoomState({
    required this.zoomLevel,
    required this.minZoomLevel,
    required this.maxZoomLevel,
  });

  /// Creates a zoom state from a platform channel map.
  factory CameraZoomState.fromMap(Map<dynamic, dynamic> map) {
    return CameraZoomState(
      zoomLevel: (map['zoomLevel'] as num?)?.toDouble() ?? 1.0,
      minZoomLevel: (map['minZoomLevel'] as num?)?.toDouble() ?? 1.0,
      maxZoomLevel: (map['maxZoomLevel'] as num?)?.toDouble() ?? 1.0,
    );
  }

  /// The zoom level the camera actually applied.
  final double zoomLevel;

  /// The minimum zoom level currently available on the device.
  final double minZoomLevel;

  /// The maximum zoom level currently available on the device.
  final double maxZoomLevel;

  @override
  String toString() =>
      'CameraZoomState(zoomLevel: $zoomLevel, '
      'minZoomLevel: $minZoomLevel, maxZoomLevel: $maxZoomLevel)';
}
