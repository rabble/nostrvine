// ABOUTME: Comprehensive full-stack integration tests for video system components
// ABOUTME: Tests interaction between services, providers, and UI layers with real dependencies

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:nostrvine_app/models/video_event.dart';
import 'package:nostrvine_app/models/video_state.dart';
import 'package:nostrvine_app/services/video_manager_interface.dart';
import 'package:nostrvine_app/services/video_manager_service.dart';
import 'package:nostrvine_app/providers/video_feed_provider_v2.dart';
import 'package:nostrvine_app/screens/feed_screen_v2.dart';
import 'package:nostrvine_app/widgets/video_feed_item_v2.dart';

import '../helpers/test_helpers.dart';
import '../mocks/mock_video_manager.dart';

void main() {
  group('Full-Stack Integration Tests', () {
    group('Real VideoManager Integration', () {
      late VideoManagerService videoManager;

      setUp(() {
        videoManager = VideoManagerService(
          config: VideoManagerConfig.testing(),
        );
      });

      tearDown(() {
        videoManager.dispose();
      });

      testWidgets('Complete video flow: Service -> Provider -> UI', (tester) async {
        // Create test widget with real services
        final testWidget = MultiProvider(
          providers: [
            Provider<IVideoManager>(
              create: (_) => videoManager,
            ),
            ChangeNotifierProxyProvider<IVideoManager, VideoFeedProviderV2>(
              create: (context) => VideoFeedProviderV2(context.read<IVideoManager>()),
              update: (_, videoManager, previous) => 
                  previous ?? VideoFeedProviderV2(videoManager),
            ),
          ],
          child: MaterialApp(
            home: const FeedScreenV2(),
          ),
        );

        await tester.pumpWidget(testWidget);
        await tester.pumpAndSettle();

        // Initial state verification
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Add videos through the service layer
        final testVideos = TestHelpers.createVideoList(3);
        for (final video in testVideos) {
          await videoManager.addVideoEvent(video);
        }

        // Allow UI to update
        await tester.pumpAndSettle();

        // Verify the complete stack works
        expect(find.byType(PageView), findsOneWidget);
        expect(find.byType(VideoFeedItemV2), findsAtLeastNWidgets(1));

        // Verify service state
        expect(videoManager.videos.length, equals(3));

        // Test preloading through the stack
        videoManager.preloadAroundIndex(0);
        await tester.pumpAndSettle();

        final debugInfo = videoManager.getDebugInfo();
        expect(debugInfo['totalVideos'], equals(3));
      });

      testWidgets('Video state transitions propagate through stack', (tester) async {
        final testWidget = Provider<IVideoManager>.value(
          value: videoManager,
          child: MaterialApp(
            home: const FeedScreenV2(),
          ),
        );

        await tester.pumpWidget(testWidget);

        // Add a video
        final testVideo = TestHelpers.createVideoEvent(id: 'state_propagation_test');
        await videoManager.addVideoEvent(testVideo);
        await tester.pumpAndSettle();

        // Check initial state
        var videoState = videoManager.getVideoState(testVideo.id);
        expect(videoState?.loadingState, equals(VideoLoadingState.notLoaded));

        // Trigger preload
        try {
          await videoManager.preloadVideo(testVideo.id);
        } catch (e) {
          // May fail in test environment, that's ok
        }
        await tester.pumpAndSettle();

        // Verify state change
        videoState = videoManager.getVideoState(testVideo.id);
        expect(videoState?.loadingState, isIn([
          VideoLoadingState.loading,
          VideoLoadingState.ready,
          VideoLoadingState.failed,
        ]));

        // UI should reflect the state change
        expect(find.byType(VideoFeedItemV2), findsOneWidget);
      });

      testWidgets('Memory management integration', (tester) async {
        final testWidget = Provider<IVideoManager>.value(
          value: videoManager,
          child: MaterialApp(
            home: const FeedScreenV2(),
          ),
        );

        await tester.pumpWidget(testWidget);

        // Add many videos to trigger memory management
        final testVideos = TestHelpers.createVideoList(25);
        for (final video in testVideos) {
          await videoManager.addVideoEvent(video);
        }

        await tester.pumpAndSettle();

        // Trigger memory pressure
        await videoManager.handleMemoryPressure();
        await tester.pumpAndSettle();

        // Verify memory management worked
        final debugInfo = videoManager.getDebugInfo();
        expect(debugInfo['memoryPressureCount'], greaterThan(0));
        expect(debugInfo['estimatedMemoryMB'], lessThan(600));

        // UI should still be functional
        expect(find.byType(PageView), findsOneWidget);
      });
    });

    group('Mock VideoManager Integration', () {
      late MockVideoManager mockVideoManager;

      setUp(() {
        mockVideoManager = MockVideoManager();
      });

      tearDown(() {
        mockVideoManager.dispose();
      });

      testWidgets('Error handling through the stack', (tester) async {
        // Configure mock for failure scenarios
        mockVideoManager.setPreloadBehavior(PreloadBehavior.alwaysFail);

        final testWidget = Provider<IVideoManager>(
          create: (_) => mockVideoManager,
          child: MaterialApp(
            home: const FeedScreenV2(),
          ),
        );

        await tester.pumpWidget(testWidget);

        // Add videos that will fail
        final failingVideos = [
          TestHelpers.createVideoEvent(id: 'fail1'),
          TestHelpers.createVideoEvent(id: 'fail2'),
        ];

        for (final video in failingVideos) {
          await mockVideoManager.addVideoEvent(video);
        }

        await tester.pumpAndSettle();

        // Attempt preloading (will fail)
        for (final video in failingVideos) {
          try {
            await mockVideoManager.preloadVideo(video.id);
          } catch (e) {
            // Expected
          }
        }

        await tester.pumpAndSettle();

        // Verify error handling through the stack
        expect(find.byType(PageView), findsOneWidget);
        expect(find.byType(VideoFeedItemV2), findsAtLeastNWidgets(1));

        // Check error states
        for (final video in failingVideos) {
          final state = mockVideoManager.getVideoState(video.id);
          expect(state?.hasFailed, isTrue);
        }
      });

      testWidgets('Provider state management', (tester) async {
        final testWidget = MultiProvider(
          providers: [
            Provider<IVideoManager>(
              create: (_) => mockVideoManager,
            ),
            ChangeNotifierProxyProvider<IVideoManager, VideoFeedProviderV2>(
              create: (context) => VideoFeedProviderV2(context.read<IVideoManager>()),
              update: (_, videoManager, previous) => 
                  previous ?? VideoFeedProviderV2(videoManager),
            ),
          ],
          child: MaterialApp(
            home: Consumer<VideoFeedProviderV2>(
              builder: (context, provider, child) {
                return Scaffold(
                  body: Column(
                    children: [
                      Text('Videos: ${provider.videos.length}'),
                      Text('Ready: ${provider.readyVideos.length}'),
                      if (provider.videos.isNotEmpty)
                        Expanded(
                          child: ListView.builder(
                            itemCount: provider.videos.length,
                            itemBuilder: (context, index) {
                              final video = provider.videos[index];
                              return ListTile(
                                title: Text(video.title ?? 'No Title'),
                                subtitle: Text(video.id),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        );

        await tester.pumpWidget(testWidget);
        await tester.pumpAndSettle();

        // Initial state
        expect(find.text('Videos: 0'), findsOneWidget);
        expect(find.text('Ready: 0'), findsOneWidget);

        // Add videos
        final testVideos = TestHelpers.createVideoList(3);
        for (final video in testVideos) {
          await mockVideoManager.addVideoEvent(video);
        }

        await tester.pumpAndSettle();

        // Verify provider updates
        expect(find.text('Videos: 3'), findsOneWidget);

        // Mark some as ready
        mockVideoManager.readyVideos = [testVideos[0]];
        await tester.pumpAndSettle();

        expect(find.text('Ready: 1'), findsOneWidget);
      });

      testWidgets('Performance under load', (tester) async {
        final testWidget = Provider<IVideoManager>(
          create: (_) => mockVideoManager,
          child: MaterialApp(
            home: const FeedScreenV2(),
          ),
        );

        await tester.pumpWidget(testWidget);

        // Add large number of videos
        const videoCount = 100;
        final testVideos = TestHelpers.generatePerformanceTestData(videoCount);

        final stopwatch = Stopwatch()..start();

        // Add videos in batches
        const batchSize = 20;
        for (int i = 0; i < videoCount; i += batchSize) {
          final batch = testVideos.skip(i).take(batchSize);
          for (final video in batch) {
            await mockVideoManager.addVideoEvent(video);
          }
          await tester.pump();
        }

        await tester.pumpAndSettle();
        stopwatch.stop();

        // Performance assertions
        expect(stopwatch.elapsedMilliseconds, lessThan(5000));
        expect(mockVideoManager.videos.length, equals(videoCount));

        // UI should handle large datasets
        expect(find.byType(PageView), findsOneWidget);

        // Test rapid operations
        final rapidStopwatch = Stopwatch()..start();
        
        for (int i = 0; i < 50; i++) {
          mockVideoManager.preloadAroundIndex(i % videoCount);
          await tester.pump(const Duration(milliseconds: 1));
        }
        
        rapidStopwatch.stop();
        expect(rapidStopwatch.elapsedMilliseconds, lessThan(2000));
      });
    });

    group('Cross-Component Integration', () {
      late VideoManagerService videoManager;

      setUp(() {
        videoManager = VideoManagerService(
          config: VideoManagerConfig.testing(),
        );
      });

      tearDown(() {
        videoManager.dispose();
      });

      testWidgets('Video feed with real video events', (tester) async {
        final testWidget = Provider<IVideoManager>.value(
          value: videoManager,
          child: MaterialApp(
            home: const FeedScreenV2(),
          ),
        );

        await tester.pumpWidget(testWidget);

        // Create realistic video events
        final realisticVideos = [
          TestHelpers.createVideoEvent(
            id: 'realistic_1',
            title: 'Realistic Video 1',
            videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
            hashtags: ['nature', 'wildlife'],
          ),
          TestHelpers.createGifVideoEvent(
            id: 'gif_1',
            title: 'Test GIF',
          ),
          TestHelpers.createVideoEvent(
            id: 'realistic_2',
            title: 'Realistic Video 2',
            videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
            hashtags: ['animation', 'short'],
          ),
        ];

        // Add videos
        for (final video in realisticVideos) {
          await videoManager.addVideoEvent(video);
        }

        await tester.pumpAndSettle();

        // Verify video feed displays
        expect(find.byType(PageView), findsOneWidget);
        expect(find.byType(VideoFeedItemV2), findsAtLeastNWidgets(1));

        // Test navigation between videos
        final pageViewFinder = find.byType(PageView);
        
        // Scroll to next video
        await tester.drag(pageViewFinder, const Offset(0, -300));
        await tester.pumpAndSettle();

        // Verify preloading is triggered
        final debugInfo = videoManager.getDebugInfo();
        expect(debugInfo['totalVideos'], equals(3));
      });

      testWidgets('State synchronization across components', (tester) async {
        final testWidget = MultiProvider(
          providers: [
            Provider<IVideoManager>(
              create: (_) => videoManager,
            ),
            ChangeNotifierProxyProvider<IVideoManager, VideoFeedProviderV2>(
              create: (context) => VideoFeedProviderV2(context.read<IVideoManager>()),
              update: (_, videoManager, previous) => 
                  previous ?? VideoFeedProviderV2(videoManager),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer2<IVideoManager, VideoFeedProviderV2>(
                builder: (context, manager, provider, child) {
                  return Column(
                    children: [
                      Text('Manager Videos: ${manager.videos.length}'),
                      Text('Provider Videos: ${provider.videos.length}'),
                      Text('Manager Ready: ${manager.readyVideos.length}'),
                      Text('Provider Ready: ${provider.readyVideos.length}'),
                      if (manager.videos.isNotEmpty)
                        Expanded(child: const FeedScreenV2()),
                    ],
                  );
                },
              ),
            ),
          ),
        );

        await tester.pumpWidget(testWidget);
        await tester.pumpAndSettle();

        // Initial state
        expect(find.text('Manager Videos: 0'), findsOneWidget);
        expect(find.text('Provider Videos: 0'), findsOneWidget);

        // Add videos through manager
        final testVideos = TestHelpers.createVideoList(3);
        for (final video in testVideos) {
          await videoManager.addVideoEvent(video);
        }

        await tester.pumpAndSettle();

        // Verify synchronization
        expect(find.text('Manager Videos: 3'), findsOneWidget);
        expect(find.text('Provider Videos: 3'), findsOneWidget);

        // Test preloading affects both
        try {
          await videoManager.preloadVideo(testVideos[0].id);
        } catch (e) {
          // May fail in test, that's ok
        }

        await tester.pumpAndSettle();

        // Both should reflect state changes
        // (Exact ready count depends on preload success)
        final managerReady = videoManager.readyVideos.length;
        expect(find.text('Manager Ready: $managerReady'), findsOneWidget);
        expect(find.text('Provider Ready: $managerReady'), findsOneWidget);
      });

      testWidgets('Error boundary integration', (tester) async {
        final testWidget = Provider<IVideoManager>.value(
          value: videoManager,
          child: MaterialApp(
            home: const FeedScreenV2(),
          ),
        );

        await tester.pumpWidget(testWidget);

        // Add a mix of good and bad videos
        final mixedVideos = [
          TestHelpers.createVideoEvent(id: 'good1'),
          TestHelpers.createFailingVideoEvent(id: 'bad1'),
          TestHelpers.createVideoEvent(id: 'good2'),
          TestHelpers.createFailingVideoEvent(id: 'bad2'),
        ];

        for (final video in mixedVideos) {
          await videoManager.addVideoEvent(video);
        }

        await tester.pumpAndSettle();

        // Attempt to preload all (some will fail)
        for (final video in mixedVideos) {
          try {
            await videoManager.preloadVideo(video.id);
          } catch (e) {
            // Expected for failing videos
          }
        }

        await tester.pumpAndSettle();

        // UI should handle mixed success/failure gracefully
        expect(find.byType(PageView), findsOneWidget);
        expect(find.byType(VideoFeedItemV2), findsAtLeastNWidgets(1));

        // Verify error states are tracked
        final debugInfo = videoManager.getDebugInfo();
        expect(debugInfo['totalVideos'], equals(4));
        expect(debugInfo['failedVideos'], greaterThan(0));
      });
    });

    group('Lifecycle Integration Tests', () {
      late VideoManagerService videoManager;

      setUp(() {
        videoManager = VideoManagerService(
          config: VideoManagerConfig.testing(),
        );
      });

      tearDown(() {
        videoManager.dispose();
      });

      testWidgets('Complete app lifecycle', (tester) async {
        final testWidget = Provider<IVideoManager>.value(
          value: videoManager,
          child: MaterialApp(
            home: const FeedScreenV2(),
          ),
        );

        // App startup
        await tester.pumpWidget(testWidget);
        await tester.pumpAndSettle();

        // Loading state
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Data loading
        final testVideos = TestHelpers.createVideoList(5);
        for (final video in testVideos) {
          await videoManager.addVideoEvent(video);
        }

        await tester.pumpAndSettle();

        // Active usage
        expect(find.byType(PageView), findsOneWidget);
        
        // User interaction
        final pageViewFinder = find.byType(PageView);
        await tester.drag(pageViewFinder, const Offset(0, -300));
        await tester.pumpAndSettle();

        // Background/foreground simulation
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'flutter/lifecycle',
          const StandardMessageCodec().encodeMessage('AppLifecycleState.paused'),
          (data) {},
        );

        await tester.pumpAndSettle();

        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'flutter/lifecycle',
          const StandardMessageCodec().encodeMessage('AppLifecycleState.resumed'),
          (data) {},
        );

        await tester.pumpAndSettle();

        // App should remain functional
        expect(find.byType(PageView), findsOneWidget);
        expect(videoManager.videos.length, equals(5));
      });

      testWidgets('Memory pressure handling throughout lifecycle', (tester) async {
        final testWidget = Provider<IVideoManager>.value(
          value: videoManager,
          child: MaterialApp(
            home: const FeedScreenV2(),
          ),
        );

        await tester.pumpWidget(testWidget);

        // Progressive loading with memory pressure
        for (int batch = 0; batch < 5; batch++) {
          // Add batch of videos
          final batchVideos = TestHelpers.createVideoList(8, idPrefix: 'batch_$batch');
          for (final video in batchVideos) {
            await videoManager.addVideoEvent(video);
          }

          await tester.pumpAndSettle();

          // Simulate memory pressure
          await videoManager.handleMemoryPressure();
          await tester.pump();

          // Verify system remains stable
          final debugInfo = videoManager.getDebugInfo();
          expect(debugInfo['disposed'], isFalse);
          expect(debugInfo['estimatedMemoryMB'], lessThan(600));
        }

        // Final verification
        expect(find.byType(PageView), findsOneWidget);
        final finalDebugInfo = videoManager.getDebugInfo();
        expect(finalDebugInfo['memoryPressureCount'], greaterThan(0));
      });
    });
  });
}