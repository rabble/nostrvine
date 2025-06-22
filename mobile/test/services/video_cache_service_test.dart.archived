// ABOUTME: Comprehensive unit tests for VideoCacheService
// ABOUTME: Tests video caching, preloading, controller management, and performance behaviors

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostrvine_app/services/video_cache_service.dart';
import 'package:nostrvine_app/models/video_event.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('VideoCacheService', () {
    late VideoCacheService service;

    setUp(() {
      service = VideoCacheService();
    });

    tearDown(() {
      // Only dispose if not already disposed
      try {
        service.dispose();
      } catch (e) {
        // Ignore disposal errors in tearDown
      }
    });

    group('Basic Controller Management', () {
      test('should return null controller for GIF video events', () {
        final gifEvent = TestHelpers.createGifVideoEvent(
          title: 'Test GIF Video',
        );

        final controller = service.getController(gifEvent);
        expect(controller, isNull);
      });

      test('should return null controller for video events without URL', () {
        final noUrlEvent = TestHelpers.createMockVideoEvent(
          url: null,
        );

        final controller = service.getController(noUrlEvent);
        expect(controller, isNull);
      });

      test('should return true for GIF initialization status', () {
        final gifEvent = TestHelpers.createGifVideoEvent(
          title: 'Test GIF Video',
        );

        final initialized = service.isInitialized(gifEvent);
        expect(initialized, isTrue);
      });

      test('should return false for non-cached video initialization status', () {
        final videoEvent = TestHelpers.createMockVideoEvent(
          url: 'https://example.com/video.mp4',
        );

        final initialized = service.isInitialized(videoEvent);
        expect(initialized, isFalse);
      });
    });

    group('Video Playing and Pausing', () {
      test('should handle play request for GIF video gracefully', () {
        final gifEvent = TestHelpers.createGifVideoEvent(
          id: 'gif_video',
          title: 'Test GIF Video',
        );

        // Should not throw
        expect(() => service.playVideo(gifEvent), returnsNormally);
      });

      test('should handle pause request for GIF video gracefully', () {
        final gifEvent = TestHelpers.createGifVideoEvent(
          id: 'gif_video',
          title: 'Test GIF Video',
        );

        // Should not throw
        expect(() => service.pauseVideo(gifEvent), returnsNormally);
      });

      test('should handle play request for non-existent controller gracefully', () {
        final videoEvent = TestHelpers.createMockVideoEvent(
          id: 'non_existent',
          url: 'https://example.com/video.mp4',
        );

        // Should not throw
        expect(() => service.playVideo(videoEvent), returnsNormally);
      });

      test('should pause all videos without throwing', () {
        // Should not throw even with no controllers
        expect(() => service.pauseAllVideos(), returnsNormally);
      });
    });

    group('Ready Queue Management', () {
      test('should start with empty ready queue', () {
        expect(service.readyToPlayQueue, isEmpty);
      });

      test('should handle removal from empty ready queue gracefully', () {
        // Should not throw
        expect(() => service.removeVideoFromReadyQueue('non_existent'), returnsNormally);
        expect(service.readyToPlayQueue, isEmpty);
      });

      test('should process empty video events list gracefully', () {
        // Should not throw
        expect(() => service.processNewVideoEvents([]), returnsNormally);
        expect(service.readyToPlayQueue, isEmpty);
      });

      test('should add GIF videos to ready queue immediately', () async {
        final gifEvent = TestHelpers.createGifVideoEvent(
          id: 'gif_1',
          title: 'Test GIF 1',
        );

        service.processNewVideoEvents([gifEvent]);

        // Wait a moment for processing
        await Future.delayed(const Duration(milliseconds: 50));

        expect(service.readyToPlayQueue, contains(gifEvent));
      });

      test('should process multiple GIF videos correctly', () async {
        final gifEvents = List.generate(3, (i) => TestHelpers.createGifVideoEvent(
          id: 'gif_$i',
          title: 'Test GIF $i',
        ));

        service.processNewVideoEvents(gifEvents);

        // Wait a moment for processing
        await Future.delayed(const Duration(milliseconds: 50));

        expect(service.readyToPlayQueue.length, equals(3));
        for (final event in gifEvents) {
          expect(service.readyToPlayQueue, contains(event));
        }
      });
    });

    group('Video Status Checking', () {
      test('should return false for non-existent video readiness', () {
        expect(service.isVideoReady('non_existent'), isFalse);
      });

      test('should handle controller addition for GIF videos gracefully', () {
        final gifEvent = TestHelpers.createGifVideoEvent(
          id: 'gif_video',
          title: 'Test GIF Video',
        );

        // Should not throw - GIF videos are handled differently
        expect(() => service.addController(gifEvent, null as dynamic), returnsNormally);
      });
    });

    group('Cache Statistics', () {
      test('should provide initial cache statistics', () {
        final stats = service.getCacheStats();

        expect(stats, isA<Map<String, dynamic>>());
        expect(stats['cached_videos'], equals(0));
        expect(stats['initialized_videos'], equals(0));
        expect(stats['preload_queue_size'], equals(0));
        expect(stats['ready_to_play_queue'], equals(0));
        expect(stats['current_cache_target'], isA<int>());
        expect(stats['prime_index'], isA<int>());
        expect(stats['max_cache_size'], isA<int>());
        expect(stats['max_ready_queue'], isA<int>());
      });

      test('should update statistics when processing GIF videos', () async {
        final gifEvent = TestHelpers.createGifVideoEvent(
          title: 'Test GIF 1',
        );

        service.processNewVideoEvents([gifEvent]);
        await Future.delayed(const Duration(milliseconds: 50));

        final stats = service.getCacheStats();
        expect(stats['ready_to_play_queue'], equals(1));
      });
    });

    group('Controller Removal', () {
      test('should handle removal of non-existent controller by string ID', () {
        // Should not throw
        expect(() => service.removeController('non_existent'), returnsNormally);
      });

      test('should handle removal of non-existent controller by VideoEvent', () {
        final videoEvent = TestHelpers.createMockVideoEvent(
          id: 'non_existent',
          url: 'https://example.com/video.mp4',
        );

        // Should not throw
        expect(() => service.removeController(videoEvent), returnsNormally);
      });
    });

    group('Preloading', () {
      test('should handle preloading with empty video list', () async {
        // Should not throw
        expect(() => service.preloadVideos([], 0), returnsNormally);
        await Future.delayed(const Duration(milliseconds: 50));
      });

      test('should handle preloading with invalid current index', () async {
        final videoEvents = [
          TestHelpers.createMockVideoEvent(id: 'video_1', url: 'https://example.com/video1.mp4'),
        ];

        // Should not throw with out-of-bounds index
        expect(() => service.preloadVideos(videoEvents, 10), returnsNormally);
        await Future.delayed(const Duration(milliseconds: 50));
      });

      test('should handle preloading with negative current index', () async {
        final videoEvents = [
          TestHelpers.createMockVideoEvent(id: 'video_1', url: 'https://example.com/video1.mp4'),
        ];

        // Should not throw with negative index
        expect(() => service.preloadVideos(videoEvents, -1), returnsNormally);
        await Future.delayed(const Duration(milliseconds: 50));
      });
    });

    group('Notification System', () {
      test('should handle multiple rapid notifications without issues', () async {
        final gifEvents = List.generate(10, (i) => TestHelpers.createGifVideoEvent(
          id: 'gif_$i',
          title: 'Test GIF $i',
        ));

        // Process events rapidly to test notification batching
        for (final event in gifEvents) {
          service.processNewVideoEvents([event]);
        }

        // Wait for all notifications to be processed
        await Future.delayed(const Duration(milliseconds: 200));

        // Should have all GIFs in ready queue
        expect(service.readyToPlayQueue.length, equals(10));
      });
    });

    group('Memory Management', () {
      test('should handle large number of GIF videos without memory issues', () async {
        final gifEvents = List.generate(150, (i) => TestHelpers.createGifVideoEvent(
          id: 'gif_$i',
          title: 'Test GIF $i',
        ));

        service.processNewVideoEvents(gifEvents);
        await Future.delayed(const Duration(milliseconds: 100));

        final stats = service.getCacheStats();
        
        // Should respect maximum ready queue limit
        expect(stats['ready_to_play_queue'], lessThanOrEqualTo(stats['max_ready_queue']));
      });
    });

    group('Edge Cases', () {
      test('should handle video events with null URLs', () {
        final nullUrlEvent = TestHelpers.createMockVideoEvent(
          id: 'null_url',
          url: null,
        );

        // Should not throw
        expect(() => service.processNewVideoEvents([nullUrlEvent]), returnsNormally);
      });

      test('should handle video events with empty URLs', () {
        final emptyUrlEvent = TestHelpers.createMockVideoEvent(
          id: 'empty_url',
          url: '',
        );

        // Should not throw
        expect(() => service.processNewVideoEvents([emptyUrlEvent]), returnsNormally);
      });

      test('should handle duplicate video events gracefully', () async {
        final gifEvent = TestHelpers.createGifVideoEvent(
          id: 'duplicate_gif',
          title: 'Duplicate GIF Test',
        );

        // Process same event multiple times
        service.processNewVideoEvents([gifEvent]);
        service.processNewVideoEvents([gifEvent]);
        service.processNewVideoEvents([gifEvent]);

        await Future.delayed(const Duration(milliseconds: 50));

        // Should only have one instance
        expect(service.readyToPlayQueue.length, equals(1));
        expect(service.readyToPlayQueue.first.id, equals('duplicate_gif'));
      });
    });

    group('Disposal', () {
      test('should dispose cleanly', () {
        // Create a separate service for this test to avoid conflicts with tearDown
        final testService = VideoCacheService();
        
        // Should not throw
        expect(() => testService.dispose(), returnsNormally);
      });

      test('should dispose cleanly with cached content', () async {
        // Create a separate service for this test to avoid conflicts with tearDown
        final testService = VideoCacheService();
        
        final gifEvent = TestHelpers.createGifVideoEvent(
          id: 'gif_for_disposal',
          title: 'GIF for Disposal Test',
        );

        testService.processNewVideoEvents([gifEvent]);
        await Future.delayed(const Duration(milliseconds: 50));

        // Should not throw during disposal
        expect(() => testService.dispose(), returnsNormally);
      });

      test('should handle operations after disposal gracefully', () {
        // Create a separate service for this test to avoid conflicts with tearDown
        final testService = VideoCacheService();
        testService.dispose();

        final gifEvent = TestHelpers.createGifVideoEvent(
          id: 'post_disposal',
          title: 'Post Disposal GIF Test',
        );

        // Operations after disposal should not crash
        expect(() => testService.processNewVideoEvents([gifEvent]), returnsNormally);
        expect(() => testService.pauseAllVideos(), returnsNormally);
        expect(() => testService.getCacheStats(), returnsNormally);
      });
    });
  });
}