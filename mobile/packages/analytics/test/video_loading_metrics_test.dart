// ABOUTME: Tests for video loading analytics event names and metrics.
// ABOUTME: Verifies cache reporting and loading sessions without Firebase.

import 'package:analytics/analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_cache/media_cache.dart';

class _RecordingAnalyticsEventSink implements AnalyticsEventSink {
  final events = <({String name, Map<String, Object> parameters})>[];

  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async {
    events.add((name: name, parameters: parameters));
  }

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object>? parameters,
  }) async {}
}

void main() {
  group(VideoLoadingMetrics, () {
    const videoId =
        'abc123def456abc123def456abc123def456abc123def456abc123def456abcd';
    late _RecordingAnalyticsEventSink sink;
    late VideoLoadingMetrics tracker;

    setUp(() {
      sink = _RecordingAnalyticsEventSink();
      tracker = VideoLoadingMetrics.testInstance(sink: sink);
    });

    test('tracks loading stages and emits video_loading_complete', () {
      final overlayEvents = <String>[];
      tracker.onMetricsEvent = overlayEvents.add;

      tracker
        ..startVideoLoading(videoId, 'https://videos.example.com/file.mp4')
        ..markControllerCreationStart(videoId)
        ..markControllerCreationEnd(videoId)
        ..markNetworkInitStart(videoId)
        ..markFirstNetworkResponse(videoId)
        ..markVideoInitStart(videoId)
        ..markVideoInitComplete(videoId)
        ..markFirstFrameReady(videoId)
        ..markBufferingStart(videoId)
        ..markBufferingEnd(videoId)
        ..recordNetworkStats(
          videoId,
          bytesDownloaded: 4096,
          bandwidth: 12.5,
          segmentCount: 4,
        )
        ..setTotalSegments(videoId, 5)
        ..markSegmentLoaded(
          videoId,
          segmentIndex: 0,
          segmentSizeBytes: 1024,
          loadTimeMs: 20,
        )
        ..markSegmentFailed(
          videoId,
          segmentIndex: 1,
          errorMessage: 'temporary failure',
        );

      final status = tracker.getLoadingStatus(videoId);
      expect(status, isNotNull);
      expect(status!.videoId, videoId);
      expect(status.currentStage, VideoLoadingStage.preparingFirstFrame);

      tracker.markPlaybackStart(videoId);

      expect(tracker.activeSessions, 0);
      expect(overlayEvents.first, contains('STARTED'));
      expect(overlayEvents.last, contains('COMPLETE'));
      expect(sink.events.single.name, 'video_loading_complete');
      expect(
        sink.events.single.parameters,
        containsPair('video_id', videoId),
      );
      expect(
        sink.events.single.parameters,
        containsPair('bytes_downloaded', 4096),
      );
      expect(
        sink.events.single.parameters,
        containsPair('estimated_bandwidth_mbps', 12.5),
      );
      expect(
        sink.events.single.parameters,
        containsPair('segment_count', 4),
      );
      expect(
        sink.events.single.parameters,
        containsPair('total_segments', 5),
      );
      expect(
        sink.events.single.parameters,
        containsPair('segments_loaded', 1),
      );
      expect(
        sink.events.single.parameters,
        containsPair('segments_failed', 1),
      );
      expect(
        sink.events.single.parameters,
        containsPair('total_segment_bytes', 1024),
      );
      expect(
        sink.events.single.parameters,
        containsPair('avg_segment_load_ms', '20'),
      );
      expect(
        sink.events.single.parameters,
        containsPair('video_url_domain', 'videos.example.com'),
      );
    });

    test('markLoadingError emits video_loading_error and clears session', () {
      tracker.startVideoLoading(videoId, 'https://videos.example.com/file.mp4');

      tracker.markLoadingError(videoId, 'decode_failed', 'short');

      expect(tracker.activeSessions, 0);
      expect(sink.events.single.name, 'video_loading_error');
      expect(sink.events.single.parameters, {
        'video_id': videoId,
        'error_type': 'decode_failed',
        'error_message': 'short',
        'time_to_error_ms': isA<int>(),
        'stage_when_failed': VideoLoadingStage.error.name,
        'video_url_domain': 'videos.example.com',
      });
    });

    test('markLoadingError truncates long error messages safely', () {
      tracker.startVideoLoading(videoId, 'https://videos.example.com/file.mp4');

      tracker.markLoadingError(videoId, 'decode_failed', 'x' * 120);

      expect(sink.events.single.parameters['error_message'], 'x' * 100);
    });

    test('unknown video IDs are no-ops for public mutators', () {
      expect(
        () {
          tracker
            ..markControllerCreationStart(videoId)
            ..markControllerCreationEnd(videoId)
            ..markNetworkInitStart(videoId)
            ..markFirstNetworkResponse(videoId)
            ..markVideoInitStart(videoId)
            ..markVideoInitComplete(videoId)
            ..markFirstFrameReady(videoId)
            ..markPlaybackStart(videoId)
            ..markLoadingError(videoId, 'load_failed', 'missing')
            ..markBufferingStart(videoId)
            ..markBufferingEnd(videoId)
            ..recordNetworkStats(videoId)
            ..markSegmentLoaded(
              videoId,
              segmentIndex: 0,
              segmentSizeBytes: 1,
              loadTimeMs: 1,
            )
            ..markSegmentFailed(
              videoId,
              segmentIndex: 0,
              errorMessage: 'missing',
            )
            ..setTotalSegments(videoId, 1);
        },
        returnsNormally,
      );
      expect(tracker.getLoadingStatus(videoId), isNull);
      expect(sink.events, isEmpty);
    });

    test('reportCacheMetrics emits video_cache_performance when wired', () {
      final metrics = CacheMetrics()
        ..hits = 3
        ..misses = 1
        ..prefetchedUsed = 2
        ..prefetchedTotal = 5;
      tracker.cacheMetricsProvider = () => metrics;

      tracker.reportCacheMetrics();

      expect(sink.events.single.name, 'video_cache_performance');
      expect(sink.events.single.parameters, {
        'cache_hits': 3,
        'cache_misses': 1,
        'hit_rate': '0.750',
        'prefetched_used': 2,
        'prefetched_total': 5,
      });
    });

    test('reportCacheMetrics is a no-op without a provider', () {
      tracker.reportCacheMetrics();

      expect(sink.events, isEmpty);
    });

    test('clearAllSessions removes active sessions', () {
      tracker.startVideoLoading(videoId, 'https://videos.example.com/file.mp4');

      tracker.clearAllSessions();

      expect(tracker.activeSessions, 0);
      expect(tracker.getLoadingStatus(videoId), isNull);
    });
  });
}
