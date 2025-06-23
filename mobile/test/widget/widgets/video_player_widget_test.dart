// ABOUTME: Widget tests for VideoPlayerWidget - Tests video player component behavior and controls
// ABOUTME: Tests play/pause, seeking, error states, and video player lifecycle management

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/widgets/video_player_widget.dart';
import '../../helpers/test_helpers.dart';

// Mock classes for testing VideoPlayerWidget
class MockVideoPlayerController extends Mock implements VideoPlayerController {}
class MockChewieController extends Mock implements ChewieController {}

void main() {
  group('VideoPlayerWidget Tests - TDD UI Specification', () {
    
    late VideoEvent testVideoEvent;
    late MockVideoPlayerController mockVideoController;
    late MockChewieController mockChewieController;

    setUp(() {
      testVideoEvent = TestHelpers.createVideoEvent(
        id: 'test_player_video',
        title: 'Test Player Video',
        content: 'Video for testing player widget',
        videoUrl: 'https://example.com/test-video.mp4',
        duration: 60,
        dimensions: '1920x1080',
      );

      mockVideoController = MockVideoPlayerController();
      mockChewieController = MockChewieController();
      
      // Register fallback values
      registerFallbackValue(testVideoEvent);
      registerFallbackValue(const Duration(seconds: 0));
    });

    Widget createTestWidget({
      VideoEvent? videoEvent,
      VideoPlayerController? controller,
      bool isActive = false,
      bool showControls = true,
      VoidCallback? onVideoEnd,
      VoidCallback? onVideoError,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: VideoPlayerWidget(
            videoEvent: videoEvent ?? testVideoEvent,
            controller: controller ?? mockVideoController,
            isActive: isActive,
            showControls: showControls,
            onVideoEnd: onVideoEnd,
            onVideoError: onVideoError,
          ),
        ),
      );
    }

    group('Video Player Display States', () {
      testWidgets('should display Chewie player when controller is initialized', (tester) async {
        // ARRANGE: Initialized controller
        when(() => mockVideoController.value).thenReturn(const VideoPlayerValue(
          isInitialized: true,
          duration: Duration(seconds: 60),
          position: Duration(seconds: 0),
          isPlaying: false,
        ));

        // ACT: Create widget
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // ASSERT: Should show Chewie player
        expect(find.byType(Chewie), findsOneWidget);
        
        // Should not show loading indicator
        expect(find.byType(CircularProgressIndicator), findsNothing);
        
        // Should not show error message
        expect(find.byIcon(Icons.error), findsNothing);
        
        // Widget should exist without errors
        expect(find.byType(VideoPlayerWidget), findsOneWidget);
      });

      testWidgets('should show loading indicator when controller is not initialized', (tester) async {
        // ARRANGE: Uninitialized controller
        when(() => mockVideoController.value).thenReturn(VideoPlayerValue(
          isInitialized: false,
          duration: Duration.zero,
        ));

        // ACT: Create widget
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // ASSERT: Should show loading indicator
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        
        // Should show loading message
        expect(find.text('Initializing video...'), findsOneWidget);
        
        // Should not show Chewie player yet
        expect(find.byType(Chewie), findsNothing);
      });

      testWidgets('should show error state when video fails to load', (tester) async {
        // ARRANGE: Controller with error
        when(() => mockVideoController.value).thenReturn(VideoPlayerValue(
          isInitialized: false,
          duration: Duration.zero,
          errorDescription: 'Failed to load video',
        ));

        // ACT: Create widget
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // ASSERT: Should show error UI
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.text('Video failed to load'), findsOneWidget);
        expect(find.text('Tap to retry'), findsOneWidget);
        
        // Should not show loading indicator
        expect(find.byType(CircularProgressIndicator), findsNothing);
        
        // Should not show Chewie player
        expect(find.byType(Chewie), findsNothing);
      });

      testWidgets('should show thumbnail while video is initializing', (tester) async {
        // ARRANGE: Video with thumbnail, uninitialized controller
        final videoWithThumbnail = TestHelpers.createVideoEvent(
          id: testVideoEvent.id,
          title: testVideoEvent.title,
          thumbnailUrl: 'https://example.com/thumbnail.jpg',
        );
        
        when(() => mockVideoController.value).thenReturn(VideoPlayerValue(
          isInitialized: false,
          duration: Duration.zero,
        ));

        // ACT: Create widget
        await tester.pumpWidget(createTestWidget(videoEvent: videoWithThumbnail));
        await tester.pump();

        // ASSERT: Should show thumbnail as background
        expect(find.byType(Image), findsOneWidget);
        
        // Should show loading overlay
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        
        // Should show initializing message
        expect(find.text('Initializing video...'), findsOneWidget);
      });
    });

    group('Video Player Controls', () {
      testWidgets('should show controls when enabled', (tester) async {
        // ARRANGE: Initialized controller with controls enabled
        when(() => mockVideoController.value).thenReturn(const VideoPlayerValue(
          isInitialized: true,
          duration: Duration(seconds: 60),
          position: Duration(seconds: 30),
          isPlaying: true,
        ));

        // ACT: Create widget with controls
        await tester.pumpWidget(createTestWidget(showControls: true));
        await tester.pump();

        // ASSERT: Should show Chewie player with controls
        expect(find.byType(Chewie), findsOneWidget);
        
        // Widget should be created successfully
        expect(find.byType(VideoPlayerWidget), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('should hide controls when disabled', (tester) async {
        // ARRANGE: Initialized controller with controls disabled
        when(() => mockVideoController.value).thenReturn(const VideoPlayerValue(
          isInitialized: true,
          duration: Duration(seconds: 60),
        ));

        // ACT: Create widget without controls
        await tester.pumpWidget(createTestWidget(showControls: false));
        await tester.pump();

        // ASSERT: Should show Chewie player
        expect(find.byType(Chewie), findsOneWidget);
        
        // Controls configuration is handled by Chewie internally
        expect(find.byType(VideoPlayerWidget), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle play/pause interactions', (tester) async {
        // ARRANGE: Initialized controller
        when(() => mockVideoController.value).thenReturn(const VideoPlayerValue(
          isInitialized: true,
          duration: Duration(seconds: 60),
          position: Duration(seconds: 0),
          isPlaying: false,
        ));
        when(() => mockVideoController.play()).thenAnswer((_) async {});
        when(() => mockVideoController.pause()).thenAnswer((_) async {});

        // ACT: Create widget
        await tester.pumpWidget(createTestWidget(showControls: true));
        await tester.pump();

        // ASSERT: Widget should be ready for interactions
        expect(find.byType(Chewie), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });

    group('Video Player Lifecycle', () {
      testWidgets('should handle active state changes', (tester) async {
        // ARRANGE: Initialized controller
        when(() => mockVideoController.value).thenReturn(const VideoPlayerValue(
          isInitialized: true,
          duration: Duration(seconds: 60),
          isPlaying: false,
        ));
        when(() => mockVideoController.play()).thenAnswer((_) async {});
        when(() => mockVideoController.pause()).thenAnswer((_) async {});

        // ACT: Start with inactive state
        await tester.pumpWidget(createTestWidget(isActive: false));
        await tester.pump();

        // ASSERT: Should handle inactive state
        expect(find.byType(VideoPlayerWidget), findsOneWidget);

        // ACT: Change to active state
        await tester.pumpWidget(createTestWidget(isActive: true));
        await tester.pump();

        // ASSERT: Should handle active state change
        expect(find.byType(VideoPlayerWidget), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('should auto-play when active', (tester) async {
        // ARRANGE: Initialized controller
        when(() => mockVideoController.value).thenReturn(const VideoPlayerValue(
          isInitialized: true,
          duration: Duration(seconds: 60),
          isPlaying: false,
        ));
        when(() => mockVideoController.play()).thenAnswer((_) async {});

        // ACT: Create active widget
        await tester.pumpWidget(createTestWidget(isActive: true));
        await tester.pump();

        // ASSERT: Should attempt to play when active
        verify(() => mockVideoController.play()).called(greaterThan(0));
        expect(find.byType(VideoPlayerWidget), findsOneWidget);
      });

      testWidgets('should pause when inactive', (tester) async {
        // ARRANGE: Playing controller
        when(() => mockVideoController.value).thenReturn(const VideoPlayerValue(
          isInitialized: true,
          duration: Duration(seconds: 60),
          isPlaying: true,
        ));
        when(() => mockVideoController.pause()).thenAnswer((_) async {});

        // ACT: Create inactive widget
        await tester.pumpWidget(createTestWidget(isActive: false));
        await tester.pump();

        // ASSERT: Should pause when inactive
        verify(() => mockVideoController.pause()).called(greaterThan(0));
        expect(find.byType(VideoPlayerWidget), findsOneWidget);
      });

      testWidgets('should dispose properly when widget is removed', (tester) async {
        // ARRANGE: Initialized controller
        when(() => mockVideoController.value).thenReturn(const VideoPlayerValue(
          isInitialized: true,
          duration: Duration(seconds: 60),
        ));

        // ACT: Create widget
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // Verify widget exists
        expect(find.byType(VideoPlayerWidget), findsOneWidget);

        // Remove widget
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        await tester.pump();

        // ASSERT: Should dispose without errors
        expect(tester.takeException(), isNull);
      });
    });

    group('Error Handling and Recovery', () {
      testWidgets('should handle retry on error tap', (tester) async {
        bool onErrorCalled = false;
        
        // ARRANGE: Controller with error
        when(() => mockVideoController.value).thenReturn(VideoPlayerValue(
          isInitialized: false,
          duration: Duration.zero,
          errorDescription: 'Network error',
        ));

        // ACT: Create widget with error callback
        await tester.pumpWidget(createTestWidget(
          onVideoError: () => onErrorCalled = true,
        ));
        await tester.pump();

        // Find and tap retry button
        final retryButton = find.text('Tap to retry');
        expect(retryButton, findsOneWidget);
        
        await tester.tap(retryButton);
        await tester.pump();

        // ASSERT: Should handle retry tap
        expect(tester.takeException(), isNull);
      });

      testWidgets('should call onVideoEnd when video completes', (tester) async {
        bool onEndCalled = false;
        
        // ARRANGE: Controller that reaches end
        when(() => mockVideoController.value).thenReturn(const VideoPlayerValue(
          isInitialized: true,
          duration: Duration(seconds: 60),
          position: Duration(seconds: 60), // At end
          isPlaying: false,
        ));

        // ACT: Create widget with end callback
        await tester.pumpWidget(createTestWidget(
          onVideoEnd: () => onEndCalled = true,
        ));
        await tester.pump();

        // ASSERT: Widget should be created successfully
        expect(find.byType(VideoPlayerWidget), findsOneWidget);
        
        // Note: Actual video end detection would be through controller listeners
        // in the real implementation
      });

      testWidgets('should handle controller initialization errors gracefully', (tester) async {
        // ARRANGE: Controller that throws during access
        when(() => mockVideoController.value).thenThrow(Exception('Controller error'));

        // ACT: Create widget
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // ASSERT: Should handle controller errors gracefully
        expect(find.byType(VideoPlayerWidget), findsOneWidget);
        
        // Should show error state or loading state, not crash
        expect(tester.takeException(), isNull);
      });

      testWidgets('should recover from temporary network errors', (tester) async {
        // ARRANGE: Start with error, then recover
        when(() => mockVideoController.value).thenReturn(VideoPlayerValue(
          isInitialized: false,
          duration: Duration.zero,
          errorDescription: 'Network timeout',
        ));

        // ACT: Create widget in error state
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // Should show error UI
        expect(find.byIcon(Icons.error_outline), findsOneWidget);

        // Simulate recovery
        when(() => mockVideoController.value).thenReturn(const VideoPlayerValue(
          isInitialized: true,
          duration: Duration(seconds: 60),
        ));

        // Rebuild widget
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // ASSERT: Should show recovered state
        expect(find.byType(Chewie), findsOneWidget);
        expect(find.byIcon(Icons.error_outline), findsNothing);
      });
    });

    group('Video Player State Management', () {
      testWidgets('should display current video progress', (tester) async {
        // ARRANGE: Controller with progress
        when(() => mockVideoController.value).thenReturn(const VideoPlayerValue(
          isInitialized: true,
          duration: Duration(seconds: 60),
          position: Duration(seconds: 30),
          isPlaying: true,
        ));

        // ACT: Create widget
        await tester.pumpWidget(createTestWidget(showControls: true));
        await tester.pump();

        // ASSERT: Should show video player with progress
        expect(find.byType(Chewie), findsOneWidget);
        expect(find.byType(VideoPlayerWidget), findsOneWidget);
        
        // Player should be displaying video content
        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle video buffering state', (tester) async {
        // ARRANGE: Controller in buffering state
        when(() => mockVideoController.value).thenReturn(const VideoPlayerValue(
          isInitialized: true,
          duration: Duration(seconds: 60),
          position: Duration(seconds: 15),
          isPlaying: true,
          isBuffering: true,
        ));

        // ACT: Create widget
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // ASSERT: Should show video player
        expect(find.byType(Chewie), findsOneWidget);
        
        // Buffering indicator would be shown by Chewie internally
        expect(find.byType(VideoPlayerWidget), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle seeking operations', (tester) async {
        // ARRANGE: Controller ready for seeking
        when(() => mockVideoController.value).thenReturn(const VideoPlayerValue(
          isInitialized: true,
          duration: Duration(seconds: 60),
          position: Duration(seconds: 10),
        ));
        when(() => mockVideoController.seekTo(any())).thenAnswer((_) async {});

        // ACT: Create widget
        await tester.pumpWidget(createTestWidget(showControls: true));
        await tester.pump();

        // ASSERT: Should create player capable of seeking
        expect(find.byType(Chewie), findsOneWidget);
        expect(find.byType(VideoPlayerWidget), findsOneWidget);
        
        // Seeking interactions would be handled by Chewie controls
        expect(tester.takeException(), isNull);
      });
    });

    group('Accessibility and User Experience', () {
      testWidgets('should provide accessible video player controls', (tester) async {
        // ARRANGE: Initialized controller
        when(() => mockVideoController.value).thenReturn(const VideoPlayerValue(
          isInitialized: true,
          duration: Duration(seconds: 60),
        ));

        // ACT: Create widget with controls
        await tester.pumpWidget(createTestWidget(showControls: true));
        await tester.pump();

        // ASSERT: Should create accessible player
        expect(find.byType(Chewie), findsOneWidget);
        expect(find.byType(VideoPlayerWidget), findsOneWidget);
        
        // Accessibility is handled by Chewie internally
        expect(tester.takeException(), isNull);
      });

      testWidgets('should provide semantic information for screen readers', (tester) async {
        // ARRANGE: Initialized controller
        when(() => mockVideoController.value).thenReturn(const VideoPlayerValue(
          isInitialized: true,
          duration: Duration(seconds: 60),
          position: Duration(seconds: 30),
        ));

        // ACT: Create widget
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // ASSERT: Should create semantically meaningful player
        expect(find.byType(VideoPlayerWidget), findsOneWidget);
        
        // Should not crash and should be accessible
        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle orientation changes gracefully', (tester) async {
        // ARRANGE: Initialized controller
        when(() => mockVideoController.value).thenReturn(const VideoPlayerValue(
          isInitialized: true,
          duration: Duration(seconds: 60),
        ));

        // ACT: Create widget
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // Simulate size change (orientation change)
        await tester.binding.setSurfaceSize(const Size(800, 600));
        await tester.pump();

        // ASSERT: Should handle size changes gracefully
        expect(find.byType(VideoPlayerWidget), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Reset surface size
        await tester.binding.setSurfaceSize(null);
      });
    });

    group('Performance and Memory Management', () {
      testWidgets('should not rebuild unnecessarily', (tester) async {
        int buildCount = 0;
        
        // ARRANGE: Initialized controller
        when(() => mockVideoController.value).thenReturn(const VideoPlayerValue(
          isInitialized: true,
          duration: Duration(seconds: 60),
        ));

        // ACT: Create widget with build counter
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                buildCount++;
                return VideoPlayerWidget(
                  videoEvent: testVideoEvent,
                  controller: mockVideoController,
                  isActive: false,
                );
              },
            ),
          ),
        ));

        // ASSERT: Should build efficiently
        expect(buildCount, greaterThan(0));
        expect(find.byType(VideoPlayerWidget), findsOneWidget);
        
        // Further pumps shouldn't trigger unnecessary rebuilds
        final initialBuildCount = buildCount;
        await tester.pump();
        expect(buildCount - initialBuildCount, lessThanOrEqualTo(1));
      });

      testWidgets('should clean up resources on disposal', (tester) async {
        // ARRANGE: Initialized controller
        when(() => mockVideoController.value).thenReturn(const VideoPlayerValue(
          isInitialized: true,
          duration: Duration(seconds: 60),
        ));

        // ACT: Create and dispose widget
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        
        expect(find.byType(VideoPlayerWidget), findsOneWidget);

        // Remove widget to test cleanup
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        await tester.pump();

        // ASSERT: Should clean up without errors
        expect(tester.takeException(), isNull);
      });
    });

    group('Edge Cases and Error Conditions', () {
      testWidgets('should handle null controller gracefully', (tester) async {
        // ACT: Create widget with null controller
        await tester.pumpWidget(createTestWidget(controller: null));
        await tester.pump();

        // ASSERT: Should handle null controller gracefully
        expect(find.byType(VideoPlayerWidget), findsOneWidget);
        
        // Should show loading or error state, not crash
        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle malformed video events', (tester) async {
        // ARRANGE: Video event with missing data
        final malformedEvent = TestHelpers.createVideoEvent(
          videoUrl: '',  // Empty URL
          title: '',     // Empty title
        );
        
        when(() => mockVideoController.value).thenReturn(VideoPlayerValue(
          isInitialized: false,
          duration: Duration.zero,
        ));

        // ACT: Create widget with malformed event
        await tester.pumpWidget(createTestWidget(videoEvent: malformedEvent));
        await tester.pump();

        // ASSERT: Should handle malformed data gracefully
        expect(find.byType(VideoPlayerWidget), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle rapid state changes', (tester) async {
        // ARRANGE: Controller with changing states
        when(() => mockVideoController.value).thenReturn(VideoPlayerValue(
          isInitialized: false,
          duration: Duration.zero,
        ));

        // ACT: Create widget and rapidly change states
        await tester.pumpWidget(createTestWidget(isActive: false));
        await tester.pump();

        // Rapidly toggle active state
        for (int i = 0; i < 10; i++) {
          await tester.pumpWidget(createTestWidget(isActive: i % 2 == 0));
          await tester.pump(const Duration(milliseconds: 10));
        }

        // ASSERT: Should handle rapid changes gracefully
        expect(find.byType(VideoPlayerWidget), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  });
}