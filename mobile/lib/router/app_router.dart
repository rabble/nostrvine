// ABOUTME: GoRouter configuration with ShellRoute for per-tab state preservation
// ABOUTME: URL is source of truth, bottom nav bound to routes

import 'dart:convert';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/router/app_shell.dart';
import 'package:openvine/screens/explore_screen.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/screens/home_screen_router.dart';
import 'package:openvine/screens/liked_videos_screen_router.dart';
import 'package:openvine/screens/notifications_screen.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/screens/pure/search_screen_pure.dart';
import 'package:openvine/screens/pure/universal_camera_screen_pure.dart';
import 'package:openvine/screens/followers/my_followers_screen.dart';
import 'package:openvine/screens/followers/others_followers_screen.dart';
import 'package:openvine/screens/following/my_following_screen.dart';
import 'package:openvine/screens/following/others_following_screen.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/screens/key_import_screen.dart';
import 'package:openvine/screens/profile_setup_screen.dart';
import 'package:openvine/screens/blossom_settings_screen.dart';
import 'package:openvine/screens/key_management_screen.dart';
import 'package:openvine/screens/notification_settings_screen.dart';
import 'package:openvine/screens/relay_diagnostic_screen.dart';
import 'package:openvine/screens/relay_settings_screen.dart';
import 'package:openvine/screens/safety_settings_screen.dart';
import 'package:openvine/screens/settings_screen.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:openvine/screens/video_editor_screen.dart';
import 'package:openvine/screens/fullscreen_video_feed_screen.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/screens/clip_manager_screen.dart';
import 'package:openvine/screens/clip_library_screen.dart';
import 'package:openvine/screens/curated_list_feed_screen.dart';
import 'package:openvine/screens/developer_options_screen.dart';
import 'package:openvine/screens/sound_detail_screen.dart';
import 'package:openvine/screens/welcome_screen.dart';
import 'package:openvine/router/route_utils.dart';
import 'package:openvine/models/audio_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/video_stop_navigator_observer.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Navigator keys for per-tab state preservation
final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _homeKey = GlobalKey<NavigatorState>(debugLabel: 'home');
final _exploreGridKey = GlobalKey<NavigatorState>(debugLabel: 'explore-grid');
final _exploreFeedKey = GlobalKey<NavigatorState>(debugLabel: 'explore-feed');
final _notificationsKey = GlobalKey<NavigatorState>(
  debugLabel: 'notifications',
);
final _searchEmptyKey = GlobalKey<NavigatorState>(debugLabel: 'search-empty');
final _searchGridKey = GlobalKey<NavigatorState>(debugLabel: 'search-grid');
final _searchFeedKey = GlobalKey<NavigatorState>(debugLabel: 'search-feed');
final _hashtagGridKey = GlobalKey<NavigatorState>(debugLabel: 'hashtag-grid');
final _hashtagFeedKey = GlobalKey<NavigatorState>(debugLabel: 'hashtag-feed');
final _profileGridKey = GlobalKey<NavigatorState>(debugLabel: 'profile-grid');
final _profileFeedKey = GlobalKey<NavigatorState>(debugLabel: 'profile-feed');
final _likedVideosGridKey = GlobalKey<NavigatorState>(
  debugLabel: 'liked-videos-grid',
);
final _likedVideosFeedKey = GlobalKey<NavigatorState>(
  debugLabel: 'liked-videos-feed',
);

/// Maps URL location to bottom nav tab index
/// Returns -1 for non-tab routes (like search, settings, edit-profile) to hide bottom nav
int tabIndexFromLocation(String loc) {
  final uri = Uri.parse(loc);
  final first = uri.pathSegments.isEmpty ? '' : uri.pathSegments.first;
  switch (first) {
    case 'home':
      return 0;
    case 'explore':
      return 1;
    case 'hashtag':
      return 1; // Hashtag keeps explore tab active
    case 'notifications':
      return 2;
    case 'profile':
    case 'liked-videos':
      return 3; // Liked videos keeps profile tab active
    case 'search':
    case 'settings':
    case 'relay-settings':
    case 'relay-diagnostic':
    case 'blossom-settings':
    case 'notification-settings':
    case 'key-management':
    case 'safety-settings':
    case 'developer-options':
    case 'edit-profile':
    case 'setup-profile':
    case 'import-key':
    case 'welcome':
    case 'camera':
    case 'clip-manager':
    case 'edit-video':
    case 'drafts':
    case 'followers':
    case 'following':
    case 'video-feed':
    case 'profile-view':
    case 'sound':
      return -1; // Non-tab routes - no bottom nav
    case 'list':
      return 1; // List keeps explore tab active (like hashtag)
    default:
      return 0; // fallback to home
  }
}

