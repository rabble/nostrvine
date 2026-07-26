import 'package:models/models.dart' as model show AspectRatio;

enum VideoRecorderMode {
  upload,
  capture,
  stopMotion,
  lipSync,
  classic;

  /// SharedPreferences key for the last-used recorder mode.
  ///
  /// Persisted by the recorder and read by surfaces that live on a separate
  /// route from the recorder's `BlocProvider` (e.g. the metadata screen), which
  /// therefore cannot read it from `VideoRecorderBloc`.
  static const persistenceKey = 'camera_last_used_recorder_mode';

  /// Parses a persisted mode [name], defaulting to [capture] for null/unknown.
  static VideoRecorderMode fromName(String? name) =>
      values.firstWhere((m) => m.name == name, orElse: () => capture);

  String get label => switch (this) {
    .upload => 'Upload',
    .capture => 'Capture',
    .stopMotion => 'Stop Motion',
    .lipSync => 'Lip Sync',
    .classic => 'Classic',
  };

  bool get hasRecordingLimit => switch (this) {
    .upload => false,
    .capture => false,
    .stopMotion => false,
    .lipSync => false,
    .classic => true,
  };

  bool get hasVideoEditor => switch (this) {
    .upload => false,
    .capture => true,
    .stopMotion => true,
    .lipSync => true,
    .classic => false,
  };

  bool get supportGridLines => switch (this) {
    .upload => false,
    .capture => false,
    .stopMotion => true,
    .lipSync => false,
    .classic => true,
  };

  bool get supportsCountdownTimer => switch (this) {
    .upload => false,
    .capture => true,
    .stopMotion => false,
    .lipSync => true,
    .classic => false,
  };

  bool get supportsVideoStabilization => switch (this) {
    .upload => false,
    .capture => true,
    .stopMotion => false,
    .lipSync => true,
    .classic => false,
  };

  model.AspectRatio get defaultAspectRatio => switch (this) {
    .upload => .vertical,
    .capture => .vertical,
    .stopMotion => .vertical,
    .lipSync => .vertical,
    .classic => .square,
  };

  /// Whether the mode itself dictates the capture shape, overriding whatever
  /// the user last chose.
  ///
  /// Only Classic does: it is the 1:1 Vine format by definition. Every other
  /// mode leaves the shape to the user's aspect-ratio toggle, so switching
  /// between them must not silently rewrite it — that is what turned an
  /// accidental Classic selection into a permanently square capture (#6200).
  bool get constrainsAspectRatio => this == classic;

  /// Whether this mode captures still photos (stop-motion) instead of
  /// recording video. Drives the shutter behavior and capture UI.
  bool get capturesStills => this == stopMotion;
}
