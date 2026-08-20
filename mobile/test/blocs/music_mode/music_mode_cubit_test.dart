// ABOUTME: Unit tests for MusicModeCubit — load + toggle.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/music_mode/music_mode_cubit.dart';
import 'package:openvine/blocs/music_mode/music_mode_state.dart';
import 'package:openvine/services/music_mode_preference_service.dart';

class _MockMusicModePreferenceService extends Mock
    implements MusicModePreferenceService {}

void main() {
  group(MusicModeCubit, () {
    late _MockMusicModePreferenceService service;

    setUp(() {
      service = _MockMusicModePreferenceService();
      when(() => service.isMusicModeEnabled).thenReturn(false);
      when(() => service.setMusicModeEnabled(any())).thenAnswer((_) async {});
    });

    MusicModeCubit buildCubit() => MusicModeCubit(service: service);

    blocTest<MusicModeCubit, MusicModeState>(
      'load snapshots service state',
      setUp: () {
        when(() => service.isMusicModeEnabled).thenReturn(true);
      },
      build: buildCubit,
      act: (cubit) => cubit.load(),
      expect: () => [
        const MusicModeState(status: MusicModeStatus.ready, isEnabled: true),
      ],
    );

    blocTest<MusicModeCubit, MusicModeState>(
      'setEnabled delegates to service and emits re-read snapshot',
      seed: () => const MusicModeState(status: MusicModeStatus.ready),
      setUp: () {
        when(() => service.isMusicModeEnabled).thenReturn(true);
      },
      build: buildCubit,
      act: (cubit) => cubit.setEnabled(true),
      expect: () => [
        const MusicModeState(status: MusicModeStatus.ready, isEnabled: true),
      ],
      verify: (_) {
        verify(() => service.setMusicModeEnabled(true)).called(1);
      },
    );
  });
}
