// ABOUTME: Integration tests for complete video system behavior - TDD specification
// ABOUTME: Tests end-to-end video flow from Nostr events to UI display with performance validation

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mockito/mockito.dart';
import 'package:nostrvine_app/models/video_event.dart';
import 'package:nostrvine_app/models/video_state.dart';
import 'package:nostrvine_app/services/video_manager_interface.dart';
import 'package:nostrvine_app/services/video_event_processor.dart';
import 'package:nostr/nostr.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Video System Integration Tests - TDD Behavior Specification', () {
    
    group('Single Source of Truth Validation', () {
      testWidgets('should maintain consistent video list across all operations', (tester) async {
        // Test: CRITICAL - This test validates the core fix for dual list problem
        
        // SCENARIO: User receives new video events from Nostr relays
        // REQUIREMENT: All parts of system must see same video list in same order
        
        // 1. Create mock Nostr events
        final nostrEvents = _createMockNostrEvents(count: 10);
        
        // 2. Process events through VideoEventProcessor
        final videoEvents = <VideoEvent>[];
        for (final nostrEvent in nostrEvents) {
          videoEvents.add(VideoEventProcessor.fromNostrEvent(nostrEvent));
        }
        
        // 3. Add events to VideoManager (single source of truth)
        final videoManager = MockVideoManager();
        for (final videoEvent in videoEvents) {
          await videoManager.addVideoEvent(videoEvent);
        }
        
        // 4. Verify ALL subsystems see same list
        final managerVideos = videoManager.videos;
        
        // UI should see exact same list (no filtering, no reordering)
        expect(managerVideos.length, equals(10));
        
        // Preloading logic should see exact same list  
        // (This was the bug: preloading used VideoEventService.videoEvents
        //  while UI used VideoCacheService.readyToPlayQueue)
        
        // 5. Simulate user scrolling to index 5
        const currentIndex = 5;
        final currentVideo = managerVideos[currentIndex];
        
        // 6. Verify preloading targets correct videos
        await videoManager.preloadAroundIndex(currentIndex, preloadRange: 2);
        
        // Videos at indices 3, 4, 5, 6, 7 should be preloaded
        for (int i = 3; i <= 7; i++) {
          final videoState = videoManager.getVideoState(managerVideos[i].id);
          expect(videoState?.loadingState, 
                 anyOf(equals(VideoLoadingState.loading), 
                      equals(VideoLoadingState.ready),
                      equals(VideoLoadingState.failed)));
        }
        
        // 7. Critical test: Video order must NEVER change unexpectedly
        final finalVideos = videoManager.videos;
        expect(finalVideos, equals(managerVideos)); // Exact same order
        expect(finalVideos[currentIndex], equals(currentVideo)); // Same video at same index
      });

      testWidgets('should eliminate index mismatch bugs completely', (tester) async {
        // Test: INDEX MISMATCH was the root cause of crashes
        
        // REPRODUCING THE BUG:
        // 1. VideoEventService gets 10 events immediately
        // 2. VideoCacheService processes only 3 successfully (network issues)
        // 3. UI shows ready queue: [video1, video2, video3] (length 3)
        // 4. User scrolls to index 2 in UI
        // 5. Preloading logic uses all events list, tries to preload event at index 5
        // 6. INDEX 5 DOESN'T EXIST in ready queue → CRASH
        
        final videoManager = MockVideoManager();
        
        // Add 10 videos
        for (int i = 0; i < 10; i++) {
          await videoManager.addVideoEvent(_createMockVideoEvent('video_$i'));
        }
        
        // Simulate some videos failing to preload (network issues)
        for (int i = 0; i < 10; i++) {
          if (i < 3) {
            // First 3 videos succeed
            await videoManager.preloadVideo('video_$i');
          } else {
            // Remaining videos fail
            // (In old system, these would be in VideoEventService but not VideoCacheService)
          }
        }
        
        // CRITICAL: VideoManager must always provide complete list
        // Even if some videos are not ready, they should still be in the list
        final allVideos = videoManager.videos;
        expect(allVideos.length, equals(10)); // All videos present
        
        // User scrolls to any valid index
        for (int userIndex = 0; userIndex < allVideos.length; userIndex++) {
          final videoAtIndex = allVideos[userIndex];
          expect(videoAtIndex, isNotNull);
          expect(videoAtIndex.id, equals('video_$userIndex'));
          
          // Preloading logic should be able to safely access this index
          expect(() => videoManager.getVideoState(videoAtIndex.id), returnsNormally);
        }
      });

      testWidgets('should handle rapid video additions without corruption', (tester) async {
        // Test: Rapid Nostr events should not corrupt video list
        
        final videoManager = MockVideoManager();
        final futures = <Future<void>>[];
        
        // Simulate rapid burst of Nostr events (realistic scenario)
        for (int i = 0; i < 50; i++) {
          futures.add(videoManager.addVideoEvent(_createMockVideoEvent('burst_video_$i')));
        }
        
        // All additions should complete without corruption
        await Future.wait(futures);
        
        final videos = videoManager.videos;
        expect(videos.length, equals(50));
        
        // Videos should be in correct order
        for (int i = 0; i < 50; i++) {
          expect(videos[i].id, equals('burst_video_$i'));
        }
        
        // No duplicates
        final uniqueIds = videos.map((v) => v.id).toSet();
        expect(uniqueIds.length, equals(50));
      });
    });

    group('Memory Management Integration', () {
      testWidgets('should stay under 500MB memory limit', (tester) async {
        // Test: CRITICAL - Prevent 3GB memory usage
        
        final videoManager = MockVideoManager();
        
        // Load 100 videos (realistic feed size)
        for (int i = 0; i < 100; i++) {
          await videoManager.addVideoEvent(_createMockVideoEvent('memory_test_$i'));
        }
        
        // Simulate user scrolling through all videos
        for (int currentIndex = 0; currentIndex < 100; currentIndex += 10) {
          await videoManager.preloadAroundIndex(currentIndex, preloadRange: 3);
          
          // Check memory usage after each scroll
          final debugInfo = videoManager.debugInfo;
          final activeControllers = debugInfo['activeControllers'] as int;
          
          // Should never exceed 15 controllers (target: <500MB)
          expect(activeControllers, lessThanOrEqualTo(15));
          
          // Verify distant videos are cleaned up
          if (currentIndex > 10) {
            final distantVideoId = 'memory_test_${currentIndex - 10}';
            final distantState = videoManager.getVideoState(distantVideoId);
            expect(distantState?.loadingState, 
                   anyOf(equals(VideoLoadingState.disposed), 
                        equals(VideoLoadingState.notLoaded)));
          }
        }
      });

      testWidgets('should handle memory pressure gracefully', (tester) async {
        // Test: System should degrade gracefully under memory pressure
        
        final videoManager = MockVideoManager();
        
        // Load many videos and preload them
        for (int i = 0; i < 20; i++) {
          await videoManager.addVideoEvent(_createMockVideoEvent('pressure_test_$i'));
          await videoManager.preloadVideo('pressure_test_$i');
        }
        
        // Simulate memory pressure
        await videoManager.handleMemoryPressure();
        
        // Should dispose non-essential videos
        final debugInfo = videoManager.debugInfo;
        final activeControllers = debugInfo['activeControllers'] as int;
        
        expect(activeControllers, lessThan(10)); // Aggressive cleanup under pressure
        
        // Core functionality should still work
        await videoManager.addVideoEvent(_createMockVideoEvent('new_video_after_pressure'));
        expect(videoManager.videos.last.id, equals('new_video_after_pressure'));
      });

      testWidgets('should prevent VideoPlayerController disposal crashes', (tester) async {
        // Test: "VideoPlayerController was disposed" errors must not occur
        
        final videoManager = MockVideoManager();
        
        await videoManager.addVideoEvent(_createMockVideoEvent('disposal_test'));
        await videoManager.preloadVideo('disposal_test');
        
        // Video should be ready
        var videoState = videoManager.getVideoState('disposal_test');
        expect(videoState?.loadingState, 
               anyOf(equals(VideoLoadingState.ready), equals(VideoLoadingState.loading)));
        
        // Force cleanup (simulate user scrolling away)
        await videoManager.cleanupDistantVideos(currentIndex: 100, keepRange: 3);
        
        // State should be safely disposed
        videoState = videoManager.getVideoState('disposal_test');
        expect(videoState?.loadingState, 
               anyOf(equals(VideoLoadingState.disposed), equals(VideoLoadingState.notLoaded)));
        
        // Multiple cleanup calls should be safe
        expect(() => videoManager.cleanupDistantVideos(currentIndex: 100, keepRange: 3), 
               returnsNormally);
      });
    });

    group('Error Handling and Recovery', () {
      testWidgets('should handle network failures gracefully', (tester) async {
        // Test: Network issues should not crash video system
        
        final videoManager = MockVideoManager();
        
        // Add videos with invalid URLs
        await videoManager.addVideoEvent(VideoEvent(
          id: 'invalid_video',
          pubkey: 'test_pubkey',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          content: 'Invalid video',
          timestamp: DateTime.now(),
          videoUrl: 'https://invalid-domain.com/video.mp4',
          title: 'Invalid Video',
        ));
        
        // Preloading should fail gracefully
        await videoManager.preloadVideo('invalid_video');
        
        final videoState = videoManager.getVideoState('invalid_video');
        expect(videoState?.loadingState, 
               anyOf(equals(VideoLoadingState.failed), equals(VideoLoadingState.permanentlyFailed)));
        
        // System should continue working with other videos
        await videoManager.addVideoEvent(_createMockVideoEvent('valid_video'));
        expect(videoManager.videos.length, equals(2));
      });

      testWidgets('should implement circuit breaker pattern', (tester) async {
        // Test: Prevent infinite retry loops for failing videos
        
        final videoManager = MockVideoManager();
        
        await videoManager.addVideoEvent(VideoEvent(
          id: 'circuit_breaker_test',
          pubkey: 'test_pubkey',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          content: 'Circuit breaker test',
          timestamp: DateTime.now(),
          videoUrl: 'https://failing-server.com/video.mp4',
          title: 'Circuit Breaker Test',
        ));
        
        // Attempt preloading multiple times (should eventually stop retrying)
        for (int attempt = 0; attempt < 10; attempt++) {
          await videoManager.preloadVideo('circuit_breaker_test');
        }
        
        final videoState = videoManager.getVideoState('circuit_breaker_test');
        expect(videoState?.loadingState, equals(VideoLoadingState.permanentlyFailed));
        expect(videoState?.canRetry, isFalse);
      });

      testWidgets('should recover from controller initialization failures', (tester) async {
        // Test: Controller init failures should not crash system
        
        final videoManager = MockVideoManager();
        
        // Add video that will fail initialization
        await videoManager.addVideoEvent(VideoEvent(
          id: 'init_failure_test',
          pubkey: 'test_pubkey',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          content: 'Init failure test',
          timestamp: DateTime.now(),
          videoUrl: 'https://example.com/corrupted.mp4',
          title: 'Init Failure Test',
        ));
        
        // Preloading should handle failure gracefully
        expect(() => videoManager.preloadVideo('init_failure_test'), returnsNormally);
        
        // System should remain stable
        await videoManager.addVideoEvent(_createMockVideoEvent('stable_video'));
        expect(videoManager.videos.length, equals(2));
      });
    });

    group('Performance Under Load', () {
      testWidgets('should handle rapid scrolling smoothly', (tester) async {
        // Test: TikTok-style rapid scrolling should not lag
        
        final videoManager = MockVideoManager();
        final stopwatch = Stopwatch()..start();
        
        // Load substantial video feed
        for (int i = 0; i < 100; i++) {
          await videoManager.addVideoEvent(_createMockVideoEvent('scroll_test_$i'));
        }
        
        // Simulate rapid scrolling (user swiping quickly)
        for (int index = 0; index < 100; index += 5) {
          await videoManager.preloadAroundIndex(index, preloadRange: 2);
          
          // Each scroll operation should be fast
          expect(stopwatch.elapsedMilliseconds, lessThan(index * 100)); // Linear time bound
        }
        
        stopwatch.stop();
        
        // Total time should be reasonable
        expect(stopwatch.elapsedMilliseconds, lessThan(10000)); // <10 seconds for 100 videos
      });

      testWidgets('should prioritize current video for instant playback', (tester) async {
        // Test: Current video should always have highest priority
        
        final videoManager = MockVideoManager();
        
        // Add videos
        for (int i = 0; i < 10; i++) {
          await videoManager.addVideoEvent(_createMockVideoEvent('priority_test_$i'));
        }
        
        // User is viewing video at index 5
        const currentIndex = 5;
        await videoManager.preloadAroundIndex(currentIndex, preloadRange: 2);
        
        // Current video should be ready first
        final currentVideoState = videoManager.getVideoState('priority_test_$currentIndex');
        expect(currentVideoState?.loadingState, 
               anyOf(equals(VideoLoadingState.ready), equals(VideoLoadingState.loading)));
        
        // Adjacent videos should have higher priority than distant ones
        final nextVideoState = videoManager.getVideoState('priority_test_${currentIndex + 1}');
        final distantVideoState = videoManager.getVideoState('priority_test_${currentIndex + 5}');
        
        // Next video should be more likely to be ready than distant video
        if (nextVideoState?.loadingState == VideoLoadingState.ready) {
          expect(distantVideoState?.loadingState, 
                 anyOf(equals(VideoLoadingState.notLoaded), 
                      equals(VideoLoadingState.loading)));
        }
      });

      testWidgets('should batch notifications to prevent rebuild loops', (tester) async {
        // Test: Prevent infinite UI rebuild loops from notification storms
        
        final videoManager = MockVideoManager();
        int notificationCount = 0;
        
        // Mock notification listener
        videoManager.addListener(() {
          notificationCount++;
        });
        
        // Add many videos rapidly (should be batched)
        final futures = <Future<void>>[];
        for (int i = 0; i < 20; i++) {
          futures.add(videoManager.addVideoEvent(_createMockVideoEvent('batch_test_$i')));
        }
        
        await Future.wait(futures);
        
        // Should not have 20 separate notifications (batching should reduce this)
        expect(notificationCount, lessThan(20));
        expect(notificationCount, greaterThan(0));
      });
    });

    group('Real-World Scenarios', () {
      testWidgets('should handle complete user session flow', (tester) async {
        // Test: Real user session from app start to background
        
        final videoManager = MockVideoManager();
        
        // 1. App startup - load initial feed
        for (int i = 0; i < 10; i++) {
          await videoManager.addVideoEvent(_createMockVideoEvent('session_$i'));
        }
        
        // 2. User scrolls to index 3
        await videoManager.preloadAroundIndex(3, preloadRange: 2);
        
        // 3. New videos arrive from Nostr
        for (int i = 10; i < 15; i++) {
          await videoManager.addVideoEvent(_createMockVideoEvent('session_$i'));
        }
        
        // 4. User continues scrolling
        await videoManager.preloadAroundIndex(7, preloadRange: 2);
        
        // 5. Memory pressure (other apps need memory)
        await videoManager.handleMemoryPressure();
        
        // 6. User returns to app
        await videoManager.preloadAroundIndex(7, preloadRange: 2);
        
        // 7. App goes to background
        await videoManager.dispose();
        
        // All operations should complete without errors
        expect(videoManager.videos.length, equals(15));
      });

      testWidgets('should handle edge case: no videos available', (tester) async {
        // Test: System should work even with empty feed
        
        final videoManager = MockVideoManager();
        
        // Operations on empty feed should not crash
        expect(videoManager.videos, isEmpty);
        expect(() => videoManager.preloadAroundIndex(0, preloadRange: 2), returnsNormally);
        expect(videoManager.getVideoState('nonexistent'), isNull);
        
        // Adding first video should work
        await videoManager.addVideoEvent(_createMockVideoEvent('first_video'));
        expect(videoManager.videos.length, equals(1));
      });

      testWidgets('should handle edge case: single video in feed', (tester) async {
        // Test: System should work with just one video
        
        final videoManager = MockVideoManager();
        
        await videoManager.addVideoEvent(_createMockVideoEvent('only_video'));
        
        // Preloading single video should work
        await videoManager.preloadAroundIndex(0, preloadRange: 5);
        
        final videoState = videoManager.getVideoState('only_video');
        expect(videoState, isNotNull);
        expect(videoState?.loadingState, 
               anyOf(equals(VideoLoadingState.loading), 
                    equals(VideoLoadingState.ready),
                    equals(VideoLoadingState.failed)));
      });
    });
  });
}

