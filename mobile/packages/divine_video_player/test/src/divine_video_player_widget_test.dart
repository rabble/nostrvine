import 'package:divine_video_player/divine_video_player.dart';
import 'package:divine_video_player/src/linux/linux_video_player_backend.dart';
import 'package:divine_video_player/src/web/web_video_player_backend.dart';
import 'package:divine_video_player/src/web/web_video_player_backend_factory.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DivineVideoPlayerController controller;

  setUp(() async {
    DivineVideoPlayerController.resetIdCounterForTesting();
    DivineVideoPlayerController.debugForceLinuxBackend = null;
    DivineVideoPlayerController.linuxBackendFactory = _FakeLinuxBackend.new;
    DivineVideoPlayerController.debugForceWebBackend = null;
    DivineVideoPlayerController.webBackendFactory = _FakeWebBackend.new;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('divine_video_player'),
          (call) async => null,
        );

    controller = DivineVideoPlayerController();
    await controller.initialize();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          MethodChannel('divine_video_player/player_${controller.playerId}'),
          (call) async => null,
        );
  });

  tearDown(() {
    DivineVideoPlayerController.debugForceLinuxBackend = null;
    DivineVideoPlayerController.linuxBackendFactory =
        MediaKitLinuxVideoPlayerBackend.new;
    DivineVideoPlayerController.debugForceWebBackend = null;
    DivineVideoPlayerController.webBackendFactory =
        createDefaultWebVideoPlayerBackend;
    _FakeLinuxBackend.instance = null;
    _FakeWebBackend.instance = null;
  });

  Future<DivineVideoPlayerController> initLinuxController({
    bool firstFrameRendered = false,
  }) async {
    DivineVideoPlayerController.debugForceLinuxBackend = true;
    final linuxController = DivineVideoPlayerController();
    await linuxController.initialize();
    _FakeLinuxBackend.instance!.emitState(
      DivineVideoPlayerState(
        status: PlaybackStatus.ready,
        clipCount: 1,
        isFirstFrameRendered: firstFrameRendered,
      ),
    );
    return linuxController;
  }

  Future<DivineVideoPlayerController> initWebController({
    bool firstFrameRendered = false,
  }) async {
    DivineVideoPlayerController.debugForceWebBackend = true;
    final webController = DivineVideoPlayerController();
    await webController.initialize();
    _FakeWebBackend.instance!.emitState(
      DivineVideoPlayerState(
        status: PlaybackStatus.ready,
        clipCount: 1,
        isFirstFrameRendered: firstFrameRendered,
      ),
    );
    return webController;
  }

  group(DivineVideoPlayer, () {
    testWidgets('renders Linux backend view on Linux', (tester) async {
      final linuxController = await initLinuxController();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: DivineVideoPlayer(controller: linuxController),
        ),
      );

      expect(find.text('Linux player view'), findsOneWidget);
    });

    testWidgets('renders Web backend view on web', (tester) async {
      final webController = await initWebController();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: DivineVideoPlayer(controller: webController),
        ),
      );

      expect(find.text('Web player view'), findsOneWidget);
    });

    testWidgets('renders Text for unsupported fuchsia', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: DivineVideoPlayer(controller: controller),
        ),
      );

      expect(find.text('Platform not supported'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('renders Text for unsupported windows', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: DivineVideoPlayer(controller: controller),
        ),
      );

      expect(find.text('Platform not supported'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets(
      'renders PlatformViewLink for Android',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: DivineVideoPlayer(controller: controller),
          ),
        );

        expect(find.byType(PlatformViewLink), findsOneWidget);
        debugDefaultTargetPlatformOverride = null;
      },
    );

    testWidgets(
      'renders UiKitView for iOS',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: DivineVideoPlayer(controller: controller),
          ),
        );

        expect(find.byType(UiKitView), findsOneWidget);
        debugDefaultTargetPlatformOverride = null;
      },
    );

    testWidgets(
      'renders AppKitView for macOS',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: DivineVideoPlayer(controller: controller),
          ),
        );

        expect(find.byType(AppKitView), findsOneWidget);
        debugDefaultTargetPlatformOverride = null;
      },
    );

    testWidgets(
      'renders Texture when useTexture is true and textureId is set',
      (tester) async {
        final nextId = DivineVideoPlayerController.nextId;

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('divine_video_player'),
              (call) async {
                if (call.method == 'create') {
                  TestDefaultBinaryMessengerBinding
                      .instance
                      .defaultBinaryMessenger
                      .setMockMethodCallHandler(
                        MethodChannel('divine_video_player/player_$nextId'),
                        (call) async => null,
                      );

                  TestDefaultBinaryMessengerBinding
                      .instance
                      .defaultBinaryMessenger
                      .setMockStreamHandler(
                        EventChannel(
                          'divine_video_player/player_$nextId/events',
                        ),
                        _FirstFrameStreamHandler(),
                      );

                  return <Object?, Object?>{'textureId': 42};
                }
                return null;
              },
            );

        final textureController = DivineVideoPlayerController(
          useTexture: true,
        );
        await textureController.initialize();

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: DivineVideoPlayer(controller: textureController),
          ),
        );

        expect(find.byType(Texture), findsOneWidget);
        expect(find.byType(RotatedBox), findsNothing);
      },
    );

    testWidgets(
      'wraps Texture in RotatedBox when state.rotationDegrees is non-zero',
      (tester) async {
        final nextId = DivineVideoPlayerController.nextId;

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('divine_video_player'),
              (call) async {
                if (call.method == 'create') {
                  TestDefaultBinaryMessengerBinding
                      .instance
                      .defaultBinaryMessenger
                      .setMockMethodCallHandler(
                        MethodChannel('divine_video_player/player_$nextId'),
                        (call) async => null,
                      );

                  TestDefaultBinaryMessengerBinding
                      .instance
                      .defaultBinaryMessenger
                      .setMockStreamHandler(
                        EventChannel(
                          'divine_video_player/player_$nextId/events',
                        ),
                        _RotatedStreamHandler(),
                      );

                  return <Object?, Object?>{'textureId': 99};
                }
                return null;
              },
            );

        final textureController = DivineVideoPlayerController(
          useTexture: true,
        );
        await textureController.initialize();

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: DivineVideoPlayer(controller: textureController),
          ),
        );
        // Allow the StreamBuilder to receive the initial event.
        await tester.pump();

        expect(find.byType(Texture), findsOneWidget);
        final rotatedBox = tester.widget<RotatedBox>(find.byType(RotatedBox));
        // 90 degrees / 90 = 1 quarter turn.
        expect(rotatedBox.quarterTurns, equals(1));
      },
    );

    testWidgets('does not render Stack when placeholder is null', (
      tester,
    ) async {
      final linuxController = await initLinuxController();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: DivineVideoPlayer(controller: linuxController),
        ),
      );

      expect(find.byType(Stack), findsNothing);
    });

    testWidgets('renders placeholder over surface before first frame', (
      tester,
    ) async {
      final linuxController = await initLinuxController();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: DivineVideoPlayer(
            controller: linuxController,
            placeholder: const Text('Loading...'),
          ),
        ),
      );

      expect(find.byType(Stack), findsOneWidget);
      expect(find.text('Loading...'), findsOneWidget);
    });

    testWidgets('hides placeholder after first frame rendered', (tester) async {
      final freshController = await initLinuxController(
        firstFrameRendered: true,
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: DivineVideoPlayer(
            controller: freshController,
            placeholder: const Text('Loading...'),
          ),
        ),
      );

      // Allow the FutureBuilder to rebuild after the future completes.
      await tester.pump();

      expect(find.text('Loading...'), findsNothing);
    });
  });
}

