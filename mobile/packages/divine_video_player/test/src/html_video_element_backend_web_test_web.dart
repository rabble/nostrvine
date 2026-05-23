import 'package:divine_video_player/divine_video_player.dart';
import 'package:divine_video_player/src/web/web_video_player_backend_web.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:web/web.dart' as web;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HtmlVideoElementBackend', () {
    late HtmlVideoElementBackend backend;
    late List<DivineVideoPlayerState> states;
    late List<Object> errors;

    setUp(() async {
      await LogCaptureService().clearAllLogs();
      states = <DivineVideoPlayerState>[];
      errors = <Object>[];
      backend = HtmlVideoElementBackend();
      await backend.initialize(
        onStateChanged: states.add,
        onError: errors.add,
      );
    });

    tearDown(() async {
      await backend.dispose();
      await LogCaptureService().clearAllLogs();
    });

    test('setClips warns once and falls back to the first clip', () async {
      const firstClip = VideoClip(uri: 'data:video/mp4;base64,AAAA');
      const secondClip = VideoClip(uri: 'data:video/mp4;base64,BBBB');

      await backend.setClips(const [firstClip, secondClip]);
      await backend.setClips(const [firstClip, secondClip]);

      expect(backend.debugVideoElement.src, firstClip.uri);
      expect(states.last.clipCount, 1);
      expect(states.last.currentClipIndex, 0);

      final warnings = LogCaptureService()
          .getRecentLogs(minLevel: LogLevel.warning)
          .where(
            (entry) =>
                entry.category == LogCategory.video &&
                entry.message.contains('multi-clip playback'),
          )
          .toList();

      expect(warnings, hasLength(1));
    });

    test('timeupdate soft-clamps at clip end and completes playback', () async {
      await backend.setClips(
        const [
          VideoClip(
            uri: 'data:video/mp4;base64,AAAA',
            start: Duration(seconds: 1),
            end: Duration(seconds: 3),
          ),
        ],
      );

      backend.debugVideoElement.currentTime = 3;
      backend.debugVideoElement.dispatchEvent(web.Event('timeupdate'));
      await Future<void>.delayed(Duration.zero);

      expect(states.last.status, PlaybackStatus.completed);
      expect(states.last.position, const Duration(seconds: 2));
      expect(backend.debugVideoElement.paused, isTrue);
      expect(errors, isEmpty);
    });

    test('setClips applies first clip volume and playback speed', () async {
      await backend.setClips(
        const [
          VideoClip(
            uri: 'data:video/mp4;base64,AAAA',
            volume: 0.4,
            playbackSpeed: 1.5,
          ),
        ],
      );

      expect(backend.debugVideoElement.volume, 0.4);
      expect(backend.debugVideoElement.muted, isFalse);
      expect(backend.debugVideoElement.playbackRate, 1.5);
      expect(states.last.volume, 0.4);
      expect(states.last.playbackSpeed, 1.5);
    });

    test('timeupdate loops clipped ranges back to clip start', () async {
      await backend.setClips(
        const [
          VideoClip(
            uri: 'data:video/mp4;base64,AAAA',
            start: Duration(seconds: 1),
            end: Duration(seconds: 3),
          ),
        ],
      );
      await backend.setLooping(looping: true);

      backend.debugVideoElement.currentTime = 3;
      backend.debugVideoElement.dispatchEvent(web.Event('timeupdate'));
      await Future<void>.delayed(Duration.zero);

      expect(backend.debugVideoElement.currentTime, 1);
      expect(states.last.status, isNot(PlaybackStatus.completed));
      expect(states.last.position, Duration.zero);
      expect(states.last.isLooping, isTrue);
      expect(errors, isEmpty);
    });

    test('setVolume zero also mutes the video element', () async {
      await backend.setVolume(0);

      expect(backend.debugVideoElement.volume, 0);
      expect(backend.debugVideoElement.muted, isTrue);
    });

    test('play rejection does not overwrite the emitted error state', () async {
      await backend.dispose();
      states = <DivineVideoPlayerState>[];
      errors = <Object>[];
      backend = HtmlVideoElementBackend();
      await backend.initialize(
        onStateChanged: states.add,
        onError: (error) {
          errors.add(error);
          states.add(
            const DivineVideoPlayerState(status: PlaybackStatus.error),
          );
        },
      );

      await backend.play();

      expect(errors, hasLength(1));
      expect(states.last.status, PlaybackStatus.error);
    });
  });
}
