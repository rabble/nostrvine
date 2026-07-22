// ABOUTME: Tests for the unsupported-platform CaptionGenerator shim.
// ABOUTME: Pins the web-safe fallback behavior.

import 'package:caption_generator/src/caption_generator_unsupported.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('throws $UnsupportedError', () {
    final generator = CaptionGenerator();

    expect(
      () => generator.generateCaptions(audioPath: '/tmp/audio.wav'),
      throwsUnsupportedError,
    );
  });
}
