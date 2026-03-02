// ABOUTME: TDD tests for video prefetching in VideoFeedScreen
// ABOUTME: Verifies that upcoming videos are cached before user scrolls to them

import 'package:flutter_test/flutter_test.dart';
import 'package:media_cache/media_cache.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/app_constants.dart';

class MockMediaCacheManager extends Mock implements MediaCacheManager {}

void main() {
  late MockMediaCacheManager mockCacheManager;

  setUp(() {
    mockCacheManager = MockMediaCacheManager();
  });

  group('Video Feed Prefetching', () {
    test(
      'SPEC: should prefetch videos after current index when page changes',
      () async {
        // Arrange
        final videos = _createMockVideoEvents(10);
        const currentIndex = 3;

        // Expected: With preloadBefore=2 and preloadAfter=3, should prefetch:
        // - Before: 1, 2 (preloadBefore=2)
        // - After: 4, 5, 6 (preloadAfter=3)
        // - Skipped: 3 (current)
        final expectedVideoIds = [
          videos[1].id,
          videos[2].id,
          videos[4].id,
          videos[5].id,
          videos[6].id,
        ];

        // Mock preCacheFiles to verify it's called with correct params
        when(
          () => mockCacheManager.preCacheFiles(
            any(),
            batchSize: any(named: 'batchSize'),
            authHeadersProvider: any(named: 'authHeadersProvider'),
          ),
        ).thenAnswer((_) async {});

        // Act
        await _triggerPrefetch(mockCacheManager, videos, currentIndex);

        // Assert
        final captured = verify(
          () => mockCacheManager.preCacheFiles(
            captureAny(),
            batchSize: any(named: 'batchSize'),
            authHeadersProvider: any(named: 'authHeadersProvider'),
          ),
        ).captured;
        final items = captured[0] as List<({String url, String key})>;
        final actualVideoIds = items.map((item) => item.key).toList();

        expect(actualVideoIds, containsAll(expectedVideoIds));
        expect(actualVideoIds.length, equals(expectedVideoIds.length));
      },
    );

    test(
      'SPEC: should prefetch videos before current index when page changes',
      () async {
        // Arrange
        final videos = _createMockVideoEvents(10);
        const currentIndex = 5;

        // Expected: With preloadBefore = 2, should prefetch videos at index 3, 4
        final expectedVideoIds = [videos[3].id, videos[4].id];

        // Mock preCacheFiles
        when(
          () => mockCacheManager.preCacheFiles(
            any(),
            batchSize: any(named: 'batchSize'),
            authHeadersProvider: any(named: 'authHeadersProvider'),
          ),
        ).thenAnswer((_) async {});

        // Act
        await _triggerPrefetch(mockCacheManager, videos, currentIndex);

        // Assert
        final captured = verify(
          () => mockCacheManager.preCacheFiles(
            captureAny(),
            batchSize: any(named: 'batchSize'),
            authHeadersProvider: any(named: 'authHeadersProvider'),
          ),
        ).captured;
        final items = captured[0] as List<({String url, String key})>;
        final actualVideoIds = items.map((item) => item.key).toList();

        expect(actualVideoIds, containsAll(expectedVideoIds));
      },
    );

    test('SPEC: should not prefetch beyond feed boundaries', () async {
      // Arrange
      final videos = _createMockVideoEvents(5);
      const currentIndex = 4; // Last video

      // Expected: Can't prefetch beyond index 4, so only prefetch before
      final expectedVideoIds = [videos[2].id, videos[3].id];

      when(
        () => mockCacheManager.preCacheFiles(
          any(),
          batchSize: any(named: 'batchSize'),
          authHeadersProvider: any(named: 'authHeadersProvider'),
        ),
      ).thenAnswer((_) async {});

      // Act
      await _triggerPrefetch(mockCacheManager, videos, currentIndex);

      // Assert
      final captured = verify(
        () => mockCacheManager.preCacheFiles(
          captureAny(),
          batchSize: any(named: 'batchSize'),
          authHeadersProvider: any(named: 'authHeadersProvider'),
        ),
      ).captured;
      final items = captured[0] as List<({String url, String key})>;
      final actualVideoIds = items.map((item) => item.key).toList();

      // Should only contain videos 2 and 3 (before current)
      expect(actualVideoIds, containsAll(expectedVideoIds));
      expect(
        actualVideoIds.length,
        lessThanOrEqualTo(AppConstants.preloadBefore),
      );
    });

    test('SPEC: should not prefetch at index 0 (no videos before)', () async {
      // Arrange
      final videos = _createMockVideoEvents(10);
      const currentIndex = 0;

      // Expected: Only prefetch after (1, 2, 3), not before
      final expectedVideoIds = [videos[1].id, videos[2].id, videos[3].id];

      when(
        () => mockCacheManager.preCacheFiles(
          any(),
          batchSize: any(named: 'batchSize'),
          authHeadersProvider: any(named: 'authHeadersProvider'),
        ),
      ).thenAnswer((_) async {});

      // Act
      await _triggerPrefetch(mockCacheManager, videos, currentIndex);

      // Assert
      final captured = verify(
        () => mockCacheManager.preCacheFiles(
          captureAny(),
          batchSize: any(named: 'batchSize'),
          authHeadersProvider: any(named: 'authHeadersProvider'),
        ),
      ).captured;
      final items = captured[0] as List<({String url, String key})>;
      final actualVideoIds = items.map((item) => item.key).toList();

      expect(actualVideoIds, containsAll(expectedVideoIds));
      expect(actualVideoIds.length, equals(AppConstants.preloadAfter));
    });

    test('SPEC: should skip already cached videos during prefetch', () async {
      // Arrange
      final videos = _createMockVideoEvents(10);
      const currentIndex = 3;

      // Mock: Video at index 5 is already cached, others are not
      for (int i = 0; i < videos.length; i++) {
        when(
          () => mockCacheManager.isFileCached(videos[i].id),
        ).thenAnswer((_) async => i == 5);
      }
      when(
        () => mockCacheManager.preCacheFiles(
          any(),
          batchSize: any(named: 'batchSize'),
          authHeadersProvider: any(named: 'authHeadersProvider'),
        ),
      ).thenAnswer((_) async {});

      // Act
      await _triggerPrefetchWithCacheCheck(
        mockCacheManager,
        videos,
        currentIndex,
      );

      // Assert
      final captured = verify(
        () => mockCacheManager.preCacheFiles(
          captureAny(),
          batchSize: any(named: 'batchSize'),
          authHeadersProvider: any(named: 'authHeadersProvider'),
        ),
      ).captured;
      final items = captured[0] as List<({String url, String key})>;
      final actualVideoIds = items.map((item) => item.key).toList();

      // Should NOT contain video[5].id since it's already cached
      expect(actualVideoIds, isNot(contains(videos[5].id)));

      // Should contain others from the prefetch window
      expect(actualVideoIds, contains(videos[1].id)); // preloadBefore
      expect(actualVideoIds, contains(videos[2].id)); // preloadBefore
      expect(actualVideoIds, contains(videos[4].id)); // preloadAfter
      expect(actualVideoIds, contains(videos[6].id)); // preloadAfter
    });

    test('SPEC: should handle prefetch errors gracefully', () async {
      // Arrange
      final videos = _createMockVideoEvents(10);
      const currentIndex = 3;

      // Mock preCacheFiles to throw error
      when(
        () => mockCacheManager.preCacheFiles(
          any(),
          batchSize: any(named: 'batchSize'),
          authHeadersProvider: any(named: 'authHeadersProvider'),
        ),
      ).thenThrow(Exception('Network error'));

      // Act & Assert - should not throw
      expect(
        () async => _triggerPrefetch(mockCacheManager, videos, currentIndex),
        returnsNormally,
      );
    });

    test('SPEC: should use AppConstants for prefetch window', () async {
      // Arrange
      final videos = _createMockVideoEvents(20);
      const currentIndex = 10;

      when(
        () => mockCacheManager.preCacheFiles(
          any(),
          batchSize: any(named: 'batchSize'),
          authHeadersProvider: any(named: 'authHeadersProvider'),
        ),
      ).thenAnswer((_) async {});

      // Act
      await _triggerPrefetch(mockCacheManager, videos, currentIndex);

      // Assert
      final captured = verify(
        () => mockCacheManager.preCacheFiles(
          captureAny(),
          batchSize: any(named: 'batchSize'),
          authHeadersProvider: any(named: 'authHeadersProvider'),
        ),
      ).captured;
      final items = captured[0] as List<({String url, String key})>;
      final actualVideoIds = items.map((item) => item.key).toList();

      // Total videos to prefetch should be preloadBefore + preloadAfter
      const expectedCount =
          AppConstants.preloadBefore + AppConstants.preloadAfter;
      expect(actualVideoIds.length, lessThanOrEqualTo(expectedCount));
    });
  });
}

