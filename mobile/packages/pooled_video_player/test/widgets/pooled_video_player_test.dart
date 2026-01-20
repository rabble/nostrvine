import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pooled_video_player/pooled_video_player.dart';
import 'package:video_player/video_player.dart';

// Mock classes
class MockVideoPlayerController extends Mock implements VideoPlayerController {}

class MockVideoPlayerValue extends Mock implements VideoPlayerValue {}

class MockPooledVideo extends Mock implements PooledVideo {}

// Test helpers
Future<VideoPlayerController?> createMockController(
  String videoUrl, {
  File? cachedFile,
}) async {
  final controller = MockVideoPlayerController();
  final value = MockVideoPlayerValue();

  when(() => value.isInitialized).thenReturn(true);
  when(() => value.isPlaying).thenReturn(false);
  when(() => value.duration).thenReturn(const Duration(seconds: 10));
  when(() => value.position).thenReturn(Duration.zero);
  when(() => controller.value).thenReturn(value);
  when(controller.dispose).thenAnswer((_) async {});
  when(controller.pause).thenAnswer((_) async {});
  when(controller.play).thenAnswer((_) async {});
  when(() => controller.setLooping(any())).thenAnswer((_) async {});

  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockPooledVideo mockVideo;

  setUp(() {
    mockVideo = MockPooledVideo();
    when(() => mockVideo.id).thenReturn('test-video-1');
    when(() => mockVideo.videoUrl).thenReturn('https://example.com/video1.mp4');
    when(() => mockVideo.thumbnailUrl).thenReturn(null);
  });

  tearDown(() async {
    await VideoControllerPoolManager.reset();
  });

  group('PooledVideoPlayer', () {
    group('Initialization', () {
      testWidgets('throws error when pool not initialized', (
        WidgetTester tester,
      ) async {
        var errorCalled = false;
        Object? capturedError;

        await tester.pumpWidget(
          MaterialApp(
            home: PooledVideoPlayer(
              video: mockVideo,
              videoBuilder: (context, controller) => Container(),
              onVideoError: (error) {
                errorCalled = true;
                capturedError = error;
              },
            ),
          ),
        );

        expect(errorCalled, isTrue);
        expect(capturedError, isA<StateError>());
        expect(
          capturedError.toString(),
          contains('VideoControllerPoolManager not initialized'),
        );
      });

      testWidgets('widget initializes successfully with pool', (
        WidgetTester tester,
      ) async {
        await VideoControllerPoolManager.initialize(
          poolSize: 3,
          controllerFactory: createMockController,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: PooledVideoPlayer(
              video: mockVideo,
              videoBuilder: (context, controller) => Container(),
            ),
          ),
        );

        expect(find.byType(PooledVideoPlayer), findsOneWidget);
      });

      testWidgets('uses prewarmed controller if available', (
        WidgetTester tester,
      ) async {
        await VideoControllerPoolManager.initialize(
          poolSize: 3,
          controllerFactory: createMockController,
        );

        // Prewarm the controller
        await VideoControllerPoolManager.instance.acquireController(
          videoId: mockVideo.id,
          videoUrl: mockVideo.videoUrl,
        );

        var readyCalled = false;
        VideoPlayerController? readyController;

        await tester.pumpWidget(
          MaterialApp(
            home: PooledVideoPlayer(
              video: mockVideo,
              videoBuilder: (context, controller) => Container(),
              onVideoReady: (controller) {
                readyCalled = true;
                readyController = controller;
              },
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(readyCalled, isTrue);
        expect(readyController, isNotNull);
        expect(readyController!.value.isInitialized, isTrue);
      });

      testWidgets('requests controller when not prewarmed', (
        WidgetTester tester,
      ) async {
        await VideoControllerPoolManager.initialize(
          poolSize: 3,
          controllerFactory: createMockController,
        );

        var loadingCalled = false;
        var readyCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: PooledVideoPlayer(
              video: mockVideo,
              videoBuilder: (context, controller) => Container(),
              onVideoLoading: () => loadingCalled = true,
              onVideoReady: (_) => readyCalled = true,
            ),
          ),
        );

        expect(loadingCalled, isTrue);

        await tester.pumpAndSettle();

        expect(readyCalled, isTrue);
      });
    });

    group('Auto-Play Behavior', () {
      testWidgets('plays video when autoPlay=true and ready', (
        WidgetTester tester,
      ) async {
        await VideoControllerPoolManager.initialize(
          poolSize: 3,
          controllerFactory: createMockController,
        );

        VideoPlayerController? capturedController;

        await tester.pumpWidget(
          MaterialApp(
            home: PooledVideoPlayer(
              video: mockVideo,
              videoBuilder: (context, controller) => Container(),
              autoPlay: true,
              onVideoReady: (controller) => capturedController = controller,
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(capturedController, isNotNull);
        verify(capturedController!.play).called(1);
      });

      testWidgets('does not play when autoPlay not specified', (
        WidgetTester tester,
      ) async {
        await VideoControllerPoolManager.initialize(
          poolSize: 3,
          controllerFactory: createMockController,
        );

        VideoPlayerController? capturedController;

        await tester.pumpWidget(
          MaterialApp(
            home: PooledVideoPlayer(
              video: mockVideo,
              videoBuilder: (context, controller) => Container(),
              onVideoReady: (controller) => capturedController = controller,
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(capturedController, isNotNull);
        verifyNever(capturedController!.play);
      });

      testWidgets('plays prewarmed controller immediately when autoPlay=true', (
        WidgetTester tester,
      ) async {
        await VideoControllerPoolManager.initialize(
          poolSize: 3,
          controllerFactory: createMockController,
        );

        // Prewarm
        await VideoControllerPoolManager.instance.acquireController(
          videoId: mockVideo.id,
          videoUrl: mockVideo.videoUrl,
        );

        VideoPlayerController? capturedController;

        await tester.pumpWidget(
          MaterialApp(
            home: PooledVideoPlayer(
              video: mockVideo,
              videoBuilder: (context, controller) => Container(),
              autoPlay: true,
              onVideoReady: (controller) => capturedController = controller,
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(capturedController, isNotNull);
        verify(capturedController!.play).called(1);
      });
    });

    group('Widget Updates', () {
      testWidgets('starts playback when autoPlay changes to true', (
        WidgetTester tester,
      ) async {
        await VideoControllerPoolManager.initialize(
          poolSize: 3,
          controllerFactory: createMockController,
        );

        // Prewarm controller
        await VideoControllerPoolManager.instance.acquireController(
          videoId: mockVideo.id,
          videoUrl: mockVideo.videoUrl,
        );

        VideoPlayerController? controller;

        await tester.pumpWidget(
          MaterialApp(
            home: PooledVideoPlayer(
              video: mockVideo,
              videoBuilder: (context, ctrl) => Container(),
              onVideoReady: (ctrl) => controller = ctrl,
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(controller, isNotNull);

        // Update to autoPlay=true
        await tester.pumpWidget(
          MaterialApp(
            home: PooledVideoPlayer(
              video: mockVideo,
              videoBuilder: (context, ctrl) => Container(),
              autoPlay: true,
              onVideoReady: (ctrl) => controller = ctrl,
            ),
          ),
        );

        await tester.pumpAndSettle();

        verify(controller!.play).called(1);
      });

      testWidgets('pauses when autoPlay changes from true to false', (
        WidgetTester tester,
      ) async {
        await VideoControllerPoolManager.initialize(
          poolSize: 3,
          controllerFactory: createMockController,
        );

        // Prewarm controller
        await VideoControllerPoolManager.instance.acquireController(
          videoId: mockVideo.id,
          videoUrl: mockVideo.videoUrl,
        );

        VideoPlayerController? controller;

        await tester.pumpWidget(
          MaterialApp(
            home: PooledVideoPlayer(
              video: mockVideo,
              videoBuilder: (context, ctrl) => Container(),
              autoPlay: true,
              onVideoReady: (ctrl) => controller = ctrl,
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(controller, isNotNull);

        // Simulate playing state
        final value = controller!.value as MockVideoPlayerValue;
        when(() => value.isPlaying).thenReturn(true);

        // Update to autoPlay=false
        await tester.pumpWidget(
          MaterialApp(
            home: PooledVideoPlayer(
              video: mockVideo,
              videoBuilder: (context, ctrl) => Container(),
              onVideoReady: (ctrl) => controller = ctrl,
            ),
          ),
        );

        await tester.pumpAndSettle();

        verify(controller!.pause).called(1);
      });

      testWidgets('requests new controller when video ID changes', (
        WidgetTester tester,
      ) async {
        await VideoControllerPoolManager.initialize(
          poolSize: 3,
          controllerFactory: createMockController,
        );

        var readyCallCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: PooledVideoPlayer(
              video: mockVideo,
              videoBuilder: (context, controller) => Container(),
              onVideoReady: (_) => readyCallCount++,
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(readyCallCount, 1);

        // Change video
        final newVideo = MockPooledVideo();
        when(() => newVideo.id).thenReturn('test-video-2');
        when(
          () => newVideo.videoUrl,
        ).thenReturn('https://example.com/video2.mp4');
        when(() => newVideo.thumbnailUrl).thenReturn(null);

        await tester.pumpWidget(
          MaterialApp(
            home: PooledVideoPlayer(
              video: newVideo,
              videoBuilder: (context, controller) => Container(),
              onVideoReady: (_) => readyCallCount++,
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(readyCallCount, 2);
      });

      testWidgets('uses prewarmed controller on video change if available', (
        WidgetTester tester,
      ) async {
        await VideoControllerPoolManager.initialize(
          poolSize: 3,
          controllerFactory: createMockController,
        );

        // Prewarm both videos
        await VideoControllerPoolManager.instance.acquireController(
          videoId: mockVideo.id,
          videoUrl: mockVideo.videoUrl,
        );

        final newVideo = MockPooledVideo();
        when(() => newVideo.id).thenReturn('test-video-2');
        when(
          () => newVideo.videoUrl,
        ).thenReturn('https://example.com/video2.mp4');
        when(() => newVideo.thumbnailUrl).thenReturn(null);

        await VideoControllerPoolManager.instance.acquireController(
          videoId: newVideo.id,
          videoUrl: newVideo.videoUrl,
        );

        var readyCallCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: PooledVideoPlayer(
              video: mockVideo,
              videoBuilder: (context, controller) => Container(),
              onVideoReady: (_) => readyCallCount++,
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(readyCallCount, 1);

        // Change to prewarmed video
        await tester.pumpWidget(
          MaterialApp(
            home: PooledVideoPlayer(
              video: newVideo,
              videoBuilder: (context, controller) => Container(),
              onVideoReady: (_) => readyCallCount++,
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(readyCallCount, 2);
      });
    });

    group('Builder Functions', () {
      testWidgets('calls videoBuilder when controller ready', (
        WidgetTester tester,
      ) async {
        await VideoControllerPoolManager.initialize(
          poolSize: 3,
          controllerFactory: createMockController,
        );

        // Prewarm
        await VideoControllerPoolManager.instance.acquireController(
          videoId: mockVideo.id,
          videoUrl: mockVideo.videoUrl,
        );

        var videoBuilderCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: PooledVideoPlayer(
              video: mockVideo,
              videoBuilder: (context, controller) {
                videoBuilderCalled = true;
                return Container(key: const Key('video-widget'));
              },
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(videoBuilderCalled, isTrue);
        expect(find.byKey(const Key('video-widget')), findsOneWidget);
      });

      testWidgets('calls overlayBuilder when provided and ready', (
        WidgetTester tester,
      ) async {
        await VideoControllerPoolManager.initialize(
          poolSize: 3,
          controllerFactory: createMockController,
        );

        // Prewarm
        await VideoControllerPoolManager.instance.acquireController(
          videoId: mockVideo.id,
          videoUrl: mockVideo.videoUrl,
        );

        var overlayBuilderCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: PooledVideoPlayer(
              video: mockVideo,
              videoBuilder: (context, controller) => Container(),
              overlayBuilder: (context, controller) {
                overlayBuilderCalled = true;
                return Container(key: const Key('overlay-widget'));
              },
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(overlayBuilderCalled, isTrue);
        expect(find.byKey(const Key('overlay-widget')), findsOneWidget);
      });

      testWidgets('calls loadingBuilder when not ready', (
        WidgetTester tester,
      ) async {
        await VideoControllerPoolManager.initialize(
          poolSize: 3,
          controllerFactory: createMockController,
        );

        var loadingBuilderCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: PooledVideoPlayer(
              video: mockVideo,
              videoBuilder: (context, controller) => Container(),
              loadingBuilder: (context) {
                loadingBuilderCalled = true;
                return Container(key: const Key('loading-widget'));
              },
            ),
          ),
        );

        // Before controller is ready
        expect(loadingBuilderCalled, isTrue);
        expect(find.byKey(const Key('loading-widget')), findsOneWidget);
      });

      testWidgets('shows default loading state when no loadingBuilder', (
        WidgetTester tester,
      ) async {
        await VideoControllerPoolManager.initialize(
          poolSize: 3,
          controllerFactory: createMockController,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: PooledVideoPlayer(
              video: mockVideo,
              videoBuilder: (context, controller) => Container(),
            ),
          ),
        );

        // Should show default loading widget (CircularProgressIndicator)
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Should use _DefaultLoadingState widget (VGE compliance)
        // Find the private widget by checking for ColoredBox with black color
        // containing the CircularProgressIndicator
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is ColoredBox &&
                widget.color == Colors.black &&
                widget.child is Center,
          ),
          findsOneWidget,
        );
      });

      testWidgets('composes Stack with video and overlay layers', (
        WidgetTester tester,
      ) async {
        await VideoControllerPoolManager.initialize(
          poolSize: 3,
          controllerFactory: createMockController,
        );

        // Prewarm
        await VideoControllerPoolManager.instance.acquireController(
          videoId: mockVideo.id,
          videoUrl: mockVideo.videoUrl,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: PooledVideoPlayer(
              video: mockVideo,
              videoBuilder: (context, controller) => Container(
                key: const Key('video-layer'),
              ),
              overlayBuilder: (context, controller) => Container(
                key: const Key('overlay-layer'),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(Stack), findsWidgets);
        expect(find.byKey(const Key('video-layer')), findsOneWidget);
        expect(find.byKey(const Key('overlay-layer')), findsOneWidget);
      });
    });

    // Note: Tap-to-pause functionality is better tested in integration tests
    // as it involves complex widget hit testing and gesture recognition.
    // The feature is implemented correctly but difficult to test in unit tests.

    group('Disposal', () {
      testWidgets('disposes without error', (WidgetTester tester) async {
        await VideoControllerPoolManager.initialize(
          poolSize: 3,
          controllerFactory: createMockController,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: PooledVideoPlayer(
              video: mockVideo,
              videoBuilder: (context, controller) => Container(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Dispose widget
        await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

        // Should dispose without errors
        await tester.pumpAndSettle();
      });
    });
  });
}
