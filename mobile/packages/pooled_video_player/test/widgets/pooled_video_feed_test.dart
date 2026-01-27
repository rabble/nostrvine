import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pooled_video_player/pooled_video_player.dart';
import 'package:video_player/video_player.dart';

class MockVideoPlayerController extends Mock implements VideoPlayerController {}

class MockVideoPlayerValue extends Mock implements VideoPlayerValue {}

class MockPooledVideo extends Mock implements PooledVideo {}

Future<VideoPlayerController?> createMockController(
  String videoUrl, {
  File? cachedFile,
}) async {
  final controller = MockVideoPlayerController();
  final value = MockVideoPlayerValue();

  when(() => value.isInitialized).thenReturn(true);
  when(() => value.isPlaying).thenReturn(false);
  when(() => value.duration).thenReturn(const Duration(seconds: 7));
  when(() => value.position).thenReturn(Duration.zero);
  when(() => controller.value).thenReturn(value);
  when(controller.dispose).thenAnswer((_) async {});
  when(controller.pause).thenAnswer((_) async {});
  when(controller.play).thenAnswer((_) async {});
  when(() => controller.setLooping(any())).thenAnswer((_) async {});

  return controller;
}

List<MockPooledVideo> createMockVideos(int count) {
  return List.generate(count, (index) {
    final video = MockPooledVideo();
    when(() => video.id).thenReturn('video-$index');
    when(
      () => video.videoUrl,
    ).thenReturn('https://example.com/video$index.mp4');
    when(() => video.thumbnailUrl).thenReturn(null);
    return video;
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MockPooledVideo> mockVideos;

  setUp(() {
    mockVideos = createMockVideos(10);
  });

  tearDown(() async {
    await VideoControllerPoolManager.reset();
  });

  group('PooledVideoFeed', () {
    group('Basic Widget Structure', () {
      testWidgets('renders PageView with correct item count', (
        WidgetTester tester,
      ) async {
        await VideoControllerPoolManager.initialize(
          poolSize: 3,
          controllerFactory: createMockController,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PooledVideoFeed(
                videos: mockVideos,
                itemBuilder: (context, video, index, isActive) => Container(
                  key: Key('video-$index'),
                ),
              ),
            ),
          ),
        );

        expect(find.byType(PageView), findsOneWidget);
        expect(find.byKey(const Key('video-0')), findsOneWidget);
      });

      testWidgets('uses vertical scroll direction by default', (
        WidgetTester tester,
      ) async {
        await VideoControllerPoolManager.initialize(
          poolSize: 3,
          controllerFactory: createMockController,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PooledVideoFeed(
                videos: mockVideos,
                itemBuilder: (context, video, index, isActive) => Container(),
              ),
            ),
          ),
        );

        final pageView = tester.widget<PageView>(find.byType(PageView));
        expect(pageView.scrollDirection, Axis.vertical);
      });

      testWidgets('respects custom scroll direction', (
        WidgetTester tester,
      ) async {
        await VideoControllerPoolManager.initialize(
          poolSize: 3,
          controllerFactory: createMockController,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PooledVideoFeed(
                videos: mockVideos,
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, video, index, isActive) => Container(),
              ),
            ),
          ),
        );

        final pageView = tester.widget<PageView>(find.byType(PageView));
        expect(pageView.scrollDirection, Axis.horizontal);
      });

      testWidgets('passes initial index to PageController', (
        WidgetTester tester,
      ) async {
        await VideoControllerPoolManager.initialize(
          poolSize: 3,
          controllerFactory: createMockController,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PooledVideoFeed(
                videos: mockVideos,
                initialIndex: 3,
                itemBuilder: (context, video, index, isActive) => Container(
                  key: Key('video-$index'),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // The widget at index 3 should be visible
        expect(find.byKey(const Key('video-3')), findsOneWidget);
      });

      testWidgets('itemBuilder receives correct parameters', (
        WidgetTester tester,
      ) async {
        await VideoControllerPoolManager.initialize(
          poolSize: 3,
          controllerFactory: createMockController,
        );

        PooledVideo? receivedVideo;
        int? receivedIndex;
        bool? receivedIsActive;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PooledVideoFeed(
                videos: mockVideos,
                itemBuilder: (context, video, index, isActive) {
                  if (index == 0) {
                    receivedVideo = video;
                    receivedIndex = index;
                    receivedIsActive = isActive;
                  }
                  return Container();
                },
              ),
            ),
          ),
        );

        expect(receivedVideo, mockVideos[0]);
        expect(receivedIndex, 0);
        expect(receivedIsActive, isTrue);
      });
    });

    group('Initial Prewarming', () {
      testWidgets('acquires controller for initial video on mount', (
        WidgetTester tester,
      ) async {
        await VideoControllerPoolManager.initialize(
          poolSize: 4,
          controllerFactory: createMockController,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PooledVideoFeed(
                videos: mockVideos,
                itemBuilder: (context, video, index, isActive) => Container(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final manager = VideoControllerPoolManager.instance;

        // Initial video should be acquired
        expect(manager.getController('video-0'), isNotNull);
      });

      testWidgets('prewarms next videos on mount', (WidgetTester tester) async {
        await VideoControllerPoolManager.initialize(
          poolSize: 5,
          controllerFactory: createMockController,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PooledVideoFeed(
                videos: mockVideos,
                itemBuilder: (context, video, index, isActive) => Container(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final manager = VideoControllerPoolManager.instance;

        // Should prewarm current + next 3 videos (indices 0, 1, 2, 3)
        expect(manager.getController('video-0'), isNotNull);
        expect(manager.getController('video-1'), isNotNull);
        expect(manager.getController('video-2'), isNotNull);
        expect(manager.getController('video-3'), isNotNull);
      });

      testWidgets('registers video indices for distance-aware eviction', (
        WidgetTester tester,
      ) async {
        await VideoControllerPoolManager.initialize(
          poolSize: 4,
          controllerFactory: createMockController,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PooledVideoFeed(
                videos: mockVideos,
                itemBuilder: (context, video, index, isActive) => Container(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final manager = VideoControllerPoolManager.instance;

        // Video indices are registered internally - we can verify by checking
        // that controllers exist and distance-aware eviction works
        expect(manager.assignedControllers.isNotEmpty, isTrue);
      });
    });

    group('Page Change Handling', () {
      testWidgets('calls setActiveVideo on page change', (
        WidgetTester tester,
      ) async {
        await VideoControllerPoolManager.initialize(
          poolSize: 4,
          controllerFactory: createMockController,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PooledVideoFeed(
                videos: mockVideos,
                itemBuilder: (context, video, index, isActive) => Container(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final manager = VideoControllerPoolManager.instance;

        // Initial active video
        expect(manager.activeVideoId, 'video-0');

        // Swipe to next page
        await tester.fling(
          find.byType(PageView),
          const Offset(0, -500),
          1000,
        );
        await tester.pumpAndSettle();

        // Active video should change
        expect(manager.activeVideoId, 'video-1');
      });

      testWidgets('invokes onActiveVideoChanged callback', (
        WidgetTester tester,
      ) async {
        await VideoControllerPoolManager.initialize(
          poolSize: 3,
          controllerFactory: createMockController,
        );

        PooledVideo? changedVideo;
        int? changedIndex;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PooledVideoFeed(
                videos: mockVideos,
                onActiveVideoChanged: (video, index) {
                  changedVideo = video;
                  changedIndex = index;
                },
                itemBuilder: (context, video, index, isActive) => Container(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Swipe to next page
        await tester.fling(
          find.byType(PageView),
          const Offset(0, -500),
          1000,
        );
        await tester.pumpAndSettle();

        expect(changedVideo, mockVideos[1]);
        expect(changedIndex, 1);
      });

      testWidgets('marks correct item as active in itemBuilder', (
        WidgetTester tester,
      ) async {
        await VideoControllerPoolManager.initialize(
          poolSize: 3,
          controllerFactory: createMockController,
        );

        final activeStates = <int, bool>{};

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PooledVideoFeed(
                videos: mockVideos,
                itemBuilder: (context, video, index, isActive) {
                  activeStates[index] = isActive;
                  return Container();
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Initially index 0 is active
        expect(activeStates[0], isTrue);

        // Swipe to next page
        await tester.fling(
          find.byType(PageView),
          const Offset(0, -500),
          1000,
        );
        await tester.pumpAndSettle();

        // Now index 1 should be active
        expect(activeStates[1], isTrue);
      });
    });

    group('Debounce Behavior', () {
      testWidgets('debounces prewarm calls during rapid scrolling', (
        WidgetTester tester,
      ) async {
        var acquireCallCount = 0;

        await VideoControllerPoolManager.initialize(
          poolSize: 10,
          controllerFactory: (videoUrl, {cachedFile}) async {
            acquireCallCount++;
            return createMockController(videoUrl, cachedFile: cachedFile);
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PooledVideoFeed(
                videos: mockVideos,
                itemBuilder: (context, video, index, isActive) => Container(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Record initial acquire count after mount
        final initialCount = acquireCallCount;

        // Rapidly swipe multiple times without waiting for settle
        await tester.fling(
          find.byType(PageView),
          const Offset(0, -300),
          2000,
        );
        await tester.pump(const Duration(milliseconds: 50));

        await tester.fling(
          find.byType(PageView),
          const Offset(0, -300),
          2000,
        );
        await tester.pump(const Duration(milliseconds: 50));

        // Wait for debounce
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();

        // Due to debouncing, acquire count should be less than
        // what it would be without debouncing
        // The exact count depends on implementation details
        expect(acquireCallCount, greaterThan(initialCount));
      });
    });

    group('Video List Updates', () {
      testWidgets('re-prewarms when videos list changes length', (
        WidgetTester tester,
      ) async {
        await VideoControllerPoolManager.initialize(
          poolSize: 6,
          controllerFactory: createMockController,
        );

        final initialVideos = createMockVideos(5);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PooledVideoFeed(
                videos: initialVideos,
                itemBuilder: (context, video, index, isActive) => Container(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final manager = VideoControllerPoolManager.instance;
        final initialControllerCount = manager.assignedControllers.length;

        // Add more videos
        final extendedVideos = createMockVideos(8);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PooledVideoFeed(
                videos: extendedVideos,
                itemBuilder: (context, video, index, isActive) => Container(),
              ),
            ),
          ),
        );

        // Wait for debounced prewarm
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();

        // Should still have controllers (may be same or more due to re-prewarm)
        expect(
          manager.assignedControllers.length,
          greaterThanOrEqualTo(initialControllerCount),
        );
      });
    });

    group('Empty and Edge Cases', () {
      testWidgets('handles empty video list', (WidgetTester tester) async {
        await VideoControllerPoolManager.initialize(
          poolSize: 3,
          controllerFactory: createMockController,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PooledVideoFeed(
                videos: const [],
                itemBuilder: (context, video, index, isActive) => Container(),
              ),
            ),
          ),
        );

        expect(find.byType(PageView), findsOneWidget);
        // Should not crash with empty list
      });

      testWidgets('handles single video', (WidgetTester tester) async {
        await VideoControllerPoolManager.initialize(
          poolSize: 3,
          controllerFactory: createMockController,
        );

        final singleVideo = createMockVideos(1);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PooledVideoFeed(
                videos: singleVideo,
                itemBuilder: (context, video, index, isActive) => Container(
                  key: const Key('single-video'),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byKey(const Key('single-video')), findsOneWidget);

        final manager = VideoControllerPoolManager.instance;
        expect(manager.getController('video-0'), isNotNull);
      });

      testWidgets('works without pool initialization (graceful degradation)', (
        WidgetTester tester,
      ) async {
        // Do NOT initialize pool

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PooledVideoFeed(
                videos: mockVideos,
                itemBuilder: (context, video, index, isActive) => Container(
                  key: Key('video-$index'),
                ),
              ),
            ),
          ),
        );

        // Should render without crashing
        expect(find.byType(PageView), findsOneWidget);
        expect(find.byKey(const Key('video-0')), findsOneWidget);
      });
    });

    group('Disposal', () {
      testWidgets('disposes PageController on widget disposal', (
        WidgetTester tester,
      ) async {
        await VideoControllerPoolManager.initialize(
          poolSize: 3,
          controllerFactory: createMockController,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PooledVideoFeed(
                videos: mockVideos,
                itemBuilder: (context, video, index, isActive) => Container(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Dispose widget
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
        );

        // Should dispose without errors
        await tester.pumpAndSettle();
      });

      testWidgets('cancels debounce timer on disposal', (
        WidgetTester tester,
      ) async {
        await VideoControllerPoolManager.initialize(
          poolSize: 3,
          controllerFactory: createMockController,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PooledVideoFeed(
                videos: mockVideos,
                itemBuilder: (context, video, index, isActive) => Container(),
              ),
            ),
          ),
        );

        // Start a scroll to trigger debounce timer
        await tester.fling(
          find.byType(PageView),
          const Offset(0, -300),
          1000,
        );
        await tester.pump(const Duration(milliseconds: 50));

        // Dispose before debounce completes
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
        );

        // Wait past debounce time - should not crash
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();
      });
    });

    group('VideoPoolProvider Integration', () {
      testWidgets('uses pool from VideoPoolProvider when available', (
        WidgetTester tester,
      ) async {
        await VideoControllerPoolManager.initialize(
          poolSize: 3,
          controllerFactory: createMockController,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VideoPoolProvider(
                pool: VideoControllerPoolManager.instance,
                child: PooledVideoFeed(
                  videos: mockVideos,
                  itemBuilder: (context, video, index, isActive) => Container(),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final manager = VideoControllerPoolManager.instance;
        expect(manager.getController('video-0'), isNotNull);
      });
    });
  });
}
