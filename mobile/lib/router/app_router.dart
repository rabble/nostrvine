// ABOUTME: GoRouter configuration with ShellRoute for per-tab state preservation
// ABOUTME: URL is source of truth, bottom nav bound to routes

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/audio_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/auth/divine_auth_screen.dart';
import 'package:openvine/screens/auth/email_verification_screen.dart';
import 'package:openvine/screens/auth/login_options_screen.dart';
import 'package:openvine/screens/auth/nostr_connect_screen.dart';
import 'package:openvine/screens/auth/reset_password.dart';
import 'package:openvine/screens/auth/secure_account_screen.dart';
import 'package:openvine/screens/blossom_settings_screen.dart';
import 'package:openvine/screens/clip_library_screen.dart';
import 'package:openvine/screens/curated_list_feed_screen.dart';
import 'package:openvine/screens/developer_options_screen.dart';
import 'package:openvine/screens/discover_lists_screen.dart';
import 'package:openvine/screens/explore_screen.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/fullscreen_video_feed_screen.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/screens/home_screen_router.dart';
import 'package:openvine/screens/key_import_screen.dart';
import 'package:openvine/screens/key_management_screen.dart';
import 'package:openvine/screens/liked_videos_screen_router.dart';
import 'package:openvine/screens/notification_settings_screen.dart';
import 'package:openvine/screens/notifications_screen.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/screens/profile_setup_screen.dart';
import 'package:openvine/screens/pure/search_screen_pure.dart';
import 'package:openvine/screens/relay_diagnostic_screen.dart';
import 'package:openvine/screens/relay_settings_screen.dart';
import 'package:openvine/screens/safety_settings_screen.dart';
import 'package:openvine/screens/settings_screen.dart';
import 'package:openvine/screens/sound_detail_screen.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:openvine/screens/video_editor/video_clip_editor_screen.dart';
import 'package:openvine/screens/video_editor/video_editor_screen.dart';
import 'package:openvine/screens/video_metadata/video_metadata_screen.dart';
import 'package:openvine/screens/video_recorder_screen.dart';
import 'package:openvine/screens/welcome_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/video_stop_navigator_observer.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/camera_permission_gate.dart';

// Track if we've done initial navigation to avoid redirect loops
bool _hasNavigated = false;

/// Reset navigation state for testing purposes
@visibleForTesting
void resetNavigationState() {
  _hasNavigated = false;
}

