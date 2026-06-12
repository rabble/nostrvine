import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/analytics_surface.dart';

void main() {
  group('AnalyticsSurface', () {
    test('core surface names are stable snake_case values', () {
      expect(AnalyticsSurface.homeFeed, 'home_feed');
      expect(AnalyticsSurface.explore, 'explore');
      expect(AnalyticsSurface.profile, 'profile');
      expect(AnalyticsSurface.videoDetail, 'video_detail');
      expect(AnalyticsSurface.commentsSheet, 'comments_sheet');
      expect(AnalyticsSurface.settings, 'settings');
    });

    test('slowBucket classifies user-visible waits', () {
      expect(AnalyticsSurface.slowBucket(999), 'under_1s');
      expect(AnalyticsSurface.slowBucket(1000), '1_3s');
      expect(AnalyticsSurface.slowBucket(3000), '3_5s');
      expect(AnalyticsSurface.slowBucket(5000), '5_10s');
      expect(AnalyticsSurface.slowBucket(10000), 'over_10s');
    });
  });
}