// Helper functions for creating test data

List<Event> _createMockNostrEvents({required int count}) {
  return List.generate(count, (index) {
    return Event(
      id: 'nostr_event_$index',
      pubkey: 'test_pubkey_$index',
      createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 - index,
      kind: 22, // NIP-71 video event
      content: 'Test video content $index',
      tags: [
        ['url', 'https://example.com/video$index.mp4'],
        ['title', 'Test Video $index'],
        ['t', 'test'],
        ['duration', '30'],
        ['dim', '1920x1080'],
      ],
      sig: 'test_signature_$index',
    );
  });
}

VideoEvent _createMockVideoEvent(String id) {
  return VideoEvent(
    id: id,
    pubkey: 'test_pubkey',
    createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    content: 'Test video content for $id',
    timestamp: DateTime.now(),
    videoUrl: 'https://example.com/$id.mp4',
    title: 'Test Video $id',
    hashtags: ['test'],
    duration: 30,
    dimensions: '1920x1080',
  );
}

// Mock classes for testing
class MockVideoManager extends Mock implements IVideoManager {
  final List<VideoEvent> _videos = [];
  final Map<String, VideoState> _states = {};
  final List<VoidCallback> _listeners = [];
  
  @override
  List<VideoEvent> get videos => List.unmodifiable(_videos);
  
