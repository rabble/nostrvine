// ABOUTME: Tests for CountdownSoundService - countdown beep playback.
// ABOUTME: Covers preload, playShortBeep, playLongBeepAndWait, dispose,
// ABOUTME: and error/edge-case handling using mocktail AudioPlayer mocks.

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sound_service/sound_service.dart';

class _MockAudioPlayer extends Mock implements AudioPlayer {}

void main() {
  group(CountdownSoundService, () {
    late _MockAudioPlayer mockShortPlayer;
    late _MockAudioPlayer mockLongPlayer;
    late int factoryCallCount;
    late CountdownSoundService service;

    setUp(() {
      mockShortPlayer = _MockAudioPlayer();
      mockLongPlayer = _MockAudioPlayer();
      factoryCallCount = 0;

      service = CountdownSoundService(
        audioPlayerFactory: () {
          factoryCallCount++;
          // First call → short beep player, second → long beep player.
          return factoryCallCount == 1 ? mockShortPlayer : mockLongPlayer;
        },
      );
    });

    group('preload', () {
      test('creates two players and sets assets', () async {
        when(
          () => mockShortPlayer.setAsset(any()),
        ).thenAnswer((_) async => .zero);
        when(
          () => mockLongPlayer.setAsset(any()),
        ).thenAnswer((_) async => .zero);

        await service.preload();

        expect(factoryCallCount, equals(2));
        verify(
          () => mockShortPlayer.setAsset(CountdownSoundService.shortBeepAsset),
        ).called(1);
        verify(
          () => mockLongPlayer.setAsset(CountdownSoundService.longBeepAsset),
        ).called(1);
      });

      test('disposes players and rethrows when setAsset fails', () async {
        when(
          () => mockShortPlayer.setAsset(any()),
        ).thenThrow(Exception('asset not found'));
        when(
          () => mockLongPlayer.setAsset(any()),
        ).thenAnswer((_) async => .zero);
        when(() => mockShortPlayer.dispose()).thenAnswer((_) async {});
        when(() => mockLongPlayer.dispose()).thenAnswer((_) async {});

        await expectLater(service.preload, throwsA(isA<Exception>()));

        verify(() => mockShortPlayer.dispose()).called(1);
        verify(() => mockLongPlayer.dispose()).called(1);
      });
    });

    for (final entry in {
      'playShortBeep': (
        player: () => mockShortPlayer,
        play: (CountdownSoundService s) => s.playShortBeep(),
      ),
      'playLongBeepAndWait': (
        player: () => mockLongPlayer,
        play: (CountdownSoundService s) => s.playLongBeepAndWait(),
      ),
    }.entries) {
      group(entry.key, () {
        late _MockAudioPlayer player;

        setUp(() {
          player = entry.value.player();
          when(
            () => mockShortPlayer.setAsset(any()),
          ).thenAnswer((_) async => Duration.zero);
          when(
            () => mockLongPlayer.setAsset(any()),
          ).thenAnswer((_) async => Duration.zero);
        });

        test('seeks to start and plays', () async {
          when(() => player.seek(any())).thenAnswer((_) async {});
          when(() => player.play()).thenAnswer((_) async {});

          await service.preload();
          await entry.value.play(service);

          verify(() => player.seek(Duration.zero)).called(1);
          verify(() => player.play()).called(1);
        });

        test('does nothing when not preloaded', () async {
          await entry.value.play(service);

          verifyNever(() => player.seek(any()));
          verifyNever(() => player.play());
        });

        test('does nothing after dispose', () async {
          when(() => player.seek(any())).thenAnswer((_) async {});
          when(() => player.play()).thenAnswer((_) async {});
          when(() => mockShortPlayer.dispose()).thenAnswer((_) async {});
          when(() => mockLongPlayer.dispose()).thenAnswer((_) async {});

          await service.preload();
          await service.dispose();
          await entry.value.play(service);

          verifyNever(() => player.seek(any()));
          verifyNever(() => player.play());
        });

        test('handles play errors gracefully', () async {
          when(
            () => player.seek(any()),
          ).thenThrow(Exception('playback error'));

          await service.preload();

          // Should not throw — errors are caught internally.
          await expectLater(entry.value.play(service), completes);
        });
      });
    }

    group('dispose', () {
      test('disposes both players after preload', () async {
        when(
          () => mockShortPlayer.setAsset(any()),
        ).thenAnswer((_) async => Duration.zero);
        when(
          () => mockLongPlayer.setAsset(any()),
        ).thenAnswer((_) async => Duration.zero);
        when(() => mockShortPlayer.dispose()).thenAnswer((_) async {});
        when(() => mockLongPlayer.dispose()).thenAnswer((_) async {});

        await service.preload();
        await service.dispose();

        verify(() => mockShortPlayer.dispose()).called(1);
        verify(() => mockLongPlayer.dispose()).called(1);
      });

      test('completes safely when called without preload', () async {
        await expectLater(service.dispose(), completes);
      });

      test('can be called multiple times safely', () async {
        when(
          () => mockShortPlayer.setAsset(any()),
        ).thenAnswer((_) async => Duration.zero);
        when(
          () => mockLongPlayer.setAsset(any()),
        ).thenAnswer((_) async => Duration.zero);
        when(() => mockShortPlayer.dispose()).thenAnswer((_) async {});
        when(() => mockLongPlayer.dispose()).thenAnswer((_) async {});

        await service.preload();
        await service.dispose();
        // Second dispose should not throw (players are null).
        await expectLater(service.dispose(), completes);
      });
    });

    group('reuse across ticks', () {
      test(
        'playShortBeep can be called multiple times on same player',
        () async {
          when(
            () => mockShortPlayer.setAsset(any()),
          ).thenAnswer((_) async => Duration.zero);
          when(
            () => mockLongPlayer.setAsset(any()),
          ).thenAnswer((_) async => Duration.zero);
          when(
            () => mockShortPlayer.seek(any()),
          ).thenAnswer((_) async {});
          when(() => mockShortPlayer.play()).thenAnswer((_) async {});

          await service.preload();

          await service.playShortBeep();
          await service.playShortBeep();
          await service.playShortBeep();

          verify(() => mockShortPlayer.seek(Duration.zero)).called(3);
          verify(() => mockShortPlayer.play()).called(3);
        },
      );
    });
  });
}
