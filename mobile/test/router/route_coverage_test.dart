// ABOUTME: Validates all app_router.dart routes have corresponding parseRoute cases
// ABOUTME: Prevents route definition/parsing drift that caused the relay-settings bug

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/router/route_utils.dart';

void main() {
  group('Route Coverage Validation', () {
    group('Settings routes parse to their own RouteTypes', () {
      // Each settings sub-route has its own RouteType to prevent
      // routeNormalizationProvider from redirecting them to /settings
      test('/settings parses to RouteType.settings', () {
        final context = parseRoute('/settings');
        expect(context.type, RouteType.settings);
      });

      test('/relay-settings parses to RouteType.relaySettings', () {
        final context = parseRoute('/relay-settings');
        expect(context.type, RouteType.relaySettings);
      });

      test('/relay-diagnostic parses to RouteType.relayDiagnostic', () {
        final context = parseRoute('/relay-diagnostic');
        expect(context.type, RouteType.relayDiagnostic);
      });

      test('/blossom-settings parses to RouteType.blossomSettings', () {
        final context = parseRoute('/blossom-settings');
        expect(context.type, RouteType.blossomSettings);
      });

      test(
        '/notification-settings parses to RouteType.notificationSettings',
        () {
          final context = parseRoute('/notification-settings');
          expect(context.type, RouteType.notificationSettings);
        },
      );

      test('/key-management parses to RouteType.keyManagement', () {
        final context = parseRoute('/key-management');
        expect(context.type, RouteType.keyManagement);
      });

      test('/safety-settings parses to RouteType.safetySettings', () {
        final context = parseRoute('/safety-settings');
        expect(context.type, RouteType.safetySettings);
      });
    });

    group('Profile editing routes parse to RouteType.editProfile', () {
      const profileEditRoutes = ['/edit-profile', '/setup-profile'];

      for (final route in profileEditRoutes) {
        test('$route parses to RouteType.editProfile', () {
          final context = parseRoute(route);
          expect(
            context.type,
            RouteType.editProfile,
            reason: '$route should parse to RouteType.editProfile',
          );
        });
      }
    });

    group('Clip routes parse to RouteType.clips', () {
      const clipRoutes = [
        '/clips',
        '/drafts', // Legacy route should also work
      ];

      for (final route in clipRoutes) {
        test('$route parses to RouteType.clips', () {
          final context = parseRoute(route);
          expect(
            context.type,
            RouteType.clips,
            reason: '$route should parse to RouteType.clips',
          );
        });
      }
    });

    group('Tab routes parse correctly', () {
      test('/home parses to RouteType.home with index 0', () {
        final context = parseRoute('/home');
        expect(context.type, RouteType.home);
        expect(context.videoIndex, 0);
      });

      test('/home/5 parses to RouteType.home with index 5', () {
        final context = parseRoute('/home/5');
        expect(context.type, RouteType.home);
        expect(context.videoIndex, 5);
      });

      test('/explore parses to RouteType.explore', () {
        final context = parseRoute('/explore');
        expect(context.type, RouteType.explore);
        expect(context.videoIndex, isNull);
      });

      test('/explore/3 parses to RouteType.explore with index 3', () {
        final context = parseRoute('/explore/3');
        expect(context.type, RouteType.explore);
        expect(context.videoIndex, 3);
      });

      test('/notifications/0 parses to RouteType.notifications', () {
        final context = parseRoute('/notifications/0');
        expect(context.type, RouteType.notifications);
        expect(context.videoIndex, 0);
      });
    });

    group('Profile routes parse correctly', () {
      test('/profile/npub1abc parses to RouteType.profile (grid mode)', () {
        final context = parseRoute('/profile/npub1abc');
        expect(context.type, RouteType.profile);
        expect(context.npub, 'npub1abc');
        expect(context.videoIndex, isNull); // Grid mode has no index
      });

      test('/profile/npub1abc/2 parses to RouteType.profile (feed mode)', () {
        final context = parseRoute('/profile/npub1abc/2');
        expect(context.type, RouteType.profile);
        expect(context.npub, 'npub1abc');
        expect(context.videoIndex, 2); // Feed mode has index
      });

      test('/profile without npub redirects to home', () {
        final context = parseRoute('/profile');
        expect(context.type, RouteType.home);
      });
    });

    group('Search routes parse correctly', () {
      test('/search parses to RouteType.search (grid mode)', () {
        final context = parseRoute('/search');
        expect(context.type, RouteType.search);
        expect(context.searchTerm, isNull);
        expect(context.videoIndex, isNull);
      });

      test('/search/flutter parses to RouteType.search with term', () {
        final context = parseRoute('/search/flutter');
        expect(context.type, RouteType.search);
        expect(context.searchTerm, 'flutter');
        expect(context.videoIndex, isNull);
      });

      test('/search/flutter/5 parses to RouteType.search (feed mode)', () {
        final context = parseRoute('/search/flutter/5');
        expect(context.type, RouteType.search);
        expect(context.searchTerm, 'flutter');
        expect(context.videoIndex, 5);
      });
    });

    group('Hashtag routes parse correctly', () {
      test('/hashtag/nostr parses to RouteType.hashtag', () {
        final context = parseRoute('/hashtag/nostr');
        expect(context.type, RouteType.hashtag);
        expect(context.hashtag, 'nostr');
        expect(context.videoIndex, isNull);
      });

      test('/hashtag/nostr/3 parses to RouteType.hashtag with index', () {
        final context = parseRoute('/hashtag/nostr/3');
        expect(context.type, RouteType.hashtag);
        expect(context.hashtag, 'nostr');
        expect(context.videoIndex, 3);
      });

      test('/hashtag without tag redirects to home', () {
        final context = parseRoute('/hashtag');
        expect(context.type, RouteType.home);
      });
    });

    group('Standalone routes parse correctly', () {
      test('/welcome parses to RouteType.welcome', () {
        final context = parseRoute('/welcome');
        expect(context.type, RouteType.welcome);
      });

      test('/import-key parses to RouteType.importKey', () {
        final context = parseRoute('/import-key');
        expect(context.type, RouteType.importKey);
      });

      test('/camera parses to RouteType.camera', () {
        final context = parseRoute('/camera');
        expect(context.type, RouteType.camera);
      });

      test('/clip-manager parses to RouteType.clipManager', () {
        final context = parseRoute('/clip-manager');
        expect(context.type, RouteType.clipManager);
      });

      test('/edit-video parses to RouteType.editVideo', () {
        final context = parseRoute('/edit-video');
        expect(context.type, RouteType.editVideo);
      });
    });

    group('Edge cases', () {
      test('Empty path defaults to home/0', () {
        final context = parseRoute('');
        expect(context.type, RouteType.home);
        expect(context.videoIndex, 0);
      });

      test('Root path defaults to home/0', () {
        final context = parseRoute('/');
        expect(context.type, RouteType.home);
        expect(context.videoIndex, 0);
      });

      test('Unknown route defaults to home/0', () {
        final context = parseRoute('/unknown-route');
        expect(context.type, RouteType.home);
        expect(context.videoIndex, 0);
      });

      test('Negative index is normalized to 0', () {
        final context = parseRoute('/home/-5');
        expect(context.type, RouteType.home);
        expect(context.videoIndex, 0);
      });
    });

    group('URL encoding is handled', () {
      test('URL-encoded npub is decoded', () {
        final encoded = Uri.encodeComponent('npub1abc+test');
        final context = parseRoute('/profile/$encoded');
        expect(context.npub, 'npub1abc+test');
      });

      test('URL-encoded hashtag is decoded', () {
        final encoded = Uri.encodeComponent('nostr+bitcoin');
        final context = parseRoute('/hashtag/$encoded');
        expect(context.hashtag, 'nostr+bitcoin');
      });

      test('URL-encoded search term is decoded', () {
        final encoded = Uri.encodeComponent('flutter dart');
        final context = parseRoute('/search/$encoded');
        expect(context.searchTerm, 'flutter dart');
      });
    });
  });

  group('Route Coverage Completeness', () {
    // This test documents all routes that should be handled by parseRoute()
    // If a new route is added to app_router.dart, it should be added here too
    test('All RouteTypes have corresponding parseRoute cases', () {
      // Test that each RouteType can be produced by parseRoute
      final routeTypeExamples = {
        RouteType.home: '/home/0',
        RouteType.explore: '/explore',
        RouteType.notifications: '/notifications/0',
        RouteType.profile: '/profile/npub1test',
        RouteType.hashtag: '/hashtag/test',
        RouteType.search: '/search',
        RouteType.camera: '/camera',
        RouteType.clipManager: '/clip-manager',
        RouteType.editVideo: '/edit-video',
        RouteType.importKey: '/import-key',
        RouteType.settings: '/settings',
        RouteType.relaySettings: '/relay-settings',
        RouteType.relayDiagnostic: '/relay-diagnostic',
        RouteType.blossomSettings: '/blossom-settings',
        RouteType.notificationSettings: '/notification-settings',
        RouteType.keyManagement: '/key-management',
        RouteType.safetySettings: '/safety-settings',
        RouteType.editProfile: '/edit-profile',
        RouteType.clips: '/clips',
        RouteType.welcome: '/welcome',
      };

      for (final entry in routeTypeExamples.entries) {
        final expectedType = entry.key;
        final exampleRoute = entry.value;
        final context = parseRoute(exampleRoute);
        expect(
          context.type,
          expectedType,
          reason: 'RouteType.$expectedType should be produced by $exampleRoute',
        );
      }
    });
  });
}
