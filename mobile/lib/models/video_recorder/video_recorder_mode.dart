import 'package:models/models.dart' as model show AspectRatio;

enum VideoRecorderMode {
  capture,
  classic
  ;

  String get label => switch (this) {
    .capture => 'Capture',
    .classic => 'Classic',
  };

  bool get hasRecordingLimit => switch (this) {
    .capture => false,
    .classic => true,
  };

  bool get hasVideoEditor => switch (this) {
    .capture => true,
    .classic => false,
  };

  bool get supportGridLines => switch (this) {
    .capture => false,
    .classic => true,
  };

  model.AspectRatio get defaultAspectRatio => switch (this) {
    .capture => .vertical,
    .classic => .square,
  };
}
