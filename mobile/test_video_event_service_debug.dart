// ABOUTME: Test to debug VideoEventService with NostrServiceV2
// ABOUTME: Run with: dart test_video_event_service_debug.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:nostr_sdk/filter.dart';
import 'lib/services/nostr_service_v2.dart';
import 'lib/services/nostr_key_manager.dart';
import 'lib/services/video_event_service.dart';

void main() async {
  print('🚀 Testing VideoEventService with NostrServiceV2...\n');
  
  // Initialize key manager
  final keyManager = NostrKeyManager();
  await keyManager.initialize();
  
  if (!keyManager.hasKeys) {
    await keyManager.generateKeys();
  }
  
  print('🔑 Generated keys: ${keyManager.publicKey!.substring(0, 8)}...');
  
  // Create NostrServiceV2
  final nostrService = NostrServiceV2(keyManager);
  
  try {
    // Initialize service
    print('🔧 Initializing NostrServiceV2...');
    await nostrService.initialize();
    
    print('✅ NostrService initialized');
    print('  - Connected relays: ${nostrService.connectedRelays}');
    print('  - Relay count: ${nostrService.relayCount}');
    
    // Create VideoEventService
    print('\n🎥 Creating VideoEventService...');
    final videoService = VideoEventService(nostrService);
    
    // Test direct subscription
    print('\n📡 Testing direct subscription to nostr service...');
    final filter = Filter(kinds: [22], limit: 5);
    final eventStream = nostrService.subscribeToEvents(filters: [filter]);
    
    int directEventCount = 0;
    final directSub = eventStream.listen((event) {
      directEventCount++;
      print('📨 Direct event #$directEventCount: kind=${event.kind}, id=${event.id.substring(0, 8)}...');
    });
    
    // Test VideoEventService subscription
    print('\n🎬 Testing VideoEventService subscription...');
    await videoService.subscribeToVideoFeed(limit: 5);
    
    print('  - Is subscribed: ${videoService.isSubscribed}');
    print('  - Is loading: ${videoService.isLoading}');
    print('  - Error: ${videoService.error}');
    print('  - Event count: ${videoService.eventCount}');
    
    // Wait for events
    print('\n⏳ Waiting for events (15 seconds)...');
    await Future.delayed(Duration(seconds: 15));
    
    print('\n📊 Final Results:');
    print('  - Direct events received: $directEventCount');
    print('  - VideoService events: ${videoService.eventCount}');
    print('  - VideoService error: ${videoService.error}');
    
    // Print some video events if any
    if (videoService.videoEvents.isNotEmpty) {
      print('\n📹 Video events:');
      for (final video in videoService.videoEvents.take(3)) {
        print('  - ${video.id.substring(0, 8)}...: ${video.content.substring(0, 50)}...');
      }
    }
    
    // Cleanup
    directSub.cancel();
    
  } catch (e) {
    print('❌ Error: $e');
  } finally {
    nostrService.dispose();
  }
}