import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/video_volume/video_volume_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(VideoVolumeCubit, () {
    late SharedPreferences prefs;

    setUp(() async {
      // Stub the volume_controller platform channel to suppress
      // MissingPluginException during tests.
      const volumeEventChannel = EventChannel(
        'com.kurenai7968.volume_controller.volume_listener_event',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
            volumeEventChannel,
            MockStreamHandler.inline(
              onListen: (_, events) => events.endOfStream(),
            ),
          );

      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await SharedPreferences.getInstance();
    });

    VideoVolumeCubit buildCubit() => VideoVolumeCubit(sharedPreferences: prefs);

    group('initial state', () {
      test('defaults volume to 1.0', () {
        final cubit = buildCubit();
        addTearDown(cubit.close);

        expect(cubit.state.volume, equals(1.0));
        expect(cubit.state.isMuted, isFalse);
      });

      test('reads persisted volume from SharedPreferences', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'video_playback_volume': 0.0,
        });
        final prefsWithValue = await SharedPreferences.getInstance();

        final cubit = VideoVolumeCubit(sharedPreferences: prefsWithValue);
        addTearDown(cubit.close);

        expect(cubit.state.volume, equals(0.0));
        expect(cubit.state.isMuted, isTrue);
      });
    });

    group('onPlaybackVolumeChanged', () {
      blocTest<VideoVolumeCubit, VideoVolumeState>(
        'emits new volume',
        build: buildCubit,
        act: (cubit) => cubit.onPlaybackVolumeChanged(0),
        expect: () => const [VideoVolumeState(volume: 0)],
      );

      blocTest<VideoVolumeCubit, VideoVolumeState>(
        'does not emit when volume is unchanged',
        build: buildCubit,
        act: (cubit) => cubit.onPlaybackVolumeChanged(1),
        expect: () => const <VideoVolumeState>[],
      );

      test('persists volume to SharedPreferences', () async {
        final cubit = buildCubit();
        addTearDown(cubit.close);

        cubit.onPlaybackVolumeChanged(0);

        // Allow the async _persist to complete.
        await Future<void>.delayed(Duration.zero);

        expect(prefs.getDouble('video_playback_volume'), equals(0.0));
      });
    });

    group('simulateSystemVolumeChange', () {
      blocTest<VideoVolumeCubit, VideoVolumeState>(
        'mutes when system volume drops to zero',
        build: buildCubit,
        act: (cubit) => cubit.simulateSystemVolumeChange(0),
        expect: () => const [VideoVolumeState(volume: 0)],
      );

      blocTest<VideoVolumeCubit, VideoVolumeState>(
        'unmutes when system volume rises above zero',
        build: buildCubit,
        seed: () => const VideoVolumeState(volume: 0),
        act: (cubit) => cubit.simulateSystemVolumeChange(0.5),
        expect: () => const [VideoVolumeState()],
      );

      blocTest<VideoVolumeCubit, VideoVolumeState>(
        'no-ops when system volume changes but state unchanged',
        build: buildCubit,
        act: (cubit) => cubit.simulateSystemVolumeChange(0.5),
        expect: () => const <VideoVolumeState>[],
      );

      blocTest<VideoVolumeCubit, VideoVolumeState>(
        'no-ops when already muted and system is zero',
        build: buildCubit,
        seed: () => const VideoVolumeState(volume: 0),
        act: (cubit) => cubit.simulateSystemVolumeChange(0),
        expect: () => const <VideoVolumeState>[],
      );

      test('persists when muting', () async {
        final cubit = buildCubit();
        addTearDown(cubit.close);

        cubit.simulateSystemVolumeChange(0);

        await Future<void>.delayed(Duration.zero);

        expect(prefs.getDouble('video_playback_volume'), equals(0.0));
      });

      test('persists when unmuting', () async {
        final cubit = buildCubit();
        addTearDown(cubit.close);

        cubit.onPlaybackVolumeChanged(0);
        await Future<void>.delayed(Duration.zero);

        cubit.simulateSystemVolumeChange(0.7);
        await Future<void>.delayed(Duration.zero);

        expect(prefs.getDouble('video_playback_volume'), equals(1.0));
      });
    });

    group('close', () {
      test('can be called without error', () async {
        final cubit = buildCubit();
        await expectLater(cubit.close(), completes);
      });
    });
  });
}
