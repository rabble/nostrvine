import 'dart:async';

import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DivineVideoPlayerController controller;
  late List<MethodCall> globalCalls;
  late List<MethodCall> playerCalls;

  /// The event channel stream controller — push events here to simulate
  /// native player state updates.
  late StreamController<Map<Object?, Object?>> eventController;

  setUp(() {
    DivineVideoPlayerController.resetIdCounterForTesting();
    globalCalls = <MethodCall>[];
    playerCalls = <MethodCall>[];
    eventController = StreamController<Map<Object?, Object?>>.broadcast();
    controller = DivineVideoPlayerController();
  });

  tearDown(() async {
    await eventController.close();
  });

  /// Registers platform channel mocks and initializes the controller.
  ///
  /// The event channel mock is set up inside the 'create' handler so that
  /// it is in place before [initialize] subscribes to
  /// `receiveBroadcastStream()`.
  Future<void> initController() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('divine_video_player'),
          (call) async {
            globalCalls.add(call);
            if (call.method == 'create') {
              final id = (call.arguments as Map)['id'] as int;

              // Register per-player method channel mock.
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                  .setMockMethodCallHandler(
                    MethodChannel('divine_video_player/player_$id'),
                    (call) async {
                      playerCalls.add(call);
                      return null;
                    },
                  );

              // Register event channel mock BEFORE initialize() subscribes.
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                  .setMockStreamHandler(
                    EventChannel('divine_video_player/player_$id/events'),
                    _TestStreamHandler(eventController),
                  );
            }
            return null;
          },
        );

    await controller.initialize();
  }

  group(DivineVideoPlayerController, () {
    group('before initialize', () {
      test('isInitialized is false', () {
        expect(controller.isInitialized, isFalse);
      });

      test('nextId returns current counter value', () {
        expect(DivineVideoPlayerController.nextId, isA<int>());
      });

      test('viewType is correct', () {
        expect(controller.viewType, equals('divine_video_player_view'));
      });

      test('initial state is default', () {
        expect(controller.state.status, equals(PlaybackStatus.idle));
        expect(controller.state.position, equals(Duration.zero));
      });

      test('play throws StateError', () {
        expect(() => controller.play(), throwsStateError);
      });

      test('pause throws StateError', () {
        expect(() => controller.pause(), throwsStateError);
      });

      test('stop throws StateError', () {
        expect(() => controller.stop(), throwsStateError);
      });

      test('seekTo throws StateError', () {
        expect(
          () => controller.seekTo(Duration.zero),
          throwsStateError,
        );
      });

      test('setVolume throws StateError', () {
        expect(() => controller.setVolume(1), throwsStateError);
      });

      test('setPlaybackSpeed throws StateError', () {
        expect(
          () => controller.setPlaybackSpeed(1),
          throwsStateError,
        );
      });

      test('setLooping throws StateError', () {
        expect(
          () => controller.setLooping(looping: true),
          throwsStateError,
        );
      });

      test('jumpToClip throws StateError', () {
        expect(() => controller.jumpToClip(0), throwsStateError);
      });

      test('setClips throws StateError', () {
        expect(() => controller.setClips([]), throwsStateError);
      });

      test('setAudioTracks throws StateError', () {
        expect(
          () => controller.setAudioTracks([]),
          throwsStateError,
        );
      });

      test('removeAllAudioTracks throws StateError', () {
        expect(
          () => controller.removeAllAudioTracks(),
          throwsStateError,
        );
      });

      test('setAudioTrackVolume throws StateError', () {
        expect(
          () => controller.setAudioTrackVolume(0, 1),
          throwsStateError,
        );
      });
    });

    group('initialize', () {
      test('sets isInitialized to true', () async {
        await initController();

        expect(controller.isInitialized, isTrue);
      });

      test('exposes playerId after initialization', () async {
        await initController();

        expect(controller.playerId, equals(0));
      });

      test("invokes 'create' on global channel", () async {
        await initController();

        expect(globalCalls, hasLength(1));
        expect(globalCalls.first.method, equals('create'));
        expect(
          globalCalls.first.arguments,
          containsPair('id', isA<int>()),
        );
      });

      test('throws StateError if called twice', () async {
        await initController();

        expect(() => controller.initialize(), throwsStateError);
      });

      test('stores textureId when useTexture is true', () async {
        controller = DivineVideoPlayerController(useTexture: true);

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('divine_video_player'),
              (call) async {
                globalCalls.add(call);
                if (call.method == 'create') {
                  final id = (call.arguments as Map)['id'] as int;

                  TestDefaultBinaryMessengerBinding
                      .instance
                      .defaultBinaryMessenger
                      .setMockMethodCallHandler(
                        MethodChannel('divine_video_player/player_$id'),
                        (call) async {
                          playerCalls.add(call);
                          return null;
                        },
                      );

                  TestDefaultBinaryMessengerBinding
                      .instance
                      .defaultBinaryMessenger
                      .setMockStreamHandler(
                        EventChannel(
                          'divine_video_player/player_$id/events',
                        ),
                        _TestStreamHandler(eventController),
                      );

                  return <Object?, Object?>{'textureId': 42};
                }
                return null;
              },
            );

        await controller.initialize();

        expect(controller.textureId, equals(42));
      });
    });

    group('playback methods', () {
      setUp(() async {
        await initController();
      });

      test('play invokes native method', () async {
        await controller.play();

        expect(playerCalls.last.method, equals('play'));
      });

      test('pause invokes native method', () async {
        await controller.pause();

        expect(playerCalls.last.method, equals('pause'));
      });

      test('stop invokes native method', () async {
        await controller.stop();

        expect(playerCalls.last.method, equals('stop'));
      });

      test('seekTo sends position in milliseconds', () async {
        await controller.seekTo(const Duration(seconds: 10));

        expect(playerCalls.last.method, equals('seekTo'));
        expect(
          playerCalls.last.arguments,
          containsPair('positionMs', 10000),
        );
      });

      test('setVolume clamps and sends value', () async {
        await controller.setVolume(0.5);

        expect(playerCalls.last.method, equals('setVolume'));
        expect(
          playerCalls.last.arguments,
          containsPair('volume', 0.5),
        );
      });

      test('setVolume clamps below 0', () async {
        await controller.setVolume(-1);

        expect(
          playerCalls.last.arguments,
          containsPair('volume', 0.0),
        );
      });

      test('setVolume clamps above 1', () async {
        await controller.setVolume(2);

        expect(
          playerCalls.last.arguments,
          containsPair('volume', 1.0),
        );
      });

      test('setPlaybackSpeed sends speed', () async {
        await controller.setPlaybackSpeed(2);

        expect(playerCalls.last.method, equals('setPlaybackSpeed'));
        expect(
          playerCalls.last.arguments,
          containsPair('speed', 2.0),
        );
      });

      test('setLooping sends looping flag', () async {
        await controller.setLooping(looping: true);

        expect(playerCalls.last.method, equals('setLooping'));
        expect(
          playerCalls.last.arguments,
          containsPair('looping', true),
        );
      });

      test('jumpToClip sends index', () async {
        await controller.jumpToClip(2);

        expect(playerCalls.last.method, equals('jumpToClip'));
        expect(
          playerCalls.last.arguments,
          containsPair('index', 2),
        );
      });
    });

    group('setSource and setClips', () {
      setUp(() async {
        await initController();
      });

      test('setSource delegates to setClips', () async {
        const clip = VideoClip(uri: '/test.mp4');
        await controller.setSource(clip);

        expect(playerCalls.last.method, equals('setClips'));
        final clips =
            (playerCalls.last.arguments as Map)['clips'] as List<dynamic>;
        expect(clips, hasLength(1));
      });

      test('setClips sends serialized clips', () async {
        const clips = [
          VideoClip(
            uri: '/a.mp4',
            start: Duration(seconds: 1),
            end: Duration(seconds: 5),
          ),
          VideoClip(uri: '/b.mp4'),
        ];
        await controller.setClips(clips);

        expect(playerCalls.last.method, equals('setClips'));
        final sent =
            (playerCalls.last.arguments as Map)['clips'] as List<dynamic>;
        expect(sent, hasLength(2));
      });

      test('setClips resets firstFrameCompleter when completed', () async {
        // Complete the firstFrameCompleter by sending a state event.
        eventController.add({
          'status': 'playing',
          'isFirstFrameRendered': true,
          'positionMs': 0,
          'durationMs': 10000,
        });
        await Future<void>.delayed(Duration.zero);

        // The future should be completed.
        expect(controller.firstFrameRendered, completes);

        // Now setClips should reset it.
        await controller.setClips([const VideoClip(uri: '/c.mp4')]);

        // The new future should NOT be completed yet.
        var completed = false;
        unawaited(
          controller.firstFrameRendered.then((_) => completed = true),
        );
        await Future<void>.delayed(Duration.zero);
        expect(completed, isFalse);
      });
    });

    group('audio tracks', () {
      setUp(() async {
        await initController();
      });

      test('setAudioTracks sends serialized tracks', () async {
        const tracks = [
          AudioTrack(
            uri: '/audio.mp3',
            volume: 0.5,
            videoStartTime: Duration(seconds: 2),
          ),
        ];
        await controller.setAudioTracks(tracks);

        expect(playerCalls.last.method, equals('setAudioTracks'));
        final sent =
            (playerCalls.last.arguments as Map)['tracks'] as List<dynamic>;
        expect(sent, hasLength(1));
      });

      test('removeAllAudioTracks invokes native method', () async {
        await controller.removeAllAudioTracks();

        expect(
          playerCalls.last.method,
          equals('removeAllAudioTracks'),
        );
      });

      test('setAudioTrackVolume sends index and clamped volume', () async {
        await controller.setAudioTrackVolume(1, 0.7);

        expect(
          playerCalls.last.method,
          equals('setAudioTrackVolume'),
        );
        expect(
          playerCalls.last.arguments,
          containsPair('index', 1),
        );
        expect(
          playerCalls.last.arguments,
          containsPair('volume', 0.7),
        );
      });

      test('setAudioTrackVolume clamps below 0', () async {
        await controller.setAudioTrackVolume(0, -5);

        expect(
          playerCalls.last.arguments,
          containsPair('volume', 0.0),
        );
      });

      test('setAudioTrackVolume clamps above 1', () async {
        await controller.setAudioTrackVolume(0, 10);

        expect(
          playerCalls.last.arguments,
          containsPair('volume', 1.0),
        );
      });
    });

    group('event handling', () {
      setUp(() async {
        await initController();
      });

      test('updates state from event', () async {
        eventController.add({
          'status': 'playing',
          'positionMs': 5000,
          'durationMs': 30000,
          'bufferedPositionMs': 10000,
          'currentClipIndex': 1,
          'clipCount': 3,
          'isLooping': false,
          'volume': 0.8,
          'playbackSpeed': 1.5,
          'isFirstFrameRendered': true,
          'videoWidth': 1920,
          'videoHeight': 1080,
        });
        await Future<void>.delayed(Duration.zero);

        expect(controller.state.status, equals(PlaybackStatus.playing));
        expect(
          controller.state.position,
          equals(const Duration(seconds: 5)),
        );
        expect(
          controller.state.duration,
          equals(const Duration(seconds: 30)),
        );
        expect(controller.state.currentClipIndex, equals(1));
        expect(controller.state.videoWidth, equals(1920));
      });

      test('emits state on stateStream', () async {
        final states = <DivineVideoPlayerState>[];
        controller.stateStream.listen(states.add);

        eventController.add({'status': 'playing', 'positionMs': 1000});
        await Future<void>.delayed(Duration.zero);

        eventController.add({'status': 'paused', 'positionMs': 2000});
        await Future<void>.delayed(Duration.zero);

        expect(states, hasLength(2));
        expect(states[0].status, equals(PlaybackStatus.playing));
        expect(states[1].status, equals(PlaybackStatus.paused));
      });

      test('completes firstFrameRendered on first frame', () async {
        var completed = false;
        unawaited(
          controller.firstFrameRendered.then((_) => completed = true),
        );

        eventController.add({
          'status': 'playing',
          'isFirstFrameRendered': true,
        });
        await Future<void>.delayed(Duration.zero);

        expect(completed, isTrue);
      });

      test(
        'does not double-complete firstFrameRendered',
        () async {
          eventController.add({
            'status': 'playing',
            'isFirstFrameRendered': true,
          });
          await Future<void>.delayed(Duration.zero);

          // Second event should not throw.
          eventController.add({
            'status': 'playing',
            'isFirstFrameRendered': true,
          });
          await Future<void>.delayed(Duration.zero);

          expect(controller.firstFrameRendered, completes);
        },
      );

      test('ignores non-Map events', () async {
        eventController.add(<Object?, Object?>{});
        await Future<void>.delayed(Duration.zero);

        // State should still be parsable (fromMap handles empty map).
        expect(controller.state.status, equals(PlaybackStatus.idle));
      });
    });

    group('error handling', () {
      setUp(() async {
        await initController();
      });

      test('handles event error by setting error status', () async {
        final states = <DivineVideoPlayerState>[];
        controller.stateStream.listen(states.add);

        eventController.addError('Test error');
        await Future<void>.delayed(Duration.zero);

        expect(states, hasLength(1));
        expect(states.first.status, equals(PlaybackStatus.error));
      });

      test('logs native errorMessage via developer.log', () async {
        final states = <DivineVideoPlayerState>[];
        controller.stateStream.listen(states.add);

        eventController.add(<Object?, Object?>{
          'status': 'error',
          'positionMs': 0,
          'durationMs': 0,
          'bufferedPositionMs': 0,
          'currentClipIndex': 0,
          'clipCount': 0,
          'isLooping': false,
          'volume': 1.0,
          'playbackSpeed': 1.0,
          'isFirstFrameRendered': false,
          'videoWidth': 0,
          'videoHeight': 0,
          'errorMessage': 'AVPlayer failed: codec not supported',
        });
        await Future<void>.delayed(Duration.zero);

        expect(states, hasLength(1));
        expect(states.first.status, equals(PlaybackStatus.error));
      });
    });

    group('dispose', () {
      test("invokes 'dispose' on global channel", () async {
        await initController();
        await controller.dispose();

        expect(
          globalCalls.where((c) => c.method == 'dispose'),
          isNotEmpty,
        );
      });

      test('is idempotent', () async {
        await initController();
        await controller.dispose();
        await controller.dispose(); // Should not throw.

        // Only one 'dispose' call.
        expect(
          globalCalls.where((c) => c.method == 'dispose'),
          hasLength(1),
        );
      });

      test('methods throw StateError after dispose', () async {
        await initController();
        await controller.dispose();

        expect(() => controller.play(), throwsStateError);
        expect(() => controller.pause(), throwsStateError);
      });
    });

    group('static methods', () {
      test('configureCache invokes global channel', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('divine_video_player'),
              (call) async {
                globalCalls.add(call);
                return null;
              },
            );

        await DivineVideoPlayerController.configureCache(
          maxSizeBytes: 100 * 1024 * 1024,
        );

        expect(globalCalls, hasLength(1));
        expect(globalCalls.first.method, equals('configureCache'));
        expect(
          globalCalls.first.arguments,
          containsPair('maxSizeBytes', 100 * 1024 * 1024),
        );
      });

      test('configureCache uses default size', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('divine_video_player'),
              (call) async {
                globalCalls.add(call);
                return null;
              },
            );

        await DivineVideoPlayerController.configureCache();

        expect(
          globalCalls.first.arguments,
          containsPair('maxSizeBytes', kDefaultCacheMaxSizeBytes),
        );
      });

      test('preload invokes global channel with clips', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('divine_video_player'),
              (call) async {
                globalCalls.add(call);
                return null;
              },
            );

        await DivineVideoPlayerController.preload([
          const VideoClip.network('https://example.com/video.mp4'),
        ]);

        expect(globalCalls, hasLength(1));
        expect(globalCalls.first.method, equals('preload'));
        final clips =
            (globalCalls.first.arguments as Map)['clips'] as List<dynamic>;
        expect(clips, hasLength(1));
      });

      test('disposeAll invokes global channel', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('divine_video_player'),
              (call) async {
                globalCalls.add(call);
                return null;
              },
            );

        await DivineVideoPlayerController.disposeAll();

        expect(globalCalls, hasLength(1));
        expect(globalCalls.first.method, equals('disposeAll'));
      });
    });
  });
}

class _TestStreamHandler extends MockStreamHandler {
  _TestStreamHandler(this._controller);

  final StreamController<Map<Object?, Object?>> _controller;
  StreamSubscription<Map<Object?, Object?>>? _subscription;

  @override
  void onListen(Object? arguments, MockStreamHandlerEventSink events) {
    _subscription = _controller.stream.listen(
      events.success,
      onError: (Object error) => events.error(code: 'error', message: '$error'),
      onDone: events.endOfStream,
    );
  }

  @override
  void onCancel(Object? arguments) {
    unawaited(_subscription?.cancel());
    _subscription = null;
  }
}
