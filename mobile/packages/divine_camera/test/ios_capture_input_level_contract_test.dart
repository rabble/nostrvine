// ABOUTME: Static guards for the iOS mic-level re-settle before capture.
// ABOUTME: The override must stay scoped to a speaker-only output route.

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
  group('iOS capture input level re-settle', () {
    late final String controllerSource;

    setUpAll(() {
      controllerSource = _readNativeSource('CameraController.swift');
    });

    test('record start re-settles the route once audio is ready', () {
      // iOS damps the mic input while the countdown beeps play out of the
      // speaker and restores it only slowly, so capture would otherwise
      // start on a damped input and climb back over several seconds.
      expect(
        controllerSource,
        contains('self.resettleSpeakerRouteBeforeCapture()'),
      );
      expect(
        controllerSource,
        contains('private func resettleSpeakerRouteBeforeCapture() {'),
      );
      expect(
        controllerSource,
        contains('try session.overrideOutputAudioPort(.speaker)'),
      );
    });

    test('the override stays scoped to a speaker-only route', () {
      // Overriding while headphones or Bluetooth are connected would drag
      // playback off them, and no speaker output reached the mic anyway.
      expect(
        controllerSource,
        contains(
          'guard outputs.count == 1, outputs[0].portType == .builtInSpeaker',
        ),
      );
    });

    test('a failed override does not abort the recording', () {
      final helperStart = controllerSource.indexOf(
        'private func resettleSpeakerRouteBeforeCapture() {',
      );
      final helper = controllerSource.substring(
        helperStart,
        controllerSource.indexOf('\n    }\n', helperStart),
      );
      expect(helper, contains('catch'));
      expect(helper, isNot(contains('return false')));
      expect(helper, isNot(contains('throw')));
    });
  });
}
