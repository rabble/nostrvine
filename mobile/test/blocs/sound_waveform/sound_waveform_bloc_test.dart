// ABOUTME: Tests for SoundWaveformBloc - waveform extraction from audio.
// ABOUTME: Covers initial state, extract events, clear events, and state transitions.

import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/sound_waveform/sound_waveform_bloc.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockProVideoEditor extends ProVideoEditor {
  bool shouldThrowError = false;
  Duration waveformDuration = const Duration(seconds: 5);
  late Float32List leftChannel;
  Float32List? rightChannel;

  _MockProVideoEditor() {
    // Default waveform data
    leftChannel = Float32List.fromList([0.1, 0.5, 0.9, 0.3, 0.7]);
    rightChannel = Float32List.fromList([0.2, 0.6, 0.8, 0.4, 0.6]);
  }

  @override
  Stream<dynamic> initializeStream() {
    return const Stream.empty();
  }

  @override
  Future<WaveformData> getWaveform(WaveformConfigs configs) async {
    if (shouldThrowError) {
      throw Exception('Waveform extraction failed');
    }
    return WaveformData(
      leftChannel: leftChannel,
      rightChannel: rightChannel,
      duration: waveformDuration,
      sampleRate: 44100,
      samplesPerSecond: 10,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockProVideoEditor mockProVideoEditor;

  setUp(() {
    mockProVideoEditor = _MockProVideoEditor();
    ProVideoEditor.instance = mockProVideoEditor;
  });

  group(SoundWaveformBloc, () {
    SoundWaveformBloc buildBloc() {
      return SoundWaveformBloc();
    }

    test('initial state is $SoundWaveformInitial', () {
      final bloc = buildBloc();
      expect(bloc.state, isA<SoundWaveformInitial>());
      bloc.close();
    });

    group(SoundWaveformExtract, () {
      blocTest<SoundWaveformBloc, SoundWaveformState>(
        'emits [$SoundWaveformLoading, $SoundWaveformLoaded] '
        'when extraction succeeds',
        build: buildBloc,
        act: (bloc) => bloc.add(
          const SoundWaveformExtract(
            path: 'https://example.com/audio.mp3',
            soundId: 'test-sound-id',
          ),
        ),
        expect: () => [isA<SoundWaveformLoading>(), isA<SoundWaveformLoaded>()],
      );

      blocTest<SoundWaveformBloc, SoundWaveformState>(
        'loaded state contains correct waveform data',
        build: buildBloc,
        setUp: () {
          mockProVideoEditor.leftChannel = Float32List.fromList([0.1, 0.2]);
          mockProVideoEditor.rightChannel = Float32List.fromList([0.3, 0.4]);
          mockProVideoEditor.waveformDuration = const Duration(seconds: 10);
        },
        act: (bloc) => bloc.add(
          const SoundWaveformExtract(
            path: 'https://example.com/audio.mp3',
            soundId: 'test-sound-id',
          ),
        ),
        verify: (bloc) {
          final state = bloc.state as SoundWaveformLoaded;
          expect(state.leftChannel, equals(Float32List.fromList([0.1, 0.2])));
          expect(state.rightChannel, equals(Float32List.fromList([0.3, 0.4])));
          expect(state.duration, equals(const Duration(seconds: 10)));
        },
      );

      blocTest<SoundWaveformBloc, SoundWaveformState>(
        'emits [$SoundWaveformLoading, $SoundWaveformError] '
        'when extraction fails',
        setUp: () {
          mockProVideoEditor.shouldThrowError = true;
        },
        build: buildBloc,
        act: (bloc) => bloc.add(
          const SoundWaveformExtract(
            path: 'https://example.com/audio.mp3',
            soundId: 'test-sound-id',
          ),
        ),
        expect: () => [isA<SoundWaveformLoading>(), isA<SoundWaveformError>()],
        errors: () => [isA<Exception>()],
      );

      blocTest<SoundWaveformBloc, SoundWaveformState>(
        'error state contains error message',
        setUp: () {
          mockProVideoEditor.shouldThrowError = true;
        },
        build: buildBloc,
        act: (bloc) => bloc.add(
          const SoundWaveformExtract(
            path: 'https://example.com/audio.mp3',
            soundId: 'test-sound-id',
          ),
        ),
        verify: (bloc) {
          final state = bloc.state as SoundWaveformError;
          expect(state.message, contains('Waveform extraction failed'));
        },
        errors: () => [isA<Exception>()],
      );

      blocTest<SoundWaveformBloc, SoundWaveformState>(
        'handles asset path extraction',
        build: buildBloc,
        act: (bloc) => bloc.add(
          const SoundWaveformExtract(
            path: 'assets/sounds/test.mp3',
            soundId: 'bundled-sound-id',
            isAsset: true,
          ),
        ),
        expect: () => [isA<SoundWaveformLoading>(), isA<SoundWaveformLoaded>()],
      );
    });

    group(SoundWaveformClear, () {
      blocTest<SoundWaveformBloc, SoundWaveformState>(
        'emits [$SoundWaveformInitial] when clearing from loaded state',
        build: buildBloc,
        seed: () => SoundWaveformLoaded(
          leftChannel: Float32List.fromList([0.1, 0.5]),
          rightChannel: Float32List.fromList([0.2, 0.6]),
          duration: const Duration(seconds: 5),
        ),
        act: (bloc) => bloc.add(const SoundWaveformClear()),
        expect: () => [isA<SoundWaveformInitial>()],
      );

      blocTest<SoundWaveformBloc, SoundWaveformState>(
        'emits [$SoundWaveformInitial] when clearing from loading state',
        build: buildBloc,
        seed: () => const SoundWaveformLoading(),
        act: (bloc) => bloc.add(const SoundWaveformClear()),
        expect: () => [isA<SoundWaveformInitial>()],
      );

      blocTest<SoundWaveformBloc, SoundWaveformState>(
        'emits [$SoundWaveformInitial] when clearing from error state',
        build: buildBloc,
        seed: () => const SoundWaveformError('Test error'),
        act: (bloc) => bloc.add(const SoundWaveformClear()),
        expect: () => [isA<SoundWaveformInitial>()],
      );

      blocTest<SoundWaveformBloc, SoundWaveformState>(
        'emits [$SoundWaveformInitial] when clearing from initial state',
        build: buildBloc,
        act: (bloc) => bloc.add(const SoundWaveformClear()),
        expect: () => [isA<SoundWaveformInitial>()],
      );
    });
  });

  group('$SoundWaveformEvent equality', () {
    test('$SoundWaveformExtract events with same props are equal', () {
      const event1 = SoundWaveformExtract(path: 'test.mp3', soundId: 'sound-1');
      const event2 = SoundWaveformExtract(path: 'test.mp3', soundId: 'sound-1');
      expect(event1, equals(event2));
      expect(event1.props, equals(event2.props));
    });

    test('$SoundWaveformExtract events with different props are not equal', () {
      const event1 = SoundWaveformExtract(
        path: 'test1.mp3',
        soundId: 'sound-1',
      );
      const event2 = SoundWaveformExtract(
        path: 'test2.mp3',
        soundId: 'sound-2',
      );
      expect(event1, isNot(equals(event2)));
    });

    test('$SoundWaveformExtract isAsset prop affects equality', () {
      const event1 = SoundWaveformExtract(path: 'test.mp3', soundId: 'sound-1');
      const event2 = SoundWaveformExtract(
        path: 'test.mp3',
        soundId: 'sound-1',
        isAsset: true,
      );
      expect(event1, isNot(equals(event2)));
    });

    test('$SoundWaveformClear events are equal', () {
      const event1 = SoundWaveformClear();
      const event2 = SoundWaveformClear();
      expect(event1, equals(event2));
    });
  });

  group('$SoundWaveformState equality', () {
    test('$SoundWaveformInitial states are equal', () {
      const state1 = SoundWaveformInitial();
      const state2 = SoundWaveformInitial();
      expect(state1, equals(state2));
    });

    test('$SoundWaveformLoading states are equal', () {
      const state1 = SoundWaveformLoading();
      const state2 = SoundWaveformLoading();
      expect(state1, equals(state2));
    });

    test('$SoundWaveformLoaded states with same data are equal', () {
      final leftChannel = Float32List.fromList([0.1, 0.5]);
      final rightChannel = Float32List.fromList([0.2, 0.6]);
      const duration = Duration(seconds: 5);

      final state1 = SoundWaveformLoaded(
        leftChannel: leftChannel,
        rightChannel: rightChannel,
        duration: duration,
      );
      final state2 = SoundWaveformLoaded(
        leftChannel: leftChannel,
        rightChannel: rightChannel,
        duration: duration,
      );
      expect(state1, equals(state2));
    });

    test(
      '$SoundWaveformLoaded states with different duration are not equal',
      () {
        final leftChannel = Float32List.fromList([0.1, 0.5]);

        final state1 = SoundWaveformLoaded(
          leftChannel: leftChannel,
          duration: const Duration(seconds: 5),
        );
        final state2 = SoundWaveformLoaded(
          leftChannel: leftChannel,
          duration: const Duration(seconds: 10),
        );
        expect(state1, isNot(equals(state2)));
      },
    );

    test('$SoundWaveformError states with same message are equal', () {
      const state1 = SoundWaveformError('Error message');
      const state2 = SoundWaveformError('Error message');
      expect(state1, equals(state2));
    });

    test('$SoundWaveformError states with different message are not equal', () {
      const state1 = SoundWaveformError('Error 1');
      const state2 = SoundWaveformError('Error 2');
      expect(state1, isNot(equals(state2)));
    });
  });
}