  @override
  VideoState? getVideoState(String videoId) => _states[videoId];
  
  @override
  Future<void> addVideoEvent(VideoEvent event) async {
    if (!_videos.any((v) => v.id == event.id)) {
      _videos.add(event);
      _states[event.id] = VideoState(
        event: event,
        loadingState: VideoLoadingState.notLoaded,
      );
      _notifyListeners();
    }
  }
  
  @override
  Future<void> preloadVideo(String videoId) async {
    final state = _states[videoId];
    if (state != null) {
      _states[videoId] = state.toLoading();
      _notifyListeners();
      
      // Simulate async preloading
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Simulate success/failure based on video ID
      if (videoId.contains('invalid') || videoId.contains('failing')) {
        _states[videoId] = state.toFailed('Simulated network error');
      } else {
        _states[videoId] = state.toReady();
      }
      _notifyListeners();
    }
  }
  
  @override
  void dispose() {
    for (final state in _states.values) {
      _states[state.event.id] = state.toDisposed();
    }
    _listeners.clear();
  }
  
  // Test-specific methods
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }
  
  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }
  
  Map<String, dynamic> get debugInfo => {
    'activeControllers': _states.values.where((s) => s.loadingState == VideoLoadingState.ready).length,
    'memoryUsage': {'total': '400MB', 'videos': '300MB'},
    'stateDistribution': _getStateDistribution(),
  };
  
  Map<String, int> _getStateDistribution() {
    final distribution = <String, int>{};
    for (final state in _states.values) {
      final stateName = state.loadingState.toString().split('.').last;
      distribution[stateName] = (distribution[stateName] ?? 0) + 1;
    }
    return distribution;
  }
  
  Future<void> preloadAroundIndex(int index, {required int preloadRange}) async {
    final start = (index - preloadRange).clamp(0, _videos.length - 1);
    final end = (index + preloadRange).clamp(0, _videos.length - 1);
    
    for (int i = start; i <= end; i++) {
      await preloadVideo(_videos[i].id);
    }
  }
  
  Future<void> cleanupDistantVideos({required int currentIndex, required int keepRange}) async {
    for (int i = 0; i < _videos.length; i++) {
      if ((i - currentIndex).abs() > keepRange) {
        final state = _states[_videos[i].id];
        if (state != null) {
          _states[_videos[i].id] = state.toDisposed();
        }
      }
    }
    _notifyListeners();
  }
  
  Future<void> handleMemoryPressure() async {
    // Dispose half of the ready videos (keep only essential ones)
    final readyStates = _states.entries
        .where((entry) => entry.value.loadingState == VideoLoadingState.ready)
        .take(_states.length ~/ 2);
    
    for (final entry in readyStates) {
      _states[entry.key] = entry.value.toDisposed();
    }
    _notifyListeners();
  }
}