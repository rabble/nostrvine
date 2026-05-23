import 'package:divine_video_player/divine_video_player.dart';
import 'package:divine_video_player/src/web/web_video_player_backend.dart';
import 'package:divine_video_player/src/web/web_video_player_backend_factory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('createDefaultWebVideoPlayerBackend on non-web platforms', () {
    late WebVideoPlayerBackend backend;

    setUp(() {
      backend = createDefaultWebVideoPlayerBackend();
    });

    test('throws UnsupportedError from every backend operation', () {
      expect(
        backend.initialize(onStateChanged: (_) {}, onError: (_) {}),
        throwsUnsupportedError,
      );
      expect(
        backend.setClips(
          const [VideoClip(uri: '/video.mp4')],
          startPosition: Duration.zero,
        ),
        throwsUnsupportedError,
      );
      expect(backend.play(), throwsUnsupportedError);
      expect(backend.pause(), throwsUnsupportedError);
      expect(backend.stop(), throwsUnsupportedError);
      expect(backend.seekTo(Duration.zero), throwsUnsupportedError);
      expect(backend.setVolume(1), throwsUnsupportedError);
      expect(backend.setPlaybackSpeed(1), throwsUnsupportedError);
      expect(backend.setLooping(looping: true), throwsUnsupportedError);
      expect(backend.jumpToClip(0), throwsUnsupportedError);
      expect(
        backend.setAudioTracks(const <AudioTrack>[]),
        throwsUnsupportedError,
      );
      expect(backend.removeAllAudioTracks(), throwsUnsupportedError);
      expect(
        backend.setAudioTrackVolume(0, 1),
        throwsUnsupportedError,
      );
      expect(backend.buildView, throwsUnsupportedError);
      expect(backend.dispose(), throwsUnsupportedError);
    });
  });
}
