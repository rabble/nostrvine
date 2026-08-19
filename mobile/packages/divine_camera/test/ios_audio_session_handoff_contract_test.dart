// ABOUTME: Static guards for the iOS recorder-to-editor audio-session handoff.
// ABOUTME: disposeCamera must not resolve before the capture sessions stop.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _readNativeSource(String fileName) {
  final file = [
    File('ios/Classes/$fileName'),
    File('packages/divine_camera/ios/Classes/$fileName'),
  ].firstWhere((file) => file.existsSync());

  return file.readAsStringSync();
}

void main() {
  group('iOS camera dispose audio-session handoff', () {
    late final String pluginSource;
    late final String controllerSource;

    setUpAll(() {
      pluginSource = _readNativeSource('DivineCameraPlugin.swift');
      controllerSource = _readNativeSource('CameraController.swift');
    });

    test('disposeCamera resolves through the teardown completion', () {
      // Resolving before CameraController.release() has stopped the capture
      // sessions makes the caller's setCategory(.playback) fail with
      // InsufficientPriority (OSStatus 561017449), which leaves the editor
      // playing back through the recorder's .playAndRecord session.
      expect(pluginSource, contains('controller.release {'));
      expect(
        pluginSource,
        isNot(
          contains(
            'cameraController?.release()\n'
            '        cameraController = nil\n'
            '        result(nil)',
          ),
        ),
      );
    });

    test('release exposes a completion and fires it after teardown', () {
      expect(
        controllerSource,
        contains('func release(completion: (() -> Void)? = nil) {'),
      );
      expect(
        controllerSource,
        contains('DispatchQueue.main.async(execute: completion)'),
      );
    });

    test('release retains the controller for its queued teardown', () {
      // The plugin drops its reference as soon as release() returns, so a
      // weak capture here could deallocate the controller before the
      // teardown — and therefore the completion — ever ran.
      expect(
        controllerSource,
        contains(
          'sessionQueue.async {\n            // Stop recording if in progress',
        ),
      );
    });
  });
}
