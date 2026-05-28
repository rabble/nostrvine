// ABOUTME: Unit tests for AudioSharingCubit — load + toggle.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/audio_sharing/audio_sharing_cubit.dart';
import 'package:openvine/blocs/audio_sharing/audio_sharing_state.dart';
import 'package:openvine/services/audio_sharing_preference_service.dart';

class _MockAudioSharingPreferenceService extends Mock
    implements AudioSharingPreferenceService {}

void main() {
  group(AudioSharingCubit, () {
    late _MockAudioSharingPreferenceService service;

    setUp(() {
      service = _MockAudioSharingPreferenceService();
      when(() => service.isAudioSharingEnabled).thenReturn(false);
      when(
        () => service.setAudioSharingEnabled(any()),
      ).thenAnswer((_) async {});
    });

    AudioSharingCubit buildCubit() => AudioSharingCubit(service: service);

    blocTest<AudioSharingCubit, AudioSharingState>(
      'load snapshots service state',
      setUp: () {
        when(() => service.isAudioSharingEnabled).thenReturn(true);
      },
      build: buildCubit,
      act: (cubit) => cubit.load(),
      expect: () => [
        const AudioSharingState(
          status: AudioSharingStatus.ready,
          isEnabled: true,
        ),
      ],
    );

    blocTest<AudioSharingCubit, AudioSharingState>(
      'setEnabled delegates to service and emits re-read snapshot',
      seed: () => const AudioSharingState(status: AudioSharingStatus.ready),
      setUp: () {
        when(() => service.isAudioSharingEnabled).thenReturn(true);
      },
      build: buildCubit,
      act: (cubit) => cubit.setEnabled(true),
      expect: () => [
        const AudioSharingState(
          status: AudioSharingStatus.ready,
          isEnabled: true,
        ),
      ],
      verify: (_) {
        verify(() => service.setAudioSharingEnabled(true)).called(1);
      },
    );
  });
}