// Track if we've done initial navigation to avoid redirect loops
bool _hasNavigated = false;

/// Reset navigation state for testing purposes
void resetNavigationState() {
  _hasNavigated = false;
}

/// Check if the CURRENT user has any cached following list in SharedPreferences
/// Exposed for testing
Future<bool> hasAnyFollowingInCache(SharedPreferences prefs) async {
  // Get the current user's pubkey
  final currentUserPubkey = prefs.getString('current_user_pubkey_hex');
  Log.debug(
    'Current user pubkey from prefs: $currentUserPubkey',
    name: 'AppRouter',
    category: LogCategory.ui,
  );

  if (currentUserPubkey == null || currentUserPubkey.isEmpty) {
    // No current user stored - treat as no following
    Log.debug(
      'No current user pubkey stored, treating as no following',
      name: 'AppRouter',
      category: LogCategory.ui,
    );
    return false;
  }

  // Check only the current user's following list
  final key = 'following_list_$currentUserPubkey';
  final value = prefs.getString(key);

  if (value == null || value.isEmpty) {
    Log.debug(
      'No following list cache for current user',
      name: 'AppRouter',
      category: LogCategory.ui,
    );
    return false;
  }

  try {
    final List<dynamic> decoded = jsonDecode(value);
    Log.debug(
      'Current user following list has ${decoded.length} entries',
      name: 'AppRouter',
      category: LogCategory.ui,
    );
    return decoded.isNotEmpty;
  } catch (e) {
    Log.debug(
      'Current user following list has invalid JSON: $e',
      name: 'AppRouter',
      category: LogCategory.ui,
    );
    return false;
  }
}

/// Listenable that notifies when auth state changes
class _AuthStateListenable extends ChangeNotifier {
  _AuthStateListenable(this._authService) {
    _authService.authStateStream.listen((_) {
      notifyListeners();
    });
  }

  final AuthService _authService;
}

