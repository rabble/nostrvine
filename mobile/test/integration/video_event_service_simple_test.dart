// ABOUTME: Simple test to verify the bug where VideoEventService isn't receiving events
// ABOUTME: Uses mock NostrService to isolate the issue from platform dependencies

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/seen_videos_service.dart';
import 'package:openvine/services/content_blocklist_service.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/utils/unified_logger.dart';

import 'video_event_service_simple_test.mocks.dart';

@GenerateMocks([INostrService, SubscriptionManager])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('VideoEventService Event Reception Bug Investigation', () {
    late MockINostrService mockNostrService;
    late MockSubscriptionManager mockSubscriptionManager;
    late VideoEventService videoEventService;
    late SeenVideosService seenVideosService;
    late ContentBlocklistService blocklistService;
    late StreamController<Event> mockEventStream;

    setUp(() async {
      // Enable logging for debugging
      UnifiedLogger.setLogLevel(LogLevel.debug);
      UnifiedLogger.enableCategories({
        LogCategory.system,
        LogCategory.relay,
        LogCategory.video,
        LogCategory.auth,
      });

      // Set up mocks
      mockNostrService = MockINostrService();
      mockSubscriptionManager = MockSubscriptionManager();
      mockEventStream = StreamController<Event>.broadcast();
      
      // Mock basic properties
      when(mockNostrService.isInitialized).thenReturn(true);
      when(mockNostrService.connectedRelays).thenReturn(['wss://vine.hol.is']);
      when(mockNostrService.hasKeys).thenReturn(true);
      when(mockNostrService.publicKey).thenReturn('test_pubkey');
      
      // Mock the critical subscribeToEvents method
      when(mockNostrService.subscribeToEvents(filters: anyNamed('filters')))
          .thenAnswer((_) => mockEventStream.stream);

      // Initialize services that don't require SharedPreferences
      seenVideosService = SeenVideosService();
      // Bypass actual initialization to avoid SharedPreferences
      
      blocklistService = ContentBlocklistService();
      
      videoEventService = VideoEventService(
        mockNostrService,
        seenVideosService: seenVideosService,
        subscriptionManager: mockSubscriptionManager,
      );
      videoEventService.setBlocklistService(blocklistService);
    });

    tearDown(() async {
      await mockEventStream.close();
      videoEventService.dispose();
    });

    test('VideoEventService calls subscribeToEvents and processes events correctly', () async {
      Log.info('🧪 Testing VideoEventService event processing with mock');
      
      // Verify initial state
      expect(videoEventService.eventCount, 0);
      expect(videoEventService.hasEvents, false);
      
      // Create a test kind 22 video event
      final testEvent = Event(
        'test_pubkey_1234567890abcdef1234567890abcdef1234567890abcdef12345678',
        22, // Kind 22 for video
        [
          ['url', 'https://example.com/test-video.mp4'],
          ['m', 'video/mp4'],
          ['title', 'Test Video'],
          ['duration', '30'],
        ],
        'Test video content from relay'
      );
      
      // Subscribe to video feed - this should call the mock
      Log.info('📡 Subscribing to video feed...');
      final subscriptionFuture = videoEventService.subscribeToVideoFeed(limit: 10);
      
      // Verify that subscribeToEvents was called on the mock
      await subscriptionFuture;
      verify(mockNostrService.subscribeToEvents(filters: anyNamed('filters'))).called(1);
      Log.info('✅ Confirmed VideoEventService called subscribeToEvents');
      
      // Verify subscription state
      expect(videoEventService.isSubscribed, true);
      expect(videoEventService.isLoading, false);
      expect(videoEventService.error, isNull);
      
      // Now simulate an event coming from the relay
      Log.info('📨 Simulating event from relay...');
      mockEventStream.add(testEvent);
      
      // Give it a moment to process
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Check if the event was processed
      Log.info('📊 Results after simulated event:');
      Log.info('  - Events received: ${videoEventService.eventCount}');
      Log.info('  - Has events: ${videoEventService.hasEvents}');
      
      if (videoEventService.hasEvents) {
        Log.info('  - First event ID: ${videoEventService.videoEvents.first.id.substring(0, 8)}...');
        Log.info('  - First event title: ${videoEventService.videoEvents.first.title}');
      }
      
      // This is the critical test - did VideoEventService receive and process the event?
      expect(videoEventService.hasEvents, true,
          reason: 'VideoEventService should process events from the stream. '
              'If this fails, there is a bug in _handleNewVideoEvent or event processing logic.');
      
      expect(videoEventService.eventCount, 1,
          reason: 'Should have exactly one event');
          
      final processedEvent = videoEventService.videoEvents.first;
      expect(processedEvent.title, 'Test Video');
      expect(processedEvent.hasVideo, true);
      
      Log.info('✅ VideoEventService successfully processed the mock event');
    });

    test('VideoEventService handles stream errors gracefully', () async {
      Log.info('🧪 Testing VideoEventService error handling');
      
      // Subscribe to video feed
      await videoEventService.subscribeToVideoFeed(limit: 5);
      
      // Simulate a stream error
      mockEventStream.addError(Exception('Mock relay error'));
      
      // Give it time to handle the error
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Should handle error gracefully without crashing
      expect(videoEventService.isSubscribed, true);
      // Error handling may vary - the important thing is it doesn't crash
      
      Log.info('✅ Error handling test completed');
    });

    test('VideoEventService filters non-video events correctly', () async {
      Log.info('🧪 Testing VideoEventService event filtering');
      
      await videoEventService.subscribeToVideoFeed(limit: 5);
      
      // Send a non-video event (kind 1 is text note)
      final textEvent = Event(
        'test_pubkey_1234567890abcdef1234567890abcdef1234567890abcdef12345678',
        1, // Kind 1 for text note
        [],
        'This is not a video event'
      );
      
      mockEventStream.add(textEvent);
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Should not process non-video events
      expect(videoEventService.eventCount, 0,
          reason: 'Should not process non-video events');
      
      // Now send a real video event
      final videoEvent = Event(
        'test_pubkey_1234567890abcdef1234567890abcdef1234567890abcdef12345678',
        22, // Kind 22 for video
        [
          ['url', 'https://example.com/filtered-test.mp4'],
          ['title', 'Filtered Test Video'],
        ],
        'Video event content'
      );
      
      mockEventStream.add(videoEvent);
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Should process the video event
      expect(videoEventService.eventCount, 1,
          reason: 'Should process video events');
      
      Log.info('✅ Event filtering test completed');
    });
  });
}