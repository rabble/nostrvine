// ABOUTME: Static guards for the iOS unprocessed-audio capture contract.
// ABOUTME: Pins the Music mode audio-session mode mapping (#7796).

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
/// brace, so an assertion cannot match an identical line elsewhere in the
/// file, nor a line that sits outside the scope being asserted on.
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
  group('iOS unprocessed audio contract', () {
    late final String controllerSource;
    late final String pluginSource;
    late final String configureAudioSession;
    late final String attachAudioToSession;

    setUpAll(() {
      controllerSource = _readNativeSource('CameraController.swift');
      pluginSource = _readNativeSource('DivineCameraPlugin.swift');
      configureAudioSession = _declarationAt(
        controllerSource,
        'private func configureAudioSessionForRecording(',
      );
      attachAudioToSession = _declarationAt(
        controllerSource,
        'private func attachAudioToSessionIfNeeded(',
      );
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
      expect(
        configureAudioSession,
        contains('var mode = desiredAudioSessionMode'),
      );
      expect(configureAudioSession, contains('mode: mode,'));
      expect(configureAudioSession, isNot(contains('mode: .videoRecording,')));
    });

    test('falls back to the default mode rather than losing the audio', () {
      // A device that rejects .measurement must still get an audio track:
      // returning false here ships a clip with no audio at all, which is
      // worse than the processing the user opted out of.
      expect(
        configureAudioSession,
        contains('guard mode != .videoRecording else { throw error }'),
      );
      expect(configureAudioSession, contains('falling back to '));
    });

    test('latches a refused mode so the reuse path stops churning', () {
      // Without this the preference stays set after the fallback, so the
      // reuse path below reads a permanent mode mismatch and tears the audio
      // capture session down and back up before every recording — and its
      // cheap setActive(true) interruption recovery never runs again.
      expect(
        configureAudioSession,
        contains('prefersUnprocessedAudio = false'),
      );
    });

    test(
      'treats a live session on the wrong mode as needing a reconfigure',
      () {
        // The reuse path returns early when the category already matches, so
        // without the mode check a warm session keeps the old processing.
        expect(
          attachAudioToSession,
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
