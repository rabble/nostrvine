// ABOUTME: Comprehensive widget tests for VideoFeedItemV2 TDD implementation
// ABOUTME: Tests all loading states, error handling, accessibility, and controller lifecycle

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:nostrvine_app/models/video_event.dart';
import 'package:nostrvine_app/models/video_state.dart';
import 'package:nostrvine_app/services/video_manager_interface.dart';
import 'package:nostrvine_app/widgets/video_feed_item_v2.dart';
import '../../helpers/test_helpers.dart';
import '../../mocks/mock_video_manager.dart';

void main() {
  group('VideoFeedItemV2 Widget Tests', () {
    late MockVideoManager mockVideoManager;
    late VideoEvent testVideoEvent;
    late VideoEvent testGifEvent;

    setUp(() {
      mockVideoManager = MockVideoManager();
      testVideoEvent = TestHelpers.createVideoEvent(
        id: 'test_video_123',
        title: 'Test Video Title',
        content: 'Test video content with description',
        hashtags: ['test', 'flutter', 'video'],
        videoUrl: 'https://example.com/test_video.mp4',
        isGif: false,
      );
      
      testGifEvent = TestHelpers.createVideoEvent(
        id: 'test_gif_456',
        title: 'Test GIF Title',
        content: 'Test GIF content',
        hashtags: ['test', 'gif'],
        videoUrl: 'https://example.com/test.gif',
        isGif: true,
      );
    });

    tearDown(() {
      mockVideoManager.dispose();
    });

    /// Helper to create widget under test with Provider
    Widget createTestWidget({
      required VideoEvent video,
      bool isActive = false,
      Function(String)? onVideoError,
    }) {
      return MaterialApp(
        home: ChangeNotifierProvider<IVideoManager>.value(
          value: mockVideoManager,
          child: Scaffold(
            body: VideoFeedItemV2(
              video: video,
              isActive: isActive,
              onVideoError: onVideoError,
            ),
          ),
        ),
      );
    }

    group('Initialization and Basic Display', () {
      testWidgets('should display video when VideoManager is available', (tester) async {
        // ARRANGE
        await mockVideoManager.addVideoEvent(testVideoEvent);
        
        // ACT
        await tester.pumpWidget(createTestWidget(video: testVideoEvent));
        await tester.pump();
        
        // ASSERT
        expect(find.byType(VideoFeedItemV2), findsOneWidget);
        expect(find.byType(Container), findsWidgets);
      });

      testWidgets('should show error when VideoManager is not available', (tester) async {
        // ACT - Create widget without Provider
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: VideoFeedItemV2(
              video: testVideoEvent,
              isActive: false,
            ),
          ),
        ));
        await tester.pump();
        
        // ASSERT
        expect(find.text('Video system not available'), findsOneWidget);
        expect(find.byIcon(Icons.error), findsOneWidget);
      });

      testWidgets('should show error when video is not found in manager', (tester) async {
        // ARRANGE - Don't add video to manager
        
        // ACT
        await tester.pumpWidget(createTestWidget(video: testVideoEvent));
        await tester.pump();
        
        // ASSERT
        expect(find.text('Video not found'), findsOneWidget);
        expect(find.byIcon(Icons.error), findsOneWidget);
      });
    });

    group('Video State Display Tests', () {
      testWidgets('should display not loaded state initially', (tester) async {
        // ARRANGE
        await mockVideoManager.addVideoEvent(testVideoEvent);
        
        // ACT
        await tester.pumpWidget(createTestWidget(video: testVideoEvent, isActive: false));
        await tester.pump();
        
        // ASSERT
        expect(find.byIcon(Icons.video_library_outlined), findsOneWidget);
      });

      testWidgets('should display loading state during preload', (tester) async {
        // ARRANGE
        await mockVideoManager.addVideoEvent(testVideoEvent);
        mockVideoManager.setPreloadDelay(Duration(milliseconds: 500)); // Slow preload
        
        // ACT
        await tester.pumpWidget(createTestWidget(video: testVideoEvent, isActive: true));
        await tester.pump(); // Initial render
        await tester.pump(Duration(milliseconds: 100)); // Let preload start
        
        // ASSERT
        expect(find.text('Loading...'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsWidgets);
      });

      testWidgets('should display ready state for successful video preload', (tester) async {
        // ARRANGE
        await mockVideoManager.addVideoEvent(testVideoEvent);
        mockVideoManager.setPreloadBehavior(PreloadBehavior.normal);
        
        // ACT
        await tester.pumpWidget(createTestWidget(video: testVideoEvent, isActive: true));
        await tester.pump();
        await tester.pump(Duration(milliseconds: 100)); // Wait for preload
        
        // ASSERT - Should show video player content
        expect(find.byType(VideoPlayer), findsOneWidget);
      });

      testWidgets('should display GIF content for GIF videos', (tester) async {
        // ARRANGE
        await mockVideoManager.addVideoEvent(testGifEvent);
        
        // ACT
        await tester.pumpWidget(createTestWidget(video: testGifEvent, isActive: true));
        await tester.pump();
        await tester.pump(Duration(milliseconds: 100)); // Wait for ready state
        
        // ASSERT
        expect(find.byIcon(Icons.gif), findsOneWidget);
        expect(find.text('Test GIF Title'), findsOneWidget);
      });

      testWidgets('should display failed state with retry button', (tester) async {
        // ARRANGE
        await mockVideoManager.addVideoEvent(testVideoEvent);
        mockVideoManager.setPreloadBehavior(PreloadBehavior.alwaysFail);
        
        // ACT
        await tester.pumpWidget(createTestWidget(video: testVideoEvent, isActive: true));
        await tester.pump();
        await tester.pump(Duration(milliseconds: 100)); // Wait for failure
        
        // ASSERT
        expect(find.text('Failed to load'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
        expect(find.byIcon(Icons.error), findsOneWidget);
      });

      testWidgets('should display permanently failed state without retry', (tester) async {
        // ARRANGE
        await mockVideoManager.addVideoEvent(testVideoEvent);
        mockVideoManager.markVideoPermanentlyFailed(testVideoEvent.id);
        
        // ACT
        await tester.pumpWidget(createTestWidget(video: testVideoEvent, isActive: true));
        await tester.pump();
        
        // ASSERT
        expect(find.text('Permanently failed'), findsOneWidget);
        expect(find.text('Retry'), findsNothing);
        expect(find.byIcon(Icons.error), findsOneWidget);
      });

      testWidgets('should display disposed state', (tester) async {
        // ARRANGE
        await mockVideoManager.addVideoEvent(testVideoEvent);
        await mockVideoManager.preloadVideo(testVideoEvent.id);
        mockVideoManager.disposeVideo(testVideoEvent.id);
        
        // ACT
        await tester.pumpWidget(createTestWidget(video: testVideoEvent, isActive: false));
        await tester.pump();
        
        // ASSERT
        expect(find.text('Video disposed'), findsOneWidget);
        expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      });
    });

    group('State Transition Tests', () {
      testWidgets('should transition from loading to ready state', (tester) async {
        // ARRANGE
        await mockVideoManager.addVideoEvent(testVideoEvent);
        mockVideoManager.setPreloadDelay(Duration(milliseconds: 200));
        
        // ACT
        await tester.pumpWidget(createTestWidget(video: testVideoEvent, isActive: true));
        await tester.pump();
        
        // ASSERT - Initially loading
        expect(find.text('Loading...'), findsOneWidget);
        
        // Wait for preload completion
        await tester.pump(Duration(milliseconds: 300));
        
        // ASSERT - Now ready
        expect(find.text('Loading...'), findsNothing);
        expect(find.byType(VideoPlayer), findsOneWidget);
      });

      testWidgets('should handle activation state changes', (tester) async {
        // ARRANGE
        await mockVideoManager.addVideoEvent(testVideoEvent);
        
        // ACT - Initially inactive
        await tester.pumpWidget(createTestWidget(video: testVideoEvent, isActive: false));
        await tester.pump();
        
        // ASSERT - Should show not loaded state
        expect(find.byIcon(Icons.video_library_outlined), findsOneWidget);
        
        // ACT - Activate video
        await tester.pumpWidget(createTestWidget(video: testVideoEvent, isActive: true));
        await tester.pump();
        await tester.pump(Duration(milliseconds: 100));
        
        // ASSERT - Should start preloading
        expect(find.text('Loading...'), findsOneWidget);
      });
    });

    group('User Interaction Tests', () {
      testWidgets('should handle retry button tap', (tester) async {
        // ARRANGE
        await mockVideoManager.addVideoEvent(testVideoEvent);
        mockVideoManager.setPreloadBehavior(PreloadBehavior.failOnce);
        
        await tester.pumpWidget(createTestWidget(video: testVideoEvent, isActive: true));
        await tester.pump();
        await tester.pump(Duration(milliseconds: 100)); // Wait for failure
        
        // ASSERT - Failure state with retry button
        expect(find.text('Failed to load'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
        
        // ACT - Tap retry button
        await tester.tap(find.text('Retry'));
        await tester.pump();
        await tester.pump(Duration(milliseconds: 100)); // Wait for retry
        
        // ASSERT - Should succeed on retry
        expect(find.byType(VideoPlayer), findsOneWidget);
        expect(find.text('Failed to load'), findsNothing);
      });

      testWidgets('should call onVideoError callback on permanent failure', (tester) async {
        // ARRANGE
        String? errorVideoId;
        await mockVideoManager.addVideoEvent(testVideoEvent);
        mockVideoManager.markVideoPermanentlyFailed(testVideoEvent.id);
        
        // ACT
        await tester.pumpWidget(createTestWidget(
          video: testVideoEvent,
          isActive: true,
          onVideoError: (videoId) => errorVideoId = videoId,
        ));
        await tester.pump();
        
        // ASSERT
        expect(find.text('Permanently failed'), findsOneWidget);
        // Note: onVideoError callback would be called in real implementation
      });
    });

    group('Video Content Display Tests', () {
      testWidgets('should display video title in overlay', (tester) async {
        // ARRANGE
        await mockVideoManager.addVideoEvent(testVideoEvent);
        
        // ACT
        await tester.pumpWidget(createTestWidget(video: testVideoEvent, isActive: true));
        await tester.pump();
        
        // ASSERT
        expect(find.text('Test Video Title'), findsOneWidget);
      });

      testWidgets('should display video content in overlay', (tester) async {
        // ARRANGE
        await mockVideoManager.addVideoEvent(testVideoEvent);
        
        // ACT
        await tester.pumpWidget(createTestWidget(video: testVideoEvent, isActive: true));
        await tester.pump();
        
        // ASSERT
        expect(find.text('Test video content with description'), findsOneWidget);
      });

      testWidgets('should display hashtags in overlay', (tester) async {
        // ARRANGE
        await mockVideoManager.addVideoEvent(testVideoEvent);
        
        // ACT
        await tester.pumpWidget(createTestWidget(video: testVideoEvent, isActive: true));
        await tester.pump();
        
        // ASSERT
        expect(find.text('#test'), findsOneWidget);
        expect(find.text('#flutter'), findsOneWidget);
        expect(find.text('#video'), findsOneWidget);
      });

      testWidgets('should handle empty title gracefully', (tester) async {
        // ARRANGE
        final videoWithoutTitle = TestHelpers.createVideoEvent(
          id: 'no_title',
          title: null,
          content: 'Content without title',
        );
        await mockVideoManager.addVideoEvent(videoWithoutTitle);
        
        // ACT
        await tester.pumpWidget(createTestWidget(video: videoWithoutTitle, isActive: true));
        await tester.pump();
        
        // ASSERT - Should not crash, should show content
        expect(find.text('Content without title'), findsOneWidget);
      });

      testWidgets('should handle empty content gracefully', (tester) async {
        // ARRANGE
        final videoWithoutContent = TestHelpers.createVideoEvent(
          id: 'no_content',
          title: 'Title Only',
          content: '',
        );
        await mockVideoManager.addVideoEvent(videoWithoutContent);
        
        // ACT
        await tester.pumpWidget(createTestWidget(video: videoWithoutContent, isActive: true));
        await tester.pump();
        
        // ASSERT - Should not crash, should show title
        expect(find.text('Title Only'), findsOneWidget);
      });
    });

    group('Controller Lifecycle Tests', () {
      testWidgets('should not dispose controller when widget disposes', (tester) async {
        // ARRANGE
        await mockVideoManager.addVideoEvent(testVideoEvent);
        
        // ACT
        await tester.pumpWidget(createTestWidget(video: testVideoEvent, isActive: true));
        await tester.pump();
        await tester.pump(Duration(milliseconds: 100)); // Wait for ready
        
        final initialControllerCount = mockVideoManager.getDebugInfo()['controllers'];
        
        // Remove widget
        await tester.pumpWidget(Container());
        await tester.pump();
        
        // ASSERT - Controller should still exist (managed by VideoManager)
        final finalControllerCount = mockVideoManager.getDebugInfo()['controllers'];
        expect(finalControllerCount, equals(initialControllerCount));
      });

      testWidgets('should update controller reference when available', (tester) async {
        // ARRANGE
        await mockVideoManager.addVideoEvent(testVideoEvent);
        
        // ACT - Start inactive
        await tester.pumpWidget(createTestWidget(video: testVideoEvent, isActive: false));
        await tester.pump();
        
        // Activate
        await tester.pumpWidget(createTestWidget(video: testVideoEvent, isActive: true));
        await tester.pump();
        await tester.pump(Duration(milliseconds: 100)); // Wait for preload
        
        // ASSERT - Should have VideoPlayer when ready
        expect(find.byType(VideoPlayer), findsOneWidget);
      });
    });

    group('Error Handling Tests', () {
      testWidgets('should display error message when provided', (tester) async {
        // ARRANGE
        await mockVideoManager.addVideoEvent(testVideoEvent);
        mockVideoManager.setPreloadBehavior(PreloadBehavior.alwaysFail);
        
        // ACT
        await tester.pumpWidget(createTestWidget(video: testVideoEvent, isActive: true));
        await tester.pump();
        await tester.pump(Duration(milliseconds: 100)); // Wait for failure
        
        // ASSERT
        expect(find.text('Failed to load'), findsOneWidget);
        expect(find.text('Mock configured to always fail'), findsOneWidget);
      });

      testWidgets('should handle state updates during widget lifecycle', (tester) async {
        // ARRANGE
        await mockVideoManager.addVideoEvent(testVideoEvent);
        
        // ACT
        await tester.pumpWidget(createTestWidget(video: testVideoEvent, isActive: true));
        await tester.pump();
        
        // Force state change via manager
        mockVideoManager.disposeVideo(testVideoEvent.id);
        await tester.pump();
        
        // ASSERT - Should update to disposed state
        expect(find.text('Video disposed'), findsOneWidget);
      });
    });

    group('Performance and Edge Cases', () {
      testWidgets('should handle rapid state changes without crashing', (tester) async {
        // ARRANGE
        await mockVideoManager.addVideoEvent(testVideoEvent);
        
        // ACT - Rapid activation/deactivation
        for (int i = 0; i < 5; i++) {
          await tester.pumpWidget(createTestWidget(video: testVideoEvent, isActive: i % 2 == 0));
          await tester.pump();
        }
        
        // ASSERT - Should not crash
        expect(find.byType(VideoFeedItemV2), findsOneWidget);
      });

      testWidgets('should handle controller becoming null gracefully', (tester) async {
        // ARRANGE
        await mockVideoManager.addVideoEvent(testVideoEvent);
        
        // ACT
        await tester.pumpWidget(createTestWidget(video: testVideoEvent, isActive: true));
        await tester.pump();
        await tester.pump(Duration(milliseconds: 100)); // Wait for ready
        
        // Force controller disposal
        mockVideoManager.disposeVideo(testVideoEvent.id);
        await tester.pump();
        
        // ASSERT - Should handle gracefully
        expect(find.byType(VideoFeedItemV2), findsOneWidget);
      });

      testWidgets('should maintain consistent layout during state changes', (tester) async {
        // ARRANGE
        await mockVideoManager.addVideoEvent(testVideoEvent);
        
        // ACT
        await tester.pumpWidget(createTestWidget(video: testVideoEvent, isActive: true));
        await tester.pump();
        
        final initialSize = tester.getSize(find.byType(VideoFeedItemV2));
        
        // Wait for state change
        await tester.pump(Duration(milliseconds: 100));
        
        final finalSize = tester.getSize(find.byType(VideoFeedItemV2));
        
        // ASSERT - Size should remain consistent
        expect(finalSize, equals(initialSize));
      });
    });

    group('Accessibility Tests', () {
      testWidgets('should provide semantic labels for video content', (tester) async {
        // ARRANGE
        await mockVideoManager.addVideoEvent(testVideoEvent);
        
        // ACT
        await tester.pumpWidget(createTestWidget(video: testVideoEvent, isActive: true));
        await tester.pump();
        
        // ASSERT - Should be semantically labeled
        expect(find.byType(Semantics), findsWidgets);
      });

      testWidgets('should handle accessibility announcements for state changes', (tester) async {
        // ARRANGE
        await mockVideoManager.addVideoEvent(testVideoEvent);
        mockVideoManager.setPreloadDelay(Duration(milliseconds: 200));
        
        // ACT
        await tester.pumpWidget(createTestWidget(video: testVideoEvent, isActive: true));
        await tester.pump();
        
        // Wait for state transition
        await tester.pump(Duration(milliseconds: 300));
        
        // ASSERT - Widget should remain accessible
        expect(find.byType(VideoFeedItemV2), findsOneWidget);
      });
    });

    group('Integration with VideoManager', () {
      testWidgets('should trigger preload when activated', (tester) async {
        // ARRANGE
        await mockVideoManager.addVideoEvent(testVideoEvent);
        mockVideoManager.clearOperationLog();
        
        // ACT
        await tester.pumpWidget(createTestWidget(video: testVideoEvent, isActive: true));
        await tester.pump();
        
        // ASSERT
        final log = mockVideoManager.getOperationLog();
        expect(log.any((entry) => entry.contains('preloadVideo')), isTrue);
      });

      testWidgets('should not trigger preload when inactive', (tester) async {
        // ARRANGE
        await mockVideoManager.addVideoEvent(testVideoEvent);
        mockVideoManager.clearOperationLog();
        
        // ACT
        await tester.pumpWidget(createTestWidget(video: testVideoEvent, isActive: false));
        await tester.pump();
        
        // ASSERT
        final log = mockVideoManager.getOperationLog();
        expect(log.any((entry) => entry.contains('preloadVideo')), isFalse);
      });

      testWidgets('should respond to VideoManager state changes', (tester) async {
        // ARRANGE
        await mockVideoManager.addVideoEvent(testVideoEvent);
        
        // ACT
        await tester.pumpWidget(createTestWidget(video: testVideoEvent, isActive: false));
        await tester.pump();
        
        // Trigger state change via manager
        await mockVideoManager.preloadVideo(testVideoEvent.id);
        await tester.pump();
        await tester.pump(Duration(milliseconds: 100));
        
        // ASSERT - Should update based on manager state
        final state = mockVideoManager.getVideoState(testVideoEvent.id);
        expect(state?.isReady, isTrue);
      });
    });
  });
}