// ABOUTME: Integration test for NIP-42 authentication with Nostr relays
// ABOUTME: Tests actual relay connection and AUTH flow in real app environment

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openvine/main.dart' as app;
import 'package:openvine/services/nostr_service_v2.dart';
import 'package:openvine/services/nostr_key_manager.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/event.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('NIP-42 Auth Integration', () {
    testWidgets('Test relay authentication and video loading', (tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Access the services directly
      print('\n=== NIP-42 Authentication Test ===');
      
      // Create test services
      final keyManager = NostrKeyManager();
      await keyManager.initialize();
      if (!keyManager.hasKeys) {
        await keyManager.generateKeys();
      }
      
      final nostrService = NostrServiceV2(keyManager);
      
      // Test 1: Connect to relay
      print('\n1. Testing relay connection...');
      await nostrService.initialize(customRelays: ['wss://vine.hol.is']);
      print('Connected to relays: ${nostrService.connectedRelays}');
      print('Public key: ${nostrService.publicKey}');
      
      // Test 2: Try to subscribe to events
      print('\n2. Testing event subscription (should trigger AUTH if needed)...');
      final filters = [
        Filter(
          kinds: [22], // Video events
          limit: 5,
        )
      ];
      
      final events = <Event>[];
      final subscription = nostrService.subscribeToEvents(filters: filters);
      
      // Listen for events with timeout
      try {
        await subscription.take(5).timeout(
          const Duration(seconds: 10),
          onTimeout: (sink) {
            print('Timeout waiting for events - checking if AUTH is required');
          },
        ).forEach((event) {
          events.add(event);
          print('Received event: ${event.kind} - ${event.id.substring(0, 8)}...');
        });
      } catch (e) {
        print('Error during subscription: $e');
      }
      
      print('\n3. Results:');
      print('Events received: ${events.length}');
      
      if (events.isEmpty) {
        print('⚠️ No events received - possible causes:');
        print('  - Relay requires NIP-42 AUTH but not sending challenge');
        print('  - No Kind 22 events on the relay');
        print('  - AUTH is failing silently');
      } else {
        print('✅ Successfully received ${events.length} events!');
      }
      
      // Test 3: Try to query our own profile
      print('\n4. Testing profile query (should work after AUTH)...');
      final profileFilters = [
        Filter(
          kinds: [0], // Profile metadata
          authors: [nostrService.publicKey!],
          limit: 1,
        )
      ];
      
      final profileEvents = <Event>[];
      try {
        await nostrService.subscribeToEvents(filters: profileFilters)
          .take(1)
          .timeout(const Duration(seconds: 3), onTimeout: (sink) {})
          .forEach((event) {
            profileEvents.add(event);
          });
      } catch (e) {
        print('Profile query error: $e');
      }
      
      print('Profile events: ${profileEvents.length}');
      
      // Wait a bit to see any notices or errors
      await tester.pump(const Duration(seconds: 2));
    });
  });
}