class _FakeLinuxBackend implements LinuxVideoPlayerBackend {
  _FakeLinuxBackend() {
    instance = this;
  }

  static _FakeLinuxBackend? instance;

  late void Function(DivineVideoPlayerState state) _onStateChanged;

  @override
  Future<void> initialize({
    required void Function(DivineVideoPlayerState state) onStateChanged,
    required void Function(Object error) onError,
  }) async {
    _onStateChanged = onStateChanged;
  }

  void emitState(DivineVideoPlayerState state) => _onStateChanged(state);

  @override
  Widget buildView() => const Text('Linux player view');

  @override
  Future<void> dispose() async {}

  @override
  Future<void> jumpToClip(int index) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> removeAllAudioTracks() async {}

  @override
  Future<void> seekTo(Duration position) async {}

  @override
  Future<void> setAudioTrackVolume(int index, double volume) async {}

  @override
  Future<void> setAudioTracks(List<AudioTrack> tracks) async {}

  @override
  Future<void> setClips(
    List<VideoClip> clips, {
    Duration? startPosition,
  }) async {}

  @override
  Future<void> setLooping({required bool looping}) async {}

  @override
  Future<void> setPlaybackSpeed(double speed) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> stop() async {}
}

class _FakeWebBackend implements WebVideoPlayerBackend {
  _FakeWebBackend() {
    instance = this;
  }

  static _FakeWebBackend? instance;

  late void Function(DivineVideoPlayerState state) _onStateChanged;

  @override
  Future<void> initialize({
    required void Function(DivineVideoPlayerState state) onStateChanged,
    required void Function(Object error) onError,
  }) async {
    _onStateChanged = onStateChanged;
  }

  void emitState(DivineVideoPlayerState state) => _onStateChanged(state);

  @override
  Widget buildView() => const Text('Web player view');

  @override
  Future<void> dispose() async {}

  @override
  Future<void> jumpToClip(int index) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> removeAllAudioTracks() async {}

  @override
  Future<void> seekTo(Duration position) async {}

  @override
  Future<void> setAudioTrackVolume(int index, double volume) async {}

  @override
  Future<void> setAudioTracks(List<AudioTrack> tracks) async {}

  @override
  Future<void> setClips(
    List<VideoClip> clips, {
    Duration? startPosition,
  }) async {}

  @override
  Future<void> setLooping({required bool looping}) async {}

  @override
  Future<void> setPlaybackSpeed(double speed) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> stop() async {}
}

class _FirstFrameStreamHandler extends MockStreamHandler {
  @override
  void onListen(Object? arguments, MockStreamHandlerEventSink events) {
    events.success(<Object?, Object?>{
      'status': 'playing',
      'positionMs': 0,
      'durationMs': 1000,
      'bufferedPositionMs': 500,
      'currentClipIndex': 0,
      'clipCount': 1,
      'isLooping': false,
      'volume': 1.0,
      'playbackSpeed': 1.0,
      'isFirstFrameRendered': true,
      'videoWidth': 1920,
      'videoHeight': 1080,
    });
  }

  @override
  void onCancel(Object? arguments) {}
}

class _RotatedStreamHandler extends MockStreamHandler {
  @override
  void onListen(Object? arguments, MockStreamHandlerEventSink events) {
    events.success(<Object?, Object?>{
      'status': 'playing',
      'positionMs': 0,
      'durationMs': 1000,
      'bufferedPositionMs': 0,
      'currentClipIndex': 0,
      'clipCount': 1,
      'isLooping': false,
      'volume': 1.0,
      'playbackSpeed': 1.0,
      'isFirstFrameRendered': true,
      'videoWidth': 1080,
      'videoHeight': 1920,
      'rotationDegrees': 90,
    });
  }

  @override
  void onCancel(Object? arguments) {}
}
