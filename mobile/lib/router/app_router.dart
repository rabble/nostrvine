// ABOUTME: GoRouter configuration with ShellRoute for per-tab state preservation
// ABOUTME: URL is source of truth, bottom nav bound to routes

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' show VideoEvent;
import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/audio_event.dart';
import 'package:openvine/models/video_category.dart';
import 'package:openvine/notifications/view/notifications_page.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/apps/app_detail_screen.dart';
import 'package:openvine/screens/apps/apps_directory_screen.dart';
import 'package:openvine/screens/apps/apps_permissions_screen.dart';
import 'package:openvine/screens/apps/nostr_app_sandbox_screen.dart';
import 'package:openvine/screens/auth/create_account_screen.dart';
import 'package:openvine/screens/auth/email_verification_screen.dart';
import 'package:openvine/screens/auth/invite_gate_screen.dart';
import 'package:openvine/screens/auth/invite_protected_create_account_screen.dart';
import 'package:openvine/screens/auth/login_options_screen.dart';
import 'package:openvine/screens/auth/nostr_connect_screen.dart';
import 'package:openvine/screens/auth/reset_password.dart';
import 'package:openvine/screens/auth/secure_account_screen.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/screens/blossom_settings_screen.dart';
import 'package:openvine/screens/category_gallery_screen.dart';
import 'package:openvine/screens/content_filters_screen.dart';
import 'package:openvine/screens/creator_analytics_screen.dart';
import 'package:openvine/screens/curated_list_feed_screen.dart';
import 'package:openvine/screens/developer_options_screen.dart';
import 'package:openvine/screens/discover_lists_screen.dart';
import 'package:openvine/screens/explore_screen.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/hashtag_feed_screen.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/screens/inbox/conversation/conversation_page.dart';
import 'package:openvine/screens/inbox/inbox_page.dart';
import 'package:openvine/screens/inbox/message_requests/message_requests_page.dart';
import 'package:openvine/screens/inbox/message_requests/request_preview_page.dart';
import 'package:openvine/screens/key_import_screen.dart';
import 'package:openvine/screens/key_management_screen.dart';
import 'package:openvine/screens/library_screen.dart';
import 'package:openvine/screens/liked_videos_screen_router.dart';
import 'package:openvine/screens/notification_settings_screen.dart';
import 'package:openvine/screens/original_sound_detail_screen.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/screens/profile_setup_screen.dart';
import 'package:openvine/screens/pure/search_screen_pure.dart';
import 'package:openvine/screens/relay_diagnostic_screen.dart';
import 'package:openvine/screens/relay_settings_screen.dart';
import 'package:openvine/screens/safety_settings_screen.dart';
import 'package:openvine/screens/search_results/view/search_results_page.dart';
import 'package:openvine/screens/settings/app_language_screen.dart';
import 'package:openvine/screens/settings/bluesky_settings_screen.dart';
import 'package:openvine/screens/settings/content_preferences_screen.dart';
import 'package:openvine/screens/settings/invites_screen.dart';
import 'package:openvine/screens/settings/legal_screen.dart';
import 'package:openvine/screens/settings/nostr_settings_screen.dart';
import 'package:openvine/screens/settings/settings_screen.dart';
import 'package:openvine/screens/settings/support_center_screen.dart';
import 'package:openvine/screens/sound_detail_screen.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:openvine/screens/video_editor/video_editor_screen.dart';
import 'package:openvine/screens/video_metadata/video_metadata_screen.dart';
import 'package:openvine/screens/video_recorder_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/page_load_observer.dart';
import 'package:openvine/services/video_stop_navigator_observer.dart';
import 'package:openvine/widgets/camera_permission_gate.dart';
import 'package:unified_logger/unified_logger.dart';

/// Global route observer for [RouteAware] subscribers (e.g. pausing video
/// when a new route is pushed on top of the feed).
final routeObserver = RouteObserver<ModalRoute<dynamic>>();

// Track if we've done initial navigation to avoid redirect loops
bool _hasNavigated = false;

/// Reset navigation state for testing purposes
@visibleForTesting
void resetNavigationState() {
  _hasNavigated = false;
}

