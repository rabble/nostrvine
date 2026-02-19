// ABOUTME: Filter callback for platform-unsupported video formats.
// ABOUTME: Allows app to inject platform checks without coupling to dart:io.

import 'package:models/models.dart';

/// Filter callback for platform-incompatible video formats.
///
/// Returns `true` if the [video] should be excluded because its format
/// is not supported on the current platform (e.g. WebM on iOS/macOS).
///
/// This keeps the repository decoupled from `dart:io` Platform checks.
/// The app layer provides the implementation with actual platform detection.
typedef VideoPlatformFilter = bool Function(VideoEvent video);
