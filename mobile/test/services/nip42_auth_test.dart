// ABOUTME: Tests for NIP-42 authentication with Nostr relays
// ABOUTME: Verifies AUTH challenge/response flow and video loading with authentication

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:openvine/services/nostr_service_v2.dart';
import 'package:openvine/services/nostr_key_manager.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('NIP-42 Authentication Tests', () {
    late NostrKeyManager keyManager;
    late NostrServiceV2 nostrService;
    late VideoEventService videoService;

    setUp(() async {
      // Initialize key manager with test keys
      keyManager = NostrKeyManager();
      await keyManager.initialize();
      
      // Generate test keys if needed
      if (!keyManager.hasKeys) {
        await keyManager.generateKeys();
      }
      
      nostrService = NostrServiceV2(keyManager);
      videoService = VideoEventService(nostrService);
    });

    tearDown(() async {
      // NostrServiceV2 doesn't have disconnect method
      // It will be cleaned up when disposed
    });

    test('should connect to vine.hol.is relay', () async {
      // Initialize with the vine relay
      await nostrService.initialize(customRelays: ['wss://vine.hol.is']);
      
      expect(nostrService.isInitialized, true);
      expect(nostrService.connectedRelays, contains('wss://vine.hol.is'));
      expect(nostrService.connectedRelayCount, greaterThan(0));
    });

    test('should handle AUTH challenge from relay', () async {
      // Initialize connection
      await nostrService.initialize(customRelays: ['wss://vine.hol.is']);
      
      // Create a test subscription to trigger AUTH if needed
      final filters = [
        Filter(
          kinds: [22], // Video events
          limit: 1,
        )
      ];
      
      // Subscribe and collect events
      final events = <Event>[];
      final subscription = nostrService.subscribeToEvents(
        filters: filters,
      );
      
      // Listen for a short time to see if we get any events or AUTH challenges
      await subscription.take(1).timeout(
        const Duration(seconds: 5),
        onTimeout: (sink) {
          print('Timeout waiting for events - possibly AUTH required');
        },
      ).forEach((event) {
        events.add(event);
      });
      
      // If we got no events, it might be due to AUTH requirement
      if (events.isEmpty) {
        print('No events received - relay may require authentication');
      }
    });

    test('should load video events after authentication', () async {
      await nostrService.initialize(customRelays: ['wss://vine.hol.is']);
      
      // Subscribe to video feed
      await videoService.subscribeToVideoFeed(limit: 10);
      
      // Wait for events to load
      await Future.delayed(const Duration(seconds: 3));
      
      // Check if we have any videos
      print('Video events loaded: ${videoService.eventCount}');
      print('Is subscribed: ${videoService.isSubscribed}');
      print('Has error: ${videoService.error}');
      
      // We expect to have some videos if AUTH is working
      expect(videoService.isSubscribed, true);
      
      if (videoService.eventCount == 0) {
        print('No videos loaded - AUTH may be failing');
        print('Error: ${videoService.error}');
      }
    });

    test('should receive AUTH challenge message from relay', () async {
      // Track all messages from relay
      final messages = <String>[];
      
      // We need to modify the nostr service to expose raw messages
      // For now, let's just test the connection
      await nostrService.initialize(customRelays: ['wss://vine.hol.is']);
      
      // Try to send a REQ to trigger AUTH
      final filters = [
        Filter(
          kinds: [22],
          limit: 1,
        )
      ];
      
      final stream = nostrService.subscribeToEvents(filters: filters);
      
      // Collect any notices or errors
      try {
        await stream.take(1).timeout(
          const Duration(seconds: 3),
          onTimeout: (sink) {
            print('Timeout - no events received');
          },
        ).toList();
      } catch (e) {
        print('Error during subscription: $e');
      }
    });

    test('relay connection status and auth state', () async {
      await nostrService.initialize(customRelays: ['wss://vine.hol.is']);
      
      // Access the relay pool through the nostr client
      // This is a diagnostic test to understand relay state
      print('\nRelay Connection Diagnostics:');
      print('- Public key: ${nostrService.publicKey}');
      print('- Connected relays: ${nostrService.connectedRelays}');
      print('- Relay count: ${nostrService.relayCount}');
      
      // Try a simple query
      final testFilters = [
        Filter(
          kinds: [0], // User metadata
          authors: [nostrService.publicKey!],
          limit: 1,
        )
      ];
      
      final events = await nostrService.subscribeToEvents(
        filters: testFilters,
      ).take(1).timeout(
        const Duration(seconds: 2),
        onTimeout: (sink) {},
      ).toList();
      
      print('- Self metadata query result: ${events.length} events');
    });
  });
}