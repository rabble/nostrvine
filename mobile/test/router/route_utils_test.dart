// ABOUTME: Tests for route parsing and building utilities
// ABOUTME: Verifies route URL parsing and construction

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/router/route_utils.dart';
import 'package:openvine/screens/clip_manager_screen.dart';
import 'package:openvine/screens/explore_screen.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/screens/home_screen_router.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/screens/pure/universal_camera_screen_pure.dart';
import 'package:openvine/screens/settings_screen.dart';
import 'package:openvine/screens/video_editor_screen.dart';

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

    test('parses camera route', () {
      final result = parseRoute(UniversalCameraScreenPure.path);

      expect(result.type, RouteType.camera);
      expect(result.videoIndex, isNull);
    });

    test('parses settings route', () {
      final result = parseRoute(SettingsScreen.path);

      expect(result.type, RouteType.settings);
      expect(result.videoIndex, isNull);
    });

    test('parses clip-manager route', () {
      final result = parseRoute(ClipManagerScreen.path);

      expect(result.type, RouteType.clipManager);
      expect(result.videoIndex, isNull);
    });

    test('parses edit-video route', () {
      final result = parseRoute(VideoEditorScreen.path);

      expect(result.type, RouteType.editVideo);
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

    test('builds camera route', () {
      final context = RouteContext(type: RouteType.camera);

      expect(buildRoute(context), UniversalCameraScreenPure.path);
    });

    test('builds settings route', () {
      final context = RouteContext(type: RouteType.settings);

      expect(buildRoute(context), SettingsScreen.path);
    });

    test('builds clip-manager route', () {
      final context = RouteContext(type: RouteType.clipManager);

      expect(buildRoute(context), ClipManagerScreen.path);
    });

    test('builds edit-video route', () {
      final context = RouteContext(type: RouteType.editVideo);

      expect(buildRoute(context), VideoEditorScreen.path);
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
        UniversalCameraScreenPure.path,
        SettingsScreen.path,
        ClipManagerScreen.path,
        VideoEditorScreen.path,
      ];

      for (final url in urls) {
        final parsed = parseRoute(url);
        final rebuilt = buildRoute(parsed);
        expect(rebuilt, url, reason: 'Failed for $url');
      }
    });
  });
}
