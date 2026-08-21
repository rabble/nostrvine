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

    test('the re-settle runs before the writer starts', () {
      // "Before capture" is the contract: once the writer is running, an
      // override no longer rescues the damped input the beeps left behind,
      // it only changes the route mid-clip.
      final resettleCall = controllerSource.indexOf(
        'self.resettleSpeakerRouteBeforeCapture()',
      );
      final writerStart = controllerSource.indexOf(
        'self.startRecordingAfterAudioReady(',
      );
      expect(resettleCall, isNonNegative);
      expect(writerStart, isNonNegative);
      expect(resettleCall, lessThan(writerStart));
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
      expect(helper, isNot(contains('throw')));
    });
  });
}