final goRouterProvider = Provider<GoRouter>((ref) {
  // Use ref.read to avoid recreating the router on auth state changes
  // The refreshListenable handles reacting to auth state changes
  final authService = ref.read(authServiceProvider);
  final authListenable = AuthStateListenable(authService);

  return GoRouter(
    navigatorKey: NavigatorKeys.root,
    // Start at /welcome - redirect logic will navigate to appropriate route
    initialLocation: WelcomeScreen.path,
    observers: [
      VideoStopNavigatorObserver(),
      FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
    ],
    // Refresh router when auth state changes
    refreshListenable: authListenable,
    redirect: (context, state) {
      final location = state.matchedLocation;
      Log.debug(
        'Redirect START for: $location',
        name: 'AppRouter',
        category: LogCategory.ui,
      );

      final authState = ref.read(authServiceProvider).authState;
      if (authState == AuthState.authenticated &&
          (location == WelcomeScreen.path ||
              location == KeyImportScreen.path ||
              location == NostrConnectScreen.path ||
              location == WelcomeScreen.loginOptionsPath ||
              location == WelcomeScreen.resetPasswordPath ||
              location == EmailVerificationScreen.path)) {
        debugPrint('[Router] Authenticated. moving to /home/0');
        // On first navigation, redirect to explore if user has no following
        if (!_hasNavigated) {
          _hasNavigated = true;
          final emptyFollowingRedirect = ref.read(
            checkEmptyFollowingRedirectProvider(location),
          );
          if (emptyFollowingRedirect != null) return emptyFollowingRedirect;
        }
        return HomeScreenRouter.pathForIndex(0);
      }

      // Auth routes are allowed without TOS - user is in the process of logging in
      final isAuthRoute =
          location.startsWith(WelcomeScreen.path) ||
          location.startsWith(KeyImportScreen.path) ||
          location.startsWith(NostrConnectScreen.path) ||
          location.startsWith(WelcomeScreen.resetPasswordPath) ||
          location.startsWith(EmailVerificationScreen.path);

      // Check TOS acceptance for non-auth routes
      if (!isAuthRoute) {
        Log.debug(
          'Checking TOS for: $location',
          name: 'AppRouter',
          category: LogCategory.ui,
        );

        final hasAcceptedTerms = ref.read(hasTosAcceptedProvider);

        Log.debug(
          'TOS accepted: $hasAcceptedTerms',
          name: 'AppRouter',
          category: LogCategory.ui,
        );

        // Only redirect to welcome if TOS not accepted
        if (!hasAcceptedTerms) {
          Log.debug(
            'TOS not accepted, redirecting to ${WelcomeScreen.path}',
            name: 'AppRouter',
            category: LogCategory.ui,
          );
          return WelcomeScreen.path;
        }

        // If TOS is accepted but user is not authenticated, redirect to welcome
        if (authState == AuthState.unauthenticated) {
          Log.debug(
            'Not authenticated, redirecting to ${WelcomeScreen.path}',
            name: 'AppRouter',
            category: LogCategory.ui,
          );
          return WelcomeScreen.path;
        }
      }

      Log.debug(
        'Redirect END for: $location, returning null',
        name: 'AppRouter',
        category: LogCategory.ui,
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
            path: HomeScreenRouter.pathWithIndex,
            name: HomeScreenRouter.routeName,
            pageBuilder: (ctx, st) => NoTransitionPage(
              key: st.pageKey,
              child: Navigator(
                key: NavigatorKeys.home,
                onGenerateRoute: (r) => MaterialPageRoute(
                  builder: (_) => const HomeScreenRouter(),
                  settings: const RouteSettings(
                    name: HomeScreenRouter.routeName,
                  ),
                ),
              ),
            ),
          ),

          // EXPLORE tab - grid mode (no index)
          GoRoute(
            path: ExploreScreen.path,
            name: ExploreScreen.routeName,
            pageBuilder: (ctx, st) => NoTransitionPage(
              key: st.pageKey,
              child: Navigator(
                key: NavigatorKeys.exploreGrid,
                onGenerateRoute: (r) => MaterialPageRoute(
                  builder: (_) => const ExploreScreen(),
                  settings: const RouteSettings(name: ExploreScreen.routeName),
                ),
              ),
            ),
          ),

          // EXPLORE tab - feed mode (with video index)
          GoRoute(
            path: ExploreScreen.pathWithIndex,
            pageBuilder: (ctx, st) => NoTransitionPage(
              key: st.pageKey,
              child: Navigator(
                key: NavigatorKeys.exploreFeed,
                onGenerateRoute: (r) => MaterialPageRoute(
                  builder: (_) => const ExploreScreen(),
                  settings: const RouteSettings(name: ExploreScreen.routeName),
                ),
              ),
            ),
          ),

          // NOTIFICATIONS tab subtree
          GoRoute(
            path: NotificationsScreen.pathWithIndex,
            name: NotificationsScreen.routeName,
            pageBuilder: (ctx, st) => NoTransitionPage(
              key: st.pageKey,
              child: Navigator(
                key: NavigatorKeys.notifications,
                onGenerateRoute: (r) => MaterialPageRoute(
                  builder: (_) => const NotificationsScreen(),
                  settings: const RouteSettings(
                    name: NotificationsScreen.routeName,
                  ),
                ),
              ),
            ),
          ),

          // PROFILE tab subtree - grid mode (no index)
          GoRoute(
            path: ProfileScreenRouter.path,
            name: ProfileScreenRouter.routeName,
            pageBuilder: (ctx, st) => NoTransitionPage(
              key: st.pageKey,
              child: Navigator(
                key: NavigatorKeys.profileGrid,
                onGenerateRoute: (r) => MaterialPageRoute(
                  builder: (_) => const ProfileScreenRouter(),
                  settings: const RouteSettings(
                    name: ProfileScreenRouter.routeName,
                  ),
                ),
              ),
            ),
          ),

          // PROFILE tab subtree - grid mode (with npub)
          GoRoute(
            path: ProfileScreenRouter.pathWithNpub,
            pageBuilder: (ctx, st) => NoTransitionPage(
              key: st.pageKey,
              child: Navigator(
                key: NavigatorKeys.profileGrid,
                onGenerateRoute: (r) => MaterialPageRoute(
                  builder: (_) => const ProfileScreenRouter(),
                  settings: const RouteSettings(
                    name: ProfileScreenRouter.routeName,
                  ),
                ),
              ),
            ),
          ),
          // PROFILE tab subtree - feed mode (with video index)
          GoRoute(
            path: ProfileScreenRouter.pathWithIndex,
            pageBuilder: (ctx, st) => NoTransitionPage(
              key: st.pageKey,
              child: Navigator(
                key: NavigatorKeys.profileFeed,
                onGenerateRoute: (r) => MaterialPageRoute(
                  builder: (_) => const ProfileScreenRouter(),
                  settings: const RouteSettings(
                    name: ProfileScreenRouter.routeName,
                  ),
                ),
              ),
            ),
          ),

          // LIKED VIDEOS route - grid mode (no index)
          GoRoute(
            path: LikedVideosScreenRouter.path,
            name: LikedVideosScreenRouter.routeName,
            pageBuilder: (ctx, st) => NoTransitionPage(
              key: st.pageKey,
              child: Navigator(
                key: NavigatorKeys.likedVideosGrid,
                onGenerateRoute: (r) => MaterialPageRoute(
                  builder: (_) => const LikedVideosScreenRouter(),
                  settings: const RouteSettings(
                    name: LikedVideosScreenRouter.routeName,
                  ),
                ),
              ),
            ),
          ),

          // LIKED VIDEOS route - feed mode (with video index)
          GoRoute(
            path: LikedVideosScreenRouter.pathWithIndex,
            pageBuilder: (ctx, st) => NoTransitionPage(
              key: st.pageKey,
              child: Navigator(
                key: NavigatorKeys.likedVideosFeed,
                onGenerateRoute: (r) => MaterialPageRoute(
                  builder: (_) => const LikedVideosScreenRouter(),
                  settings: const RouteSettings(
                    name: LikedVideosScreenRouter.routeName,
                  ),
                ),
              ),
            ),
          ),

          // SEARCH route - empty search
          GoRoute(
            path: SearchScreenPure.path,
            name: SearchScreenPure.routeName,
            pageBuilder: (ctx, st) => NoTransitionPage(
              key: st.pageKey,
              child: Navigator(
                key: NavigatorKeys.searchEmpty,
                onGenerateRoute: (r) => MaterialPageRoute(
                  builder: (_) => const SearchScreenPure(embedded: true),
                  settings: const RouteSettings(
                    name: SearchScreenPure.routeName,
                  ),
                ),
              ),
            ),
          ),

          // SEARCH route - with term, grid mode
          GoRoute(
            path: SearchScreenPure.pathWithTerm,
            pageBuilder: (ctx, st) => NoTransitionPage(
              key: st.pageKey,
              child: Navigator(
                key: NavigatorKeys.searchGrid,
                onGenerateRoute: (r) => MaterialPageRoute(
                  builder: (_) => const SearchScreenPure(embedded: true),
                  settings: const RouteSettings(
                    name: SearchScreenPure.routeName,
                  ),
                ),
              ),
            ),
          ),

          // SEARCH route - with term and index, feed mode
          GoRoute(
            path: SearchScreenPure.pathWithTermAndIndex,
            pageBuilder: (ctx, st) => NoTransitionPage(
              key: st.pageKey,
              child: Navigator(
                key: NavigatorKeys.searchFeed,
                onGenerateRoute: (r) => MaterialPageRoute(
                  builder: (_) => const SearchScreenPure(embedded: true),
                  settings: const RouteSettings(
                    name: SearchScreenPure.routeName,
                  ),
                ),
              ),
            ),
          ),

          // HASHTAG route - grid mode (no index)
          GoRoute(
            path: HashtagScreenRouter.path,
            name: HashtagScreenRouter.routeName,
            pageBuilder: (ctx, st) => NoTransitionPage(
              key: st.pageKey,
              child: Navigator(
                key: NavigatorKeys.hashtagGrid,
                onGenerateRoute: (r) => MaterialPageRoute(
                  builder: (_) => const HashtagScreenRouter(),
                  settings: const RouteSettings(
                    name: HashtagScreenRouter.routeName,
                  ),
                ),
              ),
            ),
          ),

          // HASHTAG route - feed mode (with video index)
          GoRoute(
            path: HashtagScreenRouter.pathWithIndex,
            pageBuilder: (ctx, st) => NoTransitionPage(
              key: st.pageKey,
              child: Navigator(
                key: NavigatorKeys.hashtagFeed,
                onGenerateRoute: (r) => MaterialPageRoute(
                  builder: (_) => const HashtagScreenRouter(),
                  settings: const RouteSettings(
                    name: HashtagScreenRouter.routeName,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),

      // Non-tab routes outside the shell (camera/settings/editor/video/welcome)

      // CURATED LIST route (NIP-51 kind 30005 video lists)
      // Outside shell so the screen's own AppBar is shown without the shell AppBar
      GoRoute(
        path: CuratedListFeedScreen.path,
        name: CuratedListFeedScreen.routeName,
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

      // DISCOVER LISTS route (browse public NIP-51 kind 30005 lists)
      // Outside shell so the screen's own AppBar is shown without the shell AppBar
      GoRoute(
        path: DiscoverListsScreen.path,
        name: DiscoverListsScreen.routeName,
        builder: (ctx, st) => const DiscoverListsScreen(),
      ),
      GoRoute(
        path: WelcomeScreen.path,
        name: WelcomeScreen.routeName,
        builder: (_, __) => const WelcomeScreen(),
        routes: [
          GoRoute(
            path: LoginOptionsScreen.path,
            name: LoginOptionsScreen.routeName,
            builder: (_, __) => const LoginOptionsScreen(),
            routes: [
              GoRoute(
                path: DivineAuthScreen.path,
                name: DivineAuthScreen.routeName,
                builder: (ctx, st) {
                  // Check for initialMode passed via extra or query param
                  AuthMode? mode = st.extra as AuthMode?;
                  if (mode == null) {
                    final modeParam = st.uri.queryParameters['mode'];
                    if (modeParam == 'register') mode = AuthMode.register;
                  }
                  return DivineAuthScreen(initialMode: mode ?? AuthMode.login);
                },
                routes: [
                  // route for deep link when resetting password from emailed link
                  GoRoute(
                    path: ResetPasswordScreen.path,
                    name: ResetPasswordScreen.routeName,
                    builder: (ctx, st) {
                      final token = st.uri.queryParameters['token'];
                      return ResetPasswordScreen(token: token ?? '');
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: KeyImportScreen.path,
        name: KeyImportScreen.routeName,
        builder: (_, __) => const KeyImportScreen(),
      ),
      GoRoute(
        path: NostrConnectScreen.path,
        name: NostrConnectScreen.routeName,
        builder: (_, __) => const NostrConnectScreen(),
      ),
      GoRoute(
        path: SecureAccountScreen.path,
        name: SecureAccountScreen.routeName,
        builder: (_, __) => const SecureAccountScreen(),
      ),
      // redirect deep link route to full reset password path
      GoRoute(
        path: ResetPasswordScreen.path,
        redirect: (context, state) {
          final token = state.uri.queryParameters['token'];
          return '${WelcomeScreen.resetPasswordPath}?token=$token';
        },
      ),
      // Email verification route - supports both modes:
      // - Token mode (deep link): /verify-email?token=xyz
      // - Polling mode (after registration): /verify-email?deviceCode=abc&verifier=def&email=user@example.com
      GoRoute(
        path: EmailVerificationScreen.path,
        name: EmailVerificationScreen.routeName,
        builder: (context, state) {
          final params = state.uri.queryParameters;
          return EmailVerificationScreen(
            token: params['token'],
            deviceCode: params['deviceCode'],
            verifier: params['verifier'],
            email: params['email'],
          );
        },
      ),
      GoRoute(
        path: SettingsScreen.path,
        name: SettingsScreen.routeName,
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: RelaySettingsScreen.path,
        name: RelaySettingsScreen.routeName,
        builder: (_, __) => const RelaySettingsScreen(),
      ),
      GoRoute(
        path: BlossomSettingsScreen.path,
        name: BlossomSettingsScreen.routeName,
        builder: (_, __) => const BlossomSettingsScreen(),
      ),
      GoRoute(
        path: NotificationSettingsScreen.path,
        name: NotificationSettingsScreen.routeName,
        builder: (_, __) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: KeyManagementScreen.path,
        name: KeyManagementScreen.routeName,
        builder: (_, __) => const KeyManagementScreen(),
      ),
      GoRoute(
        path: RelayDiagnosticScreen.path,
        name: RelayDiagnosticScreen.routeName,
        builder: (_, __) => const RelayDiagnosticScreen(),
      ),
      GoRoute(
        path: SafetySettingsScreen.path,
        name: SafetySettingsScreen.routeName,
        builder: (_, __) => const SafetySettingsScreen(),
      ),
      GoRoute(
        path: DeveloperOptionsScreen.path,
        name: DeveloperOptionsScreen.routeName,
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
      // Debug route for testing VideoFeedBloc as a pushed screen
      GoRoute(
        path: VideoFeedPage.path,
        name: VideoFeedPage.routeName,
        builder: (_, __) => const VideoFeedPage(),
      ),

      GoRoute(
        path: ProfileSetupScreen.editPath,
        name: ProfileSetupScreen.editRouteName,
        builder: (context, state) {
          Log.debug(
            '${ProfileSetupScreen.editPath} route builder called',
            name: 'AppRouter',
            category: LogCategory.ui,
          );
          Log.debug(
            '${ProfileSetupScreen.editPath} state.uri = ${state.uri}',
            name: 'AppRouter',
            category: LogCategory.ui,
          );
          Log.debug(
            '${ProfileSetupScreen.editPath} state.matchedLocation = ${state.matchedLocation}',
            name: 'AppRouter',
            category: LogCategory.ui,
          );
          Log.debug(
            '${ProfileSetupScreen.editPath} state.fullPath = ${state.fullPath}',
            name: 'AppRouter',
            category: LogCategory.ui,
          );
          return const ProfileSetupScreen(isNewUser: false);
        },
      ),
      GoRoute(
        path: ProfileSetupScreen.setupPath,
        name: ProfileSetupScreen.setupRouteName,
        builder: (context, state) {
          Log.debug(
            '${ProfileSetupScreen.setupPath} route builder called',
            name: 'AppRouter',
            category: LogCategory.ui,
          );
          Log.debug(
            '${ProfileSetupScreen.setupPath} state.uri = ${state.uri}',
            name: 'AppRouter',
            category: LogCategory.ui,
          );
          Log.debug(
            '${ProfileSetupScreen.setupPath} state.matchedLocation = ${state.matchedLocation}',
            name: 'AppRouter',
            category: LogCategory.ui,
          );
          Log.debug(
            '${ProfileSetupScreen.setupPath} state.fullPath = ${state.fullPath}',
            name: 'AppRouter',
            category: LogCategory.ui,
          );
          return const ProfileSetupScreen(isNewUser: true);
        },
      ),
      GoRoute(
        path: ClipLibraryScreen.draftsPath,
        name: ClipLibraryScreen.draftsRouteName,
        builder: (_, __) => const ClipLibraryScreen(),
      ),
      GoRoute(
        path: ClipLibraryScreen.clipsPath,
        name: ClipLibraryScreen.clipsRouteName,
        builder: (_, __) => const ClipLibraryScreen(),
      ),
      // Followers screen - routes to My or Others based on pubkey
      GoRoute(
        path: FollowersScreenRouter.path,
        name: FollowersScreenRouter.routeName,
        builder: (ctx, st) {
          final pubkey = st.pathParameters['pubkey'];
          final displayName = st.extra as String?;
          if (pubkey == null || pubkey.isEmpty) {
            return Scaffold(
              appBar: AppBar(title: const Text('Error')),
              body: const Center(child: Text('Invalid user ID')),
            );
          }
          return FollowersScreenRouter(
            pubkey: pubkey,
            displayName: displayName,
          );
        },
      ),
      // Following screen - routes to My or Others based on pubkey
      GoRoute(
        path: FollowingScreenRouter.path,
        name: FollowingScreenRouter.routeName,
        builder: (ctx, st) {
          final pubkey = st.pathParameters['pubkey'];
          final displayName = st.extra as String?;
          if (pubkey == null || pubkey.isEmpty) {
            return Scaffold(
              appBar: AppBar(title: const Text('Error')),
              body: const Center(child: Text('Invalid user ID')),
            );
          }
          return FollowingScreenRouter(
            pubkey: pubkey,
            displayName: displayName,
          );
        },
      ),
      // Video detail route (for deep links)
      GoRoute(
        path: VideoDetailScreen.path,
        name: VideoDetailScreen.routeName,
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
        path: SoundDetailScreen.path,
        name: SoundDetailScreen.routeName,
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
          return SoundDetailLoader(soundId: soundId);
        },
      ),
      // Video editor route (requires video passed via extra)
      GoRoute(
        path: VideoRecorderScreen.path,
        name: VideoRecorderScreen.routeName,
        builder: (_, _) =>
            const CameraPermissionGate(child: VideoRecorderScreen()),
      ),
      // Video editor route
      GoRoute(
        path: VideoEditorScreen.path,
        name: VideoEditorScreen.routeName,
        builder: (_, st) => const VideoEditorScreen(),
      ),
      GoRoute(
        path: VideoClipEditorScreen.path,
        name: VideoClipEditorScreen.routeName,
        builder: (_, st) {
          final extra = st.extra as Map<String, dynamic>?;
          final fromLibrary = extra?['fromLibrary'] as bool? ?? false;
          return VideoClipEditorScreen(fromLibrary: fromLibrary);
        },
      ),
      GoRoute(
        path: VideoClipEditorScreen.draftPathWithId,
        name: VideoClipEditorScreen.draftRouteName,
        builder: (_, st) {
          // The draft ID is optional if the user wants to continue editing
          // the draft.
          final draftId = st.pathParameters['draftId'];

          return VideoClipEditorScreen(
            draftId: draftId == null || draftId.isEmpty ? null : draftId,
          );
        },
      ),
      GoRoute(
        path: VideoMetadataScreen.path,
        name: VideoMetadataScreen.routeName,
        builder: (_, st) => const VideoMetadataScreen(),
      ),
      // Fullscreen video feed route (no bottom nav, used from profile/hashtag grids)
      GoRoute(
        path: FullscreenVideoFeedScreen.path,
        name: FullscreenVideoFeedScreen.routeName,
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
      // Uses router widget to redirect self-visits to own profile tab
      GoRoute(
        path: OtherProfileScreen.pathWithNpub,
        name: OtherProfileScreen.routeName,
        builder: (ctx, st) {
          final npub = st.pathParameters['npub'];
          if (npub == null || npub.isEmpty) {
            return Scaffold(
              appBar: AppBar(title: const Text('Error')),
              body: const Center(child: Text('Invalid profile ID')),
            );
          }
          // Extract profile hints from extra (for users without Kind 0 profiles)
          final extra = st.extra as Map<String, String?>?;
          final displayNameHint = extra?['displayName'];
          final avatarUrlHint = extra?['avatarUrl'];
          return OtherProfileScreenRouter(
            npub: npub,
            displayNameHint: displayNameHint,
            avatarUrlHint: avatarUrlHint,
          );
        },
      ),
    ],
  );
});

/// Maps URL location to bottom nav tab index.
///
/// Returns the tab index for tab routes:
/// - 0: Home
/// - 1: Explore (also for hashtag routes)
/// - 2: Notifications
/// - 3: Profile (also for liked-videos)
///
/// Returns -1 for non-tab routes (like search, settings, edit-profile)
/// to hide the bottom navigation bar.
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
    case 'nostr-connect':
    case 'welcome':
    case 'video-recorder':
    case 'video-editor':
    case 'video-metadata':
    case 'clip-manager':
    case 'drafts':
    case 'followers':
    case 'following':
    case 'video-feed':
    case 'profile-view':
    case 'sound':
    case 'new-video-feed':
    case 'list':
    case 'discover-lists':
      return -1; // Non-tab routes - no bottom nav (outside shell)
    default:
      return 0; // fallback to home
  }
}
