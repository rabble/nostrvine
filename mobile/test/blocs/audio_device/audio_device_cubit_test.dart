// ABOUTME: Unit tests for AudioDeviceCubit — load + setDeviceId (incl. null
// ABOUTME: meaning Auto recommended).

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/audio_device/audio_device_cubit.dart';
import 'package:openvine/blocs/audio_device/audio_device_state.dart';
import 'package:openvine/services/audio_device_preference_service.dart';

class _MockAudioDevicePreferenceService extends Mock
    implements AudioDevicePreferenceService {}

void main() {
  group(AudioDeviceCubit, () {
    late _MockAudioDevicePreferenceService service;

    setUp(() {
      service = _MockAudioDevicePreferenceService();
      when(() => service.initialize()).thenAnswer((_) async {});
      when(() => service.preferredDeviceId).thenReturn(null);
      when(() => service.setPreferredDeviceId(any())).thenAnswer((_) async {});
    });

    AudioDeviceCubit buildCubit() => AudioDeviceCubit(service: service);

    blocTest<AudioDeviceCubit, AudioDeviceState>(
      'load with null preference emits ready + Auto',
      build: buildCubit,
      act: (cubit) => cubit.load(),
      expect: () => [
        const AudioDeviceState(status: AudioDeviceStatus.ready),
      ],
      verify: (_) {
        verify(() => service.initialize()).called(1);
      },
    );

    blocTest<AudioDeviceCubit, AudioDeviceState>(
      'load with persisted device snapshots it',
      setUp: () {
        when(() => service.preferredDeviceId).thenReturn('mic-1');
      },
      build: buildCubit,
      act: (cubit) => cubit.load(),
      expect: () => [
        const AudioDeviceState(
          status: AudioDeviceStatus.ready,
          currentDeviceId: 'mic-1',
        ),
      ],
    );

    blocTest<AudioDeviceCubit, AudioDeviceState>(
      'setDeviceId(non-null) delegates and emits new device',
      seed: () => const AudioDeviceState(status: AudioDeviceStatus.ready),
      build: buildCubit,
      act: (cubit) => cubit.setDeviceId('mic-2'),
      setUp: () {
        when(() => service.preferredDeviceId).thenReturn('mic-2');
      },
      expect: () => [
        const AudioDeviceState(
          status: AudioDeviceStatus.ready,
          currentDeviceId: 'mic-2',
        ),
      ],
      verify: (_) {
        verify(() => service.setPreferredDeviceId('mic-2')).called(1);
      },
    );

    blocTest<AudioDeviceCubit, AudioDeviceState>(
      'setDeviceId emits the post-write service snapshot',
      seed: () => const AudioDeviceState(
        status: AudioDeviceStatus.ready,
        currentDeviceId: 'mic-2',
      ),
      setUp: () {
        when(() => service.preferredDeviceId).thenReturn('mic-1');
      },
      build: buildCubit,
      act: (cubit) => cubit.setDeviceId('mic-2'),
      expect: () => [
        const AudioDeviceState(
          status: AudioDeviceStatus.ready,
          currentDeviceId: 'mic-1',
        ),
      ],
      verify: (_) {
        verify(() => service.setPreferredDeviceId('mic-2')).called(1);
      },
    );

    blocTest<AudioDeviceCubit, AudioDeviceState>(
      'setDeviceId(null) delegates and emits the cleared Auto state',
      seed: () => const AudioDeviceState(
        status: AudioDeviceStatus.ready,
        currentDeviceId: 'mic-1',
      ),
      build: buildCubit,
      act: (cubit) => cubit.setDeviceId(null),
      expect: () => [
        const AudioDeviceState(status: AudioDeviceStatus.ready),
      ],
      verify: (_) {
        verify(() => service.setPreferredDeviceId(null)).called(1);
      },
    );
  });
}
