@Tags(['skip_very_good_optimization'])
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/video_recorder_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sound_service/sound_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

import '../mocks/mock_camera_service.dart';

class _MockAudioPlaybackService extends Mock implements AudioPlaybackService {}

class _FakeWakelockPlatform extends WakelockPlusPlatformInterface {
  @override
  Future<void> toggle({required bool enable}) async {}

  @override
  Future<bool> get enabled async => false;
}

void main() {
  setUpAll(() {
    wakelockPlusPlatformInstance = _FakeWakelockPlatform();
  });

  group('VideoRecorderNotifier - Audio Playback Service Factory (#4539)', () {
    test(
      'startRecording uses injected AudioPlaybackService factory when '
      'a sound is selected',
      () async {
        final mockAudioPlaybackService = _MockAudioPlaybackService();
        when(
          mockAudioPlaybackService.configureForRecording,
        ).thenAnswer((_) async {});
        when(
          () => mockAudioPlaybackService.loadAudio(any()),
        ).thenAnswer((_) async => const Duration(seconds: 6));
        when(mockAudioPlaybackService.play).thenAnswer((_) async {});
        when(mockAudioPlaybackService.stop).thenAnswer((_) async {});
        when(
          mockAudioPlaybackService.resetAudioSession,
        ).thenAnswer((_) async {});
        when(mockAudioPlaybackService.dispose).thenAnswer((_) async {});

        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        final mockCamera = MockCameraService.create(
          onUpdateState: ({forceCameraRebuild}) {},
          onAutoStopped: (_) {},
        );
        await mockCamera.initialize();

        const selectedSound = AudioEvent(
          id: 'sound_123',
          pubkey:
              'test_pubkey_0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          createdAt: 1700000000,
          title: 'Test Sound',
          duration: 6.0,
          url: 'https://example.com/audio/sound_123.m4a',
          mimeType: 'audio/mp4',
        );

        var factoryCalls = 0;
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            videoRecorderProvider.overrideWith(
              () => VideoRecorderNotifier(
                mockCamera,
                null,
                () {
                  factoryCalls++;
                  return mockAudioPlaybackService;
                },
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(videoRecorderProvider.notifier);
        await notifier.initialize();
        container.read(videoEditorProvider.notifier).selectSound(selectedSound);

        await notifier.startRecording();

        expect(factoryCalls, equals(1));
        verify(mockAudioPlaybackService.configureForRecording).called(1);
        verify(
          () => mockAudioPlaybackService.loadAudio(selectedSound.url!),
        ).called(1);
        verify(mockAudioPlaybackService.play).called(1);

        await notifier.stopRecording();

        verify(mockAudioPlaybackService.stop).called(1);
        verify(mockAudioPlaybackService.resetAudioSession).called(1);
      },
    );
  });
}
