// ABOUTME: Validates all app_router.dart routes have corresponding parseRoute cases
// ABOUTME: Prevents route definition/parsing drift that caused the relay-settings bug

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/router/route_utils.dart';
import 'package:openvine/screens/blossom_settings_screen.dart';
import 'package:openvine/screens/clip_library_screen.dart';
import 'package:openvine/screens/clip_manager_screen.dart';
import 'package:openvine/screens/explore_screen.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/screens/home_screen_router.dart';
import 'package:openvine/screens/key_import_screen.dart';
import 'package:openvine/screens/key_management_screen.dart';
import 'package:openvine/screens/notification_settings_screen.dart';
import 'package:openvine/screens/notifications_screen.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/screens/profile_setup_screen.dart';
import 'package:openvine/screens/pure/search_screen_pure.dart';
import 'package:openvine/screens/pure/universal_camera_screen_pure.dart';
import 'package:openvine/screens/relay_diagnostic_screen.dart';
import 'package:openvine/screens/relay_settings_screen.dart';
import 'package:openvine/screens/safety_settings_screen.dart';
import 'package:openvine/screens/settings_screen.dart';
import 'package:openvine/screens/video_editor_screen.dart';
import 'package:openvine/screens/welcome_screen.dart';

void main() {
  group('Route Coverage Validation', () {
    group('Settings routes parse to their own RouteTypes', () {
      // Each settings sub-route has its own RouteType to prevent
      // routeNormalizationProvider from redirecting them to /settings
      test('${SettingsScreen.path} parses to RouteType.settings', () {
        final context = parseRoute(SettingsScreen.path);
        expect(context.type, RouteType.settings);
      });

      test('${RelaySettingsScreen.path} parses to RouteType.relaySettings', () {
        final context = parseRoute(RelaySettingsScreen.path);
        expect(context.type, RouteType.relaySettings);
      });

      test(
        '${RelayDiagnosticScreen.path} parses to RouteType.relayDiagnostic',
        () {
          final context = parseRoute(RelayDiagnosticScreen.path);
          expect(context.type, RouteType.relayDiagnostic);
        },
      );

      test(
        '${BlossomSettingsScreen.path} parses to RouteType.blossomSettings',
        () {
          final context = parseRoute(BlossomSettingsScreen.path);
          expect(context.type, RouteType.blossomSettings);
        },
      );

      test(
        '${NotificationSettingsScreen.path} parses to RouteType.notificationSettings',
        () {
          final context = parseRoute(NotificationSettingsScreen.path);
          expect(context.type, RouteType.notificationSettings);
        },
      );

      test('${KeyManagementScreen.path} parses to RouteType.keyManagement', () {
        final context = parseRoute(KeyManagementScreen.path);
        expect(context.type, RouteType.keyManagement);
      });

      test(
        '${SafetySettingsScreen.path} parses to RouteType.safetySettings',
        () {
          final context = parseRoute(SafetySettingsScreen.path);
          expect(context.type, RouteType.safetySettings);
        },
      );
    });

    group('Profile editing routes parse to RouteType.editProfile', () {
      const profileEditRoutes = [
        ProfileSetupScreen.editPath,
        ProfileSetupScreen.setupPath,
      ];

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
        ClipLibraryScreen.clipsPath,
        ClipLibraryScreen.draftsPath, // Legacy route should also work
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
      test(
        '${HomeScreenRouter.path} parses to RouteType.home with index 0',
        () {
          final context = parseRoute(HomeScreenRouter.path);
          expect(context.type, RouteType.home);
          expect(context.videoIndex, 0);
        },
      );

      test(
        '${HomeScreenRouter.pathForIndex(5)} parses to RouteType.home with index 5',
        () {
          final context = parseRoute(HomeScreenRouter.pathForIndex(5));
          expect(context.type, RouteType.home);
          expect(context.videoIndex, 5);
        },
      );

      test('${ExploreScreen.path} parses to RouteType.explore', () {
        final context = parseRoute(ExploreScreen.path);
        expect(context.type, RouteType.explore);
        expect(context.videoIndex, isNull);
      });

      test(
        '${ExploreScreen.pathForIndex(3)} parses to RouteType.explore with index 3',
        () {
          final context = parseRoute(ExploreScreen.pathForIndex(3));
          expect(context.type, RouteType.explore);
          expect(context.videoIndex, 3);
        },
      );

      test(
        '${NotificationsScreen.pathForIndex(0)} parses to RouteType.notifications',
        () {
          final context = parseRoute(NotificationsScreen.pathForIndex(0));
          expect(context.type, RouteType.notifications);
          expect(context.videoIndex, 0);
        },
      );
    });

    group('Profile routes parse correctly', () {
      test(
        '${ProfileScreenRouter.pathForNpub('npub1abc')} parses to RouteType.profile (grid mode)',
        () {
          final context = parseRoute(
            ProfileScreenRouter.pathForNpub('npub1abc'),
          );
          expect(context.type, RouteType.profile);
          expect(context.npub, 'npub1abc');
          expect(context.videoIndex, isNull); // Grid mode has no index
        },
      );

      test(
        '${ProfileScreenRouter.pathForIndex('npub1abc', 2)} parses to RouteType.profile (feed mode)',
        () {
          final context = parseRoute(
            ProfileScreenRouter.pathForIndex('npub1abc', 2),
          );
          expect(context.type, RouteType.profile);
          expect(context.npub, 'npub1abc');
          expect(context.videoIndex, 2); // Feed mode has index
        },
      );

      test('${ProfileScreenRouter.path} without npub redirects to home', () {
        final context = parseRoute(ProfileScreenRouter.path);
        expect(context.type, RouteType.home);
      });
    });

    group('Search routes parse correctly', () {
      test(
        '${SearchScreenPure.path} parses to RouteType.search (grid mode)',
        () {
          final context = parseRoute(SearchScreenPure.path);
          expect(context.type, RouteType.search);
          expect(context.searchTerm, isNull);
          expect(context.videoIndex, isNull);
        },
      );

      test(
        '${SearchScreenPure.pathForTerm(term: 'flutter')} parses to RouteType.search with term',
        () {
          final context = parseRoute(
            SearchScreenPure.pathForTerm(term: 'flutter'),
          );
          expect(context.type, RouteType.search);
          expect(context.searchTerm, 'flutter');
          expect(context.videoIndex, isNull);
        },
      );

      test(
        '${SearchScreenPure.pathForTerm(term: 'flutter', index: 5)} parses to RouteType.search (feed mode)',
        () {
          final context = parseRoute(
            '${SearchScreenPure.pathForTerm(term: 'flutter', index: 5)}',
          );
          expect(context.type, RouteType.search);
          expect(context.searchTerm, 'flutter');
          expect(context.videoIndex, 5);
        },
      );
    });

    group('Hashtag routes parse correctly', () {
      test(
        '${HashtagScreenRouter.pathForTag('nostr')} parses to RouteType.hashtag',
        () {
          final context = parseRoute(HashtagScreenRouter.pathForTag('nostr'));
          expect(context.type, RouteType.hashtag);
          expect(context.hashtag, 'nostr');
          expect(context.videoIndex, isNull);
        },
      );

      test(
        '${HashtagScreenRouter.pathForTag('nostr', index: 3)} parses to RouteType.hashtag with index',
        () {
          final context = parseRoute(
            HashtagScreenRouter.pathForTag('nostr', index: 3),
          );
          expect(context.type, RouteType.hashtag);
          expect(context.hashtag, 'nostr');
          expect(context.videoIndex, 3);
        },
      );

      test('${HashtagScreenRouter.path} without tag redirects to home', () {
        final context = parseRoute(HashtagScreenRouter.basePath);
        expect(context.type, RouteType.home);
      });
    });

    group('Standalone routes parse correctly', () {
      test('${WelcomeScreen.path} parses to RouteType.welcome', () {
        final context = parseRoute(WelcomeScreen.path);
        expect(context.type, RouteType.welcome);
      });

      test('${KeyImportScreen.path} parses to RouteType.importKey', () {
        final context = parseRoute(KeyImportScreen.path);
        expect(context.type, RouteType.importKey);
      });

      test('${UniversalCameraScreenPure.path} parses to RouteType.camera', () {
        final context = parseRoute(UniversalCameraScreenPure.path);
        expect(context.type, RouteType.camera);
      });

      test('${ClipManagerScreen.path} parses to RouteType.clipManager', () {
        final context = parseRoute(ClipManagerScreen.path);
        expect(context.type, RouteType.clipManager);
      });

      test('${VideoEditorScreen.path} parses to RouteType.editVideo', () {
        final context = parseRoute(VideoEditorScreen.path);
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
        final context = parseRoute(HomeScreenRouter.pathForIndex(-5));
        expect(context.type, RouteType.home);
        expect(context.videoIndex, 0);
      });
    });

    group('URL encoding is handled', () {
      test('URL-encoded npub is decoded', () {
        final encoded = Uri.encodeComponent('npub1abc+test');
        final context = parseRoute(ProfileScreenRouter.pathForNpub(encoded));
        expect(context.npub, 'npub1abc+test');
      });

      test('URL-encoded hashtag is decoded', () {
        final encoded = Uri.encodeComponent('nostr+bitcoin');
        final context = parseRoute('${HashtagScreenRouter.basePath}/$encoded');
        expect(context.hashtag, 'nostr+bitcoin');
      });

      test('URL-encoded search term is decoded', () {
        final encoded = Uri.encodeComponent('flutter dart');
        final context = parseRoute('${SearchScreenPure.path}/$encoded');
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
        RouteType.home: HomeScreenRouter.pathForIndex(0),
        RouteType.explore: ExploreScreen.path,
        RouteType.notifications: NotificationsScreen.pathForIndex(0),
        RouteType.profile: ProfileScreenRouter.pathForNpub('npub1test'),
        RouteType.hashtag: HashtagScreenRouter.pathForTag('test'),
        RouteType.search: SearchScreenPure.path,
        RouteType.camera: UniversalCameraScreenPure.path,
        RouteType.clipManager: ClipManagerScreen.path,
        RouteType.editVideo: VideoEditorScreen.path,
        RouteType.importKey: KeyImportScreen.path,
        RouteType.settings: SettingsScreen.path,
        RouteType.relaySettings: RelaySettingsScreen.path,
        RouteType.relayDiagnostic: RelayDiagnosticScreen.path,
        RouteType.blossomSettings: BlossomSettingsScreen.path,
        RouteType.notificationSettings: NotificationSettingsScreen.path,
        RouteType.keyManagement: KeyManagementScreen.path,
        RouteType.safetySettings: SafetySettingsScreen.path,
        RouteType.editProfile: ProfileSetupScreen.editPath,
        RouteType.clips: ClipLibraryScreen.clipsPath,
        RouteType.welcome: WelcomeScreen.path,
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
