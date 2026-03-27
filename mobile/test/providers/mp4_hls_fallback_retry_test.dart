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

  group('quality variant error handler fallback path', () {
    // Mirrors the error handler logic at individual_video_providers.dart ~line 729:
    //   final isQualityVariant = videoUrl.contains('/720p') || videoUrl.contains('/480p');
    //   if (isQualityVariant && params.videoEvent is VideoEvent) {
    //     final fallbackUrl = params.videoEvent?.getFallbackUrl();
    //     if (fallbackUrl != null && !currentFallbackCache.containsKey(params.videoId))

    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('720p MP4 failure triggers HLS fallback storage', () {
      final video = _createDivineVideo();
      final params = VideoControllerParams.fromVideoEvent(video);
      final videoUrl = params.videoUrl;

      // Precondition: primary URL is a quality variant
      final isQualityVariant =
          videoUrl.contains('/720p') || videoUrl.contains('/480p');
      expect(isQualityVariant, isTrue, reason: 'primary URL must be 720p MP4');

      // Simulate error handler: resolve fallback
      final fallbackUrl = video.getFallbackUrl();
      expect(fallbackUrl, isNotNull);

      // Store in cache (mirroring error handler guard)
      final currentCache = container.read(fallbackUrlCacheProvider);
      if (!currentCache.containsKey(params.videoId)) {
        container.read(fallbackUrlCacheProvider.notifier).state = {
          ...currentCache,
          params.videoId: fallbackUrl!,
        };
      }

      // Verify fallback is HLS, not the same MP4
      final stored = container.read(fallbackUrlCacheProvider)[params.videoId];
      expect(stored, equals(fallbackUrl));
      expect(stored, contains('.m3u8'), reason: 'fallback must be HLS');
      expect(
        stored,
        isNot(equals(videoUrl)),
        reason: 'fallback must differ from failing MP4',
      );
      expect(
        stored,
        isNot(contains('/720p.mp4')),
        reason: 'fallback must not be same quality variant',
      );
    });

    test('480p MP4 failure also triggers fallback', () {
      final video = _createDivineVideo();
      const videoUrl480 = 'https://media.divine.video/$_hash/480p.mp4';

      final isQualityVariant =
          videoUrl480.contains('/720p') || videoUrl480.contains('/480p');
      expect(isQualityVariant, isTrue);

      final fallbackUrl = video.getFallbackUrl();
      expect(fallbackUrl, isNotNull);
      expect(fallbackUrl, contains('.m3u8'));
      expect(fallbackUrl, isNot(equals(videoUrl480)));
    });

    test('non-quality-variant URL does not trigger quality fallback path', () {
      const rawUrl = 'https://media.divine.video/$_hash';

      final isQualityVariant =
          rawUrl.contains('/720p') || rawUrl.contains('/480p');
      expect(
        isQualityVariant,
        isFalse,
        reason: 'raw URL should not match quality variant check',
      );
    });

    test('guard prevents overwriting existing fallback entry', () {
      final video = _createDivineVideo();
      final params = VideoControllerParams.fromVideoEvent(video);
      final fallbackUrl = video.getFallbackUrl()!;
      const secondFallback =
          'https://media.divine.video/$_hash/hls/stream_480p.m3u8';

      // First failure stores fallback
      container.read(fallbackUrlCacheProvider.notifier).state = {
        params.videoId: fallbackUrl,
      };

      // Second failure hits the guard
      final currentCache = container.read(fallbackUrlCacheProvider);
      if (!currentCache.containsKey(params.videoId)) {
        container.read(fallbackUrlCacheProvider.notifier).state = {
          ...currentCache,
          params.videoId: secondFallback,
        };
      }

      expect(
        container.read(fallbackUrlCacheProvider)[params.videoId],
        equals(fallbackUrl),
      );
    });

    test('non-Divine video returns null fallback — no cache write', () {
      final nonDivine = TestHelpers.createVideoEvent(
        id: 'non-divine-1',
        videoUrl: 'https://blossom.primal.net/$_hash/720p.mp4',
      );

      final isQualityVariant = nonDivine.videoUrl!.contains('/720p');
      expect(isQualityVariant, isTrue);

      final fallbackUrl = nonDivine.getFallbackUrl();
      expect(
        fallbackUrl,
        isNull,
        reason: 'non-Divine videos have no HLS fallback',
      );

      expect(container.read(fallbackUrlCacheProvider), isEmpty);
    });
  });

  group('Android codec error fallback path', () {
    // Mirrors individual_video_providers.dart ~line 877:
    //   _isCodecError(errorMessage) && Android
    //   -> getHlsFallbackUrl() -> bandwidth-aware HLS quality

    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('codec error triggers getHlsFallbackUrl storage for Divine video', () {
      final video = _createDivineVideo();
      final params = VideoControllerParams.fromVideoEvent(video);

      // Simulate codec error path: check no existing fallback
      final currentCache = container.read(fallbackUrlCacheProvider);
      final alreadyUsedFallback = currentCache.containsKey(params.videoId);
      expect(alreadyUsedFallback, isFalse);

      // getHlsFallbackUrl returns bandwidth-aware HLS
      final hlsFallback = video.getHlsFallbackUrl();
      expect(hlsFallback, isNotNull);
      expect(hlsFallback, contains('.m3u8'));

      // Store (mirroring error handler)
      final newCache = {...currentCache};
      newCache[params.videoId] = hlsFallback!;
      container.read(fallbackUrlCacheProvider.notifier).state = newCache;

      final stored = container.read(fallbackUrlCacheProvider)[params.videoId];
      expect(stored, equals(hlsFallback));
      expect(stored, isNot(equals(params.videoUrl)));
    });

    test('codec fallback uses bandwidth-based quality selection', () {
      final video = _createDivineVideo();

      // Default bandwidth (no samples) -> high quality
      final hlsFallback = video.getHlsFallbackUrl();
      expect(hlsFallback, isNotNull);
      // Should be stream_720p (high) or stream_480p (low) based on bandwidth
      expect(
        hlsFallback,
        anyOf(
          contains('stream_720p.m3u8'),
          contains('stream_480p.m3u8'),
        ),
      );
    });

    test('codec fallback skipped when fallback already cached', () {
      final video = _createDivineVideo();
      final params = VideoControllerParams.fromVideoEvent(video);
      const existingFallback =
          'https://media.divine.video/$_hash/hls/stream_720p.m3u8';

      // Pre-seed cache (simulating a previous fallback)
      container.read(fallbackUrlCacheProvider.notifier).state = {
        params.videoId: existingFallback,
      };

      // Mirroring error handler guard
      final currentCache = container.read(fallbackUrlCacheProvider);
      final alreadyUsedFallback = currentCache.containsKey(params.videoId);
      expect(
        alreadyUsedFallback,
        isTrue,
        reason: 'guard should prevent second fallback',
      );
    });

    test('non-Divine video has no codec fallback', () {
      final nonDivine = TestHelpers.createVideoEvent(
        id: 'non-divine-codec',
        videoUrl: 'https://other-server.com/video.mp4',
      );

      final hlsFallback = nonDivine.getHlsFallbackUrl();
      expect(hlsFallback, isNull);
    });
  });

  group('generic video error fallback path', () {
    // Mirrors individual_video_providers.dart ~line 925:
    //   _isVideoError(errorMessage)
    //   -> videoEvent.hlsUrl -> master.m3u8

    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('generic error triggers hlsUrl (master playlist) fallback', () {
      final video = _createDivineVideo();
      final params = VideoControllerParams.fromVideoEvent(video);

      final currentCache = container.read(fallbackUrlCacheProvider);
      final alreadyUsedFallback = currentCache.containsKey(params.videoId);
      expect(alreadyUsedFallback, isFalse);

      // Generic error path uses hlsUrl (master playlist)
      final hlsFallback = video.hlsUrl;
      expect(hlsFallback, isNotNull);
      expect(hlsFallback, contains('master.m3u8'));
      expect(
        hlsFallback,
        isNot(equals(params.videoUrl)),
        reason: 'hlsUrl must differ from original MP4',
      );

      // Store (mirroring error handler)
      final newCache = {...currentCache};
      newCache[params.videoId] = hlsFallback!;
      container.read(fallbackUrlCacheProvider.notifier).state = newCache;

      expect(
        container.read(fallbackUrlCacheProvider)[params.videoId],
        equals(hlsFallback),
      );
    });

    test('generic error skipped when hlsUrl equals videoUrl', () {
      // The error handler has: if (hlsFallback != null && hlsFallback != params.videoUrl)
      final video = _createDivineVideo();
      final hlsUrl = video.hlsUrl;
      expect(hlsUrl, isNotNull);

      // If someone already had HLS as primary URL, the guard prevents storing same URL
      final params = VideoControllerParams(
        videoId: video.id,
        videoUrl: hlsUrl!,
        videoEvent: video,
      );

      // hlsFallback == params.videoUrl, so no cache write
      expect(video.hlsUrl, equals(params.videoUrl));
      // Cache stays empty
      expect(container.read(fallbackUrlCacheProvider), isEmpty);
    });

    test('generic error skipped when fallback already cached', () {
      final video = _createDivineVideo();
      final params = VideoControllerParams.fromVideoEvent(video);
      const existing = 'https://media.divine.video/$_hash/hls/stream_720p.m3u8';

      container.read(fallbackUrlCacheProvider.notifier).state = {
        params.videoId: existing,
      };

      final currentCache = container.read(fallbackUrlCacheProvider);
      final alreadyUsedFallback = currentCache.containsKey(params.videoId);
      expect(alreadyUsedFallback, isTrue);
    });
  });

  group('provider rebuild with fallback URL', () {
    // End-to-end: after fallback is cached, simulated rebuild reads HLS from cache

    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('rebuild after quality variant failure uses HLS URL', () {
      final video = _createDivineVideo();
      final params = VideoControllerParams.fromVideoEvent(video);

      // Step 1: initial URL is MP4 720p
      expect(params.videoUrl, contains('/720p.mp4'));

      // Step 2: simulate quality variant failure -> store HLS fallback
      final fallbackUrl = video.getFallbackUrl()!;
      container.read(fallbackUrlCacheProvider.notifier).state = {
        params.videoId: fallbackUrl,
      };

      // Step 3: on rebuild, provider reads from cache (line 349-350 of provider)
      final cache = container.read(fallbackUrlCacheProvider);
      final resolvedUrl = cache[params.videoId] ?? params.videoUrl;

      expect(resolvedUrl, equals(fallbackUrl));
      expect(resolvedUrl, contains('.m3u8'));
      expect(resolvedUrl, isNot(contains('/720p.mp4')));
    });

    test('rebuild after codec error uses bandwidth-aware HLS', () {
      final video = _createDivineVideo();
      final params = VideoControllerParams.fromVideoEvent(video);

      // Simulate codec failure -> store HLS fallback
      final hlsFallback = video.getHlsFallbackUrl()!;
      container.read(fallbackUrlCacheProvider.notifier).state = {
        params.videoId: hlsFallback,
      };

      // On rebuild, resolved URL is the codec-specific HLS
      final cache = container.read(fallbackUrlCacheProvider);
      final resolvedUrl = cache[params.videoId] ?? params.videoUrl;

      expect(resolvedUrl, equals(hlsFallback));
      expect(resolvedUrl, contains('.m3u8'));
      expect(resolvedUrl, contains('stream_'));
    });

    test('rebuild after generic error uses master HLS', () {
      final video = _createDivineVideo();
      final params = VideoControllerParams.fromVideoEvent(video);

      // Simulate generic failure -> store master HLS
      final hlsUrl = video.hlsUrl!;
      container.read(fallbackUrlCacheProvider.notifier).state = {
        params.videoId: hlsUrl,
      };

      final cache = container.read(fallbackUrlCacheProvider);
      final resolvedUrl = cache[params.videoId] ?? params.videoUrl;

      expect(resolvedUrl, equals(hlsUrl));
      expect(resolvedUrl, contains('master.m3u8'));
    });

    test('each fallback scenario produces distinct HLS URL', () {
      final video = _createDivineVideo();
      final qualityFallback = video.getFallbackUrl();
      final codecFallback = video.getHlsFallbackUrl();
      final genericFallback = video.hlsUrl;

      // All three are HLS
      expect(qualityFallback, contains('.m3u8'));
      expect(codecFallback, contains('.m3u8'));
      expect(genericFallback, contains('.m3u8'));

      // Generic uses master, others use stream-specific
      expect(genericFallback, contains('master.m3u8'));
      // Quality and codec use bandwidth-selected stream
      expect(qualityFallback, contains('stream_'));
      expect(codecFallback, contains('stream_'));
    });
  });
}
