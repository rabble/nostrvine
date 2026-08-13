// ABOUTME: Featured-tab adapter for surface performance analytics.
// ABOUTME: Reports a generic surface name plus the opaque configuration id.

import 'package:analytics/analytics.dart';

/// Emits `surface_load` for a featured Explore tab.
///
/// The surface name is the same for every featured tab; the configuration id
/// is the distinguishing parameter. Deriving analytics names from tab content
/// would bake editorial names into dashboard schemas and exports, so the id
/// is the only thing that varies.
class FeaturedTabSurfaceTelemetry {
  /// Creates a telemetry adapter for the tab identified by [configId].
  ///
  /// [tracker] is required so this adapter shares the app's surface-load
  /// sessions and page-load buffer instead of starting sessions on a private
  /// tracker nothing else can complete or read.
  FeaturedTabSurfaceTelemetry({
    required String configId,
    required SurfacePerformanceTracker tracker,
  }) : _configId = configId,
       _tracker = tracker;

  final String _configId;
  final SurfacePerformanceTracker _tracker;

  /// Marks the start of a load for this tab.
  void start() {
    _tracker.startSurfaceLoad(
      AnalyticsSurface.featuredTab,
      params: {
        AnalyticsParam.entryPoint: 'explore_tab',
        AnalyticsParam.configId: _configId,
      },
    );
  }

  /// Completes the load with the page the server returned.
  Future<void> completeLoaded({
    required int itemCount,
    required bool hasMore,
  }) {
    return _tracker.completeSurfaceLoad(
      AnalyticsSurface.featuredTab,
      result: itemCount == 0
          ? SurfaceLoadResult.empty
          : SurfaceLoadResult.success,
      metrics: {
        AnalyticsParam.configId: _configId,
        AnalyticsParam.itemCount: itemCount,
        AnalyticsParam.hasMore: hasMore,
      },
    );
  }

  /// Completes the load as a failure.
  Future<void> completeFailure() {
    return _tracker.completeSurfaceLoad(
      AnalyticsSurface.featuredTab,
      result: SurfaceLoadResult.failure,
      metrics: {AnalyticsParam.configId: _configId},
    );
  }
}
