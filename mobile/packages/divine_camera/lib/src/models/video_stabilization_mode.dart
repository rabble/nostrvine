// ABOUTME: Enum for video stabilization modes
// ABOUTME: Defines the cross-platform stabilization options for recording

/// Available video stabilization modes for the camera.
///
/// The vocabulary mirrors iOS `AVCaptureVideoStabilizationMode`. Android maps
/// these onto its EIS / preview-stabilization rungs; macOS and Linux do not
/// support stabilization and only ever report [off].
enum DivineVideoStabilizationMode {
  /// Stabilization is disabled.
  off,

  /// Basic stabilization with a modest crop.
  standard,

  /// Stronger, "cinematic" stabilization (larger crop, more latency).
  cinematic,

  /// The strongest cinematic stabilization tier available.
  cinematicExtended,

  /// Low-latency, low-power stabilization tuned for the preview path.
  ///
  /// iOS 17+ only (`AVCaptureVideoStabilizationMode.previewOptimized`); other
  /// platforms never report it.
  previewOptimized,

  /// Stabilization that adds no latency to the capture pipeline, at the cost
  /// of a reduced field of view.
  ///
  /// iOS 26+ only (`AVCaptureVideoStabilizationMode.lowLatency`); other
  /// platforms never report it.
  lowLatency,

  /// Let the platform pick the best supported mode automatically.
  auto;

  /// Converts the mode to a string for platform communication.
  String toNativeString() {
    switch (this) {
      case DivineVideoStabilizationMode.off:
        return 'off';
      case DivineVideoStabilizationMode.standard:
        return 'standard';
      case DivineVideoStabilizationMode.cinematic:
        return 'cinematic';
      case DivineVideoStabilizationMode.cinematicExtended:
        return 'cinematicExtended';
      case DivineVideoStabilizationMode.previewOptimized:
        return 'previewOptimized';
      case DivineVideoStabilizationMode.lowLatency:
        return 'lowLatency';
      case DivineVideoStabilizationMode.auto:
        return 'auto';
    }
  }

  /// Creates a stabilization mode from a native string. Falls back to [off]
  /// for unknown values.
  static DivineVideoStabilizationMode fromNativeString(String value) {
    switch (value) {
      case 'standard':
        return DivineVideoStabilizationMode.standard;
      case 'cinematic':
        return DivineVideoStabilizationMode.cinematic;
      case 'cinematicExtended':
        return DivineVideoStabilizationMode.cinematicExtended;
      case 'previewOptimized':
        return DivineVideoStabilizationMode.previewOptimized;
      case 'lowLatency':
        return DivineVideoStabilizationMode.lowLatency;
      case 'auto':
        return DivineVideoStabilizationMode.auto;
      case 'off':
      default:
        return DivineVideoStabilizationMode.off;
    }
  }

  /// Maps a list of native strings to stabilization modes, preserving order
  /// and dropping duplicates. Always contains at least [off].
  static List<DivineVideoStabilizationMode> fromNativeStringList(
    List<dynamic> values,
  ) {
    final modes = <DivineVideoStabilizationMode>[];
    for (final value in values) {
      final mode = fromNativeString(value as String);
      if (!modes.contains(mode)) modes.add(mode);
    }
    if (!modes.contains(DivineVideoStabilizationMode.off)) {
      modes.insert(0, DivineVideoStabilizationMode.off);
    }
    return modes;
  }
}
