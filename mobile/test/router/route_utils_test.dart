// ABOUTME: Tests for route parsing and building utilities
// ABOUTME: Verifies route URL parsing and construction

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/router/route_utils.dart';
import 'package:openvine/screens/explore_screen.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/screens/home_screen_router.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/screens/settings_screen.dart';
import 'package:openvine/screens/video_editor/video_clip_editor_screen.dart';
import 'package:openvine/screens/video_editor/video_editor_screen.dart';
import 'package:openvine/screens/video_metadata/video_metadata_screen.dart';
import 'package:openvine/screens/video_recorder_screen.dart';

void main() {
  group('parseRoute', () {
    test('parses home route with index', () {
      final result = parseRoute(HomeScreenRouter.pathForIndex(5));

      expect(result.type, RouteType.home);
      expect(result.videoIndex, 5);
      expect(result.npub, isNull);
      expect(result.hashtag, isNull);
    });

    test('parses explore route with index', () {
      final result = parseRoute(ExploreScreen.pathForIndex(3));

      expect(result.type, RouteType.explore);
      expect(result.videoIndex, 3);
    });

    test('parses profile route with npub and index', () {
      final result = parseRoute(
        ProfileScreenRouter.pathForIndex('npub1abc123', 2),
      );

      expect(result.type, RouteType.profile);
      expect(result.npub, 'npub1abc123');
      expect(result.videoIndex, 2);
    });

    test('parses hashtag route with tag and index', () {
      final result = parseRoute(
        HashtagScreenRouter.pathForTag('nostr', index: 1),
      );

      expect(result.type, RouteType.hashtag);
      expect(result.hashtag, 'nostr');
      expect(result.videoIndex, 1);
    });

    test('parses video-recorder route', () {
      final result = parseRoute('/video-recorder');

      expect(result.type, RouteType.videoRecorder);
      expect(result.videoIndex, isNull);
    });

    test('parses video-editor route', () {
      final result = parseRoute('/video-editor');

      expect(result.type, RouteType.videoEditor);
      expect(result.videoIndex, isNull);
    });

    test('parses settings route', () {
      final result = parseRoute(SettingsScreen.path);

      expect(result.type, RouteType.settings);
      expect(result.videoIndex, isNull);
    });

    test('defaults to home/0 for unknown route', () {
      final result = parseRoute('/unknown/path');

      expect(result.type, RouteType.home);
      expect(result.videoIndex, 0);
    });

    test('handles missing index defaulting to 0', () {
      final result = parseRoute(HomeScreenRouter.path);

      expect(result.type, RouteType.home);
      expect(result.videoIndex, 0);
    });
  });

  group('buildRoute', () {
    test('builds home route with index', () {
      final context = RouteContext(type: RouteType.home, videoIndex: 5);

      expect(buildRoute(context), HomeScreenRouter.pathForIndex(5));
    });

    test('builds explore route with index', () {
      final context = RouteContext(type: RouteType.explore, videoIndex: 3);

      expect(buildRoute(context), ExploreScreen.pathForIndex(3));
    });

    test('builds profile route with npub and index', () {
      final context = RouteContext(
        type: RouteType.profile,
        npub: 'npub1abc123',
        videoIndex: 2,
      );

      expect(
        buildRoute(context),
        ProfileScreenRouter.pathForIndex('npub1abc123', 2),
      );
    });

    test('builds hashtag route with tag and index', () {
      final context = RouteContext(
        type: RouteType.hashtag,
        hashtag: 'nostr',
        videoIndex: 1,
      );

      expect(
        buildRoute(context),
        HashtagScreenRouter.pathForTag('nostr', index: 1),
      );
    });

    test('builds video-recorder route', () {
      final context = RouteContext(type: RouteType.videoRecorder);

      expect(buildRoute(context), VideoRecorderScreen.path);
    });

    test('builds video-clip-editor route', () {
      final context = RouteContext(type: RouteType.videoClipEditor);

      expect(buildRoute(context), VideoClipEditorScreen.path);
    });

    test('builds video-editor route', () {
      final context = RouteContext(type: RouteType.videoEditor);

      expect(buildRoute(context), VideoEditorScreen.path);
    });

    test('builds video-metadata route', () {
      final context = RouteContext(type: RouteType.videoMetadata);

      expect(buildRoute(context), VideoMetadataScreen.path);
    });

    test('builds settings route', () {
      final context = RouteContext(type: RouteType.settings);

      expect(buildRoute(context), SettingsScreen.path);
    });

    test('defaults missing index to 0 for video routes', () {
      final context = RouteContext(type: RouteType.home);

      expect(buildRoute(context), HomeScreenRouter.pathForIndex(0));
    });
  });

  group('round-trip consistency', () {
    test('parse then build returns original URL', () {
      final urls = [
        HomeScreenRouter.pathForIndex(5),
        ExploreScreen.pathForIndex(3),
        ProfileScreenRouter.pathForIndex('npub1abc123', 2),
        HashtagScreenRouter.pathForTag('nostr', index: 1),
        VideoRecorderScreen.path,
        VideoClipEditorScreen.path,
        VideoMetadataScreen.path,
        SettingsScreen.path,
      ];

      for (final url in urls) {
        final parsed = parseRoute(url);
        final rebuilt = buildRoute(parsed);
        expect(rebuilt, url, reason: 'Failed for $url');
      }
    });
  });
}
