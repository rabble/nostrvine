// ABOUTME: Static guards for the iOS unprocessed-audio capture contract (#7796).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('iOS unprocessed audio contract', () {
    late final String controllerSource;
    late final String pluginSource;

    String read(String relativePath) {
      final file = [
        File('ios/Classes/$relativePath'),
        File('packages/divine_camera/ios/Classes/$relativePath'),
      ].firstWhere((file) => file.existsSync());
      return file.readAsStringSync();
    }

    setUpAll(() {
      controllerSource = read('CameraController.swift');
      pluginSource = read('DivineCameraPlugin.swift');
    });

    test('keeps the speech-tuned mode as the default', () {
      // Off by default is the whole reason this ships as an opt-in: the
      // processing is what keeps ordinary talking clips clean.
      expect(
        controllerSource,
        contains('private var prefersUnprocessedAudio = false'),
      );
      expect(
        pluginSource,
        contains('args["preferUnprocessedAudio"] as? Bool ?? false'),
      );
    });

    test('maps the preference onto .measurement', () {
      // .measurement is the mode Apple documents as minimising
      // system-supplied input processing — the escape hatch from the noise
      // suppression that gates an instrument away.
      expect(
        controllerSource,
        contains('prefersUnprocessedAudio ? .measurement : .videoRecording'),
      );
    });

    test('configures the session from the resolved mode, not a literal', () {
      // A hardcoded `mode: .videoRecording` here would silently ignore the
      // preference while every other layer reported it as applied.
      expect(controllerSource, contains('var mode = desiredAudioSessionMode'));
      expect(controllerSource, contains('mode: mode,'));
      expect(controllerSource, isNot(contains('mode: .videoRecording,')));
    });

    test('falls back to the default mode rather than losing the audio', () {
      // A device that rejects .measurement must still get an audio track:
      // returning false here ships a clip with no audio at all, which is
      // worse than the processing the user opted out of.
      expect(
        controllerSource,
        contains('guard mode != .videoRecording else { throw error }'),
      );
      expect(controllerSource, contains('falling back to '));
    });

    test(
      'treats a live session on the wrong mode as needing a reconfigure',
      () {
        // The reuse path returns early when the category already matches, so
        // without the mode check a warm session keeps the old processing.
        expect(
          controllerSource,
          contains('|| session.mode != desiredAudioSessionMode'),
        );
      },
    );

    test('logs the active mode with the per-recording audio state', () {
      // A "music sounds gated" bug report has to be answerable from the
      // captured log alone.
      expect(controllerSource, contains(r'mode=\(session.mode.rawValue)'));
    });
  });
}
