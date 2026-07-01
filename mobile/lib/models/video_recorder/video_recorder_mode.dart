import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/constants/video_editor_constants.dart';

enum VideoRecorderMode {
  upload,
  capture,
  sixtySeconds,
  lipSync,
  classic,
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
    .upload => 'Upload',
    .capture => 'Capture',
    .sixtySeconds => '60s',
    .lipSync => 'Lip Sync',
    .classic => 'Classic',
  };

  bool get hasRecordingLimit => switch (this) {
    .upload => false,
    .capture => false,
    .sixtySeconds => false,
    .lipSync => true,
    .classic => true,
  };

  bool get hasVideoEditor => switch (this) {
    .upload => false,
    .capture => true,
    .sixtySeconds => true,
    .lipSync => true,
    .classic => false,
  };

  bool get supportGridLines => switch (this) {
    .upload => false,
    .capture => false,
    .sixtySeconds => false,
    .lipSync => false,
    .classic => true,
  };

  bool get supportsCountdownTimer => switch (this) {
    .upload => false,
    .capture => true,
    .sixtySeconds => true,
    .lipSync => true,
    .classic => false,
  };

  model.AspectRatio get defaultAspectRatio => switch (this) {
    .upload => .vertical,
    .capture => .vertical,
    .sixtySeconds => .vertical,
    .lipSync => .vertical,
    .classic => .square,
  };

  /// Maximum total recording and editing duration for this mode.
  ///
  /// The 60s mode raises the cap; every other mode keeps the standard
  /// [VideoEditorConstants.defaultMaxDuration]. The recorder applies this to
  /// the runtime [VideoEditorConstants.maxDuration] on mode change so the
  /// recorder, editor, render and upload paths all honour the same limit.
  Duration get maxRecordingDuration => switch (this) {
    .sixtySeconds => const Duration(seconds: 60),
    .upload ||
    .capture ||
    .lipSync ||
    .classic => VideoEditorConstants.maxDuration,
  };
}
