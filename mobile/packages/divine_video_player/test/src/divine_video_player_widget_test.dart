import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DivineVideoPlayerController controller;

  setUp(() async {
    DivineVideoPlayerController.resetIdCounterForTesting();
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

  group(DivineVideoPlayer, () {
    testWidgets('renders Text for unsupported platform', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: DivineVideoPlayer(controller: controller),
        ),
      );

      expect(find.text('Platform not supported'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
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
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: DivineVideoPlayer(controller: controller),
        ),
      );

      expect(find.byType(Stack), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('renders placeholder over surface before first frame', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: DivineVideoPlayer(
            controller: controller,
            placeholder: const Text('Loading...'),
          ),
        ),
      );

      expect(find.byType(Stack), findsOneWidget);
      expect(find.text('Loading...'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('hides placeholder after first frame rendered', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      // Set up a mock stream handler that emits firstFrameRendered=true,
      // then create a fresh controller so its initialize() subscribes to
      // that stream.
      final nextId = DivineVideoPlayerController.nextId;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            MethodChannel('divine_video_player/player_$nextId'),
            (call) async => null,
          );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
            EventChannel('divine_video_player/player_$nextId/events'),
            _FirstFrameStreamHandler(),
          );

      final freshController = DivineVideoPlayerController();
      await freshController.initialize();

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
      debugDefaultTargetPlatformOverride = null;
    });
  });
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
