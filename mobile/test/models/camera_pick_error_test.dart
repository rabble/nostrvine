// ABOUTME: Tests the image_picker PlatformException -> CameraPickError mapping.
// ABOUTME: Classification is by error code, never by the plugin's English message.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/camera_pick_error.dart';

void main() {
  group('cameraPickErrorFrom', () {
    // Codes and messages as image_picker actually throws them, from
    // FLTImagePickerPlugin.m and ImagePickerDelegate.java.
    test('classifies a denied camera permission', () {
      expect(
        cameraPickErrorFrom(
          PlatformException(
            code: 'camera_access_denied',
            message: 'The user did not allow camera access.',
          ),
        ),
        CameraPickError.permissionDenied,
      );
    });

    test('classifies a restricted camera permission', () {
      expect(
        cameraPickErrorFrom(
          PlatformException(
            code: 'camera_access_restricted',
            message: 'The user is not allowed to use the camera.',
          ),
        ),
        CameraPickError.permissionRestricted,
      );
    });

    test('classifies a picker that is already in flight', () {
      for (final code in const ['already_active', 'multiple_request']) {
        expect(
          cameraPickErrorFrom(PlatformException(code: code)),
          CameraPickError.busy,
          reason: '$code should be busy',
        );
      }
    });

    test('falls back to generic for an unknown platform code', () {
      expect(
        cameraPickErrorFrom(PlatformException(code: 'no_activity')),
        CameraPickError.generic,
      );
    });

    test('falls back to generic for a non-platform exception', () {
      expect(cameraPickErrorFrom(StateError('nope')), CameraPickError.generic);
    });

    test('ignores the message, which is plugin-owned English', () {
      // Android passes `e.stackTraceToString()` as `details`, so nothing but
      // the code is safe to branch on.
      expect(
        cameraPickErrorFrom(
          PlatformException(
            code: 'camera_access_denied',
            message: 'some other wording entirely',
            details: 'java.lang.RuntimeException\n\tat com.example...',
          ),
        ),
        CameraPickError.permissionDenied,
      );
    });
  });
}
