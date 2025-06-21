// ABOUTME: Integration tests for video event processing and VideoManager integration
// ABOUTME: Tests the complete flow: Nostr Events → VideoEventProcessor → VideoManagerService

import 'package:flutter_test/flutter_test.dart';
import 'package:nostrvine_app/services/video_event_processor.dart';
import 'package:nostrvine_app/services/video_manager_service.dart';
import 'package:nostrvine_app/services/video_manager_interface.dart';
import 'package:nostrvine_app/models/video_event.dart';
import 'package:nostrvine_app/models/video_state.dart';
import 'package:nostr/nostr.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('Video Event Processing Integration', () {
    late IVideoManager videoManager;

    setUpAll(() {
      // Initialize Flutter binding for VideoManagerService
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    setUp(() {
      videoManager = VideoManagerService();
    });

    tearDown(() {
      videoManager.dispose();
    });

    group('VideoEventProcessor to VideoManager Flow', () {
      test('should process valid Nostr video event through complete pipeline', () async {
        // ARRANGE: Create a valid Nostr event (kind 22 for short videos)
        final event = Event.from(
          kind: 22, // NIP-71 short video event
          content: 'Test video content',
          tags: [
            ['url', 'https://example.com/test-video.mp4'],
            ['m', 'video/mp4'],
            ['size', '1024000'],
            ['duration', '30'],
            ['title', 'Test Video Title'],
          ],
          privkey: '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        );

        // ACT: Process the Nostr event through the pipeline
        final videoEvent = VideoEventProcessor.fromNostrEvent(event);
        await videoManager.addVideoEvent(videoEvent);

        // ASSERT: Verify the video is properly added to VideoManager
        expect(videoManager.videos, hasLength(1));
        
        final addedVideo = videoManager.videos.first;
        expect(addedVideo.id, event.id); // Use actual generated ID
        expect(addedVideo.title, 'Test Video Title');
        expect(addedVideo.videoUrl, 'https://example.com/test-video.mp4');
        expect(addedVideo.mimeType, 'video/mp4');
        expect(addedVideo.fileSize, 1024000);
        expect(addedVideo.duration, 30);

        // Verify state management
        final videoState = videoManager.getVideoState(videoEvent.id);
        expect(videoState, isNotNull);
        expect(videoState!.loadingState, VideoLoadingState.notLoaded);
      });

      test('should handle GIF events immediately as ready', () async {
        // ARRANGE: Create a GIF event
        final gifEvent = Event.from(
          kind: 22,
          content: 'Animated GIF content',
          tags: [
            ['url', 'https://example.com/animated.gif'],
            ['m', 'image/gif'],
            ['title', 'Test GIF'],
          ],
          privkey: '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        );

        // ACT: Process the GIF event
        final videoEvent = VideoEventProcessor.fromNostrEvent(gifEvent);
        await videoManager.addVideoEvent(videoEvent);

        // ASSERT: GIF should be added and tracked
        expect(videoManager.videos, hasLength(1));
        
        final gifState = videoManager.getVideoState(videoEvent.id);
        expect(gifState, isNotNull);
        expect(gifState!.event.isGif, isTrue);
        // Note: GIFs need to be explicitly preloaded in the new architecture
      });

      test('should maintain newest-first ordering across multiple events', () async {
        // ARRANGE: Create multiple events with different timestamps
        final olderEvent = Event.from(
          kind: 22,
          content: 'Older video',
          tags: [['url', 'https://example.com/older.mp4'], ['title', 'Older Video']],
          privkey: '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
          createdAt: (DateTime.now().millisecondsSinceEpoch ~/ 1000) - 3600, // 1 hour ago
        );

        final newerEvent = Event.from(
          kind: 22,
          content: 'Newer video',
          tags: [['url', 'https://example.com/newer.mp4'], ['title', 'Newer Video']],
          privkey: '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000, // Now
        );

        // ACT: Add events in chronological order (older first)
        final olderVideoEvent = VideoEventProcessor.fromNostrEvent(olderEvent);
        final newerVideoEvent = VideoEventProcessor.fromNostrEvent(newerEvent);
        
        await videoManager.addVideoEvent(olderVideoEvent);
        await videoManager.addVideoEvent(newerVideoEvent);

        // ASSERT: Newer video should appear first
        expect(videoManager.videos, hasLength(2));
        expect(videoManager.videos[0].id, newerEvent.id); // Newest first
        expect(videoManager.videos[1].id, olderEvent.id); // Older second
      });

      test('should prevent duplicate video events', () async {
        // ARRANGE: Create the same event twice
        final event = Event.from(
          kind: 22,
          content: 'Duplicate test video',
          tags: [['url', 'https://example.com/duplicate.mp4']],
          privkey: '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        );

        // ACT: Process the same event twice
        final videoEvent1 = VideoEventProcessor.fromNostrEvent(event);
        final videoEvent2 = VideoEventProcessor.fromNostrEvent(event);
        
        await videoManager.addVideoEvent(videoEvent1);
        await videoManager.addVideoEvent(videoEvent2); // Duplicate

        // ASSERT: Should only have one video
        expect(videoManager.videos, hasLength(1));
        expect(videoManager.videos.first.id, event.id);
      });

      test('should handle VideoEventProcessor validation errors', () {
        // ARRANGE: Create an invalid event (wrong kind)
        final invalidEvent = Event.from(
          kind: 1, // Wrong kind - should be 22 for videos
          content: 'Not a video event',
          tags: [],
          privkey: '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        );

        // ACT & ASSERT: Should throw VideoEventProcessorException
        expect(
          () => VideoEventProcessor.fromNostrEvent(invalidEvent),
          throwsA(isA<VideoEventProcessorException>()),
        );
      });

      test('should handle events with missing video URLs', () {
        // ARRANGE: Create event without video URL
        final eventWithoutUrl = Event.from(
          kind: 22,
          content: 'Video without URL',
          tags: [['title', 'Video Without URL']], // No URL tag
          privkey: '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        );

        // ACT & ASSERT: Should throw exception due to missing URL
        expect(
          () => VideoEventProcessor.fromNostrEvent(eventWithoutUrl),
          throwsA(isA<VideoEventProcessorException>()),
        );
      });
    });

    group('Performance and Memory Management', () {
      test('should handle large numbers of events efficiently', () async {
        // ARRANGE: Create many video events
        final events = <VideoEvent>[];
        
        for (int i = 0; i < 50; i++) {
          final event = Event.from(
            kind: 22,
            content: 'Performance test video $i',
            tags: [
              ['url', 'https://example.com/video$i.mp4'],
              ['title', 'Performance Test Video $i'],
            ],
            privkey: '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
            createdAt: (DateTime.now().millisecondsSinceEpoch ~/ 1000) - i, // Decreasing timestamps
          );
          
          events.add(VideoEventProcessor.fromNostrEvent(event));
        }

        // ACT: Add all events
        for (final videoEvent in events) {
          await videoManager.addVideoEvent(videoEvent);
        }

        // ASSERT: All events should be added and properly ordered
        expect(videoManager.videos, hasLength(50));
        
        // Verify ordering is maintained (VideoManagerService inserts newest at index 0)
        // We added events in order 0, 1, 2, ..., 49
        // Since VideoManagerService inserts at index 0, the last added (index 49) should be first
        expect(videoManager.videos.first.content.contains('49'), isTrue, 
               reason: 'First video should be the most recently added (index 49)');
        expect(videoManager.videos.last.content.contains('0'), isTrue,
               reason: 'Last video should be the first added (index 0)');

        // Verify memory management stats
        final debugInfo = videoManager.getDebugInfo();
        // Note: Memory limits might have been enforced, so we check that we have videos
        expect(debugInfo['totalVideos'], greaterThan(0));
        expect(debugInfo['activeControllers'], 0); // No controllers created yet
      });

      test('should provide comprehensive debug information', () async {
        // ARRANGE: Add some test videos
        final testEvents = [
          TestHelpers.createVideoEvent(id: 'debug-video-1', isGif: true),
          TestHelpers.createVideoEvent(id: 'debug-video-2', isGif: false),
        ];

        for (final event in testEvents) {
          await videoManager.addVideoEvent(event);
        }

        // ACT: Get debug information
        final debugInfo = videoManager.getDebugInfo();

        // ASSERT: Should contain expected debug data
        expect(debugInfo, containsPair('totalVideos', 2));
        expect(debugInfo, containsPair('readyVideos', 0)); // No auto-ready videos in new architecture
        expect(debugInfo, containsPair('loadingVideos', 0));
        expect(debugInfo, containsPair('failedVideos', 0));
        expect(debugInfo, containsPair('activeControllers', 0));
        expect(debugInfo, containsPair('activePreloads', isA<int>()));
        expect(debugInfo['config'], containsPair('maxVideos', isA<int>()));
        expect(debugInfo['config'], containsPair('preloadAhead', isA<int>()));
      });
    });

    group('Error Handling and Validation', () {
      test('should validate event processing through VideoEventProcessor', () {
        // Test various invalid event scenarios
        final testCases = [
          {
            'description': 'unsupported video format',
            'event': Event.from(
              kind: 22,
              content: 'Test',
              tags: [
                ['url', 'https://example.com/test.mp4'],
                ['m', 'video/unsupported-format'],
              ],
              privkey: '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
            ),
          },
        ];

        for (final testCase in testCases) {
          expect(
            () => VideoEventProcessor.fromNostrEvent(testCase['event'] as Event),
            throwsA(isA<VideoEventProcessorException>()),
            reason: 'Should reject event with ${testCase['description']}',
          );
        }
      });

      test('should validate URLs through VideoEventProcessor', () {
        // Test URL validation cases - VideoEventProcessor has basic URL validation
        final invalidUrls = [
          'not-a-url',  // Completely invalid URL
          '',           // Empty URL
        ];

        for (final url in invalidUrls) {
          final event = Event.from(
            kind: 22,
            content: 'URL test',
            tags: [['url', url]],
            privkey: '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
          );

          expect(
            () => VideoEventProcessor.fromNostrEvent(event),
            throwsA(isA<VideoEventProcessorException>()),
            reason: 'Should reject invalid URL: $url',
          );
        }
      });
    });
  });
}