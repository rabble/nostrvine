// ABOUTME: Test to debug VideoEventService with NostrService
// ABOUTME: Run with: dart test_video_event_service_debug.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:nostr_sdk/filter.dart';
import 'lib/services/nostr_service.dart';
import 'lib/services/nostr_key_manager.dart';
import 'lib/services/video_event_service.dart';
import 'lib/services/subscription_manager.dart';
import 'package:openvine/utils/unified_logger.dart';

void main() async {
  Log.debug('🚀 Testing VideoEventService with NostrService...\n');
  
  // Initialize key manager
  final keyManager = NostrKeyManager();
  await keyManager.initialize();
  
  if (!keyManager.hasKeys) {
    await keyManager.generateKeys();
  }
  
  Log.debug('🔑 Generated keys: ${keyManager.publicKey!.substring(0, 8)}...');
  
  // Create NostrService
  final nostrService = NostrService(keyManager);
  
  try {
    // Initialize service
    Log.debug('🔧 Initializing NostrService...');
    await nostrService.initialize();
    
    Log.debug('✅ NostrService initialized');
    Log.debug('  - Connected relays: ${nostrService.connectedRelays}');
    Log.debug('  - Relay count: ${nostrService.relayCount}');
    
    // Create VideoEventService
    Log.debug('\n🎥 Creating VideoEventService...');
    final subscriptionManager = SubscriptionManager(nostrService);
    final videoService = VideoEventService(nostrService, subscriptionManager: subscriptionManager);
    
    // Test direct subscription
    Log.debug('\n📡 Testing direct subscription to nostr service...');
    final filter = Filter(kinds: [22], limit: 5);
    final eventStream = nostrService.subscribeToEvents(filters: [filter]);
    
    int directEventCount = 0;
    final directSub = eventStream.listen((event) {
      directEventCount++;
      Log.debug('📨 Direct event #$directEventCount: kind=${event.kind}, id=${event.id.substring(0, 8)}...');
    });
    
    // Test VideoEventService subscription
    Log.debug('\n🎬 Testing VideoEventService subscription...');
    await videoService.subscribeToVideoFeed(limit: 5);
    
    Log.debug('  - Is subscribed: ${videoService.isSubscribed}');
    Log.debug('  - Is loading: ${videoService.isLoading}');
    Log.debug('  - Error: ${videoService.error}');
    Log.debug('  - Event count: ${videoService.eventCount}');
    
    // Wait for events
    Log.debug('\n⏳ Waiting for events (15 seconds)...');
    await Future.delayed(Duration(seconds: 15));
    
    Log.debug('\n📊 Final Results:');
    Log.debug('  - Direct events received: $directEventCount');
    Log.debug('  - VideoService events: ${videoService.eventCount}');
    Log.debug('  - VideoService error: ${videoService.error}');
    
    // Print some video events if any
    if (videoService.videoEvents.isNotEmpty) {
      Log.debug('\n📹 Video events:');
      for (final video in videoService.videoEvents.take(3)) {
        Log.debug('  - ${video.id.substring(0, 8)}...: ${video.content.substring(0, 50)}...');
      }
    }
    
    // Cleanup
    directSub.cancel();
    
  } catch (e) {
    Log.debug('❌ Error: $e');
  } finally {
    nostrService.dispose();
  }
}
