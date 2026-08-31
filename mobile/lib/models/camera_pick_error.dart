// ABOUTME: Reason codes for a failed camera capture in the image picker.
// ABOUTME: Classifies image_picker PlatformExceptions; the UI localizes the code.

import 'package:flutter/services.dart';

/// Why opening the camera to pick an image failed.
///
/// The arms differ in what the user can do: a denied permission is fixable in
/// Settings, a restricted one is not, and a busy picker just needs a retry.
enum CameraPickError {
  /// The user declined the camera permission. Fixable in system Settings.
  /// image_picker code `camera_access_denied`.
  permissionDenied,

  /// Camera use is blocked by device policy or parental controls, so the user
  /// cannot grant it themselves. image_picker code `camera_access_restricted`.
  permissionRestricted,

  /// A pick is already in flight. image_picker codes `already_active` and
  /// `multiple_request`.
  busy,

  /// Anything else. Kept last so a new arm is a compile error in the
  /// localization switch rather than a silent fallthrough.
  generic,
}

/// Classifies what `ImagePicker.pickImage` threw.
///
/// Matches on the platform error *code*, never the message: the messages are
/// English strings owned by the plugin, and on Android the `details` field
/// carries a stack trace.
CameraPickError cameraPickErrorFrom(Object error) {
  if (error is! PlatformException) return CameraPickError.generic;
  switch (error.code) {
    case 'camera_access_denied':
      return CameraPickError.permissionDenied;
    case 'camera_access_restricted':
      return CameraPickError.permissionRestricted;
    case 'already_active':
    case 'multiple_request':
      return CameraPickError.busy;
    default:
      return CameraPickError.generic;
  }
}
