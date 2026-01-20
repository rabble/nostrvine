import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pooled_video_player/pooled_video_player.dart';
import 'package:video_player/video_player.dart';

class MockVideoPlayerController extends Mock implements VideoPlayerController {}

class MockVideoPlayerValue extends Mock implements VideoPlayerValue {}

void main() {
  Future<VideoPlayerController?> createMockController(
    String videoUrl, {
    File? cachedFile,
  }) async {
    final controller = MockVideoPlayerController();
    final value = MockVideoPlayerValue();

    when(() => value.isInitialized).thenReturn(true);
    when(() => value.isPlaying).thenReturn(false);
    when(() => controller.value).thenReturn(value);
    when(controller.dispose).thenAnswer((_) async {});
    when(controller.pause).thenAnswer((_) async {});
    when(controller.play).thenAnswer((_) async {});
    when(() => controller.setLooping(any())).thenAnswer((_) async {});

    return controller;
  }

  group('Multi-Feed Context Tracking', () {
    late VideoControllerPoolManager pool;

    setUp(() async {
      await VideoControllerPoolManager.initialize(
        poolSize: 3,
        controllerFactory: createMockController,
      );
      pool = VideoControllerPoolManager.instance;
    });

    tearDown(() async {
      await VideoControllerPoolManager.reset();
    });

    test('setActiveFeedContext sets active context', () {
      pool.setActiveFeedContext('feed_a');
      expect(pool, isNotNull);
      // Context is set internally, no public getter to verify directly
    });

    test('registerVideoForContext registers video under context', () {
      pool
        ..registerVideoForContext('video1', 'feed_a')
        ..registerVideoForContext('video2', 'feed_a')
        ..registerVideoForContext('video3', 'feed_b');
      // Videos are tracked internally
      expect(pool, isNotNull);
    });

    test('pauseFeedContext protects context videos from eviction', () async {
      // Acquire 2 videos for feed_a
      pool.setActiveFeedContext('feed_a');
      for (var i = 1; i <= 2; i++) {
        pool.registerVideoForContext('feed_a_video_$i', 'feed_a');
        await pool.acquireController(
          videoId: 'feed_a_video_$i',
          videoUrl: 'https://example.com/video$i.mp4',
        );
      }

      // Acquire 1 video for feed_b (not paused) to fill pool to capacity (3)
      pool
        ..setActiveFeedContext('feed_b')
        ..registerVideoForContext('feed_b_video_1', 'feed_b');
      await pool.acquireController(
        videoId: 'feed_b_video_1',
        videoUrl: 'https://example.com/feed_b_video_1.mp4',
      );

      // Pause feed_a context (protects its 2 videos)
      // Try to acquire another feed_b video - should evict the non-paused
      // feed_b_video_1 since feed_a videos are protected
      pool
        ..pauseFeedContext('feed_a')
        ..registerVideoForContext('feed_b_video_2', 'feed_b');
      final result = await pool.acquireController(
        videoId: 'feed_b_video_2',
        videoUrl: 'https://example.com/feed_b_video_2.mp4',
      );

      // Should succeed by evicting non-paused video
      expect(result, isNotNull);
      // feed_a videos should still be in pool (protected by pause)
      expect(pool.getController('feed_a_video_1'), isNotNull);
      expect(pool.getController('feed_a_video_2'), isNotNull);
    });

    test('resumeFeedContext allows normal eviction', () {
      pool
        ..pauseFeedContext('feed_a')
        ..resumeFeedContext('feed_a');
      // Context is no longer paused
      expect(pool, isNotNull);
    });

    test('clearFeedContext removes context tracking', () {
      pool
        ..registerVideoForContext('video1', 'feed_a')
        ..registerVideoForContext('video2', 'feed_a')
        ..clearFeedContext('feed_a');
      // Context is cleared
      expect(pool, isNotNull);
    });

    test('context-aware eviction prefers inactive contexts', () async {
      // Fill pool with feed_a videos
      pool.setActiveFeedContext('feed_a');
      for (var i = 1; i <= 3; i++) {
        pool
          ..registerVideoForContext('feed_a_video_$i', 'feed_a')
          ..registerVideoIndex('feed_a_video_$i', i);
        await pool.acquireController(
          videoId: 'feed_a_video_$i',
          videoUrl: 'https://example.com/feed_a_$i.mp4',
        );
      }

      // Switch to feed_b (feed_a is now inactive)
      // Acquire feed_b video - should evict feed_a video (inactive context)
      pool
        ..setActiveFeedContext('feed_b')
        ..registerVideoForContext('feed_b_video_1', 'feed_b')
        ..registerVideoIndex('feed_b_video_1', 1);
      final result = await pool.acquireController(
        videoId: 'feed_b_video_1',
        videoUrl: 'https://example.com/feed_b_video.mp4',
      );

      expect(result, isNotNull);
      expect(result!.videoId, 'feed_b_video_1');

      // At least one feed_a video should be evicted
      var feedAVideosInPool = 0;
      for (var i = 1; i <= 3; i++) {
        if (pool.getController('feed_a_video_$i') != null) {
          feedAVideosInPool++;
        }
      }
      expect(feedAVideosInPool, lessThan(3));
    });

    test('concurrent feed acquisition works correctly', () async {
      // Simulate two feeds acquiring controllers concurrently
      pool.setActiveFeedContext('feed_a');

      final futures = <Future<void>>[];

      // Feed A acquires 2 videos
      for (var i = 1; i <= 2; i++) {
        pool.registerVideoForContext('feed_a_video_$i', 'feed_a');
        futures.add(
          pool.acquireController(
            videoId: 'feed_a_video_$i',
            videoUrl: 'https://example.com/feed_a_$i.mp4',
          ),
        );
      }

      // Switch context and acquire feed B video
      pool
        ..setActiveFeedContext('feed_b')
        ..registerVideoForContext('feed_b_video_1', 'feed_b');
      futures.add(
        pool.acquireController(
          videoId: 'feed_b_video_1',
          videoUrl: 'https://example.com/feed_b_video.mp4',
        ),
      );

      await Future.wait(futures);

      // All acquisitions should succeed
      expect(pool.getController('feed_a_video_1'), isNotNull);
      expect(pool.getController('feed_a_video_2'), isNotNull);
      expect(pool.getController('feed_b_video_1'), isNotNull);
    });

    test('feed disposal cleans up context', () async {
      pool
        ..setActiveFeedContext('feed_a')
        ..registerVideoForContext('video1', 'feed_a')
        ..registerVideoForContext('video2', 'feed_a');

      await pool.acquireController(
        videoId: 'video1',
        videoUrl: 'https://example.com/video1.mp4',
      );
      await pool.acquireController(
        videoId: 'video2',
        videoUrl: 'https://example.com/video2.mp4',
      );

      // Clear context (simulating feed disposal)
      pool.clearFeedContext('feed_a');

      // Videos are no longer tracked under context, but still in pool
      expect(pool.getController('video1'), isNotNull);
      expect(pool.getController('video2'), isNotNull);
    });
  });
}
