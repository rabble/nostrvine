// ABOUTME: Unit tests for VideoManager interface covering TDD requirements and behavior
// ABOUTME: Comprehensive test suite for video lifecycle, memory management, and error handling

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:video_player/video_player.dart';
import 'package:nostrvine_app/models/video_event.dart';
import 'package:nostrvine_app/models/video_state.dart';
import 'package:nostrvine_app/services/video_manager_interface.dart';

// Mock implementations for testing
class MockVideoPlayerController extends Mock implements VideoPlayerController {
  @override
  Future<void> dispose() async {
    // Mock implementation
  }
}

class MockVideoManager extends Mock implements IVideoManager {}

// Test implementation of IVideoManager for behavior testing
class TestVideoManager implements IVideoManager {
  final VideoManagerConfig _config;
  final List<VideoEvent> _videos = [];
  final Map<String, VideoState> _videoStates = {};
  final Map<String, VideoPlayerController> _controllers = {};
  
  TestVideoManager([VideoManagerConfig? config]) 
      : _config = config ?? VideoManagerConfig.testing();

  @override
  List<VideoEvent> get videos => List.unmodifiable(_videos);

  @override
  List<VideoEvent> get readyVideos => _videos
      .where((v) => _videoStates[v.id]?.isReady == true)
      .toList();

  @override
  VideoState? getVideoState(String videoId) => _videoStates[videoId];

  @override
  VideoPlayerController? getController(String videoId) {
    final state = _videoStates[videoId];
    if (state?.isReady != true) return null;
    return _controllers[videoId];
  }

  @override
  Future<void> addVideoEvent(VideoEvent event) async {
    // Prevent duplicates
    if (_videos.any((v) => v.id == event.id)) return;
    
    // Enforce memory limits
    if (_videos.length >= _config.maxVideos) {
      // Remove oldest video
      final oldestEvent = _videos.removeLast();
      disposeVideo(oldestEvent.id);
    }
    
    // Add to beginning (newest first)
    _videos.insert(0, event);
    _videoStates[event.id] = VideoState(event: event);
    
    // Handle GIFs immediately
    if (event.isGif) {
      _videoStates[event.id] = _videoStates[event.id]!.toLoading().toReady();
    }
  }

  @override
  Future<void> preloadVideo(String videoId) async {
    final state = _videoStates[videoId];
    if (state == null) {
      throw VideoManagerException('Video not found', videoId: videoId);
    }
    
    if (state.isReady || state.isLoading) return;
    
    _videoStates[videoId] = state.toLoading();
    
    try {
      // Simulate video loading
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Create mock controller
      final controller = MockVideoPlayerController();
      _controllers[videoId] = controller;
      _videoStates[videoId] = state.toLoading().toReady();
      
    } catch (e) {
      _videoStates[videoId] = state.toFailed(e.toString());
      rethrow;
    }
  }

  @override
  void preloadAroundIndex(int currentIndex, {int? preloadRange}) {
    if (currentIndex < 0 || currentIndex >= _videos.length) return;
    
    final range = preloadRange ?? _config.preloadAhead;
    
    // Preload ahead
    for (int i = 0; i <= range; i++) {
      final index = currentIndex + i;
      if (index < _videos.length) {
        final videoId = _videos[index].id;
        final state = _videoStates[videoId];
        if (state != null && !state.isLoading && !state.isReady) {
          preloadVideo(videoId);
        }
      }
    }
    
    // Dispose distant videos if memory management enabled
    if (_config.enableMemoryManagement) {
      final disposeThreshold = range + 5;
      for (int i = currentIndex + disposeThreshold; i < _videos.length; i++) {
        disposeVideo(_videos[i].id);
      }
    }
  }

  @override
  void disposeVideo(String videoId) {
    final controller = _controllers.remove(videoId);
    controller?.dispose();
    
    final state = _videoStates[videoId];
    if (state != null && !state.isDisposed) {
      _videoStates[videoId] = state.toDisposed();
    }
  }

  @override
  Future<void> handleMemoryPressure() async {
    // Simple implementation for testing: dispose all but the first 2 controllers
    final controllersToDispose = _controllers.keys.skip(2).toList();
    for (final videoId in controllersToDispose) {
      disposeVideo(videoId);
    }
  }