final goRouterProvider = Provider<GoRouter>((ref) {
  // Watch auth service to trigger router refresh on auth state changes
  final authService = ref.watch(authServiceProvider);
  final authListenable = _AuthStateListenable(authService);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/home/0',
    observers: [
      VideoStopNavigatorObserver(),
      FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
    ],
    // Refresh router when auth state changes
    refreshListenable: authListenable,
    redirect: (context, state) async {
      final location = state.matchedLocation;
      Log.debug(
        'Redirect START for: $location',
        name: 'AppRouter',
        category: LogCategory.ui,
      );
      Log.debug(
        'Getting SharedPreferences...',
        name: 'AppRouter',
        category: LogCategory.ui,
      );
      final prefs = await SharedPreferences.getInstance();
      Log.debug(
        'SharedPreferences obtained',
        name: 'AppRouter',
        category: LogCategory.ui,
      );

      // Check TOS acceptance first (before any other routes except /welcome)
      if (!location.startsWith('/welcome') &&
          !location.startsWith('/import-key')) {
        Log.debug(
          'Checking TOS for: $location',
          name: 'AppRouter',
          category: LogCategory.ui,
        );
        final hasAcceptedTerms = prefs.getBool('age_verified_16_plus') ?? false;
        Log.debug(
          'TOS accepted: $hasAcceptedTerms',
          name: 'AppRouter',
          category: LogCategory.ui,
        );

        if (!hasAcceptedTerms) {
          Log.debug(
            'TOS not accepted, redirecting to /welcome',
            name: 'AppRouter',
            category: LogCategory.ui,
          );
          return '/welcome';
        }
      }

      // Redirect FROM /welcome TO /explore when TOS is accepted
      if (location.startsWith('/welcome')) {
        final hasAcceptedTerms = prefs.getBool('age_verified_16_plus') ?? false;
        if (hasAcceptedTerms) {
          Log.debug(
            'TOS accepted, redirecting from /welcome to /explore',
            name: 'AppRouter',
            category: LogCategory.ui,
          );
          return '/explore';
        }
      }

      // Only redirect to explore on very first navigation if user follows nobody
      // After that, let users navigate to home freely (they'll see a message to follow people)
      if (!_hasNavigated && location.startsWith('/home')) {
        _hasNavigated = true;

        // Check SharedPreferences cache directly for following list
        // This is more reliable than checking socialProvider state which may not be initialized
        final prefs = await SharedPreferences.getInstance();
        final hasFollowing = await hasAnyFollowingInCache(prefs);
        Log.debug(
          'Empty contacts check: hasFollowing=$hasFollowing, redirecting=${!hasFollowing}',
          name: 'AppRouter',
          category: LogCategory.ui,
        );
        if (!hasFollowing) {
          Log.debug(
            'Redirecting to /explore because no following list found',
            name: 'AppRouter',
            category: LogCategory.ui,
          );
          return '/explore';
        }
      } else if (location.startsWith('/home')) {
        Log.debug(
          'Skipping empty contacts check: _hasNavigated=$_hasNavigated',
          name: 'AppRouter',
          category: LogCategory.ui,
        );
      }

      Log.debug(
        'Redirect END for: $location, returning null',
        name: 'AppRouter',
        category: LogCategory.ui,
      );
      print(
        '🔵🔵🔵 REDIRECT RETURNING NULL for $location - route builder should be called next 🔵🔵🔵',
      );
      return null;
    },
    routes: [
      // Shell keeps tab navigators alive
      ShellRoute(
        builder: (context, state, child) {
          final location = state.uri.toString();
          final current = tabIndexFromLocation(location);
          return AppShell(currentIndex: current, child: child);
        },
        routes: [
          // HOME tab subtree
          GoRoute(
            path: '/home/:index',
            name: 'home',
            pageBuilder: (ctx, st) => NoTransitionPage(
              key: st.pageKey,
              child: Navigator(
                key: _homeKey,
                onGenerateRoute: (r) => MaterialPageRoute(
                  builder: (_) => const HomeScreenRouter(),
                  settings: const RouteSettings(name: 'HomeScreen'),
                ),
              ),
            ),
          ),

          // EXPLORE tab - grid mode (no index)
          GoRoute(
            path: '/explore',
            name: 'explore',
            pageBuilder: (ctx, st) => NoTransitionPage(
              key: st.pageKey,
              child: Navigator(
                key: _exploreGridKey,
                onGenerateRoute: (r) => MaterialPageRoute(
                  builder: (_) => const ExploreScreen(),
                  settings: const RouteSettings(name: 'ExploreScreen'),
                ),
              ),
            ),
          ),

          // EXPLORE tab - feed mode (with video index)
          GoRoute(
            path: '/explore/:index',
            pageBuilder: (ctx, st) => NoTransitionPage(
              key: st.pageKey,
              child: Navigator(
                key: _exploreFeedKey,
                onGenerateRoute: (r) => MaterialPageRoute(
                  builder: (_) => const ExploreScreen(),
                  settings: const RouteSettings(name: 'ExploreScreen'),
                ),
              ),
            ),
          ),

          // NOTIFICATIONS tab subtree
          GoRoute(
            path: '/notifications/:index',
            name: 'notifications',
            pageBuilder: (ctx, st) => NoTransitionPage(
              key: st.pageKey,
              child: Navigator(
                key: _notificationsKey,
                onGenerateRoute: (r) => MaterialPageRoute(
                  builder: (_) => const NotificationsScreen(),
                  settings: const RouteSettings(name: 'NotificationsScreen'),
                ),
              ),
            ),
          ),

          // PROFILE tab subtree - grid mode (no index)
          GoRoute(
            path: '/profile/:npub',
            name: 'profile',
            pageBuilder: (ctx, st) => NoTransitionPage(
              key: st.pageKey,
              child: Navigator(
                key: _profileGridKey,
                onGenerateRoute: (r) => MaterialPageRoute(
                  builder: (_) => const ProfileScreenRouter(),
                  settings: const RouteSettings(name: 'ProfileScreen'),
                ),
              ),
            ),
          ),

          // PROFILE tab subtree - feed mode (with video index)
          GoRoute(
            path: '/profile/:npub/:index',
            pageBuilder: (ctx, st) => NoTransitionPage(
              key: st.pageKey,
              child: Navigator(
                key: _profileFeedKey,
                onGenerateRoute: (r) => MaterialPageRoute(
                  builder: (_) => const ProfileScreenRouter(),
                  settings: const RouteSettings(name: 'ProfileScreen'),
                ),
              ),
            ),
          ),

          // LIKED VIDEOS route - grid mode (no index)
          GoRoute(
            path: '/liked-videos',
            name: 'liked-videos',
            pageBuilder: (ctx, st) => NoTransitionPage(
              key: st.pageKey,
              child: Navigator(
                key: _likedVideosGridKey,
                onGenerateRoute: (r) => MaterialPageRoute(
                  builder: (_) => const LikedVideosScreenRouter(),
                  settings: const RouteSettings(name: 'LikedVideosScreen'),
                ),
              ),
            ),
          ),

          // LIKED VIDEOS route - feed mode (with video index)
          GoRoute(
            path: '/liked-videos/:index',
            pageBuilder: (ctx, st) => NoTransitionPage(
              key: st.pageKey,
              child: Navigator(
                key: _likedVideosFeedKey,
                onGenerateRoute: (r) => MaterialPageRoute(
                  builder: (_) => const LikedVideosScreenRouter(),
                  settings: const RouteSettings(name: 'LikedVideosScreen'),
                ),
              ),
            ),
          ),

          // SEARCH route - empty search
          GoRoute(
            path: '/search',
            name: 'search',
            pageBuilder: (ctx, st) => NoTransitionPage(
              key: st.pageKey,
              child: Navigator(
                key: _searchEmptyKey,
                onGenerateRoute: (r) => MaterialPageRoute(
                  builder: (_) => const SearchScreenPure(embedded: true),
                  settings: const RouteSettings(name: 'SearchScreen'),
                ),
              ),
            ),
          ),

          // SEARCH route - with term, grid mode
          GoRoute(
            path: '/search/:searchTerm',
            pageBuilder: (ctx, st) => NoTransitionPage(
              key: st.pageKey,
              child: Navigator(
                key: _searchGridKey,
                onGenerateRoute: (r) => MaterialPageRoute(
                  builder: (_) => const SearchScreenPure(embedded: true),
                  settings: const RouteSettings(name: 'SearchScreen'),
                ),
              ),
            ),
          ),

          // SEARCH route - with term and index, feed mode
          GoRoute(
            path: '/search/:searchTerm/:index',
            pageBuilder: (ctx, st) => NoTransitionPage(
              key: st.pageKey,
              child: Navigator(
                key: _searchFeedKey,
                onGenerateRoute: (r) => MaterialPageRoute(
                  builder: (_) => const SearchScreenPure(embedded: true),
                  settings: const RouteSettings(name: 'SearchScreen'),
                ),
              ),
            ),
          ),

          // HASHTAG route - grid mode (no index)
          GoRoute(
            path: '/hashtag/:tag',
            name: 'hashtag',
            pageBuilder: (ctx, st) => NoTransitionPage(
              key: st.pageKey,
              child: Navigator(
                key: _hashtagGridKey,
                onGenerateRoute: (r) => MaterialPageRoute(
                  builder: (_) => const HashtagScreenRouter(),
                  settings: const RouteSettings(name: 'HashtagScreen'),
                ),
              ),
            ),
          ),

          // HASHTAG route - feed mode (with video index)
          GoRoute(
            path: '/hashtag/:tag/:index',
            pageBuilder: (ctx, st) => NoTransitionPage(
              key: st.pageKey,
              child: Navigator(
                key: _hashtagFeedKey,
                onGenerateRoute: (r) => MaterialPageRoute(
                  builder: (_) => const HashtagScreenRouter(),
                  settings: const RouteSettings(name: 'HashtagScreen'),
                ),
              ),
            ),
          ),

          // CURATED LIST route (NIP-51 kind 30005 video lists)
          GoRoute(
            path: '/list/:listId',
            name: 'list',
            builder: (ctx, st) {
              final listId = st.pathParameters['listId'];
              if (listId == null || listId.isEmpty) {
                return Scaffold(
                  appBar: AppBar(title: const Text('Error')),
                  body: const Center(child: Text('Invalid list ID')),
                );
              }
              // Extra data contains listName, videoIds, authorPubkey
              final extra = st.extra as CuratedListRouteExtra?;
              return CuratedListFeedScreen(
                listId: listId,
                listName: extra?.listName ?? 'List',
                videoIds: extra?.videoIds,
                authorPubkey: extra?.authorPubkey,
              );
            },
          ),
        ],
      ),

      // Non-tab routes outside the shell (camera/settings/editor/video/welcome)
      GoRoute(
        path: '/welcome',
        name: 'welcome',
        builder: (_, __) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/import-key',
        name: 'import-key',
        builder: (_, __) => const KeyImportScreen(),
      ),
      GoRoute(
        path: '/camera',
        name: 'camera',
        builder: (_, __) => const UniversalCameraScreenPure(),
      ),
      GoRoute(
        path: '/clip-manager',
        name: 'clip-manager',
        builder: (_, __) => const ClipManagerScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/relay-settings',
        name: 'relay-settings',
        builder: (_, __) => const RelaySettingsScreen(),
      ),
      GoRoute(
        path: '/blossom-settings',
        name: 'blossom-settings',
        builder: (_, __) => const BlossomSettingsScreen(),
      ),
      GoRoute(
        path: '/notification-settings',
        name: 'notification-settings',
        builder: (_, __) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: '/key-management',
        name: 'key-management',
        builder: (_, __) => const KeyManagementScreen(),
      ),
      GoRoute(
        path: '/relay-diagnostic',
        name: 'relay-diagnostic',
        builder: (_, __) => const RelayDiagnosticScreen(),
      ),
      GoRoute(
        path: '/safety-settings',
        name: 'safety-settings',
        builder: (_, __) => const SafetySettingsScreen(),
      ),
      GoRoute(
        path: '/developer-options',
        name: 'developer-options',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const DeveloperOptionsScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            );
          },
        ),
      ),
      GoRoute(
        path: '/edit-profile',
        name: 'edit-profile',
        builder: (context, state) {
          Log.debug(
            '/edit-profile route builder called',
            name: 'AppRouter',
            category: LogCategory.ui,
          );
          Log.debug(
            '/edit-profile state.uri = ${state.uri}',
            name: 'AppRouter',
            category: LogCategory.ui,
          );
          Log.debug(
            '/edit-profile state.matchedLocation = ${state.matchedLocation}',
            name: 'AppRouter',
            category: LogCategory.ui,
          );
          Log.debug(
            '/edit-profile state.fullPath = ${state.fullPath}',
            name: 'AppRouter',
            category: LogCategory.ui,
          );
          return const ProfileSetupScreen(isNewUser: false);
        },
      ),
      GoRoute(
        path: '/setup-profile',
        name: 'setup-profile',
        builder: (context, state) {
          Log.debug(
            '/setup-profile route builder called',
            name: 'AppRouter',
            category: LogCategory.ui,
          );
          Log.debug(
            '/setup-profile state.uri = ${state.uri}',
            name: 'AppRouter',
            category: LogCategory.ui,
          );
          Log.debug(
            '/setup-profile state.matchedLocation = ${state.matchedLocation}',
            name: 'AppRouter',
            category: LogCategory.ui,
          );
          Log.debug(
            '/setup-profile state.fullPath = ${state.fullPath}',
            name: 'AppRouter',
            category: LogCategory.ui,
          );
          return const ProfileSetupScreen(isNewUser: true);
        },
      ),
      GoRoute(
        path: '/drafts',
        name: 'drafts',
        builder: (_, __) => const ClipLibraryScreen(),
      ),
      GoRoute(
        path: '/clips',
        name: 'clips',
        builder: (_, __) => const ClipLibraryScreen(),
      ),
      // Followers screen - routes to My or Others based on pubkey
      GoRoute(
        path: '/followers/:pubkey',
        name: 'followers',
        builder: (ctx, st) {
          final pubkey = st.pathParameters['pubkey'];
          final displayName = st.extra as String?;
          if (pubkey == null || pubkey.isEmpty) {
            return Scaffold(
              appBar: AppBar(title: const Text('Error')),
              body: const Center(child: Text('Invalid user ID')),
            );
          }
          return _FollowersScreenRouter(
            pubkey: pubkey,
            displayName: displayName,
          );
        },
      ),
      // Following screen - routes to My or Others based on pubkey
      GoRoute(
        path: '/following/:pubkey',
        name: 'following',
        builder: (ctx, st) {
          final pubkey = st.pathParameters['pubkey'];
          final displayName = st.extra as String?;
          if (pubkey == null || pubkey.isEmpty) {
            return Scaffold(
              appBar: AppBar(title: const Text('Error')),
              body: const Center(child: Text('Invalid user ID')),
            );
          }
          return _FollowingScreenRouter(
            pubkey: pubkey,
            displayName: displayName,
          );
        },
      ),
      // Video detail route (for deep links)
      GoRoute(
        path: '/video/:id',
        name: 'video',
        builder: (ctx, st) {
          final videoId = st.pathParameters['id'];
          if (videoId == null || videoId.isEmpty) {
            return Scaffold(
              appBar: AppBar(title: const Text('Error')),
              body: const Center(child: Text('Invalid video ID')),
            );
          }
          return VideoDetailScreen(videoId: videoId);
        },
      ),
      // Sound detail route (for audio reuse feature)
      GoRoute(
        path: '/sound/:id',
        name: 'sound',
        builder: (ctx, st) {
          final soundId = st.pathParameters['id'];
          final sound = st.extra as AudioEvent?;
          if (soundId == null || soundId.isEmpty) {
            return Scaffold(
              appBar: AppBar(title: const Text('Error')),
              body: const Center(child: Text('Invalid sound ID')),
            );
          }
          // If sound was passed via extra, use it directly
          // Otherwise, SoundDetailScreen will need to fetch it
          if (sound != null) {
            return SoundDetailScreen(sound: sound);
          }
          // Wrap in a loader that fetches the sound by ID
          return _SoundDetailLoader(soundId: soundId);
        },
      ),
      // Video editor route (requires video passed via extra)
      GoRoute(
        path: '/edit-video',
        name: 'edit-video',
        builder: (ctx, st) {
          final videoPath = st.extra as String?;
          if (videoPath == null) {
            // If no video provided, show error screen
            return Scaffold(
              appBar: AppBar(title: const Text('Error')),
              body: const Center(child: Text('No video selected for editing')),
            );
          }
          return VideoEditorScreen(videoPath: videoPath);
        },
      ),
      // Fullscreen video feed route (no bottom nav, used from profile/hashtag grids)
      GoRoute(
        path: '/video-feed',
        name: 'video-feed',
        builder: (ctx, st) {
          final args = st.extra as FullscreenVideoFeedArgs?;
          if (args == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Error')),
              body: const Center(child: Text('No videos to display')),
            );
          }
          return FullscreenVideoFeedScreen(
            source: args.source,
            initialIndex: args.initialIndex,
            contextTitle: args.contextTitle,
          );
        },
      ),
      // Other user's profile screen (no bottom nav, pushed from feeds/search)
      GoRoute(
        path: '/profile-view/:npub',
        name: 'profile-view',
        builder: (ctx, st) {
          final npub = st.pathParameters['npub'];
          if (npub == null || npub.isEmpty) {
            return Scaffold(
              appBar: AppBar(title: const Text('Error')),
              body: const Center(child: Text('Invalid profile ID')),
            );
          }
          return OtherProfileScreen(npub: npub);
        },
      ),
    ],
  );
});

