// ABOUTME: Stable semantic names and safe parameter helpers for analytics.

abstract final class AnalyticsSurface {
  static const homeFeed = 'home_feed';
  static const explore = 'explore';
  static const notifications = 'notifications';
  static const inbox = 'inbox';
  static const profile = 'profile';
  static const videoDetail = 'video_detail';
  static const commentsSheet = 'comments_sheet';
  static const settings = 'settings';
  static const searchResults = 'search_results';
  static const videoRecorder = 'video_recorder';
  static const videoEditor = 'video_editor';
  static const unknownRoute = 'unknown_route';

  static String slowBucket(int totalMs) {
    if (totalMs < 1000) return 'under_1s';
    if (totalMs < 3000) return '1_3s';
    if (totalMs < 5000) return '3_5s';
    if (totalMs < 10000) return '5_10s';
    return 'over_10s';
  }

  static String sanitizeName(String value) {
    final normalized = value
        .trim()
        .replaceAll(RegExp('[^A-Za-z0-9_]+'), '_')
        .replaceAll(RegExp('_+'), '_')
        .toLowerCase();
    return normalized.isEmpty ? unknownRoute : normalized;
  }
}

abstract final class AnalyticsParam {
  static const screenName = 'screen_name';
  static const surfaceName = 'surface_name';
  static const routeName = 'route_name';
  static const entryPoint = 'entry_point';
  static const result = 'result';
  static const visibleMs = 'visible_ms';
  static const dataMs = 'data_ms';
  static const totalMs = 'total_ms';
  static const slowBucket = 'slow_bucket';
  static const itemCount = 'item_count';
  static const initialCount = 'initial_count';
  static const hasMore = 'has_more';
  static const featureFlag = 'feature_flag';
}

abstract final class SurfaceLoadResult {
  static const success = 'success';
  static const empty = 'empty';
  static const failure = 'failure';
  static const dismissed = 'dismissed';
}
