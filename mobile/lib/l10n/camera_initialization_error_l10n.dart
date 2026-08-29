// ABOUTME: Maps CameraInitializationError reason codes to localized strings.
// ABOUTME: State stores the reason; the UI layer localizes for display.

import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_recorder/camera_initialization_error.dart';

/// Maps a [CameraInitializationError] to a localized, user-facing message.
///
/// Follows the project's l10n rule: state carries codes, never English copy.
/// Call this from widgets, where an [AppLocalizations] is available.
extension CameraInitializationErrorL10n on AppLocalizations {
  String cameraInitializationErrorMessage(CameraInitializationError error) {
    switch (error) {
      case CameraInitializationError.failed:
        return cameraCouldNotStart;
      case CameraInitializationError.unsupportedPlatform:
        return cameraUnsupportedPlatform;
    }
  }
}
