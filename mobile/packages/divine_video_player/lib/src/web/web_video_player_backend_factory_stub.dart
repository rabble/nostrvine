import 'package:divine_video_player/src/audio_track.dart' as divine;
import 'package:divine_video_player/src/video_clip.dart';
import 'package:divine_video_player/src/video_player_state.dart';
import 'package:divine_video_player/src/web/web_video_player_backend.dart';
import 'package:flutter/widgets.dart';

/// Non-web fallback. The controller only instantiates the web backend when
/// `kIsWeb` is true, so this implementation only exists to satisfy the
/// conditional import on native targets.
WebVideoPlayerBackend createWebVideoPlayerBackend() =>
    _UnsupportedWebVideoPlayerBackend();

class _UnsupportedWebVideoPlayerBackend implements WebVideoPlayerBackend {
  Never _unsupported() => throw UnsupportedError(
    'Web video backend is only available on Flutter '
    'web.',
  );

  @override
  Future<void> initialize({
    required void Function(DivineVideoPlayerState state) onStateChanged,
    required void Function(Object error) onError,
  }) async => _unsupported();

  @override
  Future<void> setClips(
    List<VideoClip> clips, {
    Duration? startPosition,
  }) async => _unsupported();

  @override
  Future<void> play() async => _unsupported();

  @override
  Future<void> pause() async => _unsupported();

  @override
  Future<void> stop() async => _unsupported();

  @override
  Future<void> seekTo(Duration position) async => _unsupported();

  @override
  Future<void> setVolume(double volume) async => _unsupported();

  @override
  Future<void> setPlaybackSpeed(double speed) async => _unsupported();

  @override
  Future<void> setLooping({required bool looping}) async => _unsupported();

  @override
  Future<void> jumpToClip(int index) async => _unsupported();

  @override
  Future<void> setAudioTracks(List<divine.AudioTrack> tracks) async =>
      _unsupported();

  @override
  Future<void> removeAllAudioTracks() async => _unsupported();

  @override
  Future<void> setAudioTrackVolume(int index, double volume) async =>
      _unsupported();

  @override
  Widget buildView() => _unsupported();

  @override
  Future<void> dispose() async => _unsupported();
}
