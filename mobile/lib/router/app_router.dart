// ABOUTME: GoRouter configuration with StatefulShellRoute for per-tab state preservation
// ABOUTME: URL is source of truth, bottom nav bound to routes via StatefulNavigationShell

import 'dart:convert';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/router/app_shell.dart';
import 'package:openvine/screens/comments/comments_screen.dart';
import 'package:openvine/screens/explore_screen.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/screens/home_screen_router.dart';
import 'package:openvine/screens/notifications_screen.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/screens/pure/search_screen_pure.dart';
import 'package:openvine/screens/pure/universal_camera_screen_pure.dart';
import 'package:openvine/screens/followers/my_followers_screen.dart';
import 'package:openvine/screens/following/my_following_screen.dart';
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
import 'package:openvine/screens/welcome_screen.dart';
import 'package:openvine/router/route_utils.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/video_stop_navigator_observer.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Root navigator key
final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Maps URL location to bottom nav tab index.
/// Returns -1 for non-tab routes.
int tabIndexFromLocation(String loc) {
  if (loc.startsWith('/home')) return 0;
  if (loc.startsWith('/explore') ||
      loc.startsWith('/hashtag') ||
      loc.startsWith('/search'))
    return 1;
  if (loc.startsWith('/notifications')) return 2;
  if (loc.startsWith('/profile')) return 3;
  return -1;
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
  final currentUserPubkey = prefs.getString('current_user_pubkey_hex');
  Log.debug(
    'Current user pubkey from prefs: $currentUserPubkey',
    name: 'AppRouter',
    category: LogCategory.ui,
  );

  if (currentUserPubkey == null || currentUserPubkey.isEmpty) {
    Log.debug(
      'No current user pubkey stored, treating as no following',
      name: 'AppRouter',
      category: LogCategory.ui,
    );
    return false;
  }

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
  final authService = ref.watch(authServiceProvider);
  final authListenable = _AuthStateListenable(authService);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/home/0',
    observers: [
      VideoStopNavigatorObserver(),
      FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
    ],
    refreshListenable: authListenable,
    redirect: (context, state) async {
      final location = state.matchedLocation;
      final prefs = await SharedPreferences.getInstance();

      // Check TOS acceptance first
      if (!location.startsWith('/welcome') &&
          !location.startsWith('/import-key')) {
        final hasAcceptedTerms = prefs.getBool('age_verified_16_plus') ?? false;
        if (!hasAcceptedTerms) {
          return '/welcome';
        }
      }

      // Redirect FROM /welcome TO /explore when TOS is accepted
      if (location.startsWith('/welcome')) {
        final hasAcceptedTerms = prefs.getBool('age_verified_16_plus') ?? false;
        if (hasAcceptedTerms) {
          return '/explore';
        }
      }

      // Redirect to explore on first navigation if user follows nobody
      if (!_hasNavigated && location.startsWith('/home')) {
        _hasNavigated = true;
        final hasFollowing = await hasAnyFollowingInCache(prefs);
        if (!hasFollowing) {
          return '/explore';
        }
      }

      return null;
    },
    routes: [
      // StatefulShellRoute preserves state per branch when switching tabs
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          // Branch 0: Home tab
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home/:index',
                name: 'home',
                builder: (context, state) => const HomeScreenRouter(),
              ),
            ],
          ),

          // Branch 1: Explore tab (includes search and hashtag)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/explore',
                name: 'explore',
                builder: (context, state) => const ExploreScreen(),
              ),
              GoRoute(
                path: '/explore/:index',
                builder: (context, state) => const ExploreScreen(),
              ),
              GoRoute(
                path: '/search',
                name: 'search',
                builder: (context, state) =>
                    const SearchScreenPure(embedded: true),
              ),
              GoRoute(
                path: '/search/:searchTerm',
                builder: (context, state) =>
                    const SearchScreenPure(embedded: true),
              ),
              GoRoute(
                path: '/search/:searchTerm/:index',
                builder: (context, state) =>
                    const SearchScreenPure(embedded: true),
              ),
              GoRoute(
                path: '/hashtag/:tag',
                name: 'hashtag',
                builder: (context, state) => const HashtagScreenRouter(),
              ),
              GoRoute(
                path: '/hashtag/:tag/:index',
                builder: (context, state) => const HashtagScreenRouter(),
              ),
            ],
          ),

          // Branch 2: Notifications tab
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/notifications/:index',
                name: 'notifications',
                builder: (context, state) => const NotificationsScreen(),
              ),
            ],
          ),

          // Branch 3: Profile tab
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile/:npub',
                name: 'profile',
                builder: (context, state) => const ProfileScreenRouter(),
              ),
              GoRoute(
                path: '/profile/:npub/:index',
                builder: (context, state) => const ProfileScreenRouter(),
              ),
            ],
          ),
        ],
      ),

      // Non-shell routes (outside bottom nav)
      GoRoute(
        path: WelcomeScreen.path,
        name: WelcomeScreen.routeName,
        pageBuilder: WelcomeScreen.pageBuilder,
      ),
      GoRoute(
        path: KeyImportScreen.path,
        name: KeyImportScreen.routeName,
        pageBuilder: KeyImportScreen.pageBuilder,
      ),
      GoRoute(
        path: UniversalCameraScreenPure.path,
        name: UniversalCameraScreenPure.routeName,
        pageBuilder: UniversalCameraScreenPure.pageBuilder,
      ),
      GoRoute(
        path: ClipManagerScreen.path,
        name: ClipManagerScreen.routeName,
        pageBuilder: ClipManagerScreen.pageBuilder,
      ),
      GoRoute(
        path: SettingsScreen.path,
        name: SettingsScreen.routeName,
        pageBuilder: SettingsScreen.pageBuilder,
      ),
      GoRoute(
        path: RelaySettingsScreen.path,
        name: RelaySettingsScreen.routeName,
        pageBuilder: RelaySettingsScreen.pageBuilder,
      ),
      GoRoute(
        path: BlossomSettingsScreen.path,
        name: BlossomSettingsScreen.routeName,
        pageBuilder: BlossomSettingsScreen.pageBuilder,
      ),
      GoRoute(
        path: NotificationSettingsScreen.path,
        name: NotificationSettingsScreen.routeName,
        pageBuilder: NotificationSettingsScreen.pageBuilder,
      ),
      GoRoute(
        path: KeyManagementScreen.path,
        name: KeyManagementScreen.routeName,
        pageBuilder: KeyManagementScreen.pageBuilder,
      ),
      GoRoute(
        path: RelayDiagnosticScreen.path,
        name: RelayDiagnosticScreen.routeName,
        pageBuilder: RelayDiagnosticScreen.pageBuilder,
      ),
      GoRoute(
        path: SafetySettingsScreen.path,
        name: SafetySettingsScreen.routeName,
        pageBuilder: SafetySettingsScreen.pageBuilder,
      ),
      GoRoute(
        path: DeveloperOptionsScreen.path,
        name: DeveloperOptionsScreen.routeName,
        pageBuilder: DeveloperOptionsScreen.pageBuilder,
      ),
      GoRoute(
        path: ProfileSetupScreen.editPath,
        name: ProfileSetupScreen.editRouteName,
        pageBuilder: ProfileSetupScreen.editPageBuilder,
      ),
      GoRoute(
        path: ProfileSetupScreen.setupPath,
        name: ProfileSetupScreen.setupRouteName,
        pageBuilder: ProfileSetupScreen.setupPageBuilder,
      ),
      GoRoute(
        path: '/drafts',
        name: 'drafts',
        pageBuilder: ClipLibraryScreen.pageBuilder,
      ),
      GoRoute(
        path: ClipLibraryScreen.path,
        name: ClipLibraryScreen.routeName,
        pageBuilder: ClipLibraryScreen.pageBuilder,
      ),
      GoRoute(
        path: MyFollowersScreen.path,
        name: MyFollowersScreen.routeName,
        pageBuilder: MyFollowersScreen.pageBuilder,
      ),
      GoRoute(
        path: MyFollowingScreen.path,
        name: MyFollowingScreen.routeName,
        pageBuilder: MyFollowingScreen.pageBuilder,
      ),
      GoRoute(
        path: VideoDetailScreen.path,
        name: VideoDetailScreen.routeName,
        pageBuilder: VideoDetailScreen.pageBuilder,
      ),
      GoRoute(
        path: CommentsScreen.path,
        name: CommentsScreen.routeName,
        pageBuilder: CommentsScreen.pageBuilder,
      ),
      GoRoute(
        path: VideoEditorScreen.path,
        name: VideoEditorScreen.routeName,
        pageBuilder: VideoEditorScreen.pageBuilder,
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
  );
});
