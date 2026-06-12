// ABOUTME: Tests for user-visible surface performance analytics.
// ABOUTME: Verifies terminal surface_load events and stale session cleanup.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/analytics_event_sink.dart';
import 'package:openvine/services/analytics_surface.dart';
import 'package:openvine/services/surface_performance_tracker.dart';

class RecordingAnalyticsEventSink implements AnalyticsEventSink {
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
  group(SurfacePerformanceTracker, () {
    late RecordingAnalyticsEventSink sink;
    late DateTime now;
    late SurfacePerformanceTracker tracker;

    void elapse(Duration duration) {
      now = now.add(duration);
    }

    setUp(() {
      SurfacePerformanceTracker.resetInstance();
      sink = RecordingAnalyticsEventSink();
      now = DateTime(2026, 6, 12, 12);
      tracker = SurfacePerformanceTracker.testInstance(
        sink: sink,
        now: () => now,
      );
    });

    tearDown(SurfacePerformanceTracker.resetInstance);

    test('logs one surface_load event with semantic parameters', () async {
      tracker.startSurfaceLoad(
        'Comments Sheet',
        params: const {
          AnalyticsParam.entryPoint: 'feed_button',
          AnalyticsParam.initialCount: 12,
        },
      );
      elapse(const Duration(milliseconds: 120));

      tracker.markSurfaceVisible('Comments Sheet');
      elapse(const Duration(milliseconds: 680));

      await tracker.completeSurfaceLoad(
        'Comments Sheet',
        result: SurfaceLoadResult.success,
        metrics: const {
          AnalyticsParam.itemCount: 10,
          AnalyticsParam.hasMore: true,
        },
      );
      await tracker.completeSurfaceLoad(
        'Comments Sheet',
        result: SurfaceLoadResult.success,
      );

      expect(sink.events, hasLength(1));
      expect(sink.events.single.name, 'surface_load');
      expect(sink.events.single.parameters, {
        AnalyticsParam.surfaceName: AnalyticsSurface.commentsSheet,
        AnalyticsParam.result: SurfaceLoadResult.success,
        AnalyticsParam.visibleMs: 120,
        AnalyticsParam.dataMs: 800,
        AnalyticsParam.totalMs: 800,
        AnalyticsParam.slowBucket: 'under_1s',
        AnalyticsParam.entryPoint: 'feed_button',
        AnalyticsParam.initialCount: 12,
        AnalyticsParam.itemCount: 10,
        AnalyticsParam.hasMore: true,
      });
      expect(tracker.activeSessionCount, 0);
    });

    test(
      'completing dismissed removes the session and logs dismissed',
      () async {
        tracker.startSurfaceLoad(AnalyticsSurface.commentsSheet);
        elapse(const Duration(milliseconds: 50));

        await tracker.completeSurfaceLoad(
          AnalyticsSurface.commentsSheet,
          result: SurfaceLoadResult.dismissed,
        );

        expect(tracker.activeSessionCount, 0);
        expect(sink.events, hasLength(1));
        expect(
          sink.events.single.parameters[AnalyticsParam.result],
          SurfaceLoadResult.dismissed,
        );
      },
    );

    test(
      'resetAllSessions clears active sessions and later completion is no-op',
      () async {
        tracker
          ..startSurfaceLoad(AnalyticsSurface.commentsSheet)
          ..startSurfaceLoad(AnalyticsSurface.profile);

        expect(tracker.activeSessionCount, 2);

        tracker.resetAllSessions();
        await tracker.completeSurfaceLoad(
          AnalyticsSurface.commentsSheet,
          result: SurfaceLoadResult.success,
        );

        expect(tracker.activeSessionCount, 0);
        expect(sink.events, isEmpty);
      },
    );

    test(
      'stale sessions older than 60s are discarded without logging',
      () async {
        tracker.startSurfaceLoad(AnalyticsSurface.commentsSheet);
        elapse(const Duration(seconds: 61));

        tracker.markSurfaceVisible(AnalyticsSurface.commentsSheet);
        await tracker.completeSurfaceLoad(
          AnalyticsSurface.commentsSheet,
          result: SurfaceLoadResult.success,
        );

        expect(tracker.activeSessionCount, 0);
        expect(sink.events, isEmpty);
      },
    );
  });
}