final goRouterProvider = Provider<GoRouter>((ref) {
  // Use ref.read to avoid recreating the router on auth state changes
  final authService = ref.read(authServiceProvider);

  // Convert auth state stream to a Listenable for GoRouter
  final authListenable = _StreamListenable(authService.authStateStream);

  final router = GoRouter(
    navigatorKey: NavigatorKeys.root,
    // Start at /welcome - redirect logic will navigate to appropriate route
    initialLocation: WelcomeScreen.path,
    observers: [
      routeObserver,
      PageLoadObserver(),
      VideoStopNavigatorObserver(),
      if (Firebase.apps.isNotEmpty)
        FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
    ],
    // Refresh router when auth state changes
    refreshListenable: authListenable,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final authService = ref.read(authServiceProvider);
      final authState = authService.authState;

      Log.debug(
        'Router redirect: location=$location, '
        'authState=${authState.name}',
        name: 'AppRouter',
        category: LogCategory.auth,
      );

      // Handle authenticated users on auth routes
      // Note: resetPasswordPath and EmailVerificationScreen are intentionally
      // excluded — authenticated users may navigate there via deep links.
      if (authState == AuthState.authenticated &&
          (location == WelcomeScreen.path ||
              location == KeyImportScreen.path ||
              location == NostrConnectScreen.path ||
              location == WelcomeScreen.inviteGatePath ||
              location == WelcomeScreen.createAccountPath ||
              location == WelcomeScreen.loginOptionsPath)) {
        // Allow expired-session users through to login options
        // so they can re-authenticate instead of being bounced home
        if (authService.hasExpiredOAuthSession &&
            location == WelcomeScreen.loginOptionsPath) {
          return null;
        }
        // On first navigation, redirect to explore if user has no following
        if (!_hasNavigated) {
          _hasNavigated = true;
          final emptyFollowingRedirect = ref.read(
            checkEmptyFollowingRedirectProvider(location),
          );
          if (emptyFollowingRedirect != null) {
            Log.info(
              'Router redirect: authenticated on auth route — '
              'redirecting to $emptyFollowingRedirect (no following)',
              name: 'AppRouter',
              category: LogCategory.auth,
            );
            return emptyFollowingRedirect;
          }
        }
        return VideoFeedPage.pathForIndex(0);
      }

      // Auth routes don't require authentication — user is in the
      // process of logging in.
      final isAuthRoute =
          location.startsWith(WelcomeScreen.path) ||
          location.startsWith(KeyImportScreen.path) ||
          location.startsWith(NostrConnectScreen.path) ||
          location.startsWith(WelcomeScreen.inviteGatePath) ||
          location.startsWith(WelcomeScreen.resetPasswordPath) ||
          location.startsWith(ResetPasswordScreen.path) ||
          location.startsWith(EmailVerificationScreen.path);

      // Non-authenticated users on protected routes → welcome.
      // awaitingTosAcceptance has no dedicated screen, so treat it like unauthenticated.
      if (!isAuthRoute &&
          (authState == AuthState.unauthenticated ||
              authState == AuthState.awaitingTosAcceptance)) {
        _hasNavigated = false;
        Log.info(
          'Router redirect: ${authState.name} on $location — '
          'redirecting to ${WelcomeScreen.path}',
          name: 'AppRouter',
          category: LogCategory.auth,
        );
        return WelcomeScreen.path;
      }

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
            path: VideoFeedPage.pathWithIndex,
            name: VideoFeedPage.routeName,
            pageBuilder: (ctx, st) => NoTransitionPage(
              key: st.pageKey,
              child: Navigator(
                key: NavigatorKeys.home,
                onGenerateRoute: (r) => MaterialPageRoute(
                  builder: (_) => const VideoFeedPage(),
                  settings: const RouteSettings(name: VideoFeedPage.routeName),
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
            path: NotificationsPage.pathWithIndex,
            name: NotificationsPage.routeName,
            pageBuilder: (ctx, st) => NoTransitionPage(
              key: st.pageKey,
              child: Navigator(
                key: NavigatorKeys.notifications,
                onGenerateRoute: (r) => MaterialPageRoute(
                  builder: (_) => const NotificationsPage(),
                  settings: const RouteSettings(
                    name: NotificationsPage.routeName,
                  ),
                ),
              ),
            ),
          ),

          // INBOX tab (Messages + Notifications combined)
          GoRoute(
            path: InboxPage.path,
            name: InboxPage.routeName,
            pageBuilder: (ctx, st) => NoTransitionPage(
              key: st.pageKey,
              child: Navigator(
                key: NavigatorKeys.inbox,
                onGenerateRoute: (r) => MaterialPageRoute(
                  builder: (_) => const InboxPage(),
                  settings: const RouteSettings(name: InboxPage.routeName),
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
        ],
      ),

      // HASHTAG route - standalone screen (no bottom nav)
      GoRoute(
        path: HashtagScreenRouter.path,
        name: HashtagScreenRouter.routeName,
        parentNavigatorKey: NavigatorKeys.root,
        builder: (ctx, st) {
          final tag = st.pathParameters['tag'];
          if (tag == null || tag.isEmpty) {
            return Scaffold(
              appBar: DiVineAppBar(title: ctx.l10n.routeErrorTitle),
              body: Center(child: Text(ctx.l10n.routeInvalidHashtag)),
            );
          }
          final decoded = Uri.decodeComponent(tag);
          return HashtagFeedScreen(hashtag: decoded);
        },
      ),
      // SEARCH RESULTS - unified search screen (no bottom nav)
      GoRoute(
        path: SearchResultsPage.path,
        parentNavigatorKey: NavigatorKeys.root,
        builder: (ctx, st) {
          final query = st.pathParameters['query'];
          final decoded = query != null ? Uri.decodeComponent(query) : '';
          return SearchResultsPage(initialQuery: decoded);
        },
      ),

      // DM conversation detail (pushed from inbox, no bottom nav)
      GoRoute(
        path: ConversationPage.pathPattern,
        name: ConversationPage.routeName,
        builder: (ctx, st) {
          final id = st.pathParameters['id'];
          if (id == null || id.isEmpty) {
            return Scaffold(
              appBar: DiVineAppBar(title: ctx.l10n.routeErrorTitle),
              body: Center(child: Text(ctx.l10n.routeInvalidConversationId)),
            );
          }
          final participantPubkeys = st.extra as List<String>? ?? [];
          return ConversationPage(
            conversationId: id,
            participantPubkeys: participantPubkeys,
          );
        },
      ),

      // Message requests inbox (pushed from inbox, no bottom nav)
      GoRoute(
        path: MessageRequestsPage.path,
        name: MessageRequestsPage.routeName,
        parentNavigatorKey: NavigatorKeys.root,
        builder: (ctx, st) => const MessageRequestsPage(),
      ),

      // Message request preview (pushed from requests inbox)
      GoRoute(
        path: RequestPreviewPage.pathPattern,
        name: RequestPreviewPage.routeName,
        parentNavigatorKey: NavigatorKeys.root,
        builder: (ctx, st) {
          final id = st.pathParameters['id'];
          if (id == null || id.isEmpty) {
            return Scaffold(
              appBar: DiVineAppBar(title: ctx.l10n.routeErrorTitle),
              body: Center(child: Text(ctx.l10n.routeInvalidRequestId)),
            );
          }
          // Pubkeys are optional — the page loads them from the DB
          // when not provided (e.g. deep link).
          final participantPubkeys = st.extra as List<String>? ?? [];
          return RequestPreviewPage(
            conversationId: id,
            participantPubkeys: participantPubkeys,
          );
        },
      ),

      // Non-tab routes outside the shell (camera/settings/editor/video/welcome)
      GoRoute(
        path: CreatorAnalyticsScreen.path,
        name: CreatorAnalyticsScreen.routeName,
        parentNavigatorKey: NavigatorKeys.root,
        builder: (ctx, st) => const CreatorAnalyticsScreen(),
      ),

      // CURATED LIST route (NIP-51 kind 30005 video lists)
      // Outside shell so the screen's own AppBar is shown without the shell AppBar
      GoRoute(
        path: CuratedListFeedScreen.path,
        name: CuratedListFeedScreen.routeName,
        builder: (ctx, st) {
          final listId = st.pathParameters['listId'];
          if (listId == null || listId.isEmpty) {
            return Scaffold(
              appBar: DiVineAppBar(title: ctx.l10n.routeErrorTitle),
              body: Center(child: Text(ctx.l10n.routeInvalidListId)),
            );
          }
          // Extra data contains listName, videoIds, authorPubkey
          final extra = st.extra as CuratedListRouteExtra?;
          return CuratedListFeedScreen(
            listId: listId,
            listName: extra?.listName ?? ctx.l10n.routeDefaultListName,
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
        builder: (_, state) => WelcomeScreen(
          initialSelectedPubkeyHex:
              state.uri.queryParameters[WelcomeScreen.selectedPubkeyParam],
        ),
        routes: [
          GoRoute(
            path: 'invite',
            name: InviteGateScreen.routeName,
            builder: (_, state) => InviteGateScreen(
              initialCode: state.uri.queryParameters['code'],
              initialError: state.uri.queryParameters['error'],
            ),
          ),
          GoRoute(
            path: 'create-account',
            name: CreateAccountScreen.routeName,
            builder: (_, _) => const InviteProtectedCreateAccountScreen(),
          ),
          GoRoute(
            path: 'login-options',
            name: LoginOptionsScreen.routeName,
            builder: (_, _) => const LoginOptionsScreen(),
            routes: [
              // Route for deep link when resetting password
              GoRoute(
                path: 'reset-password',
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
      GoRoute(
        path: KeyImportScreen.path,
        name: KeyImportScreen.routeName,
        builder: (_, _) => const KeyImportScreen(),
      ),
      GoRoute(
        path: NostrConnectScreen.path,
        name: NostrConnectScreen.routeName,
        builder: (_, _) => const NostrConnectScreen(),
      ),
      GoRoute(
        path: SecureAccountScreen.path,
        name: SecureAccountScreen.routeName,
        builder: (_, _) => const SecureAccountScreen(),
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
        builder: (_, _) => const SettingsScreen(),
      ),
      GoRoute(
        path: InvitesScreen.path,
        name: InvitesScreen.routeName,
        builder: (_, _) => const InvitesScreen(),
      ),
      GoRoute(
        path: AppsDirectoryScreen.path,
        name: AppsDirectoryScreen.routeName,
        builder: (_, _) => const AppsDirectoryScreen(),
      ),
      GoRoute(
        path: AppsPermissionsScreen.path,
        name: AppsPermissionsScreen.routeName,
        builder: (_, state) {
          final authService = ref.read(authServiceProvider);
          final grantStore = ref.read(nostrAppGrantStoreProvider);
          return AppsPermissionsScreen(
            grantStore: grantStore,
            currentUserPubkey: authService.currentPublicKeyHex,
          );
        },
      ),
      GoRoute(
        path: NostrAppSandboxScreen.path,
        name: NostrAppSandboxScreen.routeName,
        builder: (_, state) {
          final app = state.extra is NostrAppDirectoryEntry
              ? state.extra! as NostrAppDirectoryEntry
              : null;
          final appId = state.pathParameters['appId'] ?? '';
          return ResolvedSandboxRouteScreen(appId: appId, initialApp: app);
        },
      ),
      GoRoute(
        path: AppDetailScreen.path,
        name: AppDetailScreen.routeName,
        builder: (_, state) {
          final slug = state.pathParameters['slug'] ?? '';
          final initialEntry = state.extra is NostrAppDirectoryEntry
              ? state.extra! as NostrAppDirectoryEntry
              : null;
          return AppDetailScreen(slug: slug, initialEntry: initialEntry);
        },
      ),
      GoRoute(
        path: SupportCenterScreen.path,
        name: SupportCenterScreen.routeName,
        builder: (_, _) => const SupportCenterScreen(),
      ),
      GoRoute(
        path: LegalScreen.path,
        name: LegalScreen.routeName,
        builder: (_, _) => const LegalScreen(),
      ),
      GoRoute(
        path: ContentPreferencesScreen.path,
        name: ContentPreferencesScreen.routeName,
        builder: (_, _) => const ContentPreferencesScreen(),
      ),
      GoRoute(
        path: AppLanguageScreen.path,
        name: AppLanguageScreen.routeName,
        builder: (_, _) => const AppLanguageScreen(),
      ),
      GoRoute(
        path: BlueskySettingsScreen.path,
        name: BlueskySettingsScreen.routeName,
        builder: (_, _) => const BlueskySettingsScreen(),
      ),
      GoRoute(
        path: NostrSettingsScreen.path,
        name: NostrSettingsScreen.routeName,
        builder: (_, _) => const NostrSettingsScreen(),
      ),
      GoRoute(
        path: RelaySettingsScreen.path,
        name: RelaySettingsScreen.routeName,
        builder: (_, _) => const RelaySettingsScreen(),
      ),
      GoRoute(
        path: BlossomSettingsScreen.path,
        name: BlossomSettingsScreen.routeName,
        builder: (_, _) => const BlossomSettingsScreen(),
      ),
      GoRoute(
        path: NotificationSettingsScreen.path,
        name: NotificationSettingsScreen.routeName,
        builder: (_, _) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: KeyManagementScreen.path,
        name: KeyManagementScreen.routeName,
        builder: (_, _) => const KeyManagementScreen(),
      ),
      GoRoute(
        path: RelayDiagnosticScreen.path,
        name: RelayDiagnosticScreen.routeName,
        builder: (_, _) => const RelayDiagnosticScreen(),
      ),
      GoRoute(
        path: SafetySettingsScreen.path,
        name: SafetySettingsScreen.routeName,
        builder: (_, _) => const SafetySettingsScreen(),
      ),
      GoRoute(
        path: ContentFiltersScreen.path,
        name: ContentFiltersScreen.routeName,
        builder: (_, _) => const ContentFiltersScreen(),
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
        path: LibraryScreen.draftsPath,
        name: LibraryScreen.draftsRouteName,
        builder: (_, _) => const LibraryScreen(),
      ),
      GoRoute(
        path: LibraryScreen.clipsPath,
        name: LibraryScreen.clipsRouteName,
        builder: (_, _) => const LibraryScreen(initialTabIndex: 1),
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
              appBar: DiVineAppBar(title: ctx.l10n.routeErrorTitle),
              body: Center(child: Text(ctx.l10n.routeInvalidUserId)),
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
              appBar: DiVineAppBar(title: ctx.l10n.routeErrorTitle),
              body: Center(child: Text(ctx.l10n.routeInvalidUserId)),
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
              appBar: DiVineAppBar(title: ctx.l10n.routeErrorTitle),
              body: Center(child: Text(ctx.l10n.routeInvalidVideoId)),
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
          if (soundId == null || soundId.isEmpty) {
            return Scaffold(
              appBar: DiVineAppBar(title: ctx.l10n.routeErrorTitle),
              body: Center(child: Text(ctx.l10n.routeInvalidSoundId)),
            );
          }
          // Extra can be an AudioEvent directly or a Map with both
          // sound and sourceVideo (for original sounds).
          final extra = st.extra;
          AudioEvent? sound;
          VideoEvent? sourceVideo;
          if (extra is AudioEvent) {
            sound = extra;
          } else if (extra is Map<String, dynamic>) {
            sound = extra['sound'] as AudioEvent?;
            sourceVideo = extra['sourceVideo'] as VideoEvent?;
          }
          if (sound != null) {
            return SoundDetailScreen(
              sound: sound,
              sourceVideo: sourceVideo,
            );
          }
          // Wrap in a loader that fetches the sound by ID
          return SoundDetailLoader(soundId: soundId);
        },
      ),
      // Original sound detail route (for videos without shared audio)
      GoRoute(
        path: OriginalSoundDetailScreen.path,
        name: OriginalSoundDetailScreen.routeName,
        builder: (ctx, st) {
          final pubkey = st.pathParameters['pubkey'];
          final video = st.extra as VideoEvent?;
          if (pubkey == null || pubkey.isEmpty) {
            return const Scaffold(
              appBar: DiVineAppBar(title: 'Error'),
              body: Center(child: Text('Invalid creator')),
            );
          }
          return OriginalSoundDetailScreen(
            creatorPubkey: pubkey,
            sourceVideo: video,
          );
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
        builder: (_, st) {
          final extra = st.extra as Map<String, dynamic>?;
          final fromLibrary = extra?['fromLibrary'] as bool? ?? false;

          return VideoEditorScreen(fromLibrary: fromLibrary);
        },
      ),
      GoRoute(
        path: VideoEditorScreen.draftPathWithId,
        name: VideoEditorScreen.draftRouteName,
        builder: (_, st) {
          // The draft ID is optional if the user wants to continue editing
          // the draft.
          final draftId = st.pathParameters['draftId'];
          final extra = st.extra as Map<String, dynamic>?;
          final fromLibrary = extra?['fromLibrary'] as bool? ?? false;

          return VideoEditorScreen(
            draftId: draftId == null || draftId.isEmpty ? null : draftId,
            fromLibrary: fromLibrary,
          );
        },
      ),
      GoRoute(
        path: VideoMetadataScreen.path,
        name: VideoMetadataScreen.routeName,
        builder: (_, st) => const VideoMetadataScreen(),
      ),
      GoRoute(
        path: CategoryGalleryScreen.path,
        name: CategoryGalleryScreen.routeName,
        builder: (ctx, st) {
          final categoryName = st.pathParameters['categoryName'];
          final category =
              st.extra as VideoCategory? ??
              VideoCategory(name: categoryName ?? '', videoCount: 0);

          if (category.name.isEmpty) {
            return Scaffold(
              appBar: DiVineAppBar(title: ctx.l10n.routeErrorTitle),
              body: Center(child: Text(ctx.l10n.routeInvalidCategory)),
            );
          }

          return CategoryGalleryScreen(category: category);
        },
      ),
      // Pooled fullscreen video feed (uses pooled_video_player package)
      GoRoute(
        path: PooledFullscreenVideoFeedScreen.path,
        name: PooledFullscreenVideoFeedScreen.routeName,
        builder: (ctx, st) {
          final args = st.extra as PooledFullscreenVideoFeedArgs?;
          if (args == null) {
            return Scaffold(
              appBar: DiVineAppBar(title: ctx.l10n.routeErrorTitle),
              body: Center(child: Text(ctx.l10n.routeNoVideosToDisplay)),
            );
          }
          return PooledFullscreenVideoFeedScreen(
            videosStream: args.videosStream,
            initialIndex: args.initialIndex,
            onLoadMore: args.onLoadMore,
            contextTitle: args.contextTitle,
            trafficSource: args.trafficSource,
            sourceDetail: args.sourceDetail,
            autoOpenComments: args.autoOpenComments,
            onPageChanged: args.onPageChanged,
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
              appBar: DiVineAppBar(title: ctx.l10n.routeErrorTitle),
              body: Center(child: Text(ctx.l10n.routeInvalidProfileId)),
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

  ref.onDispose(() {
    router.dispose();
    authListenable.dispose();
  });

  return router;
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
    case 'notifications':
    case 'inbox':
      return 2; // Inbox replaces notifications in the same tab position
    case 'profile':
    case 'liked-videos':
      return 3; // Liked videos keeps profile tab active
    case 'search':
    case 'apps':
    case 'settings':
    case 'relay-settings':
    case 'relay-diagnostic':
    case 'blossom-settings':
    case 'notification-settings':
    case 'key-management':
    case 'safety-settings':
    case 'content-filters':
    case 'content-preferences':
    case 'app-language':
    case 'support-center':
    case 'legal':
    case 'nostr-settings':
    case 'bluesky-settings':
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
    case 'list':
    case 'discover-lists':
    case 'creator-analytics':
    case 'hashtag':
    case 'categories':
      return -1; // Non-tab routes - no bottom nav (outside shell)
    default:
      return 0; // fallback to home
  }
}

/// Adapts a [Stream] to a [ChangeNotifier] for use with GoRouter's
/// `refreshListenable`.
class _StreamListenable extends ChangeNotifier {
  _StreamListenable(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
