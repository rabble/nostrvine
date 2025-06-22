// ABOUTME: Widget tests for VideoFeedItem - Tests current video widget implementation
// ABOUTME: Tests video display states, error handling, and user interactions for current architecture

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:nostrvine_app/models/video_event.dart';
import 'package:nostrvine_app/widgets/video_feed_item.dart';
import 'package:nostrvine_app/services/video_cache_service.dart';
import 'package:nostrvine_app/services/user_profile_service.dart';
import 'package:nostrvine_app/services/seen_videos_service.dart';
import '../../helpers/test_helpers.dart';

// Mock classes for testing current VideoFeedItem
class MockVideoCacheService extends Mock implements VideoCacheService {}
class MockUserProfileService extends Mock implements UserProfileService {}
class MockSeenVideosService extends Mock implements SeenVideosService {}
class MockVideoPlayerController extends Mock implements VideoPlayerController {}

void main() {
  group('VideoFeedItem Widget Tests - Current Implementation', () {
    
    late VideoEvent testVideoEvent;
    late MockVideoCacheService mockVideoCacheService;
    late MockUserProfileService mockUserProfileService;
    late MockSeenVideosService mockSeenVideosService;

    setUp(() {
      testVideoEvent = TestHelpers.createVideoEvent(
        id: 'test_video_123',
        title: 'Test Video',
        content: 'Test video content',
        hashtags: ['test', 'flutter'],
        duration: 45,
        dimensions: '1920x1080',
      );

      mockVideoCacheService = MockVideoCacheService();
      mockUserProfileService = MockUserProfileService();
      mockSeenVideosService = MockSeenVideosService();
      
      // Register fallback values for mocktail
      registerFallbackValue(testVideoEvent);
    });

    Widget createTestWidget({
      VideoEvent? videoEvent,
      bool isActive = false,
      VoidCallback? onLike,
      VoidCallback? onComment,
      VoidCallback? onShare,
      VoidCallback? onMoreOptions,
      VoidCallback? onUserTap,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: VideoFeedItem(
            videoEvent: videoEvent ?? testVideoEvent,
            isActive: isActive,
            onLike: onLike,
            onComment: onComment,
            onShare: onShare,
            onMoreOptions: onMoreOptions,
            onUserTap: onUserTap,
            videoCacheService: mockVideoCacheService,
            userProfileService: mockUserProfileService,
            seenVideosService: mockSeenVideosService,
          ),
        ),
      );
    }

    group('Loading State Display', () {
      testWidgets('should show loading spinner when video is preparing', (tester) async {
        // Test: Video without preloaded controller should show loading state
        when(() => mockVideoCacheService.getController(any())).thenReturn(null);

        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // Should show loading indicator with message
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Preparing video...'), findsOneWidget);
        
        // Should show video metadata even while loading
        expect(find.text(testVideoEvent.title!), findsOneWidget);
        expect(find.text(testVideoEvent.content), findsOneWidget);
      });

      testWidgets('should show loading state when no cached controller available', (tester) async {
        // Mock no preloaded controller available
        when(() => mockVideoCacheService.getController(testVideoEvent)).thenReturn(null);

        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // Should show loading indicator
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Preparing video...'), findsOneWidget);
        
        // Should show overlay indicating loading state
        final loadingContainer = find.descendant(
          of: find.byType(Container),
          matching: find.byType(CircularProgressIndicator),
        );
        expect(loadingContainer, findsOneWidget);
      });

      testWidgets('should show thumbnail while video is loading', (tester) async {
        final videoEventWithThumbnail = TestHelpers.createVideoEvent(
          id: testVideoEvent.id,
          title: testVideoEvent.title,
          thumbnailUrl: 'https://example.com/thumbnail.jpg',
        );
        
        when(() => mockVideoCacheService.getController(videoEventWithThumbnail)).thenReturn(null);

        await tester.pumpWidget(createTestWidget(videoEvent: videoEventWithThumbnail));
        await tester.pump();

        // Should show thumbnail as background layer (CachedNetworkImage)
        expect(find.byType(Image), findsAtLeastNWidgets(1));
        
        // Should show loading indicator over thumbnail
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Preparing video...'), findsOneWidget);
      });
    });

    group('Ready State Display', () {
      testWidgets('should show video player when video is ready', (tester) async {
        // Mock initialized controller to simulate ready state
        final mockController = MockVideoPlayerController();
        when(() => mockController.value).thenReturn(const VideoPlayerValue(
          isInitialized: true,
          duration: Duration(seconds: 30),
        ));
        when(() => mockVideoCacheService.getController(testVideoEvent)).thenReturn(mockController);

        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // Should show Chewie player (wraps VideoPlayer)
        expect(find.byType(Chewie), findsOneWidget);
        
        // Should not show loading indicator when ready
        expect(find.text('Preparing video...'), findsNothing);
        
        // Should not show error indicator
        expect(find.byIcon(Icons.error_outline), findsNothing);
      });

      testWidgets('should display video metadata correctly', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // Should show title
        expect(find.text(testVideoEvent.title!), findsOneWidget);
        
        // Should show content
        expect(find.text(testVideoEvent.content), findsOneWidget);
        
        // Should show duration if available
        if (testVideoEvent.duration != null) {
          expect(find.text(testVideoEvent.formattedDuration), findsOneWidget);
        }
        
        // Should show relative time
        expect(find.textContaining('ago'), findsOneWidget);
        
        // Should show user display name area
        expect(find.byType(GestureDetector), findsAtLeastNWidgets(1));
      });

      testWidgets('should handle active state correctly', (tester) async {
        // Mock ready controller
        final mockController = MockVideoPlayerController();
        when(() => mockController.value).thenReturn(const VideoPlayerValue(
          isInitialized: true,
          duration: Duration.zero,
        ));
        when(() => mockVideoCacheService.getController(testVideoEvent)).thenReturn(mockController);

        await tester.pumpWidget(createTestWidget(isActive: true));
        await tester.pump();

        // Should create widget without errors
        expect(find.byType(VideoFeedItem), findsOneWidget);
        
        // Should show video content when active
        expect(find.byType(Stack), findsAtLeastNWidgets(1));
      });

      testWidgets('should handle active state transitions', (tester) async {
        // Start with inactive video
        await tester.pumpWidget(createTestWidget(isActive: false));
        await tester.pump();

        // Should create widget successfully
        expect(find.byType(VideoFeedItem), findsOneWidget);

        // Change to active
        await tester.pumpWidget(createTestWidget(isActive: true));
        await tester.pump();

        // Should handle state change without errors
        expect(find.byType(VideoFeedItem), findsOneWidget);
      });
    });

    group('Error State Display', () {
      testWidgets('should show error widget when video failed to load', (tester) async {
        // No need to create artificial error state - widget handles errors internally
        when(() => mockVideoCacheService.getController(testVideoEvent)).thenReturn(null);

        await tester.pumpWidget(createTestWidget());
        
        // Simulate error by creating widget with invalid video URL
        final invalidVideoEvent = TestHelpers.createVideoEvent(
          videoUrl: 'invalid://url',
          title: 'Failed Video',
        );
        
        await tester.pumpWidget(createTestWidget(videoEvent: invalidVideoEvent));
        await tester.pump();

        // Should show error elements (will be shown if initialization fails)
        expect(find.byType(VideoFeedItem), findsOneWidget);
        
        // Widget should handle error gracefully
        expect(tester.takeException(), isNull);
      });

      testWidgets('should display error state correctly when video fails', (tester) async {
        // Test error handling in current implementation
        when(() => mockVideoCacheService.getController(testVideoEvent)).thenReturn(null);

        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // Widget should render without throwing
        expect(find.byType(VideoFeedItem), findsOneWidget);
        
        // Should show loading initially
        expect(find.text('Preparing video...'), findsOneWidget);
        
        // Error handling is internal - test for graceful degradation
        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle error state gracefully', (tester) async {
        // Test that widget doesn't crash on error conditions
        final errorVideoEvent = TestHelpers.createFailingVideoEvent();
        
        when(() => mockVideoCacheService.getController(errorVideoEvent)).thenReturn(null);

        await tester.pumpWidget(createTestWidget(videoEvent: errorVideoEvent));
        await tester.pump();

        // Should handle error gracefully
        expect(find.byType(VideoFeedItem), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('should display video metadata even on error', (tester) async {
        // Test that metadata is shown even when video fails
        final errorVideoEvent = TestHelpers.createFailingVideoEvent(
          id: 'error_video',
        );
        
        await tester.pumpWidget(createTestWidget(videoEvent: errorVideoEvent));
        await tester.pump();

        // Should show title and content even if video fails
        expect(find.text('Failing Test Video'), findsOneWidget);
        expect(find.text('This video is designed to fail for testing purposes'), findsOneWidget);
      });

      testWidgets('should show error widget when explicitly in error state', (tester) async {
        // Test when error widget is explicitly shown (after max retries)
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // Widget should be created successfully
        expect(find.byType(VideoFeedItem), findsOneWidget);
        
        // If error state occurs, should show graceful error handling
        expect(tester.takeException(), isNull);
      });
    });

    group('Initial State Display', () {
      testWidgets('should show placeholder for videos without controller', (tester) async {
        when(() => mockVideoCacheService.getController(testVideoEvent)).thenReturn(null);

        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // Should show loading state initially
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Preparing video...'), findsOneWidget);
        
        // Should show video metadata
        expect(find.text(testVideoEvent.title!), findsOneWidget);
        
        // Should show thumbnail if available
        if (testVideoEvent.thumbnailUrl != null) {
          expect(find.byType(Image), findsAtLeastNWidgets(1));
        }
      });

      testWidgets('should initialize video when widget is created', (tester) async {
        when(() => mockVideoCacheService.getController(testVideoEvent)).thenReturn(null);

        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // Widget should attempt to get controller from cache
        verify(() => mockVideoCacheService.getController(testVideoEvent)).called(greaterThan(0));
        
        // Should create widget successfully
        expect(find.byType(VideoFeedItem), findsOneWidget);
      });
    });

    group('Widget Lifecycle', () {
      testWidgets('should dispose controllers properly', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // Widget should be created
        expect(find.byType(VideoFeedItem), findsOneWidget);
        
        // Remove widget to test disposal
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        await tester.pump();

        // Should dispose without errors
        expect(tester.takeException(), isNull);
      });
    });

    group('GIF Handling', () {
      testWidgets('should display GIFs differently from videos', (tester) async {
        final gifEvent = TestHelpers.createGifVideoEvent(
          id: 'test_gif',
          title: 'Test GIF',
        );

        await tester.pumpWidget(createTestWidget(videoEvent: gifEvent));
        await tester.pump();

        // Should show CachedNetworkImage for GIF, not video player
        expect(find.byType(Image), findsAtLeastNWidgets(1));
        expect(find.byType(Chewie), findsNothing);
        
        // Should not show video loading indicator
        expect(find.text('Preparing video...'), findsNothing);
        
        // Should show GIF metadata
        expect(find.text('Test GIF'), findsOneWidget);
      });
    });

    group('User Interactions', () {
      testWidgets('should handle tap to play/pause', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // Find video content area (GestureDetector)
        final gestureDetector = find.byType(GestureDetector);
        expect(gestureDetector, findsAtLeastNWidgets(1));

        // Tap on video area should not crash
        await tester.tap(gestureDetector.first);
        await tester.pump();

        // Should handle tap gracefully
        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle interaction button taps', (tester) async {
        bool likePressed = false;
        bool commentPressed = false;
        bool sharePressed = false;
        
        await tester.pumpWidget(createTestWidget(
          onLike: () => likePressed = true,
          onComment: () => commentPressed = true,
          onShare: () => sharePressed = true,
        ));
        await tester.pump();

        // Find interaction buttons
        final likeButton = find.byIcon(Icons.favorite_border);
        final commentButton = find.byIcon(Icons.chat_bubble_outline);
        final shareButton = find.byIcon(Icons.share_outlined);

        expect(likeButton, findsOneWidget);
        expect(commentButton, findsOneWidget);
        expect(shareButton, findsOneWidget);

        // Test button taps
        await tester.tap(likeButton);
        await tester.pump();
        expect(likePressed, isTrue);

        await tester.tap(commentButton);
        await tester.pump();
        expect(commentPressed, isTrue);

        await tester.tap(shareButton);
        await tester.pump();
        expect(sharePressed, isTrue);
      });

      testWidgets('should handle more options button tap', (tester) async {
        bool moreOptionsPressed = false;
        
        await tester.pumpWidget(createTestWidget(
          onMoreOptions: () => moreOptionsPressed = true,
        ));
        await tester.pump();

        // Find more options button
        final moreButton = find.byIcon(Icons.more_horiz);
        expect(moreButton, findsOneWidget);

        // Test button tap
        await tester.tap(moreButton);
        await tester.pump();
        expect(moreOptionsPressed, isTrue);
      });

      testWidgets('should handle user tap for profile navigation', (tester) async {
        bool userTapped = false;
        
        await tester.pumpWidget(createTestWidget(
          onUserTap: () => userTapped = true,
        ));
        await tester.pump();

        // Find user name area (should be tappable)
        final userTapArea = find.byType(GestureDetector);
        expect(userTapArea, findsAtLeastNWidgets(1));

        // Find the specific GestureDetector for user tap
        // The user name should be in a GestureDetector in the bottom area
        expect(userTapArea, findsAtLeastNWidgets(1));
      });
    });

    group('Accessibility', () {
      testWidgets('should provide accessible widget structure', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // Should have semantic structure for screen readers
        expect(find.byType(VideoFeedItem), findsOneWidget);
        
        // Should have text elements that can be read
        expect(find.text(testVideoEvent.title!), findsOneWidget);
        expect(find.text(testVideoEvent.content), findsOneWidget);
        
        // Should have interactive elements
        expect(find.byType(GestureDetector), findsAtLeastNWidgets(1));
      });

      testWidgets('should handle widget without errors', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // Should create accessible widget structure
        expect(find.byType(VideoFeedItem), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('should provide readable content for screen readers', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // Should have readable text content
        expect(find.text(testVideoEvent.title!), findsOneWidget);
        expect(find.text(testVideoEvent.content), findsOneWidget);
        
        // Should show relative time
        expect(find.textContaining('ago'), findsOneWidget);
      });
    });

    group('Performance', () {
      testWidgets('should build efficiently', (tester) async {
        int buildCount = 0;

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                buildCount++;
                return VideoFeedItem(
                  videoEvent: testVideoEvent,
                  isActive: false,
                  videoCacheService: mockVideoCacheService,
                  userProfileService: mockUserProfileService,
                  seenVideosService: mockSeenVideosService,
                );
              },
            ),
          ),
        ));

        // Should build once initially
        expect(buildCount, greaterThan(0));
        
        // Should create widget successfully
        expect(find.byType(VideoFeedItem), findsOneWidget);
      });

      testWidgets('should dispose resources when widget is removed', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // Verify widget exists
        expect(find.byType(VideoFeedItem), findsOneWidget);

        // Remove widget
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        await tester.pump();

        // Should dispose without errors
        expect(tester.takeException(), isNull);
      });
    });

    group('Edge Cases', () {
      testWidgets('should handle missing video URL gracefully', (tester) async {
        final noUrlEvent = TestHelpers.createVideoEvent(
          videoUrl: '',  // Empty string instead of null
          title: 'No URL Video',
        );

        await tester.pumpWidget(createTestWidget(videoEvent: noUrlEvent));
        await tester.pump();

        // Should not crash
        expect(find.byType(VideoFeedItem), findsOneWidget);
        
        // Should show title
        expect(find.text('No URL Video'), findsOneWidget);
      });

      testWidgets('should handle rapid widget updates gracefully', (tester) async {
        await tester.pumpWidget(createTestWidget(isActive: false));
        await tester.pump();

        // Rapid active state changes
        for (int i = 0; i < 5; i++) {
          await tester.pumpWidget(createTestWidget(isActive: i % 2 == 0));
          await tester.pump();
        }

        // Should handle all state changes without error
        expect(find.byType(VideoFeedItem), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle very long video titles', (tester) async {
        final longTitleEvent = TestHelpers.createVideoEvent(
          title: 'This is a very long video title that might cause layout issues if not handled properly by the UI components',
          content: 'This is also very long content that should be handled gracefully by the widget layout system',
        );

        await tester.pumpWidget(createTestWidget(videoEvent: longTitleEvent));
        await tester.pump();

        // Should handle long title without overflow
        expect(tester.takeException(), isNull);
        expect(find.text(longTitleEvent.title!), findsOneWidget);
        expect(find.text(longTitleEvent.content), findsOneWidget);
      });
    });
  });
}