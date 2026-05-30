import 'package:models/models.dart' as model show AspectRatio;

enum VideoRecorderMode {
  capture,
  classic,
  upload,
  ;

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
    .capture => 'Capture',
    .classic => 'Classic',
    .upload => 'Upload',
  };

  bool get hasRecordingLimit => switch (this) {
    .capture => false,
    .classic => true,
    .upload => false,
  };

  bool get hasVideoEditor => switch (this) {
    .capture => true,
    .classic => false,
    .upload => false,
  };

  bool get supportGridLines => switch (this) {
    .capture => false,
    .classic => true,
    .upload => false,
  };

  bool get supportsCountdownTimer => switch (this) {
    .capture => true,
    .classic => false,
    .upload => false,
  };

  model.AspectRatio get defaultAspectRatio => switch (this) {
    .capture => .vertical,
    .classic => .square,
    .upload => .vertical,
  };
}
