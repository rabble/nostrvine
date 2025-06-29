// ABOUTME: Integration test for VideoEventService to verify it can receive events from live relay
// ABOUTME: Tests the complete chain from relay connection to event handling in VideoEventService

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/nostr_service.dart';
import 'package:openvine/services/nostr_key_manager.dart';
import 'package:openvine/services/seen_videos_service.dart';
import 'package:openvine/services/content_blocklist_service.dart';
import 'package:openvine/utils/unified_logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('VideoEventService Live Relay Integration', () {
    late NostrKeyManager keyManager;
    late NostrService nostrService;
    late VideoEventService videoEventService;
    late SeenVideosService seenVideosService;
    late ContentBlocklistService blocklistService;

    setUp(() async {
      // Enable logging for debugging
      UnifiedLogger.setLogLevel(LogLevel.debug);
      UnifiedLogger.enableCategories({
        LogCategory.system,
        LogCategory.relay,
        LogCategory.video,
        LogCategory.auth,
      });

      // Initialize key manager
      keyManager = NostrKeyManager();
      await keyManager.initialize();
      
      if (!keyManager.hasKeys) {
        await keyManager.generateKeys();
      }

      // Initialize services
      seenVideosService = SeenVideosService();
      await seenVideosService.initialize();
      
      blocklistService = ContentBlocklistService();
      
      nostrService = NostrService(keyManager);
      await nostrService.initialize();

      videoEventService = VideoEventService(
        nostrService,
        seenVideosService: seenVideosService,
      );
      videoEventService.setBlocklistService(blocklistService);
    });

    tearDown(() async {
      videoEventService.dispose();
      nostrService.dispose();
      seenVideosService.dispose();
    });

    test('VideoEventService receives events from wss://vine.hol.is', () async {
      Log.info('🧪 Starting VideoEventService relay test');
      
      // Verify nostr service is connected
      expect(nostrService.isInitialized, true);
      expect(nostrService.connectedRelays.isNotEmpty, true);
      Log.info('✅ NostrService connected to ${nostrService.connectedRelays.length} relays: ${nostrService.connectedRelays}');

      // Check initial state
      expect(videoEventService.eventCount, 0);
      expect(videoEventService.hasEvents, false);
      
      // Subscribe to video feed
      Log.info('📡 Subscribing to video feed...');
      await videoEventService.subscribeToVideoFeed(
        limit: 10, // Request 10 recent videos
      );
      
      // Wait for subscription to be established and events to arrive
      Log.info('⏳ Waiting for events to arrive...');
      int waitAttempts = 0;
      const maxWaitAttempts = 30; // 15 seconds total (500ms * 30)
      
      while (!videoEventService.hasEvents && waitAttempts < maxWaitAttempts) {
        await Future.delayed(const Duration(milliseconds: 500));
        waitAttempts++;
        
        if (waitAttempts % 6 == 0) { // Log every 3 seconds
          Log.info('⏳ Still waiting for events... attempt ${waitAttempts}/${maxWaitAttempts} (${videoEventService.eventCount} events so far)');
          
          // Log detailed relay status
          final relayStatus = nostrService.getDetailedRelayStatus();
          Log.info('🔍 Relay status: $relayStatus');
        }
      }
      
      // Check results
      Log.info('📊 Final results after ${waitAttempts * 500}ms:');
      Log.info('  - Events received: ${videoEventService.eventCount}');
      Log.info('  - Has events: ${videoEventService.hasEvents}');
      Log.info('  - Is subscribed: ${videoEventService.isSubscribed}');
      Log.info('  - Error: ${videoEventService.error}');
      
      // Log individual events if any were received
      if (videoEventService.hasEvents) {
        Log.info('📝 Received events:');
        for (final event in videoEventService.videoEvents.take(5)) {
          Log.info('  - Event ${event.id.substring(0, 8)}: author=${event.pubkey.substring(0, 8)}..., content="${event.content.length > 50 ? event.content.substring(0, 50) + "..." : event.content}", hasVideo=${event.hasVideo}');
        }
      }
      
      // The main assertion - should receive at least one video event
      expect(videoEventService.hasEvents, true,
          reason: 'VideoEventService should receive at least one kind 22 video event from wss://vine.hol.is relay within 15 seconds. '
              'This test confirms the relay connection and event subscription pipeline is working correctly. '
              'Events received: ${videoEventService.eventCount}');
      
      expect(videoEventService.eventCount, greaterThan(0),
          reason: 'Should have received at least one video event');
          
      // Verify we got video events with valid video URLs
      final hasVideoEvents = videoEventService.videoEvents.any((event) => event.hasVideo);
      expect(hasVideoEvents, true,
          reason: 'Should have received at least one video event with a valid video URL');
      
      Log.info('✅ Test passed! VideoEventService successfully received ${videoEventService.eventCount} events');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('VideoEventService subscription management works correctly', () async {
      Log.info('🧪 Testing VideoEventService subscription management');
      
      // Initial state
      expect(videoEventService.isSubscribed, false);
      expect(videoEventService.isLoading, false);
      
      // Start subscription
      final subscriptionFuture = videoEventService.subscribeToVideoFeed(limit: 5);
      
      // Should be loading
      expect(videoEventService.isLoading, true);
      
      await subscriptionFuture;
      
      // Should be subscribed and not loading
      expect(videoEventService.isSubscribed, true);
      expect(videoEventService.isLoading, false);
      expect(videoEventService.error, isNull);
      
      Log.info('✅ Subscription management test passed');
    });

    test('VideoEventService handles errors gracefully', () async {
      Log.info('🧪 Testing VideoEventService error handling');
      
      // Dispose the underlying nostr service to cause errors
      nostrService.dispose();
      
      // Try to subscribe - should handle error gracefully
      await videoEventService.subscribeToVideoFeed(limit: 5);
      
      // Should have an error state
      expect(videoEventService.error, isNotNull);
      expect(videoEventService.isSubscribed, false);
      
      Log.info('✅ Error handling test passed');
    });
  });
}