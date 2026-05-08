// ABOUTME: Tests for AudioClipPlayer clipped audio playback wrapper
// ABOUTME: Validates setClip, playback controls, completionStream, dispose

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sound_service/sound_service.dart';

class _MockAudioPlayer extends Mock implements AudioPlayer {}

class _FakeAudioSource extends Fake implements AudioSource {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeAudioSource());
    registerFallbackValue(Duration.zero);
  });

  group(AudioClipPlayer, () {
    late AudioClipPlayer player;
    late _MockAudioPlayer mockAudioPlayer;

    setUp(() {
      mockAudioPlayer = _MockAudioPlayer();

      when(() => mockAudioPlayer.playing).thenReturn(false);
      when(
        () => mockAudioPlayer.playerStateStream,
      ).thenAnswer((_) => const Stream<PlayerState>.empty());
      when(
        () => mockAudioPlayer.setAudioSource(any()),
      ).thenAnswer((_) async => const Duration(seconds: 10));
      when(() => mockAudioPlayer.play()).thenAnswer((_) async {});
      when(() => mockAudioPlayer.pause()).thenAnswer((_) async {});
      when(() => mockAudioPlayer.stop()).thenAnswer((_) async {});
      when(() => mockAudioPlayer.seek(any())).thenAnswer((_) async {});
      when(() => mockAudioPlayer.dispose()).thenAnswer((_) async {});

      player = AudioClipPlayer(audioPlayer: mockAudioPlayer);
    });

    tearDown(() async {
      await player.dispose();
    });

    group('isPlaying', () {
      test('returns false when not playing', () {
        when(() => mockAudioPlayer.playing).thenReturn(false);

        expect(player.isPlaying, isFalse);
      });

      test('returns true when playing', () {
        when(() => mockAudioPlayer.playing).thenReturn(true);

        expect(player.isPlaying, isTrue);
      });
    });

    group('completionStream', () {
      test('emits when processing state is completed', () async {
        final controller = StreamController<PlayerState>();
        when(
          () => mockAudioPlayer.playerStateStream,
        ).thenAnswer((_) => controller.stream);

        final emissions = <void>[];
        final sub = player.completionStream.listen(emissions.add);

        controller
          ..add(PlayerState(false, ProcessingState.ready))
          ..add(PlayerState(true, ProcessingState.ready))
          ..add(PlayerState(false, ProcessingState.completed));

        await Future<void>.delayed(Duration.zero);

        expect(emissions, hasLength(1));

        await sub.cancel();
        await controller.close();
      });

      test('does not emit for non-completed states', () async {
        final controller = StreamController<PlayerState>();
        when(
          () => mockAudioPlayer.playerStateStream,
        ).thenAnswer((_) => controller.stream);

        final emissions = <void>[];
        final sub = player.completionStream.listen(emissions.add);

        controller
          ..add(PlayerState(false, ProcessingState.idle))
          ..add(PlayerState(true, ProcessingState.loading))
          ..add(PlayerState(true, ProcessingState.buffering))
          ..add(PlayerState(true, ProcessingState.ready));

        await Future<void>.delayed(Duration.zero);

        expect(emissions, isEmpty);

        await sub.cancel();
        await controller.close();
      });
    });

    group('setClip', () {
      test('sets network audio source', () async {
        var loaderCallCount = 0;
        player = AudioClipPlayer(
          audioPlayer: mockAudioPlayer,
          remoteAudioFileLoader: (uri, cachedFile, cachedUri) async {
            loaderCallCount++;
            final dir = Directory.systemTemp.createTempSync('audio_clip_test_');
            final file = File('${dir.path}/clip.mp3')
              ..writeAsBytesSync(const [1, 2, 3], flush: true);
            return file;
          },
        );

        await player.setClip(
          const AudioSourceConfig.network(
            'https://example.com/audio.mp3',
            start: Duration(seconds: 1),
            end: Duration(seconds: 5),
          ),
        );

        final capturedSource =
            verify(
                  () => mockAudioPlayer.setAudioSource(captureAny()),
                ).captured.single
                as ClippingAudioSource;
        expect(capturedSource.child.uri.scheme, 'file');
        expect(loaderCallCount, 1);
      });

      test(
        'reuses cached file for repeated network clips from same URI',
        () async {
          File? cachedFile;
          var loaderCallCount = 0;
          player = AudioClipPlayer(
            audioPlayer: mockAudioPlayer,
            remoteAudioFileLoader: (uri, existingFile, existingUri) async {
              loaderCallCount++;
              if (existingFile != null &&
                  existingUri == uri &&
                  existingFile.existsSync()) {
                return existingFile;
              }

              final dir = Directory.systemTemp.createTempSync(
                'audio_clip_test_',
              );
              cachedFile = File('${dir.path}/clip.mp3');
              cachedFile!.writeAsBytesSync(const [1, 2, 3], flush: true);
              return cachedFile!;
            },
          );

          const source = AudioSourceConfig.network(
            'https://example.com/audio.mp3',
            start: Duration(seconds: 1),
            end: Duration(seconds: 5),
          );

          await player.setClip(source);
          await player.setClip(
            const AudioSourceConfig.network(
              'https://example.com/audio.mp3',
              start: Duration(seconds: 2),
              end: Duration(seconds: 6),
            ),
          );

          verify(() => mockAudioPlayer.setAudioSource(any())).called(2);
          expect(loaderCallCount, 2);
          expect(cachedFile, isNotNull);
          expect(cachedFile!.existsSync(), isTrue);
        },
      );

      test('sets asset audio source', () async {
        await player.setClip(
          const AudioSourceConfig.asset(
            'assets/sounds/clip.mp3',
            start: Duration.zero,
            end: Duration(seconds: 3),
          ),
        );

        verify(() => mockAudioPlayer.setAudioSource(any())).called(1);
      });

      test('sets file audio source', () async {
        await player.setClip(
          const AudioSourceConfig.file(
            '/path/to/audio.mp3',
            start: Duration(seconds: 2),
            end: Duration(seconds: 8),
          ),
        );

        verify(() => mockAudioPlayer.setAudioSource(any())).called(1);
      });
    });

    group('play', () {
      test('delegates to audio player', () async {
        await player.play();

        verify(() => mockAudioPlayer.play()).called(1);
      });
    });

    group('pause', () {
      test('delegates to audio player', () async {
        await player.pause();

        verify(() => mockAudioPlayer.pause()).called(1);
      });
    });

    group('stop', () {
      test('delegates to audio player', () async {
        await player.stop();

        verify(() => mockAudioPlayer.stop()).called(1);
      });
    });

    group('seek', () {
      test('delegates to audio player', () async {
        const position = Duration(seconds: 3);
        await player.seek(position);

        verify(() => mockAudioPlayer.seek(position)).called(1);
      });
    });

    group('dispose', () {
      test('disposes the audio player', () async {
        await player.dispose();

        verify(() => mockAudioPlayer.dispose()).called(1);
      });

      test('logs error when dispose throws', () async {
        when(
          () => mockAudioPlayer.dispose(),
        ).thenThrow(Exception('dispose failed'));

        // Should not throw — error is caught and logged.
        await expectLater(player.dispose(), completes);
      });
    });
  });
}
