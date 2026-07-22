// ABOUTME: Tests for the caption generator platform interface defaults.
// ABOUTME: Pins that unimplemented platforms surface UnimplementedError.

import 'package:caption_generator/caption_generator_method_channel.dart';
import 'package:caption_generator/caption_generator_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

class _PartialPlatform extends CaptionGeneratorPlatform {}

void main() {
  group(CaptionGeneratorPlatform, () {
    test('defaults to $MethodChannelCaptionGenerator', () {
      expect(
        CaptionGeneratorPlatform.instance,
        isA<MethodChannelCaptionGenerator>(),
      );
    });

    test('transcribe throws $UnimplementedError by default', () {
      expect(
        () => _PartialPlatform().transcribe(audioPath: '/tmp/a.wav'),
        throwsUnimplementedError,
      );
    });
  });
}
