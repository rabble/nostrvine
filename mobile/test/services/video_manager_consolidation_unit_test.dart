// ABOUTME: Unit tests for VideoManagerService consolidation without video player dependencies
// ABOUTME: Tests core functionality, state management, and legacy service replacement

import 'package:flutter_test/flutter_test.dart';
import 'package:nostrvine_app/services/video_manager_service.dart';
import 'package:nostrvine_app/services/video_manager_interface.dart';
import 'package:nostrvine_app/models/video_event.dart';
import 'package:nostrvine_app/models/video_state.dart';

void main() {
  group('VideoManagerService Unit Tests', () {
    late VideoManagerService videoManager;
    
    setUp(() {
      videoManager = VideoManagerService(
        config: VideoManagerConfig.testing(),
      );
    });

    tearDown(() {
      videoManager.dispose();
    });

    group('Core Video Management', () {
      test('should add video events and track state', () async {
        // Arrange
        final videoEvent = VideoEvent(
          id: 'test123456789',
          pubkey: 'author456',
          createdAt: 1000,
          content: 'Test video',
          timestamp: DateTime.now(),
          videoUrl: 'https://example.com/video.mp4',
        );

        // Act
        await videoManager.addVideoEvent(videoEvent);

        // Assert
        expect(videoManager.videos.length, equals(1));
        expect(videoManager.videos.first.id, equals('test123456789'));
        
        final state = videoManager.getVideoState('test123456789');
        expect(state, isNotNull);
        expect(state!.loadingState, equals(VideoLoadingState.notLoaded));
        expect(state.event.id, equals('test123456789'));
      });

      test('should handle multiple videos in newest-first order', () async {
        // Arrange
        final videos = List.generate(5, (index) => VideoEvent(
          id: 'video${index}12345678',
          pubkey: 'author$index',
          createdAt: 1000 + index,
          content: 'Video $index',
          timestamp: DateTime.now().add(Duration(seconds: index)),
          videoUrl: 'https://example.com/video$index.mp4',
        ));

        // Act
        for (final video in videos) {
          await videoManager.addVideoEvent(video);
        }

        // Assert
        expect(videoManager.videos.length, equals(5));
        // Videos are stored newest-first
        expect(videoManager.videos.map((v) => v.id).toList(), 
          equals(['video412345678', 'video312345678', 'video212345678', 'video112345678', 'video012345678']));
      });

      test('should prevent duplicate videos', () async {
        // Arrange
        final videoEvent = VideoEvent(
          id: 'test123456789',
          pubkey: 'author456',
          createdAt: 1000,
          content: 'Test video',
          timestamp: DateTime.now(),
          videoUrl: 'https://example.com/video.mp4',
        );

        // Act
        await videoManager.addVideoEvent(videoEvent);
        await videoManager.addVideoEvent(videoEvent); // Try to add duplicate

        // Assert
        expect(videoManager.videos.length, equals(1));
      });

      test('should validate video events', () async {
        // Arrange
        final invalidVideo = VideoEvent(
          id: '', // Invalid empty ID
          pubkey: 'author456',
          createdAt: 1000,
          content: 'Test video',
          timestamp: DateTime.now(),
          videoUrl: 'https://example.com/video.mp4',
        );

        // Act & Assert
        expect(
          () async => await videoManager.addVideoEvent(invalidVideo),
          throwsA(isA<VideoManagerException>()),
        );
      });
    });

    group('Video State Management', () {
      test('should initialize videos with notLoaded state', () async {
        // Arrange
        final videoEvent = VideoEvent(
          id: 'test123456789',
          pubkey: 'author456',
          createdAt: 1000,
          content: 'Test video',
          timestamp: DateTime.now(),
          videoUrl: 'https://example.com/video.mp4',
        );

        // Act
        await videoManager.addVideoEvent(videoEvent);
        final state = videoManager.getVideoState('test123456789');

        // Assert
        expect(state, isNotNull);
        expect(state!.loadingState, equals(VideoLoadingState.notLoaded));
        expect(state.isLoading, isFalse);
        expect(state.isReady, isFalse);
        expect(state.hasFailed, isFalse);
        expect(state.canRetry, isFalse);
      });

      test('should return null for non-existent video states', () {
        // Act
        final state = videoManager.getVideoState('nonexistent');

        // Assert
        expect(state, isNull);
      });

      test('should handle disposal correctly', () {
        // Act
        videoManager.dispose();

        // Assert
        expect(videoManager.videos, isEmpty);
        expect(videoManager.getVideoState('any'), isNull);
        expect(videoManager.getController('any'), isNull);
      });
    });

    group('Memory Management', () {
      test('should respect max videos configuration', () async {
        // Arrange
        final limitedManager = VideoManagerService(
          config: const VideoManagerConfig(
            maxVideos: 5,
            preloadAhead: 1,
            preloadBehind: 1,
            enableMemoryManagement: true,
          ),
        );

        final videos = List.generate(10, (index) => VideoEvent(
          id: 'video${index}12345678',
          pubkey: 'author$index',
          createdAt: 1000 + index,
          content: 'Video $index',
          timestamp: DateTime.now().add(Duration(seconds: index)),
          videoUrl: 'https://example.com/video$index.mp4',
        ));

        // Act
        for (final video in videos) {
          await limitedManager.addVideoEvent(video);
        }

        // Assert
        // Should keep only the 5 most recent videos
        expect(limitedManager.videos.length, equals(5));
        expect(limitedManager.videos.map((v) => v.id).toList(),
          equals(['video912345678', 'video812345678', 'video712345678', 'video612345678', 'video512345678']));
        
        limitedManager.dispose();
      });

      test('should handle memory pressure', () async {
        // Arrange
        final videos = List.generate(10, (index) => VideoEvent(
          id: 'video${index}12345678',
          pubkey: 'author$index',
          createdAt: 1000 + index,
          content: 'Video $index',
          timestamp: DateTime.now().add(Duration(seconds: index)),
          videoUrl: 'https://example.com/video$index.mp4',
        ));

        for (final video in videos) {
          await videoManager.addVideoEvent(video);
        }

        // Act
        await videoManager.handleMemoryPressure();

        // Assert
        // Should keep 70% of max videos (7 out of 10 with default config)
        expect(videoManager.videos.length, equals(7));
      });
    });

    group('Debug Information', () {
      test('should provide accurate debug information', () async {
        // Arrange
        final videos = List.generate(3, (index) => VideoEvent(
          id: 'video${index}12345678',
          pubkey: 'author$index',
          createdAt: 1000 + index,
          content: 'Video $index',
          timestamp: DateTime.now().add(Duration(seconds: index)),
          videoUrl: 'https://example.com/video$index.mp4',
        ));

        for (final video in videos) {
          await videoManager.addVideoEvent(video);
        }

        // Act
        final debugInfo = videoManager.getDebugInfo();

        // Assert
        expect(debugInfo['totalVideos'], equals(3));
        expect(debugInfo['readyVideos'], equals(0)); // None are loaded yet
        expect(debugInfo['loadingVideos'], equals(0));
        expect(debugInfo['failedVideos'], equals(0));
        expect(debugInfo['activeControllers'], equals(0));
        expect(debugInfo['activePreloads'], equals(0));
        expect(debugInfo['disposed'], isFalse);
        expect(debugInfo['estimatedMemoryMB'], equals(0));
        
        expect(debugInfo['config'], isNotNull);
        expect(debugInfo['config']['maxVideos'], equals(10)); // Testing config
        expect(debugInfo['config']['preloadAhead'], equals(2));
        expect(debugInfo['config']['preloadBehind'], equals(1));
        
        expect(debugInfo['metrics'], isNotNull);
        expect(debugInfo['metrics']['preloadCount'], equals(0));
        expect(debugInfo['metrics']['preloadSuccessCount'], equals(0));
        expect(debugInfo['metrics']['preloadFailureCount'], equals(0));
      });
    });

    group('State Change Notifications', () {
      test('should emit state changes when videos are added', () async {
        // Arrange
        final stateChanges = <void>[];
        final subscription = videoManager.stateChanges.listen((event) {
          stateChanges.add(event);
        });

        final videoEvent = VideoEvent(
          id: 'test123456789',
          pubkey: 'author456',
          createdAt: 1000,
          content: 'Test video',
          timestamp: DateTime.now(),
          videoUrl: 'https://example.com/video.mp4',
        );

        // Act
        await videoManager.addVideoEvent(videoEvent);
        await Future.delayed(const Duration(milliseconds: 10)); // Allow stream to emit

        // Assert
        expect(stateChanges.length, greaterThan(0));
        
        // Cleanup
        await subscription.cancel();
      });
    });

    group('Legacy Service Replacement', () {
      test('validates VideoManagerService can replace VideoCacheService functionality', () {
        // This test verifies architectural compatibility
        
        // 1. Video storage - VideoManagerService maintains video list
        expect(videoManager.videos, isNotNull);
        expect(videoManager.videos, isEmpty); // Initially empty
        
        // 2. State tracking - VideoManagerService tracks video states
        expect(videoManager.getVideoState('any'), isNull);
        
        // 3. Controller access - VideoManagerService provides controller interface
        expect(videoManager.getController('any'), isNull);
        
        // 4. Memory management - VideoManagerService has memory controls
        expect(videoManager.handleMemoryPressure, isNotNull);
        
        // 5. Debug info - VideoManagerService provides system insights
        final debugInfo = videoManager.getDebugInfo();
        expect(debugInfo['totalVideos'], equals(0));
        expect(debugInfo['estimatedMemoryMB'], equals(0));
      });

      test('validates VideoManagerService can replace VideoControllerManager functionality', () {
        // This test verifies playback control compatibility
        
        // 1. Preloading interface - VideoManagerService supports preloading
        expect(() => videoManager.preloadAroundIndex(0), returnsNormally);
        
        // 2. Individual video preloading
        expect(videoManager.preloadVideo, isNotNull);
        
        // 3. Controller disposal
        expect(() => videoManager.disposeVideo('any'), returnsNormally);
        
        // 4. Ready videos filtering
        expect(videoManager.readyVideos, isEmpty);
        
        // 5. State change notifications for UI updates
        expect(videoManager.stateChanges, isNotNull);
      });
    });

    group('Configuration', () {
      test('should use correct testing configuration', () {
        // Act
        final debugInfo = videoManager.getDebugInfo();
        final config = debugInfo['config'] as Map<String, dynamic>;

        // Assert
        expect(config['maxVideos'], equals(10));
        expect(config['preloadAhead'], equals(2));
        expect(config['preloadBehind'], equals(1));
        expect(config['maxRetries'], equals(1));
        expect(config['preloadTimeout'], equals(500)); // milliseconds
        expect(config['enableMemoryManagement'], isTrue);
      });

      test('should handle different configurations', () {
        // Test WiFi config
        final wifiManager = VideoManagerService(
          config: VideoManagerConfig.wifi(),
        );
        final wifiDebug = wifiManager.getDebugInfo();
        expect(wifiDebug['config']['maxVideos'], equals(100));
        expect(wifiDebug['config']['preloadAhead'], equals(2));
        wifiManager.dispose();

        // Test Cellular config
        final cellularManager = VideoManagerService(
          config: VideoManagerConfig.cellular(),
        );
        final cellularDebug = cellularManager.getDebugInfo();
        expect(cellularDebug['config']['maxVideos'], equals(50));
        expect(cellularDebug['config']['preloadAhead'], equals(1));
        cellularManager.dispose();
      });
    });
  });
}