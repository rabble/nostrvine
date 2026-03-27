// ABOUTME: Provider-level tests for MP4→HLS fallback retry path
// ABOUTME: Validates fallback cache state management and URL resolution chain

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/providers/individual_video_providers.dart';
import 'package:openvine/services/bandwidth_tracker_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_helpers.dart';

const _hash =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

VideoEvent _createDivineVideo({String? hash}) {
  final h = hash ?? _hash;
  return TestHelpers.createVideoEvent(
    id: 'test-video-$h',
    videoUrl: 'https://media.divine.video/$h',
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    bandwidthTracker.clearSamples();
    await bandwidthTracker.setQualityOverride(null);
  });

  group('fallbackUrlCacheProvider state management', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('starts with empty cache', () {
      final cache = container.read(fallbackUrlCacheProvider);
      expect(cache, isEmpty);
    });

    test('stores a fallback URL for a video ID', () {
      const videoId = 'video-123';
      const fallbackUrl =
          'https://media.divine.video/$_hash/hls/stream_720p.m3u8';

      container.read(fallbackUrlCacheProvider.notifier).state = {
        videoId: fallbackUrl,
      };

      final cache = container.read(fallbackUrlCacheProvider);
      expect(cache[videoId], equals(fallbackUrl));
    });

    test('does not affect other video IDs', () {
      const videoId1 = 'video-1';
      const videoId2 = 'video-2';
      const fallbackUrl =
          'https://media.divine.video/$_hash/hls/stream_720p.m3u8';

      container.read(fallbackUrlCacheProvider.notifier).state = {
        videoId1: fallbackUrl,
      };

      final cache = container.read(fallbackUrlCacheProvider);
      expect(cache.containsKey(videoId1), isTrue);
      expect(cache.containsKey(videoId2), isFalse);
    });

    test('preserves existing entries when adding new ones', () {
      const id1 = 'video-1';
      const id2 = 'video-2';
      const url1 = 'https://media.divine.video/$_hash/hls/stream_720p.m3u8';
      const url2 = 'https://media.divine.video/$_hash/hls/stream_480p.m3u8';

      // Add first entry
      container.read(fallbackUrlCacheProvider.notifier).state = {id1: url1};

      // Add second entry, preserving first
      final current = container.read(fallbackUrlCacheProvider);
      container.read(fallbackUrlCacheProvider.notifier).state = {
        ...current,
        id2: url2,
      };

      final cache = container.read(fallbackUrlCacheProvider);
      expect(cache[id1], equals(url1));
      expect(cache[id2], equals(url2));
    });

    test('does not overwrite existing fallback for same video ID', () {
      // Mirrors the guard in the error handler: if (!currentFallbackCache.containsKey(params.videoId))
      const videoId = 'video-123';
      const firstUrl = 'https://media.divine.video/$_hash/hls/stream_720p.m3u8';
      const secondUrl =
          'https://media.divine.video/$_hash/hls/stream_480p.m3u8';

      container.read(fallbackUrlCacheProvider.notifier).state = {
        videoId: firstUrl,
      };

      // Simulate the guard: only store if not already present
      final current = container.read(fallbackUrlCacheProvider);
      if (!current.containsKey(videoId)) {
        container.read(fallbackUrlCacheProvider.notifier).state = {
          ...current,
          videoId: secondUrl,
        };
      }

      expect(
        container.read(fallbackUrlCacheProvider)[videoId],
        equals(firstUrl),
      );
    });
  });

  group('MP4→HLS URL resolution chain', () {
    test('VideoControllerParams.fromVideoEvent uses MP4 720p primary URL', () {
      final video = _createDivineVideo();
      final params = VideoControllerParams.fromVideoEvent(video);

      expect(params.videoUrl, contains('/720p.mp4'));
      expect(
        params.videoUrl,
        equals('https://media.divine.video/$_hash/720p.mp4'),
      );
    });

    test('getFallbackUrl returns HLS for Divine videos', () {
      final video = _createDivineVideo();
      final fallback = video.getFallbackUrl();

      expect(fallback, isNotNull);
      expect(fallback, contains('/hls/'));
      expect(fallback, contains('.m3u8'));
    });

    test('getFallbackUrl returns null for non-Divine videos', () {
      final video = TestHelpers.createVideoEvent(
        videoUrl: 'https://blossom.primal.net/abc123.mp4',
      );

      expect(video.getFallbackUrl(), isNull);
    });

    test('primary MP4 URL differs from HLS fallback URL', () {
      final video = _createDivineVideo();
      final params = VideoControllerParams.fromVideoEvent(video);
      final fallback = video.getFallbackUrl();

      expect(params.videoUrl, isNot(equals(fallback)));
      // Primary is MP4, fallback is HLS
      expect(params.videoUrl, contains('.mp4'));
      expect(fallback, contains('.m3u8'));
    });

    test('hlsUrl returns master playlist for generic fallback path', () {
      final video = _createDivineVideo();
      final hlsUrl = video.hlsUrl;

      expect(hlsUrl, isNotNull);
      expect(hlsUrl, contains('/hls/master.m3u8'));
    });

    test('getHlsUrl quality variants resolve correctly', () {
      final video = _createDivineVideo();

      expect(
        video.getHlsUrl(quality: 'high'),
        equals('https://media.divine.video/$_hash/hls/stream_720p.m3u8'),
      );
      expect(
        video.getHlsUrl(quality: 'low'),
        equals('https://media.divine.video/$_hash/hls/stream_480p.m3u8'),
      );
      expect(
        video.getHlsUrl(),
        equals('https://media.divine.video/$_hash/hls/master.m3u8'),
      );
    });
  });

  group('fallback cache drives provider URL selection', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('provider reads fallback URL from cache when present', () {
      final video = _createDivineVideo();
      final params = VideoControllerParams.fromVideoEvent(video);
      const hlsFallback =
          'https://media.divine.video/$_hash/hls/stream_720p.m3u8';

      // Pre-seed fallback cache (simulating a previous MP4 failure)
      container.read(fallbackUrlCacheProvider.notifier).state = {
        params.videoId: hlsFallback,
      };

      // Verify the cache has the fallback
      final cache = container.read(fallbackUrlCacheProvider);
      final resolvedUrl = cache[params.videoId] ?? params.videoUrl;

      expect(resolvedUrl, equals(hlsFallback));
      expect(resolvedUrl, isNot(equals(params.videoUrl)));
    });

    test('provider uses primary URL when no fallback cached', () {
      final video = _createDivineVideo();
      final params = VideoControllerParams.fromVideoEvent(video);

      final cache = container.read(fallbackUrlCacheProvider);
      final resolvedUrl = cache[params.videoId] ?? params.videoUrl;

      expect(resolvedUrl, equals(params.videoUrl));
      expect(resolvedUrl, contains('/720p.mp4'));
    });

    test('end-to-end: MP4 params + fallback storage + cache lookup', () {
      final video = _createDivineVideo();
      final params = VideoControllerParams.fromVideoEvent(video);

      // Step 1: Primary URL is MP4
      expect(params.videoUrl, contains('/720p.mp4'));

      // Step 2: Simulate failure — store fallback (mirrors error handler logic)
      final fallbackUrl = video.getFallbackUrl();
      expect(fallbackUrl, isNotNull);

      final currentCache = container.read(fallbackUrlCacheProvider);
      if (!currentCache.containsKey(params.videoId)) {
        container.read(fallbackUrlCacheProvider.notifier).state = {
          ...currentCache,
          params.videoId: fallbackUrl!,
        };
      }

      // Step 3: On retry, resolved URL is HLS
      final retryCache = container.read(fallbackUrlCacheProvider);
      final retryUrl = retryCache[params.videoId] ?? params.videoUrl;

      expect(retryUrl, equals(fallbackUrl));
      expect(retryUrl, contains('.m3u8'));
      expect(retryUrl, isNot(contains('.mp4')));
    });
  });
}
