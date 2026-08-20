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

/// Returns the Swift declaration starting at [signature] up to its closing
/// brace, so an assertion cannot match an identical line elsewhere in the file.
String _declarationAt(String source, String signature) {
  final start = source.indexOf(signature);
  if (start < 0) {
    throw StateError('No declaration starting with "$signature".');
  }

  var depth = 0;
  for (var i = source.indexOf('{', start); i < source.length; i++) {
    if (source[i] == '{') depth++;
    if (source[i] == '}') {
      depth--;
      if (depth == 0) return source.substring(start, i + 1);
    }
  }
  throw StateError('Unbalanced braces after "$signature".');
}

void main() {
  group('iOS camera dispose audio-session handoff', () {
    late final String disposeCamera;
    late final String release;

    setUpAll(() {
      disposeCamera = _declarationAt(
        _readNativeSource('DivineCameraPlugin.swift'),
        'private func disposeCamera(',
      );
      release = _declarationAt(
        _readNativeSource('CameraController.swift'),
        'func release(',
      );
    });

    test('disposeCamera resolves through the teardown completion', () {
      // Resolving before CameraController.release() has stopped the capture
      // sessions makes the caller's setCategory(.playback) fail with
      // InsufficientPriority (OSStatus 561017449), which leaves the editor
      // playing back through the recorder's .playAndRecord session.
      expect(disposeCamera, contains('controller.release {'));
      expect(disposeCamera, isNot(contains('cameraController?.release()')));
    });

    test('disposeCamera still answers when there is no camera', () {
      // The completion is the only remaining path to `result`, so the
      // no-controller case needs its own early return or Dart waits forever.
      expect(
        disposeCamera,
        contains('guard let controller = cameraController'),
      );
    });

    test('release takes a completion and fires it after the teardown', () {
      expect(
        release,
        startsWith('func release(completion: (() -> Void)? = nil) {'),
      );
      expect(
        release,
        contains('DispatchQueue.main.async(execute: completion)'),
      );
    });

    test('release retains the controller so the completion always fires', () {
      // A `guard let self else { return }` inside the queued teardown would
      // drop the completion and hang the Dart caller awaiting disposeCamera.
      expect(release, isNot(contains('[weak self]')));
    });
  });
}
