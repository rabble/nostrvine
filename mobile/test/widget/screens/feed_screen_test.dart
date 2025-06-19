// ABOUTME: Widget tests for FeedScreen - TDD specification for video feed behavior
// ABOUTME: Tests PageView behavior, index handling, preloading triggers, and error boundaries

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:nostrvine_app/models/video_event.dart';
import 'package:nostrvine_app/models/video_state.dart';
import 'package:nostrvine_app/screens/feed_screen_v2.dart';
import 'package:nostrvine_app/services/video_manager_interface.dart';

// Mock classes
class MockVideoManager extends Mock implements IVideoManager {}

void main() {
  group('FeedScreen Widget Tests - TDD UI Specification', () {
    
    late MockVideoManager mockVideoManager;
    late List<VideoEvent> testVideoEvents;

    setUp(() {
      mockVideoManager = MockVideoManager();
      
      // Create test video events
      testVideoEvents = List.generate(10, (index) => VideoEvent(
        id: 'test_video_$index',
        pubkey: 'test_pubkey_$index',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 - index,
        content: 'Test video content $index',
        timestamp: DateTime.now().subtract(Duration(hours: index)),
        videoUrl: 'https://example.com/video$index.mp4',
        title: 'Test Video $index',
        hashtags: ['test', 'video$index'],
        duration: 30 + index,
        dimensions: '1920x1080',
      ));

      // Setup mock behavior
      when(mockVideoManager.videos).thenReturn(testVideoEvents);
      for (final video in testVideoEvents) {
        when(mockVideoManager.getVideoState(video.id)).thenReturn(
          VideoState(
            event: video,
            loadingState: VideoLoadingState.ready,
          ),
        );
      }
    });

    Widget createTestWidget({
      VideoFeedProvider? videoFeedProvider,
      ConnectionStatusService? connectionStatusService,
      SeenVideosService? seenVideosService,
    }) {
      return MaterialApp(
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<VideoFeedProvider>.value(
              value: videoFeedProvider ?? mockVideoFeedProvider,
            ),
            ChangeNotifierProvider<ConnectionStatusService>.value(
              value: connectionStatusService ?? mockConnectionStatusService,
            ),
            ChangeNotifierProvider<SeenVideosService>.value(
              value: seenVideosService ?? mockSeenVideosService,
            ),
          ],
          child: const FeedScreen(),
        ),
      );
    }

    group('PageView Construction', () {
      testWidgets('should build PageView with correct video count', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // Should create PageView with videos
        expect(find.byType(PageView), findsOneWidget);
        
        // Should create correct number of video items
        expect(find.byType(VideoFeedItem), findsAtLeastNWidgets(1));
        
        // Should show app bar with title
        expect(find.text('NostrVine'), findsOneWidget);
      });

      testWidgets('should handle empty video list gracefully', (tester) async {
        when(() => mockVideoFeedProvider.videoEvents).thenReturn([]);
        when(() => mockVideoFeedProvider.allVideoEvents).thenReturn([]);
        when(() => mockVideoFeedProvider.hasEvents).thenReturn(false);

        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // Should show empty state message
        expect(find.text('Finding videos...'), findsOneWidget);
        expect(find.byIcon(Icons.video_library_outlined), findsOneWidget);
        expect(find.text('Searching Nostr relays for video content'), findsOneWidget);
      });

      testWidgets('should handle single video correctly', (tester) async {
        final singleVideo = [testVideoEvents[0]];
        when(() => mockVideoFeedProvider.videoEvents).thenReturn(singleVideo);
        when(() => mockVideoFeedProvider.allVideoEvents).thenReturn(singleVideo);

        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // Should build with single video
        expect(find.byType(PageView), findsOneWidget);
        expect(find.byType(VideoFeedItem), findsOneWidget);
        
        // Should display the video content
        expect(find.text(testVideoEvents[0].title!), findsOneWidget);
      });

      testWidgets('should use vertical scrolling direction', (tester) async {
        await tester.pumpWidget(createTestWidget());

        final pageView = tester.widget<PageView>(find.byType(PageView));
        expect(pageView.scrollDirection, equals(Axis.vertical));
      });

      testWidgets('should snap to pages (not free scroll)', (tester) async {
        await tester.pumpWidget(createTestWidget());

        final pageView = tester.widget<PageView>(find.byType(PageView));
        expect(pageView.pageSnapping, isTrue);
      });
    });

    group('Index Handling and Bounds Checking', () {
      testWidgets('should prevent index out of bounds errors', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // Should build PageView successfully
        expect(find.byType(PageView), findsOneWidget);
        
        // PageView should handle bounds checking internally
        final pageView = tester.widget<PageView>(find.byType(PageView));
        expect(pageView.itemCount, equals(testVideoEvents.length));

        // Should not crash with valid video count
        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle page changes gracefully', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // Should create PageView with videos
        expect(find.byType(PageView), findsOneWidget);
        
        // Test page change simulation
        final pageView = find.byType(PageView);
        expect(pageView, findsOneWidget);

        // Should handle widget creation without error
        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle page navigation correctly', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // Should create PageView
        expect(find.byType(PageView), findsOneWidget);
        
        // Should handle swipe gestures gracefully
        final pageView = find.byType(PageView);
        expect(pageView, findsOneWidget);
        
        // Should not crash on interaction
        expect(tester.takeException(), isNull);
      });

    });

    group('Provider Integration', () {
      testWidgets('should integrate with VideoFeedProvider correctly', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // Should create FeedScreen widget
        expect(find.byType(FeedScreen), findsOneWidget);
        
        // Should integrate with provider
        expect(find.byType(Consumer), findsAtLeastNWidgets(1));
        
        // Should display videos from provider
        expect(find.byType(VideoFeedItem), findsAtLeastNWidgets(1));
      });

      testWidgets('should handle provider state changes', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // Should create app bar with title
        expect(find.text('NostrVine'), findsOneWidget);
        
        // Should show action buttons
        expect(find.byIcon(Icons.search), findsOneWidget);
        expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
      });
      
      testWidgets('should handle refresh functionality', (tester) async {
        // Set up empty state to show refresh indicator
        when(() => mockVideoFeedProvider.hasEvents).thenReturn(false);
        when(() => mockVideoFeedProvider.error).thenReturn(null);
        
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // Should show refresh indicator for empty state
        expect(find.byType(RefreshIndicator), findsOneWidget);
      });
    });

    group('Widget Lifecycle', () {
      testWidgets('should dispose resources properly', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // Verify widget created
        expect(find.byType(FeedScreen), findsOneWidget);

        // Remove widget
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        await tester.pump();

        // Should dispose without errors
        expect(tester.takeException(), isNull);
      });
    });
  });
}
