// ABOUTME: Tests for AudioTimingCubit - audio timing state and playback.
// ABOUTME: Covers initialization, offset updates, playback lifecycle,
// ABOUTME: and start offset calculation using mocktail AudioClipPlayer mocks.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_editor/audio_timing/audio_timing_cubit.dart';
import 'package:sound_service/sound_service.dart';

class _MockAudioClipPlayer extends Mock implements AudioClipPlayer {}

/// Creates a test [AudioEvent] with optional overrides.
AudioEvent _createTestSound({
  String id = 'test_sound_id',
  double? duration = 20,
  Duration startOffset = Duration.zero,
  String? url = 'https://example.com/audio.mp3',
}) {
  return AudioEvent(
    id: id,
    pubkey: 'test_pubkey',
    createdAt: 0,
    duration: duration,
    startOffset: startOffset,
    url: url,
  );
}

/// Creates a bundled test [AudioEvent].
AudioEvent _createBundledSound({
  double? duration = 20,
  Duration startOffset = Duration.zero,
}) {
  return AudioEvent(
    id: 'bundled_test_sound',
    pubkey: AudioEvent.bundledMarker,
    createdAt: 0,
    duration: duration,
    startOffset: startOffset,
    url: 'asset://assets/sounds/test.mp3',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(Duration.zero);
    registerFallbackValue(const AudioSourceConfig.network(''));
  });

  group(AudioTimingCubit, () {
    late _MockAudioClipPlayer mockClipPlayer;

    setUp(() {
      mockClipPlayer = _MockAudioClipPlayer();
      when(() => mockClipPlayer.completionStream).thenAnswer(
        (_) => const Stream.empty(),
      );
      when(
        () => mockClipPlayer.setClip(any()),
      ).thenAnswer((_) async {});
      when(() => mockClipPlayer.play()).thenAnswer((_) async {});
      when(() => mockClipPlayer.pause()).thenAnswer((_) async {});
      when(() => mockClipPlayer.stop()).thenAnswer((_) async {});
      when(() => mockClipPlayer.seek(any())).thenAnswer((_) async {});
      when(() => mockClipPlayer.dispose()).thenAnswer((_) async {});
    });

    AudioTimingCubit buildCubit({
      AudioEvent? sound,
    }) {
      return AudioTimingCubit(
        sound: sound ?? _createTestSound(),
        clipPlayer: mockClipPlayer,
      );
    }

    test('initial state is default $AudioTimingState', () {
      final cubit = buildCubit();
      expect(cubit.state, equals(const AudioTimingState()));
      expect(cubit.state.startOffset, equals(0));
      expect(cubit.state.audioDuration, isNull);
      expect(cubit.state.isPlaying, isFalse);
      cubit.close();
    });

    group('initialize', () {
      blocTest<AudioTimingCubit, AudioTimingState>(
        'emits state with audio duration and starts playback '
        'for network audio',
        build: buildCubit,
        act: (cubit) => cubit.initialize(),
        expect: () => [
          isA<AudioTimingState>()
              .having((s) => s.audioDuration, 'audioDuration', 20)
              .having((s) => s.startOffset, 'startOffset', 0),
          isA<AudioTimingState>().having(
            (s) => s.isPlaying,
            'isPlaying',
            isTrue,
          ),
        ],
        verify: (_) {
          verify(
            () => mockClipPlayer.setClip(any()),
          ).called(1);
          verify(() => mockClipPlayer.play()).called(1);
        },
      );

      blocTest<AudioTimingCubit, AudioTimingState>(
        'restores previous offset from sound startOffset',
        build: () => buildCubit(
          sound: _createTestSound(
            // maxDuration = 6.3s, scrollable = 20 - 6.3 = 13.7s
            // For offset 0.5: startTime = 0.5 * 13.7 = 6.85s
            startOffset: const Duration(milliseconds: 6850),
          ),
        ),
        act: (cubit) => cubit.initialize(),
        expect: () => [
          isA<AudioTimingState>()
              .having((s) => s.audioDuration, 'audioDuration', 20)
              .having(
                (s) => s.startOffset,
                'startOffset',
                closeTo(0.5, 0.01),
              ),
          isA<AudioTimingState>().having(
            (s) => s.isPlaying,
            'isPlaying',
            isTrue,
          ),
        ],
      );

      blocTest<AudioTimingCubit, AudioTimingState>(
        'uses offset 0 when audio is shorter than maxDuration',
        build: () => buildCubit(
          sound: _createTestSound(duration: 3),
        ),
        act: (cubit) => cubit.initialize(),
        expect: () => [
          isA<AudioTimingState>()
              .having((s) => s.audioDuration, 'audioDuration', 3)
              .having((s) => s.startOffset, 'startOffset', 0),
          isA<AudioTimingState>().having(
            (s) => s.isPlaying,
            'isPlaying',
            isTrue,
          ),
        ],
      );

      blocTest<AudioTimingCubit, AudioTimingState>(
        'handles null duration gracefully',
        build: () => buildCubit(
          sound: _createTestSound(duration: null),
        ),
        act: (cubit) => cubit.initialize(),
        expect: () => [
          isA<AudioTimingState>()
              .having((s) => s.audioDuration, 'audioDuration', 0)
              .having((s) => s.startOffset, 'startOffset', 0),
          // Still emits isPlaying since play() is called even though
          // setClippedAudioSource bails early for zero duration
          isA<AudioTimingState>().having(
            (s) => s.isPlaying,
            'isPlaying',
            isTrue,
          ),
        ],
      );

      blocTest<AudioTimingCubit, AudioTimingState>(
        'handles bundled sound with asset path',
        build: () => buildCubit(
          sound: _createBundledSound(),
        ),
        act: (cubit) => cubit.initialize(),
        expect: () => [
          isA<AudioTimingState>().having(
            (s) => s.audioDuration,
            'audioDuration',
            20,
          ),
          isA<AudioTimingState>().having(
            (s) => s.isPlaying,
            'isPlaying',
            isTrue,
          ),
        ],
        verify: (_) {
          verify(
            () => mockClipPlayer.setClip(any()),
          ).called(1);
          verify(() => mockClipPlayer.play()).called(1);
        },
      );
    });

    group('updateOffset', () {
      blocTest<AudioTimingCubit, AudioTimingState>(
        'emits state with updated offset',
        build: buildCubit,
        act: (cubit) => cubit.updateOffset(0.75),
        expect: () => [
          isA<AudioTimingState>().having(
            (s) => s.startOffset,
            'startOffset',
            0.75,
          ),
        ],
      );

      blocTest<AudioTimingCubit, AudioTimingState>(
        'clamps offset to 0.0 when negative',
        build: buildCubit,
        act: (cubit) => cubit.updateOffset(-0.5),
        expect: () => [
          isA<AudioTimingState>().having(
            (s) => s.startOffset,
            'startOffset',
            0,
          ),
        ],
      );

      blocTest<AudioTimingCubit, AudioTimingState>(
        'clamps offset to 1.0 when exceeding maximum',
        build: buildCubit,
        act: (cubit) => cubit.updateOffset(1.5),
        expect: () => [
          isA<AudioTimingState>().having(
            (s) => s.startOffset,
            'startOffset',
            1.0,
          ),
        ],
      );
    });

    group('pausePlayback', () {
      blocTest<AudioTimingCubit, AudioTimingState>(
        'pauses audio and emits isPlaying false',
        build: buildCubit,
        seed: () => const AudioTimingState(isPlaying: true),
        act: (cubit) => cubit.pausePlayback(),
        expect: () => [
          isA<AudioTimingState>().having(
            (s) => s.isPlaying,
            'isPlaying',
            isFalse,
          ),
        ],
        verify: (_) {
          verify(() => mockClipPlayer.pause()).called(1);
        },
      );
    });

    group('resumePlayback', () {
      blocTest<AudioTimingCubit, AudioTimingState>(
        'sets clipped source and plays audio',
        build: buildCubit,
        seed: () => const AudioTimingState(
          audioDuration: 20,
          startOffset: 0.5,
        ),
        act: (cubit) => cubit.resumePlayback(),
        expect: () => [
          isA<AudioTimingState>().having(
            (s) => s.isPlaying,
            'isPlaying',
            isTrue,
          ),
        ],
        verify: (_) {
          verify(
            () => mockClipPlayer.setClip(any()),
          ).called(1);
          verify(() => mockClipPlayer.play()).called(1);
        },
      );
    });

    group('stopPlayback', () {
      blocTest<AudioTimingCubit, AudioTimingState>(
        'stops audio and emits isPlaying false',
        build: buildCubit,
        seed: () => const AudioTimingState(isPlaying: true),
        act: (cubit) => cubit.stopPlayback(),
        expect: () => [
          isA<AudioTimingState>().having(
            (s) => s.isPlaying,
            'isPlaying',
            isFalse,
          ),
        ],
        verify: (_) {
          verify(() => mockClipPlayer.stop()).called(1);
        },
      );
    });

    group('calculateStartOffset', () {
      test('returns Duration.zero when audio is shorter than maxDuration', () {
        final cubit = buildCubit(
          sound: _createTestSound(duration: 3),
        );
        // Simulate initialized state
        cubit.emit(const AudioTimingState(audioDuration: 3, startOffset: 0.5));

        // Audio (3s) < maxDuration (6.3s), so scrollable = 0 → always zero
        expect(cubit.calculateStartOffset(), equals(Duration.zero));
        cubit.close();
      });

      test('returns correct offset for 20s audio at midpoint', () {
        final cubit = buildCubit(
          sound: _createTestSound(),
        );
        // maxDuration = 6.3s, scrollable = 20 - 6.3 = 13.7s
        // At offset 0.5: startTime = 0.5 * 13.7 = 6.85s = 6850ms
        cubit.emit(const AudioTimingState(audioDuration: 20, startOffset: 0.5));

        expect(
          cubit.calculateStartOffset(),
          equals(const Duration(milliseconds: 6850)),
        );
        cubit.close();
      });

      test('returns Duration.zero at offset 0', () {
        final cubit = buildCubit(
          sound: _createTestSound(),
        );
        cubit.emit(const AudioTimingState(audioDuration: 20));

        expect(cubit.calculateStartOffset(), equals(Duration.zero));
        cubit.close();
      });

      test('returns maximum offset at 1.0', () {
        final cubit = buildCubit(
          sound: _createTestSound(),
        );
        // scrollable = 20 - 6.3 = 13.7s
        cubit.emit(const AudioTimingState(audioDuration: 20, startOffset: 1.0));

        expect(
          cubit.calculateStartOffset(),
          equals(const Duration(milliseconds: 13700)),
        );
        cubit.close();
      });
    });

    group('player state changes', () {
      test('restarts playback when audio completes', () async {
        final completionController = StreamController<void>();

        when(() => mockClipPlayer.completionStream).thenAnswer(
          (_) => completionController.stream,
        );

        final cubit = buildCubit(
          sound: _createTestSound(),
        );
        await cubit.initialize();

        // Simulate audio completion
        completionController.add(null);

        // Allow the stream listener to process
        await Future<void>.delayed(Duration.zero);

        verify(() => mockClipPlayer.seek(Duration.zero)).called(1);
        // Initial play + restart play
        verify(() => mockClipPlayer.play()).called(2);

        await completionController.close();
        await cubit.close();
      });
    });

    group('close', () {
      test('disposes audio clip player', () async {
        final cubit = buildCubit();
        await cubit.close();

        verify(() => mockClipPlayer.dispose()).called(1);
      });
    });
  });

  group(AudioTimingState, () {
    test('supports value equality', () {
      expect(
        const AudioTimingState(),
        equals(const AudioTimingState()),
      );
    });

    test('props are correct', () {
      expect(
        const AudioTimingState().props,
        equals([0.0, null, false]),
      );
    });

    group('copyWith', () {
      test('returns same object when no parameters', () {
        const state = AudioTimingState(
          startOffset: 0.5,
          audioDuration: 20,
          isPlaying: true,
        );
        expect(state.copyWith(), equals(state));
      });

      test('replaces startOffset', () {
        const state = AudioTimingState(startOffset: 0.5);
        expect(
          state.copyWith(startOffset: 0.75),
          equals(const AudioTimingState(startOffset: 0.75)),
        );
      });

      test('replaces audioDuration', () {
        const state = AudioTimingState();
        expect(
          state.copyWith(audioDuration: 15),
          equals(const AudioTimingState(audioDuration: 15)),
        );
      });

      test('replaces isPlaying', () {
        const state = AudioTimingState();
        expect(
          state.copyWith(isPlaying: true),
          equals(const AudioTimingState(isPlaying: true)),
        );
      });
    });
  });
}
