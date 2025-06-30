// ABOUTME: Debug test to investigate why VideoEventService isn't receiving events
// ABOUTME: This is a minimal test to trace the issue step by step

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/nostr_service.dart';
import 'package:openvine/services/nostr_key_manager.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/utils/unified_logger.dart';

// Simple mock NostrService that we can control
class TestableNostrService extends NostrService {
  StreamController<Event>? _testStreamController;
  bool _mockInitialized = true; // Mark as initialized for testing
  
  TestableNostrService(super.keyManager);
  
  @override
  bool get isInitialized => _mockInitialized;
  
  @override
  Stream<Event> subscribeToEvents({
    required List<Filter> filters,
    bool bypassLimits = false,
  }) {
    Log.info('🔍 TestableNostrService.subscribeToEvents called with ${filters.length} filters', name: 'TestableNostrService');
    
    // Log filter details
    for (final filter in filters) {
      final filterJson = filter.toJson();
      Log.info('  - Filter: $filterJson', name: 'TestableNostrService');
    }
    
    // Create a test stream that we can control
    _testStreamController = StreamController<Event>.broadcast();
    
    // Simulate receiving some test events after a delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_testStreamController != null && !_testStreamController!.isClosed) {
        Log.info('📨 Injecting test event into stream', name: 'TestableNostrService');
        
        // Use a valid hex pubkey (64 hex chars)
        final testEvent = Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
          22, // Kind 22 for video
          [
            ['url', 'https://example.com/test-video.mp4'],
            ['m', 'video/mp4'],
            ['title', 'Debug Test Video'],
            ['duration', '30'],
          ],
          'Debug test video content'
        );
        
        _testStreamController!.add(testEvent);
      }
    });
    
    return _testStreamController!.stream;
  }
  
  @override
  void dispose() {
    _testStreamController?.close();
    super.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  test('Debug: Trace VideoEventService event handling', () async {
    // Enable maximum logging
    UnifiedLogger.setLogLevel(LogLevel.verbose);
    UnifiedLogger.enableCategories({
      LogCategory.system,
      LogCategory.relay,
      LogCategory.video,
      LogCategory.auth,
    });
    
    Log.info('🔍 Starting debug test for VideoEventService', name: 'DebugTest');
    
    // Create a simple key manager without SharedPreferences
    final keyManager = NostrKeyManager();
    // Skip initialization to avoid SharedPreferences
    
    // Create our testable service
    final nostrService = TestableNostrService(keyManager);
    
    // Set up the service state manually
    // This is a hack but allows us to test without SharedPreferences
    
    Log.info('📡 Creating VideoEventService', name: 'DebugTest');
    final subscriptionManager = SubscriptionManager(nostrService);
    final videoEventService = VideoEventService(nostrService, subscriptionManager: subscriptionManager);
    
    // Add a listener to track changes
    int changeCount = 0;
    videoEventService.addListener(() {
      changeCount++;
      Log.info('🔔 VideoEventService notified listeners (change #$changeCount)', name: 'DebugTest');
      Log.info('  - Event count: ${videoEventService.eventCount}', name: 'DebugTest');
      Log.info('  - Has events: ${videoEventService.hasEvents}', name: 'DebugTest');
      Log.info('  - Is subscribed: ${videoEventService.isSubscribed}', name: 'DebugTest');
    });
    
    // Check initial state
    Log.info('📊 Initial state:', name: 'DebugTest');
    Log.info('  - Event count: ${videoEventService.eventCount}', name: 'DebugTest');
    Log.info('  - Has events: ${videoEventService.hasEvents}', name: 'DebugTest');
    Log.info('  - Is subscribed: ${videoEventService.isSubscribed}', name: 'DebugTest');
    
    // Subscribe to video feed
    Log.info('🚀 Calling subscribeToVideoFeed...', name: 'DebugTest');
    try {
      await videoEventService.subscribeToVideoFeed(limit: 10);
      Log.info('✅ subscribeToVideoFeed completed successfully', name: 'DebugTest');
    } catch (e) {
      Log.error('❌ subscribeToVideoFeed failed: $e', name: 'DebugTest');
    }
    
    // Check state after subscription
    Log.info('📊 State after subscription:', name: 'DebugTest');
    Log.info('  - Event count: ${videoEventService.eventCount}', name: 'DebugTest');
    Log.info('  - Has events: ${videoEventService.hasEvents}', name: 'DebugTest');
    Log.info('  - Is subscribed: ${videoEventService.isSubscribed}', name: 'DebugTest');
    Log.info('  - Error: ${videoEventService.error}', name: 'DebugTest');
    
    // Wait for events to arrive
    Log.info('⏳ Waiting for events...', name: 'DebugTest');
    await Future.delayed(const Duration(seconds: 2));
    
    // Final check
    Log.info('📊 Final state:', name: 'DebugTest');
    Log.info('  - Event count: ${videoEventService.eventCount}', name: 'DebugTest');
    Log.info('  - Has events: ${videoEventService.hasEvents}', name: 'DebugTest');
    Log.info('  - Is subscribed: ${videoEventService.isSubscribed}', name: 'DebugTest');
    Log.info('  - Total listener notifications: $changeCount', name: 'DebugTest');
    
    if (videoEventService.hasEvents) {
      Log.info('📝 Events received:', name: 'DebugTest');
      for (final event in videoEventService.videoEvents) {
        Log.info('  - Event: ${event.id.substring(0, 8)}... title="${event.title}"', name: 'DebugTest');
      }
    } else {
      Log.error('❌ No events received! This confirms the bug.', name: 'DebugTest');
    }
    
    // The key assertion
    expect(videoEventService.hasEvents, true,
        reason: 'VideoEventService should have received and processed the test event. '
            'If this fails, the bug is confirmed in the event handling chain.');
    
    // Clean up
    videoEventService.removeListener(() {});
    videoEventService.dispose();
    nostrService.dispose();
  });
}