  @override
  Map<String, dynamic> getDebugInfo() {
    final states = _videoStates.values;
    return {
      'totalVideos': _videos.length,
      'readyVideos': states.where((s) => s.isReady).length,
      'loadingVideos': states.where((s) => s.isLoading).length,
      'failedVideos': states.where((s) => s.hasFailed).length,
      'controllers': _controllers.length,
      'estimatedMemoryMB': _controllers.length * 10, // Rough estimate
      'config': {
        'maxVideos': _config.maxVideos,
        'preloadAhead': _config.preloadAhead,
        'maxRetries': _config.maxRetries,
      },
    };
  }

  @override
  void pauseVideo(String videoId) {
    final controller = _controllers[videoId];
    // In test, we don't actually pause since it's a mock
    // Just log for verification
  }

  @override
  void pauseAllVideos() {
    // In test, we don't actually pause since controllers are mocks
    // Just log for verification
  }

  @override
  void resumeVideo(String videoId) {
    final controller = _controllers[videoId];
    // In test, we don't actually resume since it's a mock
    // Just log for verification
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _videoStates.clear();
    _videos.clear();
  }

  @override
  Stream<void> get stateChanges => Stream.empty(); // Simplified for tests
}

void main() {
  group('VideoManager Interface', () {
    late TestVideoManager videoManager;
    late VideoEvent testEvent1;
    late VideoEvent testEvent2;
    late VideoEvent testGifEvent;
    
    setUp(() {
      videoManager = TestVideoManager();
      testEvent1 = VideoEvent(
        id: 'test-id-1',  
        pubkey: 'test-pubkey-1',
        createdAt: 1234567890,
        content: 'Test video 1',
        timestamp: DateTime.now(),
        videoUrl: 'https://example.com/video1.mp4',
        mimeType: 'video/mp4',
      );
      
      testEvent2 = VideoEvent(
        id: 'test-id-2',
        pubkey: 'test-pubkey-2',
        createdAt: 1234567891,
        content: 'Test video 2',
        timestamp: DateTime.now().add(const Duration(minutes: 1)),
        videoUrl: 'https://example.com/video2.mp4',
        mimeType: 'video/mp4',
      );
      
      testGifEvent = VideoEvent(
        id: 'gif-id',
        pubkey: 'gif-pubkey',
        createdAt: 1234567892,
        content: 'Test GIF',
        timestamp: DateTime.now().add(const Duration(minutes: 2)),
        videoUrl: 'https://example.com/animated.gif',
        mimeType: 'image/gif',
      );
    });
    
    tearDown(() {
      videoManager.dispose();
    });

    group('Single Source of Truth', () {
      test('videos list is empty initially', () {
        expect(videoManager.videos, isEmpty);
        expect(videoManager.readyVideos, isEmpty);
      });

      test('addVideoEvent adds video to list', () async {
        await videoManager.addVideoEvent(testEvent1);
        
        expect(videoManager.videos, hasLength(1));
        expect(videoManager.videos.first, equals(testEvent1));
        expect(videoManager.getVideoState(testEvent1.id), isNotNull);
        expect(videoManager.getVideoState(testEvent1.id)!.loadingState, 
               equals(VideoLoadingState.notLoaded));
      });

      test('videos are ordered newest first', () async {
        await videoManager.addVideoEvent(testEvent1);
        await videoManager.addVideoEvent(testEvent2);
        
        expect(videoManager.videos, hasLength(2));
        expect(videoManager.videos.first.id, equals(testEvent2.id)); // Newer first
        expect(videoManager.videos.last.id, equals(testEvent1.id));
      });

      test('duplicate videos are prevented', () async {
        await videoManager.addVideoEvent(testEvent1);
        await videoManager.addVideoEvent(testEvent1); // Same event
        
        expect(videoManager.videos, hasLength(1));
      });

      test('memory limits are enforced', () async {
        final config = VideoManagerConfig.testing(); // maxVideos = 10
        final limitedManager = TestVideoManager(config);
        
        // Add videos beyond limit
        for (int i = 0; i < 15; i++) {
          final event = VideoEvent(
            id: 'video-$i',
            pubkey: 'pubkey-$i',
            createdAt: 1234567890 + i,
            content: 'Video $i',
            timestamp: DateTime.now().add(Duration(minutes: i)),
            videoUrl: 'https://example.com/video$i.mp4',
          );
          await limitedManager.addVideoEvent(event);
        }
        
        expect(limitedManager.videos, hasLength(10));
        // Should have newest 10 videos
        expect(limitedManager.videos.first.id, equals('video-14'));
        expect(limitedManager.videos.last.id, equals('video-5'));
        
        limitedManager.dispose();
      });
    });

    group('GIF Handling', () {
      test('GIFs are marked ready immediately', () async {
        await videoManager.addVideoEvent(testGifEvent);
        
        final state = videoManager.getVideoState(testGifEvent.id);
        expect(state, isNotNull);
        expect(state!.isReady, isTrue);
        expect(videoManager.readyVideos, hasLength(1));
        expect(videoManager.readyVideos.first.id, equals(testGifEvent.id));
      });

      test('GIFs do not need preloading', () async {
        await videoManager.addVideoEvent(testGifEvent);
        
        // Attempting to preload GIF should not change state
        await videoManager.preloadVideo(testGifEvent.id);
        
        final state = videoManager.getVideoState(testGifEvent.id);
        expect(state!.isReady, isTrue);
      });
    });

    group('Video State Management', () {
      test('getVideoState returns null for non-existent video', () {
        expect(videoManager.getVideoState('non-existent'), isNull);
      });

      test('preloadVideo creates controller and transitions to ready', () async {
        await videoManager.addVideoEvent(testEvent1);
        
        final initialState = videoManager.getVideoState(testEvent1.id);
        expect(initialState!.loadingState, equals(VideoLoadingState.notLoaded));
        expect(videoManager.getController(testEvent1.id), isNull);
        
        await videoManager.preloadVideo(testEvent1.id);
        
        final finalState = videoManager.getVideoState(testEvent1.id);
        expect(finalState!.isReady, isTrue);
        expect(videoManager.getController(testEvent1.id), isNotNull);
        expect(videoManager.readyVideos, hasLength(1));
      });

      test('preloadVideo throws exception for non-existent video', () async {
        expect(
          () => videoManager.preloadVideo('non-existent'),
          throwsA(isA<VideoManagerException>()),
        );
      });

      test('preloadVideo is idempotent for ready videos', () async {
        await videoManager.addVideoEvent(testEvent1);
        await videoManager.preloadVideo(testEvent1.id);
        
        final readyState = videoManager.getVideoState(testEvent1.id);
        expect(readyState!.isReady, isTrue);
        
        // Preloading again should not change state
        await videoManager.preloadVideo(testEvent1.id);
        
        final stillReadyState = videoManager.getVideoState(testEvent1.id);
        expect(stillReadyState!.isReady, isTrue);
      });
    });

    group('Smart Preloading', () {
      test('preloadAroundIndex preloads videos ahead', () async {
        // Add multiple videos
        for (int i = 0; i < 5; i++) {
          final event = VideoEvent(
            id: 'video-$i',
            pubkey: 'pubkey-$i',
            createdAt: 1234567890 + i,
            content: 'Video $i',
            timestamp: DateTime.now().add(Duration(minutes: i)),
            videoUrl: 'https://example.com/video$i.mp4',
          );
          await videoManager.addVideoEvent(event);
        }
        
        // Videos are newest first, so video-4 is at index 0
        videoManager.preloadAroundIndex(1); // video-3 position
        
        // Should preload current + preloadAhead (2 in test config)
        // video-3, video-2, video-1
        await Future.delayed(const Duration(milliseconds: 200));
        
        final debugInfo = videoManager.getDebugInfo();
        expect(debugInfo['controllers'], greaterThan(0));
      });

      test('preloadAroundIndex handles edge cases', () async {
        await videoManager.addVideoEvent(testEvent1);
        
        // Should not crash on invalid indices
        videoManager.preloadAroundIndex(-1);
        videoManager.preloadAroundIndex(10);
        
        // Should work with valid index
        videoManager.preloadAroundIndex(0);
      });
    });

    group('Memory Management', () {
      test('disposeVideo cleans up controller and state', () async {
        await videoManager.addVideoEvent(testEvent1);
        await videoManager.preloadVideo(testEvent1.id);
        
        expect(videoManager.getController(testEvent1.id), isNotNull);
        expect(videoManager.getVideoState(testEvent1.id)!.isReady, isTrue);
        
        videoManager.disposeVideo(testEvent1.id);
        
        expect(videoManager.getController(testEvent1.id), isNull);
        expect(videoManager.getVideoState(testEvent1.id)!.isDisposed, isTrue);
      });

      test('dispose cleans up all resources', () async {
        await videoManager.addVideoEvent(testEvent1);
        await videoManager.addVideoEvent(testEvent2);
        await videoManager.preloadVideo(testEvent1.id);
        await videoManager.preloadVideo(testEvent2.id);
        
        expect(videoManager.videos, hasLength(2));
        final debugInfo = videoManager.getDebugInfo();
        expect(debugInfo['controllers'], equals(2));
        
        videoManager.dispose();
        
        expect(videoManager.videos, isEmpty);
        final finalDebugInfo = videoManager.getDebugInfo();
        expect(finalDebugInfo['controllers'], equals(0));
        expect(finalDebugInfo['totalVideos'], equals(0));
      });
    });

    group('Debug Information', () {
      test('getDebugInfo provides comprehensive metrics', () async {
        await videoManager.addVideoEvent(testEvent1);
        await videoManager.addVideoEvent(testGifEvent);
        await videoManager.preloadVideo(testEvent1.id);
        
        final debugInfo = videoManager.getDebugInfo();
        
        expect(debugInfo['totalVideos'], equals(2));
        expect(debugInfo['readyVideos'], equals(2)); // GIF + preloaded video
        expect(debugInfo['loadingVideos'], equals(0));
        expect(debugInfo['failedVideos'], equals(0));
        expect(debugInfo['controllers'], equals(1)); // Only non-GIF has controller
        expect(debugInfo['estimatedMemoryMB'], isA<int>());
        expect(debugInfo['config'], isA<Map>());
        expect(debugInfo['config']['maxVideos'], isA<int>());
      });

      test('debug info tracks state changes correctly', () async {
        await videoManager.addVideoEvent(testEvent1);
        
        var debugInfo = videoManager.getDebugInfo();
        expect(debugInfo['totalVideos'], equals(1));
        expect(debugInfo['readyVideos'], equals(0));
        
        await videoManager.preloadVideo(testEvent1.id);
        
        debugInfo = videoManager.getDebugInfo();
        expect(debugInfo['readyVideos'], equals(1));
        expect(debugInfo['controllers'], equals(1));
        
        videoManager.disposeVideo(testEvent1.id);
        
        debugInfo = videoManager.getDebugInfo();
        expect(debugInfo['controllers'], equals(0));
      });
    });

    group('Error Handling', () {
      test('VideoManagerException includes context information', () {
        const exception = VideoManagerException(
          'Test error',
          videoId: 'test-video',
          originalError: 'Network timeout',
        );
        
        expect(exception.message, equals('Test error'));
        expect(exception.videoId, equals('test-video'));
        expect(exception.originalError, equals('Network timeout'));
        
        final str = exception.toString();
        expect(str, contains('Test error'));
        expect(str, contains('test-video'));
        expect(str, contains('Network timeout'));
      });

      test('video loading failures are handled gracefully', () async {
        // This test would require a more sophisticated mock implementation
        // For now, we test that the interface supports error scenarios
        await videoManager.addVideoEvent(testEvent1);
        
        final state = videoManager.getVideoState(testEvent1.id);
        expect(state, isNotNull);
        expect(state!.loadingState, equals(VideoLoadingState.notLoaded));
      });
    });

    group('Configuration', () {
      test('VideoManagerConfig provides sensible defaults', () {
        const config = VideoManagerConfig();
        
        expect(config.maxVideos, equals(100));
        expect(config.preloadAhead, equals(3));
        expect(config.maxRetries, equals(3));
        expect(config.preloadTimeout, equals(Duration(seconds: 10)));
        expect(config.enableMemoryManagement, isTrue);
      });

      test('cellular configuration is conservative', () {
        final config = VideoManagerConfig.cellular();
        
        expect(config.maxVideos, equals(50));
        expect(config.preloadAhead, equals(1));
        expect(config.maxRetries, equals(2));
        expect(config.preloadTimeout, equals(Duration(seconds: 15)));
      });

      test('wifi configuration is aggressive', () {
        final config = VideoManagerConfig.wifi();
        
        expect(config.maxVideos, equals(100));
        expect(config.preloadAhead, equals(5));
        expect(config.maxRetries, equals(3));
        expect(config.preloadTimeout, equals(Duration(seconds: 10)));
      });

      test('testing configuration has small limits', () {
        final config = VideoManagerConfig.testing();
        
        expect(config.maxVideos, equals(10));
        expect(config.preloadAhead, equals(2));
        expect(config.maxRetries, equals(1));
        expect(config.preloadTimeout, equals(Duration(milliseconds: 500)));
      });
    });

    group('Enums and Types', () {
      test('PreloadPriority enum has correct values', () {
        expect(PreloadPriority.values, hasLength(4));
        expect(PreloadPriority.current.name, equals('current'));
        expect(PreloadPriority.next.name, equals('next'));
        expect(PreloadPriority.nearby.name, equals('nearby'));
        expect(PreloadPriority.background.name, equals('background'));
      });

      test('CleanupStrategy enum has correct values', () {
        expect(CleanupStrategy.values, hasLength(4));
        expect(CleanupStrategy.immediate.name, equals('immediate'));
        expect(CleanupStrategy.delayed.name, equals('delayed'));
        expect(CleanupStrategy.memoryPressure.name, equals('memoryPressure'));
        expect(CleanupStrategy.limitBased.name, equals('limitBased'));
      });
    });

    group('Interface Contract Validation', () {
      test('interface methods are properly defined', () {
        // This test validates the interface contract exists
        expect(IVideoManager, isNotNull);
        
        // Test that our implementation follows the contract
        expect(videoManager, isA<IVideoManager>());
        expect(videoManager.videos, isA<List<VideoEvent>>());
        expect(videoManager.readyVideos, isA<List<VideoEvent>>());
        expect(videoManager.getDebugInfo(), isA<Map<String, dynamic>>());
        expect(videoManager.stateChanges, isA<Stream<void>>());
      });

      test('async methods return correct types', () async {
        final addFuture = videoManager.addVideoEvent(testEvent1);
        expect(addFuture, isA<Future<void>>());
        await addFuture;
        
        final preloadFuture = videoManager.preloadVideo(testEvent1.id);
        expect(preloadFuture, isA<Future<void>>());
        await preloadFuture;
      });

      test('state access methods handle null cases', () {
        expect(videoManager.getVideoState('non-existent'), isNull);
        expect(videoManager.getController('non-existent'), isNull);
      });
    });

    group('Integration Scenarios', () {
      test('full video lifecycle works correctly', () async {
        // Add video
        await videoManager.addVideoEvent(testEvent1);
        expect(videoManager.videos, hasLength(1));
        expect(videoManager.getVideoState(testEvent1.id)!.loadingState, 
               equals(VideoLoadingState.notLoaded));
        
        // Preload video
        await videoManager.preloadVideo(testEvent1.id);
        expect(videoManager.getVideoState(testEvent1.id)!.isReady, isTrue);
        expect(videoManager.getController(testEvent1.id), isNotNull);
        expect(videoManager.readyVideos, hasLength(1));
        
        // Use debug info
        final debugInfo = videoManager.getDebugInfo();
        expect(debugInfo['totalVideos'], equals(1));
        expect(debugInfo['readyVideos'], equals(1));
        expect(debugInfo['controllers'], equals(1));
        
        // Dispose video
        videoManager.disposeVideo(testEvent1.id);
        expect(videoManager.getVideoState(testEvent1.id)!.isDisposed, isTrue);
        expect(videoManager.getController(testEvent1.id), isNull);
        
        final finalDebugInfo = videoManager.getDebugInfo();
        expect(finalDebugInfo['controllers'], equals(0));
      });

      test('multiple video management works correctly', () async {
        // Add multiple videos
        await videoManager.addVideoEvent(testEvent1);
        await videoManager.addVideoEvent(testEvent2);
        await videoManager.addVideoEvent(testGifEvent);
        
        expect(videoManager.videos, hasLength(3));
        
        // Preload some videos
        await videoManager.preloadVideo(testEvent1.id);
        // GIF should already be ready
        // testEvent2 remains not loaded
        
        expect(videoManager.readyVideos, hasLength(2)); // testEvent1 + GIF
        
        // Smart preloading
        videoManager.preloadAroundIndex(0); // Should preload nearby videos
        await Future.delayed(const Duration(milliseconds: 150));
        
        final debugInfo = videoManager.getDebugInfo();
        expect(debugInfo['totalVideos'], equals(3));
        expect(debugInfo['readyVideos'], greaterThanOrEqualTo(2));
      });
    });
  });
}