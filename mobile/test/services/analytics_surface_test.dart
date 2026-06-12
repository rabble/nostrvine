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

    test('sanitizeName normalizes route and surface names', () {
      expect(AnalyticsSurface.sanitizeName('video-detail'), 'video_detail');
      expect(AnalyticsSurface.sanitizeName('/settings'), 'settings');
      expect(AnalyticsSurface.sanitizeName('originalSound'), 'original_sound');
      expect(AnalyticsSurface.sanitizeName('settings/'), 'settings');
      expect(AnalyticsSurface.sanitizeName('__settings__'), 'settings');
      expect(AnalyticsSurface.sanitizeName('  Home Feed  '), 'home_feed');
      expect(
        AnalyticsSurface.sanitizeName('home---feed///detail'),
        'home_feed_detail',
      );
      expect(AnalyticsSurface.sanitizeName(''), AnalyticsSurface.unknownRoute);
      expect(
        AnalyticsSurface.sanitizeName('///'),
        AnalyticsSurface.unknownRoute,
      );
    });

    test('routeSurfaceName maps app route names to semantic surfaces', () {
      expect(AnalyticsSurface.routeSurfaceName('/'), AnalyticsSurface.homeFeed);
      expect(
        AnalyticsSurface.routeSurfaceName('home'),
        AnalyticsSurface.homeFeed,
      );
      expect(
        AnalyticsSurface.routeSurfaceName('video'),
        AnalyticsSurface.videoDetail,
      );
      expect(
        AnalyticsSurface.routeSurfaceName('video-recorder'),
        AnalyticsSurface.videoRecorder,
      );
      expect(
        AnalyticsSurface.routeSurfaceName('video-editor'),
        AnalyticsSurface.videoEditor,
      );
      expect(
        AnalyticsSurface.routeSurfaceName('developer-options'),
        'developer_options',
      );
      expect(
        AnalyticsSurface.routeSurfaceName('originalSound'),
        'original_sound',
      );
      expect(
        AnalyticsSurface.routeSurfaceName(null),
        AnalyticsSurface.unknownRoute,
      );
    });
  });
}
