// ABOUTME: Unit tests for SoundsCubit — search filter, audio-preview
// ABOUTME: lifecycle (toggle, no-url, success, failure), and the saveSound
// ABOUTME: passthrough.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/sounds/sounds_cubit.dart';
import 'package:openvine/blocs/sounds/sounds_state.dart';
import 'package:openvine/services/saved_sounds_service.dart';
import 'package:sound_service/sound_service.dart';

class _MockAudioPlaybackService extends Mock implements AudioPlaybackService {}

void main() {
  group(SoundsCubit, () {
    late _MockAudioPlaybackService audio;
    late SaveSoundAction saveSound;
    SavedSoundSaveResult saveSoundResult = SavedSoundSaveResult.saved;
    final saveSoundCalls = <AudioEvent>[];

    AudioEvent makeSound({
      String id = 's1',
      String? url = 'https://cdn.example/s1.mp3',
      String? title = 'Sound',
    }) {
      return AudioEvent(
        id: id,
        pubkey: 'pk',
        createdAt: 0,
        url: url,
        title: title,
      );
    }

    setUp(() {
      audio = _MockAudioPlaybackService();
      saveSoundResult = SavedSoundSaveResult.saved;
      saveSoundCalls.clear();
      saveSound = (sound) async {
        saveSoundCalls.add(sound);
        return saveSoundResult;
      };
      when(audio.stop).thenAnswer((_) async {});
      when(audio.play).thenAnswer((_) async {});
      when(() => audio.loadAudio(any())).thenAnswer((_) async => null);
    });

    SoundsCubit buildCubit() => SoundsCubit(
      audioPlaybackService: audio,
      saveSound: saveSound,
    );

    blocTest<SoundsCubit, SoundsState>(
      'setSearchQuery lowercases and emits',
      build: buildCubit,
      act: (cubit) => cubit.setSearchQuery('MeMe'),
      expect: () => [const SoundsState(searchQuery: 'meme')],
    );

    test('filterSounds returns input unchanged with empty query', () {
      final cubit = buildCubit();
      final sounds = [makeSound(id: '1', title: 'Drumroll')];
      expect(cubit.filterSounds(sounds), same(sounds));
      addTearDown(cubit.close);
    });

    test('filterSounds matches title case-insensitively', () {
      final cubit = buildCubit()..setSearchQuery('DRUM');
      final sounds = [
        makeSound(id: '1', title: 'Drumroll'),
        makeSound(id: '2', title: 'Trumpet'),
      ];
      final filtered = cubit.filterSounds(sounds);
      expect(filtered.map((s) => s.id), ['1']);
      addTearDown(cubit.close);
    });

    blocTest<SoundsCubit, SoundsState>(
      'previewSound returns ignored when already loading',
      seed: () => const SoundsState(isLoadingPreview: true),
      build: buildCubit,
      act: (cubit) async {
        final outcome = await cubit.previewSound(makeSound());
        expect(outcome, PreviewSoundOutcome.ignored);
      },
      expect: () => const <SoundsState>[],
      verify: (_) {
        verifyNever(audio.stop);
        verifyNever(audio.play);
      },
    );

    blocTest<SoundsCubit, SoundsState>(
      'previewSound on currently-playing id stops and clears state',
      seed: () => const SoundsState(previewingSoundId: 's1'),
      build: buildCubit,
      act: (cubit) async {
        final outcome = await cubit.previewSound(makeSound());
        expect(outcome, PreviewSoundOutcome.stopped);
      },
      expect: () => [const SoundsState()],
      verify: (_) {
        verify(audio.stop).called(1);
        verifyNever(audio.play);
      },
    );

    blocTest<SoundsCubit, SoundsState>(
      'previewSound returns unavailable when URL is missing',
      build: buildCubit,
      act: (cubit) async {
        final outcome = await cubit.previewSound(
          makeSound(id: 's2', url: null),
        );
        expect(outcome, PreviewSoundOutcome.unavailable);
      },
      expect: () => const <SoundsState>[],
      verify: (_) {
        verifyNever(audio.play);
      },
    );

    blocTest<SoundsCubit, SoundsState>(
      'previewSound success: loads, plays, then clears state',
      build: buildCubit,
      act: (cubit) async {
        final outcome = await cubit.previewSound(makeSound(id: 's3'));
        expect(outcome, PreviewSoundOutcome.completed);
      },
      // States: loading → playing → cleared.
      expect: () => [
        const SoundsState(isLoadingPreview: true),
        const SoundsState(previewingSoundId: 's3'),
        const SoundsState(),
      ],
      verify: (_) {
        verify(audio.stop).called(1);
        verify(() => audio.loadAudio('https://cdn.example/s1.mp3')).called(1);
        verify(audio.play).called(1);
      },
    );

    blocTest<SoundsCubit, SoundsState>(
      'previewSound failure reports addError and returns failed',
      setUp: () {
        when(audio.play).thenThrow(StateError('audio bus locked'));
      },
      build: buildCubit,
      act: (cubit) async {
        final outcome = await cubit.previewSound(makeSound(id: 's4'));
        expect(outcome, PreviewSoundOutcome.failed);
      },
      expect: () => [
        const SoundsState(isLoadingPreview: true),
        const SoundsState(previewingSoundId: 's4'),
        const SoundsState(),
      ],
      errors: () => [isA<StateError>()],
    );

    blocTest<SoundsCubit, SoundsState>(
      'stopPreview is a no-op when nothing is playing',
      build: buildCubit,
      act: (cubit) => cubit.stopPreview(),
      expect: () => const <SoundsState>[],
      verify: (_) {
        verifyNever(audio.stop);
      },
    );

    blocTest<SoundsCubit, SoundsState>(
      'stopPreview clears the playing sound and calls stop',
      seed: () => const SoundsState(previewingSoundId: 's5'),
      build: buildCubit,
      act: (cubit) => cubit.stopPreview(),
      expect: () => [const SoundsState()],
      verify: (_) {
        verify(audio.stop).called(1);
      },
    );

    test(
      'close() stops the audio service while a preview is playing '
      '(navigate-away cleanup contract)',
      () async {
        // play() stays pending so the Cubit rests in the "currently
        // previewing" state, mirroring real playback (just_audio's play()
        // completes only when the sound is stopped or finishes).
        final playController = Completer<void>();
        when(audio.play).thenAnswer((_) => playController.future);
        final cubit = buildCubit();

        final previewing = cubit.previewSound(makeSound());
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.previewingSoundId, 's1');

        // Isolate the close()-triggered stop from the pre-load stop().
        clearInteractions(audio);
        await cubit.close();
        verify(audio.stop).called(1);

        // Let the dangling play() future resolve cleanly (no emit-after-close).
        playController.complete();
        await previewing;
      },
    );

    test(
      'previewSound stops the loaded source and skips emitting when the '
      'Cubit is closed mid-load',
      () async {
        // Hold loadAudio open so we can close() the Cubit while it is still
        // in the loading phase (previewingSoundId not yet set).
        final loadController = Completer<Duration?>();
        when(
          () => audio.loadAudio(any()),
        ).thenAnswer((_) => loadController.future);
        final cubit = buildCubit();

        final previewing = cubit.previewSound(makeSound(id: 's7'));
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.isLoadingPreview, isTrue);
        expect(cubit.state.previewingSoundId, isNull);

        // Navigate away mid-load: close() can't stop yet (no id set).
        await cubit.close();
        clearInteractions(audio);

        // Resolving the load must stop the just-loaded source and must NOT
        // emit into the closed Cubit (which would throw a StateError).
        loadController.complete(const Duration(seconds: 6));
        final outcome = await previewing;

        expect(outcome, PreviewSoundOutcome.ignored);
        verify(audio.stop).called(1);
        verifyNever(audio.play);
      },
    );

    test(
      'saveSound delegates to injected callable and returns result',
      () async {
        final cubit = buildCubit();
        saveSoundResult = SavedSoundSaveResult.alreadySaved;
        final sound = makeSound(id: 's6');
        final result = await cubit.saveSound(sound);
        expect(result, SavedSoundSaveResult.alreadySaved);
        expect(saveSoundCalls, [sound]);
        addTearDown(cubit.close);
      },
    );
  });
}