/// Router widget that decides between MyFollowersScreen and OthersFollowersScreen
/// based on whether the pubkey matches the current user.
class _FollowersScreenRouter extends ConsumerWidget {
  const _FollowersScreenRouter({
    required this.pubkey,
    required this.displayName,
  });

  final String pubkey;
  final String? displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nostrClient = ref.watch(nostrServiceProvider);
    final isCurrentUser = pubkey == nostrClient.publicKey;

    if (isCurrentUser) {
      return MyFollowersScreen(displayName: displayName);
    } else {
      return OthersFollowersScreen(pubkey: pubkey, displayName: displayName);
    }
  }
}

/// Router widget that decides between MyFollowingScreen and OthersFollowingScreen
/// based on whether the pubkey matches the current user.
class _FollowingScreenRouter extends ConsumerWidget {
  const _FollowingScreenRouter({
    required this.pubkey,
    required this.displayName,
  });

  final String pubkey;
  final String? displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nostrClient = ref.watch(nostrServiceProvider);
    final isCurrentUser = pubkey == nostrClient.publicKey;

    if (isCurrentUser) {
      return MyFollowingScreen(displayName: displayName);
    } else {
      return OthersFollowingScreen(pubkey: pubkey, displayName: displayName);
    }
  }
}

/// Loader widget that fetches a sound by ID before displaying SoundDetailScreen.
/// Used when navigating via deep link without the sound object.
class _SoundDetailLoader extends ConsumerWidget {
  const _SoundDetailLoader({required this.soundId});

  final String soundId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final soundAsync = ref.watch(soundByIdProvider(soundId));

    return soundAsync.when(
      data: (sound) {
        if (sound == null) {
          return Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              title: const Text('Sound Not Found'),
            ),
            body: const Center(
              child: Text(
                'This sound could not be found',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        }
        return SoundDetailScreen(sound: sound);
      },
      loading: () => const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: BrandedLoadingIndicator(size: 60)),
      ),
      error: (error, stack) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: const Text('Error'),
        ),
        body: Center(
          child: Text(
            'Failed to load sound: $error',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
