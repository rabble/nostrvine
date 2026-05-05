import 'package:models/models.dart' as model show AspectRatio;

enum VideoRecorderMode {
  capture,
  classic,
  upload,
  ;

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

  model.AspectRatio get defaultAspectRatio => switch (this) {
    .capture => .vertical,
    .classic => .square,
    .upload => .vertical,
  };
}
