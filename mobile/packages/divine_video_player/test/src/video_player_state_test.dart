import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(PlaybackStatus, () {
    test('isIdle returns true only for idle', () {
      expect(PlaybackStatus.idle.isIdle, isTrue);
      expect(PlaybackStatus.playing.isIdle, isFalse);
    });

    test('isReady returns true only for ready', () {
      expect(PlaybackStatus.ready.isReady, isTrue);
      expect(PlaybackStatus.idle.isReady, isFalse);
    });

    test('isPlaying returns true only for playing', () {
      expect(PlaybackStatus.playing.isPlaying, isTrue);
      expect(PlaybackStatus.paused.isPlaying, isFalse);
    });

    test('isPaused returns true only for paused', () {
      expect(PlaybackStatus.paused.isPaused, isTrue);
      expect(PlaybackStatus.playing.isPaused, isFalse);
    });

    test('isBuffering returns true only for buffering', () {
      expect(PlaybackStatus.buffering.isBuffering, isTrue);
      expect(PlaybackStatus.playing.isBuffering, isFalse);
    });

    test('isCompleted returns true only for completed', () {
      expect(PlaybackStatus.completed.isCompleted, isTrue);
      expect(PlaybackStatus.playing.isCompleted, isFalse);
    });

    test('hasError returns true only for error', () {
      expect(PlaybackStatus.error.hasError, isTrue);
      expect(PlaybackStatus.playing.hasError, isFalse);
    });
  });

  group(DivineVideoPlayerState, () {
    test('default constructor has correct defaults', () {
      const state = DivineVideoPlayerState();

      expect(state.status, equals(PlaybackStatus.idle));
      expect(state.position, equals(Duration.zero));
      expect(state.duration, equals(Duration.zero));
      expect(state.bufferedPosition, equals(Duration.zero));
      expect(state.currentClipIndex, isZero);
      expect(state.clipCount, isZero);
      expect(state.isLooping, isFalse);
      expect(state.volume, equals(1.0));
      expect(state.playbackSpeed, equals(1.0));
      expect(state.isFirstFrameRendered, isFalse);
      expect(state.videoWidth, isZero);
      expect(state.videoHeight, isZero);
    });

    test('isPlaying delegates to status', () {
      const playing = DivineVideoPlayerState(status: PlaybackStatus.playing);
      const paused = DivineVideoPlayerState(status: PlaybackStatus.paused);

      expect(playing.isPlaying, isTrue);
      expect(paused.isPlaying, isFalse);
    });

    group('aspectRatio', () {
      test('returns width / height when both are positive', () {
        const state = DivineVideoPlayerState(
          videoWidth: 1920,
          videoHeight: 1080,
        );
        expect(state.aspectRatio, closeTo(1.778, 0.001));
      });

      test('returns 0 when width is zero', () {
        const state = DivineVideoPlayerState(videoHeight: 1080);
        expect(state.aspectRatio, isZero);
      });

      test('returns 0 when height is zero', () {
        const state = DivineVideoPlayerState(videoWidth: 1920);
        expect(state.aspectRatio, isZero);
      });

      test('returns 0 when both are zero', () {
        const state = DivineVideoPlayerState();
        expect(state.aspectRatio, isZero);
      });
    });

    group('equality', () {
      test('two default states are equal', () {
        const a = DivineVideoPlayerState();
        const b = DivineVideoPlayerState();

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('states with identical fields are equal', () {
        const a = DivineVideoPlayerState(
          status: PlaybackStatus.playing,
          position: Duration(seconds: 5),
          duration: Duration(seconds: 30),
          bufferedPosition: Duration(seconds: 10),
          currentClipIndex: 1,
          clipCount: 3,
          isLooping: true,
          volume: 0.5,
          playbackSpeed: 2,
          isFirstFrameRendered: true,
          videoWidth: 1920,
          videoHeight: 1080,
        );
        const b = DivineVideoPlayerState(
          status: PlaybackStatus.playing,
          position: Duration(seconds: 5),
          duration: Duration(seconds: 30),
          bufferedPosition: Duration(seconds: 10),
          currentClipIndex: 1,
          clipCount: 3,
          isLooping: true,
          volume: 0.5,
          playbackSpeed: 2,
          isFirstFrameRendered: true,
          videoWidth: 1920,
          videoHeight: 1080,
        );

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('states with different status are not equal', () {
        const a = DivineVideoPlayerState(status: PlaybackStatus.playing);
        const b = DivineVideoPlayerState(status: PlaybackStatus.paused);

        expect(a, isNot(equals(b)));
      });

      test('states with different position are not equal', () {
        const a = DivineVideoPlayerState(position: Duration(seconds: 1));
        const b = DivineVideoPlayerState(position: Duration(seconds: 2));

        expect(a, isNot(equals(b)));
      });

      test('copyWith without changes returns equal state', () {
        const original = DivineVideoPlayerState(
          status: PlaybackStatus.playing,
          position: Duration(seconds: 5),
        );
        final copy = original.copyWith();

        expect(copy, equals(original));
        expect(copy.hashCode, equals(original.hashCode));
      });
    });

    group('copyWith', () {
      test('returns identical state when no args given', () {
        const original = DivineVideoPlayerState(
          status: PlaybackStatus.playing,
          position: Duration(seconds: 5),
          duration: Duration(seconds: 30),
          bufferedPosition: Duration(seconds: 10),
          currentClipIndex: 1,
          clipCount: 3,
          isLooping: true,
          volume: 0.5,
          playbackSpeed: 2,
          isFirstFrameRendered: true,
          videoWidth: 1920,
          videoHeight: 1080,
        );
        final copy = original.copyWith();

        expect(copy.status, equals(original.status));
        expect(copy.position, equals(original.position));
        expect(copy.duration, equals(original.duration));
        expect(copy.bufferedPosition, equals(original.bufferedPosition));
        expect(copy.currentClipIndex, equals(original.currentClipIndex));
        expect(copy.clipCount, equals(original.clipCount));
        expect(copy.isLooping, equals(original.isLooping));
        expect(copy.volume, equals(original.volume));
        expect(copy.playbackSpeed, equals(original.playbackSpeed));
        expect(
          copy.isFirstFrameRendered,
          equals(original.isFirstFrameRendered),
        );
        expect(copy.videoWidth, equals(original.videoWidth));
        expect(copy.videoHeight, equals(original.videoHeight));
      });

      test('overrides only specified fields', () {
        const original = DivineVideoPlayerState();
        final copy = original.copyWith(
          status: PlaybackStatus.playing,
          volume: 0.7,
        );

        expect(copy.status, equals(PlaybackStatus.playing));
        expect(copy.volume, equals(0.7));
        expect(copy.position, equals(original.position));
      });
    });

    group('fromMap', () {
      test('parses a complete map', () {
        final state = DivineVideoPlayerState.fromMap({
          'status': 'playing',
          'positionMs': 5000,
          'durationMs': 30000,
          'bufferedPositionMs': 10000,
          'currentClipIndex': 1,
          'clipCount': 3,
          'isLooping': true,
          'volume': 0.5,
          'playbackSpeed': 2.0,
          'isFirstFrameRendered': true,
          'videoWidth': 1920,
          'videoHeight': 1080,
        });

        expect(state.status, equals(PlaybackStatus.playing));
        expect(state.position, equals(const Duration(seconds: 5)));
        expect(state.duration, equals(const Duration(seconds: 30)));
        expect(state.bufferedPosition, equals(const Duration(seconds: 10)));
        expect(state.currentClipIndex, equals(1));
        expect(state.clipCount, equals(3));
        expect(state.isLooping, isTrue);
        expect(state.volume, equals(0.5));
        expect(state.playbackSpeed, equals(2.0));
        expect(state.isFirstFrameRendered, isTrue);
        expect(state.videoWidth, equals(1920));
        expect(state.videoHeight, equals(1080));
      });

      test('uses defaults for missing keys', () {
        final state = DivineVideoPlayerState.fromMap({});

        expect(state.status, equals(PlaybackStatus.idle));
        expect(state.position, equals(Duration.zero));
        expect(state.duration, equals(Duration.zero));
        expect(state.bufferedPosition, equals(Duration.zero));
        expect(state.currentClipIndex, isZero);
        expect(state.clipCount, isZero);
        expect(state.isLooping, isFalse);
        expect(state.volume, equals(1.0));
        expect(state.playbackSpeed, equals(1.0));
        expect(state.isFirstFrameRendered, isFalse);
        expect(state.videoWidth, isZero);
        expect(state.videoHeight, isZero);
      });

      test('parses all status values', () {
        for (final name in [
          'idle',
          'ready',
          'playing',
          'paused',
          'buffering',
          'completed',
          'error',
        ]) {
          final state = DivineVideoPlayerState.fromMap({'status': name});
          expect(state.status.name, equals(name));
        }
      });

      test('defaults unknown status to idle', () {
        final state = DivineVideoPlayerState.fromMap(
          {'status': 'unknown_status'},
        );
        expect(state.status, equals(PlaybackStatus.idle));
      });

      test('handles null status', () {
        final state = DivineVideoPlayerState.fromMap({'status': null});
        expect(state.status, equals(PlaybackStatus.idle));
      });
    });

    group('toString', () {
      test('includes all fields', () {
        const state = DivineVideoPlayerState(
          status: PlaybackStatus.playing,
          videoWidth: 1920,
          videoHeight: 1080,
        );
        final string = state.toString();

        expect(string, contains('playing'));
        expect(string, contains('1920x1080'));
      });

      test('includes error message when present', () {
        const state = DivineVideoPlayerState(
          status: PlaybackStatus.error,
        );
        expect(state.toString(), contains('error'));
      });

      test('omits error section when not in error state', () {
        const state = DivineVideoPlayerState();
        expect(state.toString(), isNot(contains('error')));
      });
    });
  });
}
