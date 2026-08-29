// ABOUTME: Maps CameraPickError codes to localized strings.
// ABOUTME: The picker reports a code; the UI layer localizes for display.

import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/camera_pick_error.dart';

/// Maps a [CameraPickError] to a localized, user-facing message.
///
/// The switch has no `default`, so a new enum arm is a compile error here
/// rather than a silent fallthrough to the generic message.
extension CameraPickErrorL10n on AppLocalizations {
  String cameraPickErrorMessage(CameraPickError reason) {
    switch (reason) {
      case CameraPickError.permissionDenied:
        return cameraPickErrorPermissionDenied;
      case CameraPickError.permissionRestricted:
        return cameraPickErrorPermissionRestricted;
      case CameraPickError.busy:
        return cameraPickErrorBusy;
      case CameraPickError.generic:
        return cameraPickErrorGeneric;
    }
  }
}