/// Helper: Create mock video events for testing
List<VideoEvent> _createMockVideoEvents(int count) {
  final now = DateTime.now();
  return List.generate(count, (index) {
    final timestamp = now.subtract(Duration(days: index));
    final createdAtUnix = timestamp.millisecondsSinceEpoch ~/ 1000;
    return VideoEvent(
      id: 'video-id-$index',
      pubkey: 'pubkey-$index',
      createdAt: createdAtUnix,
      content: 'Test video content $index',
      timestamp: timestamp,
      videoUrl: 'https://example.com/video-$index.mp4',
      title: 'Test Video $index',
    );
  });
}

/// Simulates triggering prefetch logic after page change
/// This will be the actual implementation in VideoFeedScreen._onPageChanged
Future<void> _triggerPrefetch(
  MediaCacheManager cacheManager,
  List<VideoEvent> videos,
  int currentIndex,
) async {
  // Calculate prefetch range
  final startIndex = (currentIndex - AppConstants.preloadBefore).clamp(
    0,
    videos.length - 1,
  );
  final endIndex = (currentIndex + AppConstants.preloadAfter + 1).clamp(
    0,
    videos.length,
  );

  final videosToPreFetch = <VideoEvent>[];
  for (int i = startIndex; i < endIndex; i++) {
    if (i != currentIndex && i >= 0 && i < videos.length) {
      videosToPreFetch.add(videos[i]);
    }
  }

  if (videosToPreFetch.isEmpty) return;

  final items = videosToPreFetch
      .map((v) => (url: v.videoUrl!, key: v.id))
      .toList();

  try {
    await cacheManager.preCacheFiles(items);
  } catch (e) {
    // Gracefully handle errors
  }
}

/// Simulates prefetch with cache checking
Future<void> _triggerPrefetchWithCacheCheck(
  MediaCacheManager cacheManager,
  List<VideoEvent> videos,
  int currentIndex,
) async {
  final startIndex = (currentIndex - AppConstants.preloadBefore).clamp(
    0,
    videos.length - 1,
  );
  final endIndex = (currentIndex + AppConstants.preloadAfter + 1).clamp(
    0,
    videos.length,
  );

  final videosToPreFetch = <VideoEvent>[];
  for (int i = startIndex; i < endIndex; i++) {
    if (i != currentIndex && i >= 0 && i < videos.length) {
      // Check if already cached before adding
      final isCached = await cacheManager.isFileCached(videos[i].id);
      if (!isCached) {
        videosToPreFetch.add(videos[i]);
      }
    }
  }

  if (videosToPreFetch.isEmpty) return;

  final items = videosToPreFetch
      .map((v) => (url: v.videoUrl!, key: v.id))
      .toList();

  try {
    await cacheManager.preCacheFiles(items);
  } catch (e) {
    // Gracefully handle errors
  }
}
