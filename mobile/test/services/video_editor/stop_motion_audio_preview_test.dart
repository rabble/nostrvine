// ABOUTME: Tests for StopMotionAudioPreview - stop-motion preview audio engine
// ABOUTME: Verifies window scheduling, scrub re-seek, pause, and disposal

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/video_editor/stop_motion_audio_preview.dart';
import 'package:sound_service/sound_service.dart';

class _MockAudioClipPlayer extends Mock implements AudioClipPlayer {}

void main() {
  setUpAll(() {
    registerFallbackValue(const AudioSourceConfig.file('/fallback.mp3'));
    registerFallbackValue(Duration.zero);
  });

  group(StopMotionAudioPreview, () {
    late List<_MockAudioClipPlayer> players;
    late StopMotionAudioPreview preview;

    _MockAudioClipPlayer newPlayer() {
      final player = _MockAudioClipPlayer();
      when(() => player.setClip(any())).thenAnswer((_) async {});
      when(() => player.setVolume(any())).thenAnswer((_) async {});
      when(() => player.seek(any())).thenAnswer((_) async {});
      when(player.play).thenAnswer((_) async {});
      when(player.pause).thenAnswer((_) async {});
      when(player.dispose).thenAnswer((_) async {});
      players.add(player);
      return player;
    }

    StopMotionAudioPreviewTrack track({
      String id = 'sound-1',
      Duration windowStart = Duration.zero,
      Duration windowEnd = const Duration(seconds: 2),
      double volume = 1,
    }) {
      return StopMotionAudioPreviewTrack(
        id: id,
        source: const AudioSourceConfig.file('/music.mp3'),
        windowStart: windowStart,
        windowEnd: windowEnd,
        volume: volume,
      );
    }

    setUp(() {
      players = [];
      preview = StopMotionAudioPreview(playerFactory: newPlayer);
    });

    tearDown(() async {
      await preview.dispose();
    });

    test('setTracks loads the clip and applies the track volume', () async {
      await preview.setTracks([track(volume: 0.4)]);

      expect(players, hasLength(1));
      verify(
        () =>
            players.single.setClip(const AudioSourceConfig.file('/music.mp3')),
      ).called(1);
      verify(() => players.single.setVolume(0.4)).called(1);
    });

    test('starts a sound when the playhead enters its window', () async {
      await preview.setTracks([
        track(
          windowStart: const Duration(seconds: 1),
          windowEnd: const Duration(seconds: 3),
        ),
      ]);

      await preview.syncTo(const Duration(milliseconds: 500), isPlaying: true);
      verifyNever(players.single.play);

      await preview.syncTo(const Duration(milliseconds: 1500), isPlaying: true);
      verify(
        () => players.single.seek(const Duration(milliseconds: 500)),
      ).called(1);
      verify(players.single.play).called(1);
    });

    test('steady playback inside the window does not re-seek', () async {
      await preview.setTracks([track()]);

      await preview.syncTo(const Duration(milliseconds: 100), isPlaying: true);
      await preview.syncTo(const Duration(milliseconds: 117), isPlaying: true);
      await preview.syncTo(const Duration(milliseconds: 134), isPlaying: true);

      verify(() => players.single.seek(any())).called(1);
      verify(players.single.play).called(1);
    });

    test('pauses a sound when the playhead leaves its window', () async {
      await preview.setTracks([
        track(windowEnd: const Duration(seconds: 1)),
      ]);

      await preview.syncTo(const Duration(milliseconds: 500), isPlaying: true);
      await preview.syncTo(const Duration(milliseconds: 900), isPlaying: true);
      // 1.2s is past the 1s window end but within the jump threshold.
      await preview.syncTo(const Duration(milliseconds: 1200), isPlaying: true);

      verify(players.single.pause).called(1);
    });

    test('a backwards jump (loop wrap / scrub) re-seeks the sound', () async {
      await preview.setTracks([track()]);

      await preview.syncTo(const Duration(milliseconds: 1500), isPlaying: true);
      await preview.syncTo(const Duration(milliseconds: 100), isPlaying: true);

      verifyInOrder([
        () => players.single.seek(const Duration(milliseconds: 1500)),
        () => players.single.seek(const Duration(milliseconds: 100)),
      ]);
      verify(players.single.play).called(2);
    });

    test('a forward jump past the threshold re-seeks the sound', () async {
      await preview.setTracks([track(windowEnd: const Duration(seconds: 5))]);

      await preview.syncTo(const Duration(milliseconds: 100), isPlaying: true);
      await preview.syncTo(const Duration(seconds: 3), isPlaying: true);

      verify(() => players.single.seek(const Duration(seconds: 3))).called(1);
    });

    test('syncTo with isPlaying false pauses an active sound', () async {
      await preview.setTracks([track()]);

      await preview.syncTo(const Duration(milliseconds: 500), isPlaying: true);
      await preview.syncTo(const Duration(milliseconds: 600), isPlaying: false);

      verify(players.single.pause).called(1);
    });

    test('pauseAll pauses only active sounds', () async {
      await preview.setTracks([
        track(id: 'a'),
        track(
          id: 'b',
          windowStart: const Duration(seconds: 5),
          windowEnd: const Duration(seconds: 6),
        ),
      ]);

      await preview.syncTo(const Duration(seconds: 1), isPlaying: true);
      await preview.pauseAll();

      verify(players[0].pause).called(1);
      verifyNever(players[1].pause);
    });

    test('setTracks disposes the previous generation of players', () async {
      await preview.setTracks([track(id: 'a')]);
      await preview.setTracks([track(id: 'b')]);

      expect(players, hasLength(2));
      verify(players[0].dispose).called(1);
      verifyNever(players[1].dispose);
    });

    test('a track whose clip fails to load is skipped and disposed', () async {
      final failing = _MockAudioClipPlayer();
      when(() => failing.setClip(any())).thenThrow(Exception('bad file'));
      when(failing.dispose).thenAnswer((_) async {});

      preview = StopMotionAudioPreview(playerFactory: () => failing);
      await preview.setTracks([track()]);

      verify(failing.dispose).called(1);
      // No crash on sync with the failed track skipped.
      await preview.syncTo(Duration.zero, isPlaying: true);
      verifyNever(failing.play);
    });

    test('dispose releases every player and ignores later syncs', () async {
      await preview.setTracks([track()]);
      await preview.dispose();

      verify(players.single.dispose).called(1);

      await preview.syncTo(const Duration(milliseconds: 500), isPlaying: true);
      verifyNever(players.single.play);
    });
  });
}
