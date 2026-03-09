// ABOUTME: Tests for AudioSessionWrapper abstraction layer
// ABOUTME: Validates the wrapper interface and default implementation

import 'package:flutter_test/flutter_test.dart';
import 'package:sound_service/sound_service.dart';

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  group(AudioSessionWrapper, () {
    test('DefaultAudioSessionWrapper implements AudioSessionWrapper', () {
      final wrapper = DefaultAudioSessionWrapper();
      expect(wrapper, isA<AudioSessionWrapper>());
    });
  });
}
