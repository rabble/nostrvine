// ABOUTME: Tests for the typed caption generation exceptions.
// ABOUTME: Pins the toString contract used in logs and error reports.

import 'package:caption_generator/caption_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(CaptionGenerationException, () {
    test('toString names the concrete type and message', () {
      expect(
        const AudioFileNotFoundException('/tmp/a.wav').toString(),
        equals('AudioFileNotFoundException: Audio file not found: /tmp/a.wav'),
      );
      expect(
        const SpeechRecognizerUnavailableException('no recognizer').toString(),
        equals('SpeechRecognizerUnavailableException: no recognizer'),
      );
    });

    test('$TranscriptionFailedException omits an absent cause', () {
      expect(
        const TranscriptionFailedException('boom').toString(),
        equals('TranscriptionFailedException: boom'),
      );
    });
  });
}
