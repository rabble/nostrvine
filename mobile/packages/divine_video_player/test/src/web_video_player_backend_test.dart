import 'dart:async';

import 'package:divine_video_player/divine_video_player.dart';
import 'package:divine_video_player/src/audio_track.dart' as divine;
import 'package:divine_video_player/src/web/web_video_player_backend.dart';
import 'package:divine_video_player/src/web/web_video_player_backend_factory.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DivineVideoPlayerController controller;

  setUp(() {
    DivineVideoPlayerController.resetIdCounterForTesting();
    DivineVideoPlayerController.debugForceLinuxBackend = null;
    DivineVideoPlayerController.debugForceWebBackend = null;
    DivineVideoPlayerController.webBackendFactory =
        createDefaultWebVideoPlayerBackend;
    controller = DivineVideoPlayerController();
  });

  tearDown(() async {
    DivineVideoPlayerController.debugForceWebBackend = null;
    DivineVideoPlayerController.webBackendFactory =
        createDefaultWebVideoPlayerBackend;
    await controller.dispose();
  });

  group('web backend via controller test hook', () {
    late _FakeWebVideoPlayerBackend fakeWeb;

    setUp(() {
      fakeWeb = _FakeWebVideoPlayerBackend();
      DivineVideoPlayerController.debugForceWebBackend = true;
      DivineVideoPlayerController.webBackendFactory = () => fakeWeb;
    });

    group('initialize', () {
      test('sets usesWebBackend to true', () async {
        await controller.initialize();

        expect(controller.usesWebBackend, isTrue);
      });

      test('calls initialize on the backend', () async {
        await controller.initialize();

        expect(fakeWeb.initializeCalls, equals(1));
      });

      test('sets usesLinuxBackend to false', () async {
        await controller.initialize();

        expect(controller.usesLinuxBackend, isFalse);
      });

      test('throws StateError if called twice', () async {
        await controller.initialize();

        expect(() => controller.initialize(), throwsStateError);
      });
    });

    group('playback methods', () {
      setUp(() async {
        await controller.initialize();
      });

      test('play delegates to web backend', () async {
        await controller.play();

        expect(fakeWeb.playCalls, equals(1));
      });

      test('pause delegates to web backend', () async {
        await controller.pause();

        expect(fakeWeb.pauseCalls, equals(1));
      });

      test('stop delegates to web backend', () async {
        await controller.stop();

        expect(fakeWeb.stopCalls, equals(1));
      });

      test('seekTo delegates to web backend', () async {
        await controller.seekTo(const Duration(seconds: 5));

        expect(fakeWeb.lastSeekPosition, equals(const Duration(seconds: 5)));
      });

      test('setVolume delegates to web backend', () async {
        await controller.setVolume(0.6);

        expect(fakeWeb.lastVolume, equals(0.6));
      });

      test('setPlaybackSpeed delegates to web backend', () async {
        await controller.setPlaybackSpeed(1.5);

        expect(fakeWeb.lastPlaybackSpeed, equals(1.5));
      });

      test('setLooping delegates to web backend', () async {
        await controller.setLooping(looping: true);

        expect(fakeWeb.lastLooping, isTrue);
      });

      test('jumpToClip delegates to web backend', () async {
        await controller.jumpToClip(2);

        expect(fakeWeb.lastJumpToClipIndex, equals(2));
      });

      test('setAudioTracks delegates to web backend (no-op on web)', () async {
        await controller.setAudioTracks([
          const AudioTrack(uri: '/audio.mp3'),
        ]);

        expect(fakeWeb.setAudioTracksCalls, equals(1));
      });

      test('removeAllAudioTracks delegates to web backend', () async {
        await controller.removeAllAudioTracks();

        expect(fakeWeb.removeAllAudioTracksCalls, equals(1));
      });

      test('setAudioTrackVolume delegates to web backend', () async {
        await controller.setAudioTrackVolume(0, 0.9);

        expect(fakeWeb.lastAudioTrackIndex, equals(0));
        expect(fakeWeb.lastAudioTrackVolume, equals(0.9));
      });
    });

    group('setClips', () {
      setUp(() async {
        await controller.initialize();
      });

      test('delegates to web backend with clips and startPosition', () async {
        const clips = [VideoClip(uri: '/web.mp4')];

        await controller.setClips(
          clips,
          startPosition: const Duration(seconds: 3),
        );

        expect(fakeWeb.lastClips, hasLength(1));
        expect(
          fakeWeb.lastStartPosition,
          equals(const Duration(seconds: 3)),
        );
      });

      test('setSource passes single clip', () async {
        const clip = VideoClip(uri: '/web-single.mp4');
        await controller.setSource(clip);

        expect(fakeWeb.lastClips, hasLength(1));
        expect(fakeWeb.lastClips!.first.uri, equals('/web-single.mp4'));
      });

      test('rejects empty clip list', () async {
        expect(() => controller.setClips([]), throwsArgumentError);
      });
    });

    group('state propagation', () {
      test('state changes from backend are emitted on stateStream', () async {
        final states = <DivineVideoPlayerState>[];
        controller.stateStream.listen(states.add);

        await controller.initialize();

        fakeWeb.emitState(
          const DivineVideoPlayerState(
            status: PlaybackStatus.playing,
            position: Duration(seconds: 2),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(states, hasLength(1));
        expect(states.first.status, equals(PlaybackStatus.playing));
        expect(states.first.position, equals(const Duration(seconds: 2)));
      });

      test('first frame state completes firstFrameRendered', () async {
        var completed = false;
        unawaited(controller.firstFrameRendered.then((_) => completed = true));

        await controller.initialize();

        fakeWeb.emitState(
          const DivineVideoPlayerState(isFirstFrameRendered: true),
        );
        await Future<void>.delayed(Duration.zero);

        expect(completed, isTrue);
      });

      test('error from backend sets error status on stateStream', () async {
        final states = <DivineVideoPlayerState>[];
        controller.stateStream.listen(states.add);

        await controller.initialize();

        fakeWeb.emitError('web error');
        await Future<void>.delayed(Duration.zero);

        expect(states, hasLength(1));
        expect(states.first.status, equals(PlaybackStatus.error));
      });
    });

    group('buildWebView', () {
      test('throws before the web backend is initialized', () {
        expect(() => controller.buildWebView(), throwsStateError);
      });

      test('returns the backend view after initialization', () async {
        await controller.initialize();

        expect(controller.buildWebView(), isA<SizedBox>());
      });
    });

    group('dispose', () {
      test('calls dispose on web backend', () async {
        await controller.initialize();
        await controller.dispose();

        expect(fakeWeb.disposeCalls, equals(1));
      });

      test('dispose is idempotent', () async {
        await controller.initialize();
        await controller.dispose();
        await controller.dispose();

        expect(fakeWeb.disposeCalls, equals(1));
      });
    });
  });
}

/// Fake [WebVideoPlayerBackend] for unit tests.
class _FakeWebVideoPlayerBackend implements WebVideoPlayerBackend {
  int initializeCalls = 0;
  int disposeCalls = 0;
  int playCalls = 0;
  int pauseCalls = 0;
  int stopCalls = 0;
  int setAudioTracksCalls = 0;
  int removeAllAudioTracksCalls = 0;

  List<VideoClip>? lastClips;
  Duration? lastStartPosition;
  Duration? lastSeekPosition;
  double? lastVolume;
  double? lastPlaybackSpeed;
  bool? lastLooping;
  int? lastJumpToClipIndex;
  int? lastAudioTrackIndex;
  double? lastAudioTrackVolume;

  late void Function(DivineVideoPlayerState state) _onStateChanged;
  late void Function(Object error) _onError;

  void emitState(DivineVideoPlayerState state) => _onStateChanged(state);
  void emitError(Object error) => _onError(error);

  @override
  Widget buildView() => const SizedBox.shrink();

  @override
  Future<void> initialize({
    required void Function(DivineVideoPlayerState state) onStateChanged,
    required void Function(Object error) onError,
  }) async {
    initializeCalls++;
    _onStateChanged = onStateChanged;
    _onError = onError;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }

  @override
  Future<void> play() async {
    playCalls++;
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<void> seekTo(Duration position) async {
    lastSeekPosition = position;
  }

  @override
  Future<void> setVolume(double volume) async {
    lastVolume = volume;
  }

  @override
  Future<void> setPlaybackSpeed(double speed) async {
    lastPlaybackSpeed = speed;
  }

  @override
  Future<void> setLooping({required bool looping}) async {
    lastLooping = looping;
  }

  @override
  Future<void> jumpToClip(int index) async {
    lastJumpToClipIndex = index;
  }

  @override
  Future<void> setClips(
    List<VideoClip> clips, {
    Duration? startPosition,
  }) async {
    lastClips = clips;
    lastStartPosition = startPosition;
  }

  @override
  Future<void> setAudioTracks(List<divine.AudioTrack> tracks) async {
    setAudioTracksCalls++;
  }

  @override
  Future<void> removeAllAudioTracks() async {
    removeAllAudioTracksCalls++;
  }

  @override
  Future<void> setAudioTrackVolume(int index, double volume) async {
    lastAudioTrackIndex = index;
    lastAudioTrackVolume = volume;
  }
}
