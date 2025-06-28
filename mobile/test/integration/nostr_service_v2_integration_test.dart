// ABOUTME: Integration test for NostrServiceV2 event reception
// ABOUTME: Tests actual connection to relay and event subscription

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/nostr_service_v2.dart';
import 'package:openvine/services/nostr_key_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('NostrServiceV2 Integration', () {
    test('receives events from relay', () async {
      // Create real key manager
      final keyManager = NostrKeyManager();
      await keyManager.initialize();
      
      if (!keyManager.hasKeys) {
        await keyManager.generateKeys();
      }
      
      // Create service
      final service = NostrServiceV2(keyManager);
      
      try {
        // Initialize service
        await service.initialize();
        
        expect(service.isInitialized, true);
        expect(service.connectedRelays.isNotEmpty, true);
        
        // Create subscription for video events
        final filter = Filter(
          kinds: [22], // Video events
          limit: 5,
        );
        
        final eventStream = service.subscribeToEvents(filters: [filter]);
        
        // Collect events for 10 seconds
        final events = <dynamic>[];
        final subscription = eventStream.listen((event) {
          events.add(event);
          print('Received event: ${event.kind} - ${event.id.substring(0, 8)}...');
        });
        
        // Wait for events
        await Future.delayed(const Duration(seconds: 10));
        
        // Cancel subscription
        await subscription.cancel();
        
        // Should have received at least one event
        expect(events.isNotEmpty, true,
            reason: 'Should receive at least one event from relay');
        
        if (events.isNotEmpty) {
          print('✅ Received ${events.length} events');
        }
        
      } finally {
        service.dispose();
      }
    });
  });
}