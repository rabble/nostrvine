// ABOUTME: Tests for AudioSessionService AVAudioSession policy.
// ABOUTME: Covers recorder/editor playback configuration without an audio player.

import 'package:audio_session/audio_session.dart' as audio_session;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sound_service/sound_service.dart';

class _MockAudioSessionWrapper extends Mock implements AudioSessionWrapper {}

class _FakeAudioSessionConfig extends Fake
    implements audio_session.AudioSessionConfiguration {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeAudioSessionConfig());
  });

  group(AudioSessionService, () {
    late _MockAudioSessionWrapper wrapper;
    late AudioSessionService service;

    setUp(() {
      wrapper = _MockAudioSessionWrapper();
      service = AudioSessionService(audioSessionWrapper: wrapper);

      when(() => wrapper.configure(any())).thenAnswer((_) async {});
    });

    test('can create with default audio session wrapper', () {
      expect(AudioSessionService(), isA<AudioSessionService>());
    });

    test('configureForRecording uses playAndRecord with A2DP', () async {
      await service.configureForRecording();

      final captured =
          verify(() => wrapper.configure(captureAny())).captured.single
              as audio_session.AudioSessionConfiguration;
      expect(
        captured.avAudioSessionCategory,
        audio_session.AVAudioSessionCategory.playAndRecord,
      );
      expect(
        captured.avAudioSessionCategoryOptions,
        audio_session.AVAudioSessionCategoryOptions.defaultToSpeaker |
            audio_session.AVAudioSessionCategoryOptions.allowBluetoothA2dp,
      );
      expect(
        captured.avAudioSessionCategoryOptions! &
            audio_session.AVAudioSessionCategoryOptions.allowBluetooth,
        audio_session.AVAudioSessionCategoryOptions.none,
      );
      expect(captured.androidWillPauseWhenDucked, isFalse);
    });

    test(
      'configureForMixedPlayback uses playback with mixWithOthers',
      () async {
        await service.configureForMixedPlayback();

        final captured =
            verify(() => wrapper.configure(captureAny())).captured.single
                as audio_session.AudioSessionConfiguration;
        expect(
          captured.avAudioSessionCategory,
          audio_session.AVAudioSessionCategory.playback,
        );
        expect(
          captured.avAudioSessionCategoryOptions,
          audio_session.AVAudioSessionCategoryOptions.mixWithOthers,
        );
        expect(captured.androidWillPauseWhenDucked, isFalse);
      },
    );

    test('resetAudioSession uses playback without mixing', () async {
      await service.resetAudioSession();

      final captured =
          verify(() => wrapper.configure(captureAny())).captured.single
              as audio_session.AudioSessionConfiguration;
      expect(
        captured.avAudioSessionCategory,
        audio_session.AVAudioSessionCategory.playback,
      );
      expect(
        captured.avAudioSessionCategoryOptions,
        audio_session.AVAudioSessionCategoryOptions.none,
      );
      expect(captured.androidWillPauseWhenDucked, isTrue);
    });

    test('configuration errors are swallowed', () async {
      when(() => wrapper.configure(any())).thenThrow(Exception('boom'));

      await expectLater(service.configureForRecording(), completes);
      await expectLater(service.configureForMixedPlayback(), completes);
      await expectLater(service.resetAudioSession(), completes);
    });
  });
}
