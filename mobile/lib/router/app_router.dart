// ABOUTME: GoRouter configuration with ShellRoute for per-tab state preservation
// ABOUTME: URL is source of truth, bottom nav bound to routes

import 'package:analytics/analytics.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' show AudioEvent, VideoCategory, VideoEvent;
import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';
import 'package:openvine/blocs/video_engagement/video_engagement_bloc.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/people_lists/view/add_people_to_list_screen.dart';
import 'package:openvine/features/people_lists/view/create_people_list_page.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/notifications/view/notifications_page.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/pooled_fullscreen_feed_route.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/router/router_refresh_listenable.dart';
import 'package:openvine/router/universal_link_resolver.dart';
import 'package:openvine/screens/apps/app_detail_screen.dart';
import 'package:openvine/screens/apps/apps_directory_screen.dart';
import 'package:openvine/screens/apps/apps_permissions_screen.dart';
import 'package:openvine/screens/apps/nostr_app_sandbox_screen.dart';
import 'package:openvine/screens/apps/web_iframe_sandbox_screen.dart';
import 'package:openvine/screens/auth/create_account_screen.dart';
import 'package:openvine/screens/auth/email_verification_screen.dart';
import 'package:openvine/screens/auth/invite_gate_screen.dart';
import 'package:openvine/screens/auth/invite_protected_create_account_screen.dart';
import 'package:openvine/screens/auth/login_options_screen.dart';
import 'package:openvine/screens/auth/nostr_connect_screen.dart';
import 'package:openvine/screens/auth/reset_password.dart';
import 'package:openvine/screens/auth/secure_account_screen.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/screens/badges/badges_screen.dart';
import 'package:openvine/screens/blossom_settings_screen.dart';
import 'package:openvine/screens/category_gallery_screen.dart';
import 'package:openvine/screens/content_filters_screen.dart';
import 'package:openvine/screens/creator_analytics_screen.dart';
import 'package:openvine/screens/curated_list_feed_screen.dart';
import 'package:openvine/screens/developer_options_screen.dart';
import 'package:openvine/screens/discover_lists_screen.dart';
import 'package:openvine/screens/explore/explore_screen.dart';
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
import 'package:openvine/screens/minor_account_review_parent_consent_screen.dart';
import 'package:openvine/screens/minor_account_review_parent_contact_screen.dart';
import 'package:openvine/screens/minor_account_review_screen.dart';
import 'package:openvine/screens/minor_account_review_under13_screen.dart';
import 'package:openvine/screens/minor_account_review_under13_support_screen.dart';
import 'package:openvine/screens/notification_settings_screen.dart';
import 'package:openvine/screens/original_sound_detail_screen.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/screens/profile_setup_screen.dart';
import 'package:openvine/screens/relay_diagnostic_screen.dart';
import 'package:openvine/screens/relay_settings_screen.dart';
import 'package:openvine/screens/safety_settings_screen.dart';
import 'package:openvine/screens/search_results/view/search_results_page.dart';
import 'package:openvine/screens/settings/app_language_screen.dart';
import 'package:openvine/screens/settings/bluesky_settings_screen.dart';
import 'package:openvine/screens/settings/content_preferences_screen.dart';
import 'package:openvine/screens/settings/general_settings_screen.dart';
import 'package:openvine/screens/settings/invites_screen.dart';
import 'package:openvine/screens/settings/legal_screen.dart';
import 'package:openvine/screens/settings/nip05_settings_screen.dart';
import 'package:openvine/screens/settings/nostr_settings_screen.dart';
import 'package:openvine/screens/settings/settings_screen.dart';
import 'package:openvine/screens/settings/support_center_screen.dart';
import 'package:openvine/screens/sound_detail_screen.dart';
import 'package:openvine/screens/subtitle_editor/subtitle_editor_screen.dart';
import 'package:openvine/screens/user_list_people_screen.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:openvine/screens/video_editor/video_editor_screen.dart';
import 'package:openvine/screens/video_engagement/video_engagement_list_screen.dart';
import 'package:openvine/screens/video_metadata/video_metadata_edit_screen.dart';
import 'package:openvine/screens/video_metadata/video_metadata_screen.dart';
import 'package:openvine/screens/video_recorder_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/video_stop_navigator_observer.dart';
import 'package:unified_logger/unified_logger.dart';

/// Global route observer for [RouteAware] subscribers (e.g. pausing video
/// when a new route is pushed on top of the feed).
final routeObserver = RouteObserver<ModalRoute<dynamic>>();

// Track if we've done initial navigation to avoid redirect loops
bool _hasNavigated = false;
bool _suppressNextAuthenticatedAuthRouteRedirect = false;

/// Prevents the next authenticated auth-route redirect from going home.
///
/// Used when a cold-start quick action already opened a protected route before
/// auth restoration finishes. In that case the route should remain visible
/// instead of being covered by the normal `/welcome` -> home redirect.
void suppressNextAuthenticatedAuthRouteRedirect() {
  _suppressNextAuthenticatedAuthRouteRedirect = true;
}

/// Clears a pending authenticated auth-route redirect suppression.
void clearAuthenticatedAuthRouteRedirectSuppression() {
  _suppressNextAuthenticatedAuthRouteRedirect = false;
}

/// Reset navigation state for testing purposes
@visibleForTesting
void resetNavigationState() {
  _hasNavigated = false;
  _suppressNextAuthenticatedAuthRouteRedirect = false;
}

/// Rewrites a `/reset-password` deep link to the nested
/// [WelcomeScreen.resetPasswordPath] route, preserving `token` and
/// optional `email` query params.
///
/// Shared by the top-level redirect in [goRouterProvider] and the
/// router-level regression test so both paths produce the same output for
/// the same input. See issue #3156.
@visibleForTesting
String rewriteResetPasswordDeepLink(Uri uri) {
  final token = uri.queryParameters['token'] ?? '';
  final email = uri.queryParameters['email'];
  final buffer = StringBuffer(WelcomeScreen.resetPasswordPath)
    ..write('?token=')
    ..write(Uri.encodeQueryComponent(token));
  if (email != null && email.isNotEmpty) {
    buffer
      ..write('&email=')
      ..write(Uri.encodeQueryComponent(email));
  }
  return buffer.toString();
}

/// Redirects deep links for people-lists routes to the home feed when the
/// [FeatureFlag.curatedLists] feature flag is off.
///
/// The people-lists screens depend on a `PeopleListsBloc` that is only
/// provided in `main.dart` when the flag is enabled. Without this guard a
/// deep link / push / saved URL would crash with `ProviderNotFoundException`.
/// Returns `null` (no redirect) when the flag is on.
String? _peopleListsRedirectIfDisabled(Ref ref, GoRouterState state) {
  final enabled = ref.read(isFeatureEnabledProvider(FeatureFlag.curatedLists));
  if (enabled) return null;
  Log.info(
    'Router redirect: ${state.matchedLocation} — '
    'FeatureFlag.curatedLists is off, redirecting to home',
    name: 'AppRouter',
    category: LogCategory.ui,
  );
  return VideoFeedPage.pathForIndex(0);
}

String _minorAccountReviewLoadingPath(String fromLocation) {
  return Uri(
    path: MinorAccountReviewLoadingScreen.path,
    queryParameters: <String, String>{'from': fromLocation},
  ).toString();
}

@visibleForTesting
String minorAccountReviewReturnLocationForTest(Uri uri) {
  final from = uri.queryParameters['from'];
  if (from == null || from.isEmpty) {
    return VideoFeedPage.pathForIndex(0);
  }

  final fromLocation = Uri.parse(from).path;
  if (_isAuthEntryLocation(fromLocation) ||
      fromLocation == MinorAccountReviewLoadingScreen.path) {
    return VideoFeedPage.pathForIndex(0);
  }

  return from;
}

String _minorAccountReviewReturnLocation(GoRouterState state) {
  return minorAccountReviewReturnLocationForTest(state.uri);
}

String? _moderationConversationId(
  AuthService authService,
  MinorReviewCase? reviewCase,
) {
  if (reviewCase == null) return null;
  if (reviewCase.moderationConversationId != null &&
      reviewCase.moderationConversationId!.isNotEmpty) {
    return reviewCase.moderationConversationId;
  }

  final currentPubkey = authService.currentPublicKeyHex;
  final moderationPubkey = reviewCase.moderationConversationPubkey;
  if (currentPubkey == null ||
      currentPubkey.isEmpty ||
      moderationPubkey == null ||
      moderationPubkey.isEmpty) {
    return null;
  }

  return DmRepository.computeConversationId([currentPubkey, moderationPubkey]);
}

bool _isAuthEntryLocation(String location) {
  return location == WelcomeScreen.path ||
      location.startsWith('${WelcomeScreen.path}/') ||
      location.startsWith(KeyImportScreen.path) ||
      location.startsWith(NostrConnectScreen.path) ||
      location == WelcomeScreen.inviteGatePath ||
      location.startsWith(WelcomeScreen.resetPasswordPath) ||
      location.startsWith(ResetPasswordScreen.path) ||
      location.startsWith(EmailVerificationScreen.path) ||
      location == MinorAccountReviewScreen.welcomePath ||
      location == MinorAccountReviewParentConsentScreen.path ||
      location == MinorAccountReviewUnder13Screen.path;
}

@visibleForTesting
int homeInitialIndexFromPathParameters(Map<String, String> pathParameters) {
  final rawIndex = int.tryParse(pathParameters['index'] ?? '') ?? 0;
  return rawIndex < 0 ? 0 : rawIndex;
}

@visibleForTesting
List<String> stringListRouteExtra(Object? extra) {
  if (extra is! Iterable) return const [];

  final values = <String>[];
  for (final item in extra) {
    if (item is! String) return const [];
    values.add(item);
  }
  return List<String>.unmodifiable(values);
}

bool _isPublicRecorderLocation(String location) =>
    location == VideoRecorderScreen.path;

/// Builds a [StatefulShellBranch] page whose subtree sees its *own* route's
/// [RouteContext] via a scoped [pageContextProvider], rather than the
/// globally-active route's.
///
/// `StatefulShellRoute` keeps every branch mounted, but the tab screens gate
/// their content on the global [pageContextProvider] (they render a
/// placeholder when its type doesn't match). Without this scope an inactive
/// branch would see the active tab's context and blank out — breaking both
/// state preservation and the live cross-fade. Scoping per branch makes each
/// tab keep rendering its real content while inactive. [NoTransitionPage]
/// keeps within-branch navigation (e.g. grid → feed) instant; the *between
/// tab* cross-fade is done by [AppShellBranchContainer].
///
/// Scoping caveat: only a *direct* `ref.watch(pageContextProvider)` from a
/// widget in this subtree observes the branch-local override. A root-level
/// provider that derives from [pageContextProvider] (e.g.
/// [activeVideoIdProvider], [videoControllerAutoCleanupProvider]) is
/// instantiated in the root container
/// and therefore always reads the *global* route — by design, since playback
/// gating must follow the genuinely-active tab. Any new provider that reads
/// [pageContextProvider] inherits this global behaviour even when consumed
/// inside a branch; reach for the scoped value only via a direct widget read.
Page<void> _branchPage(GoRouterState state, Widget child) {
  return NoTransitionPage<void>(
    key: state.pageKey,
    child: ProviderScope(
      overrides: [
        pageContextProvider.overrideWith(
          (ref) => Stream<RouteContext>.value(parseRoute(state.uri.path)),
        ),
      ],
      child: child,
    ),
  );
}

final goRouterProvider = Provider<GoRouter>((ref) {
  // Use ref.read to avoid recreating the router on auth state changes
  final authService = ref.read(authServiceProvider);

  // Keep one router instance alive; drive redirect reevaluation through a
  // dedicated listenable instead of rebuilding GoRouter when app state changes.
  final refreshListenable = RouterRefreshListenable(
    authService.authStateStream,
  );
  ref.listen(currentMinorAccountReviewStatusProvider, (previous, next) {
    refreshListenable.refresh();
  });
  ref.onDispose(refreshListenable.dispose);

  final router = GoRouter(
    navigatorKey: NavigatorKeys.root,
    // Start at /welcome - redirect logic will navigate to appropriate route
    initialLocation: WelcomeScreen.path,
    observers: _buildRouterObservers(),
    // Refresh router when auth or account-review state changes
    refreshListenable: refreshListenable,
    errorBuilder: (context, state) =>
        RouteErrorScreen(message: context.l10n.routeUnknownPath),
    redirect: (context, state) {
      // Rewrite divine.video universal-link URLs to internal paths before the
      // auth/match logic runs. Android delivers the full intent URL (scheme +
      // host + path) to GoRouter, which only matches on path. Without this
      // step, paths that differ between the public URL contract and the
      // internal route table (notably `/search/*` → `/search-results/:query`)
      // would fall through to GoRouter's "Page Not Found" page.
      final universalRedirect = universalLinkToRouterPath(state.uri);
      if (universalRedirect != null) {
        Log.info(
          'Router redirect: universal link ${state.uri} → $universalRedirect',
          name: 'AppRouter',
          category: LogCategory.ui,
        );
        return universalRedirect;
      }

      final location = state.matchedLocation;
      final authService = ref.read(authServiceProvider);
      final authState = authService.authState;
      final reviewStatusAsync = ref.read(
        currentMinorAccountReviewStatusProvider,
      );
      final reviewStatus = reviewStatusAsync.value;
      final moderationConversationId = _moderationConversationId(
        authService,
        reviewStatus?.currentCase,
      );

      final isReviewRoute = location == MinorAccountReviewScreen.path;
      final isPublicReviewRoute =
          location == MinorAccountReviewScreen.welcomePath;
      final isReviewLoadingRoute =
          location == MinorAccountReviewLoadingScreen.path;
      final isPublicParentConsentRoute =
          location == MinorAccountReviewParentConsentScreen.path;
      final isParentContactRoute =
          location == MinorAccountReviewParentContactScreen.path;
      final isPublicUnder13Route =
          location == MinorAccountReviewUnder13Screen.path;
      final isUnder13SupportRoute =
          location == MinorAccountReviewUnder13SupportScreen.path;
      final isSupportRoute = location == SupportCenterScreen.path;
      final isModerationConversationRoute =
          moderationConversationId != null &&
          location == ConversationPage.pathForId(moderationConversationId);

      Log.debug(
        'Router redirect: location=$location, '
        'authState=${authState.name}',
        name: 'AppRouter',
        category: LogCategory.auth,
      );

      // Auth routes don't require authentication — user is in the
      // process of logging in.
      final isAuthRoute = _isAuthEntryLocation(location);

      // Only bounce to the loading screen on a true cold load (no value yet).
      // Riverpod keeps the previous value during a background refetch
      // (isLoading == true while hasValue == true), e.g. when
      // currentAuthStateProvider re-invalidates on an authStateStream event.
      // Treating those transient refetches as "loading" would redirect away
      // from the current route to the review loading screen and back, which
      // tears down the video feed (VideoStopNavigatorObserver disposes all
      // controllers on push).
      if (authState == AuthState.authenticated &&
          reviewStatusAsync.isLoading &&
          !reviewStatusAsync.hasValue) {
        if (!isReviewLoadingRoute) {
          return _minorAccountReviewLoadingPath(state.uri.toString());
        }
        return null;
      }

      if (authState == AuthState.authenticated && isReviewLoadingRoute) {
        // Only route to the restricted-account screen once the backend has
        // *confirmed* a restriction. If the status could not be fetched
        // (a non-404/501 API failure surfaces here as AsyncError), fail open
        // and return the user to their destination instead of stranding them
        // on the review screen — an account whose restriction we cannot prove
        // must not be treated as restricted, and bouncing an errored status
        // through the review screen risks a loading-screen ↔ review-screen
        // loop (issue #5195).
        if (reviewStatus?.isRestricted == true) {
          return MinorAccountReviewScreen.path;
        }
        return _minorAccountReviewReturnLocation(state);
      }

      if (authState == AuthState.authenticated &&
          reviewStatus?.isRestricted != true &&
          (isReviewRoute || isParentContactRoute || isUnder13SupportRoute)) {
        return VideoFeedPage.pathForIndex(0);
      }

      if (authState == AuthState.authenticated &&
          reviewStatus?.isRestricted == true) {
        final reviewCase = reviewStatus?.currentCase;
        if (isParentContactRoute) {
          if (reviewCase == null) {
            return MinorAccountReviewScreen.path;
          }
          if (!reviewCase.allowsParentVideoOrEmail) {
            return MinorAccountReviewUnder13SupportScreen.path;
          }
        }

        if (!isReviewRoute &&
            !isParentContactRoute &&
            !isUnder13SupportRoute &&
            !isSupportRoute &&
            !isModerationConversationRoute &&
            !isPublicReviewRoute &&
            !isPublicParentConsentRoute &&
            !isPublicUnder13Route) {
          Log.info(
            'Router redirect: restricted account on $location — '
            'redirecting to ${MinorAccountReviewScreen.path}',
            name: 'AppRouter',
            category: LogCategory.auth,
          );
          return MinorAccountReviewScreen.path;
        }
      }

      // Handle authenticated users on auth routes
      // Note: resetPasswordPath and EmailVerificationScreen are intentionally
      // excluded — authenticated users may navigate there via deep links.
      if (authState == AuthState.authenticated &&
          (location == WelcomeScreen.path ||
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
        if (_suppressNextAuthenticatedAuthRouteRedirect) {
          _suppressNextAuthenticatedAuthRouteRedirect = false;
          Log.info(
            'Router redirect: authenticated on auth route — '
            'staying on quick-action route instead of redirecting home',
            name: 'AppRouter',
            category: LogCategory.auth,
          );
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

      // Non-authenticated users on protected routes → welcome.
      // awaitingTosAcceptance has no dedicated screen, so treat it like unauthenticated.
      if (!isAuthRoute &&
          !_isPublicRecorderLocation(location) &&
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
      GoRoute(
        path: VideoRecorderScreen.path,
        name: VideoRecorderScreen.routeName,
        builder: (_, _) => const VideoRecorderRoute(),
      ),
      // Bottom-nav tabs live in a StatefulShellRoute so every tab keeps its
      // own Navigator (and state) alive while inactive — that is what lets the
      // tab switch cross-fade between two live tabs (see AppShellBranchContainer).
      //
      // Each branch screen reads the *globally-active* route via
      // pageContextProvider and renders a placeholder when it doesn't match.
      // Because all branches stay mounted, [_branchPage] scopes
      // pageContextProvider per branch so each tab sees *its own* route context
      // (not the active tab's) and keeps rendering real content while inactive.
      StatefulShellRoute(
        builder: (context, state, navigationShell) => AppShell(
          currentIndex: navigationShell.currentIndex,
          child: navigationShell,
        ),
        navigatorContainerBuilder: (context, navigationShell, children) =>
            AppShellBranchContainer(
              currentIndex: navigationShell.currentIndex,
              children: children,
            ),
        branches: [
          // HOME tab
          StatefulShellBranch(
            navigatorKey: NavigatorKeys.home,
            initialLocation: VideoFeedPage.pathForIndex(0),
            routes: [
              GoRoute(
                path: VideoFeedPage.pathWithIndex,
                name: VideoFeedPage.routeName,
                pageBuilder: (ctx, st) => _branchPage(
                  st,
                  VideoFeedPage(
                    initialIndex: homeInitialIndexFromPathParameters(
                      st.pathParameters,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // EXPLORE tab (grid + tab-by-name + feed)
          StatefulShellBranch(
            navigatorKey: NavigatorKeys.explore,
            initialLocation: ExploreScreen.path,
            routes: [
              GoRoute(
                path: ExploreScreen.path,
                name: ExploreScreen.routeName,
                pageBuilder: (ctx, st) =>
                    _branchPage(st, const ExploreScreen()),
              ),
              GoRoute(
                path: ExploreScreen.pathTabSubpath,
                pageBuilder: (ctx, st) {
                  final tabName = ExploreScreen.tabNameFromPathParameter(
                    st.pathParameters['name'],
                  );
                  if (tabName == null) {
                    return _branchPage(
                      st,
                      RouteErrorScreen(message: ctx.l10n.routeUnknownPath),
                    );
                  }
                  return _branchPage(
                    st,
                    ExploreScreen(initialTabName: tabName),
                  );
                },
              ),
              GoRoute(
                path: ExploreScreen.pathWithIndex,
                pageBuilder: (ctx, st) =>
                    _branchPage(st, const ExploreScreen()),
              ),
            ],
          ),

          // INBOX tab (inbox + notifications share tab position 2)
          StatefulShellBranch(
            navigatorKey: NavigatorKeys.inbox,
            initialLocation: InboxPage.path,
            routes: [
              GoRoute(
                path: NotificationsPage.pathWithIndex,
                name: NotificationsPage.routeName,
                pageBuilder: (ctx, st) =>
                    _branchPage(st, const NotificationsPage()),
              ),
              GoRoute(
                path: InboxPage.path,
                name: InboxPage.routeName,
                pageBuilder: (ctx, st) => _branchPage(st, const InboxPage()),
              ),
            ],
          ),

          // PROFILE tab (own profile grid/feed + liked-videos)
          StatefulShellBranch(
            navigatorKey: NavigatorKeys.profile,
            initialLocation: ProfileScreenRouter.path,
            routes: [
              GoRoute(
                path: ProfileScreenRouter.path,
                name: ProfileScreenRouter.routeName,
                pageBuilder: (ctx, st) =>
                    _branchPage(st, const ProfileScreenRouter()),
              ),
              GoRoute(
                path: ProfileScreenRouter.pathWithNpub,
                pageBuilder: (ctx, st) =>
                    _branchPage(st, const ProfileScreenRouter()),
              ),
              GoRoute(
                path: ProfileScreenRouter.pathWithIndex,
                pageBuilder: (ctx, st) =>
                    _branchPage(st, const ProfileScreenRouter()),
              ),
              GoRoute(
                path: LikedVideosScreenRouter.path,
                name: LikedVideosScreenRouter.routeName,
                pageBuilder: (ctx, st) =>
                    _branchPage(st, const LikedVideosScreenRouter()),
              ),
              GoRoute(
                path: LikedVideosScreenRouter.pathWithIndex,
                pageBuilder: (ctx, st) =>
                    _branchPage(st, const LikedVideosScreenRouter()),
              ),
            ],
          ),
        ],
      ),

      // HASHTAG route - standalone screen (no bottom nav)
      GoRoute(
        path: HashtagScreenRouter.path,
        name: HashtagScreenRouter.routeName,
        parentNavigatorKey: NavigatorKeys.root,
        builder: (ctx, st) {
          // go_router already decodes path parameters once during route
          // matching (see go_router/src/match.dart). Decoding again here
          // would crash on legitimate inputs containing literal `%`
          // (e.g. `100%fun`) because the second decode sees a malformed
          // sequence. Pass the value through as-is.
          final tag = st.pathParameters['tag'];
          if (tag == null || tag.isEmpty) {
            return RouteErrorScreen(message: ctx.l10n.routeInvalidHashtag);
          }
          return HashtagFeedScreen(hashtag: tag);
        },
      ),
      // SEARCH RESULTS - unified search screen (no bottom nav)
      GoRoute(
        path: SearchResultsPage.emptyPath,
        parentNavigatorKey: NavigatorKeys.root,
        builder: (ctx, st) => SearchResultsPage(
          requestFocusOnMount: SearchResultsPage.requestFocusOnMountForRoute(
            st.uri,
          ),
        ),
      ),
      GoRoute(
        path: SearchResultsPage.path,
        parentNavigatorKey: NavigatorKeys.root,
        builder: (ctx, st) {
          // See note above: do not double-decode path parameters.
          final query = st.pathParameters['query'] ?? '';
          return SearchResultsPage(
            initialQuery: query,
            requestFocusOnMount: SearchResultsPage.requestFocusOnMountForRoute(
              st.uri,
            ),
          );
        },
      ),

      // DM conversation detail (pushed from inbox, no bottom nav)
      GoRoute(
        path: ConversationPage.pathPattern,
        name: ConversationPage.routeName,
        builder: (ctx, st) {
          final id = st.pathParameters['id'];
          if (id == null || id.isEmpty) {
            return RouteErrorScreen(
              message: ctx.l10n.routeInvalidConversationId,
            );
          }
          final participantPubkeys = stringListRouteExtra(st.extra);
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
            return RouteErrorScreen(message: ctx.l10n.routeInvalidRequestId);
          }
          // Pubkeys are optional — the page loads them from the DB
          // when not provided (e.g. deep link).
          final participantPubkeys = stringListRouteExtra(st.extra);
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
      GoRoute(
        path: MinorAccountReviewScreen.welcomePath,
        name: '${MinorAccountReviewScreen.routeName}-welcome',
        parentNavigatorKey: NavigatorKeys.root,
        builder: (ctx, st) => const MinorAccountReviewScreen(
          entryPoint: MinorAccountReviewEntryPoint.welcome,
        ),
      ),
      GoRoute(
        path: MinorAccountReviewScreen.path,
        name: MinorAccountReviewScreen.routeName,
        parentNavigatorKey: NavigatorKeys.root,
        builder: (ctx, st) => const MinorAccountReviewScreen(),
      ),
      GoRoute(
        path: MinorAccountReviewLoadingScreen.path,
        name: MinorAccountReviewLoadingScreen.routeName,
        parentNavigatorKey: NavigatorKeys.root,
        builder: (ctx, st) => const MinorAccountReviewLoadingScreen(),
      ),
      GoRoute(
        path: MinorAccountReviewParentConsentScreen.path,
        name: MinorAccountReviewParentConsentScreen.routeName,
        parentNavigatorKey: NavigatorKeys.root,
        builder: (ctx, st) => const MinorAccountReviewParentConsentScreen(),
      ),
      GoRoute(
        path: MinorAccountReviewParentContactScreen.path,
        name: MinorAccountReviewParentContactScreen.routeName,
        parentNavigatorKey: NavigatorKeys.root,
        builder: (ctx, st) => const MinorAccountReviewParentContactScreen(),
      ),
      GoRoute(
        path: MinorAccountReviewUnder13Screen.path,
        name: MinorAccountReviewUnder13Screen.routeName,
        parentNavigatorKey: NavigatorKeys.root,
        builder: (ctx, st) => const MinorAccountReviewUnder13Screen(),
      ),
      GoRoute(
        path: MinorAccountReviewUnder13SupportScreen.path,
        name: MinorAccountReviewUnder13SupportScreen.routeName,
        parentNavigatorKey: NavigatorKeys.root,
        builder: (ctx, st) => const MinorAccountReviewUnder13SupportScreen(),
      ),

      // CURATED LIST route (NIP-51 kind 30005 video lists)
      // Outside shell so the screen's own AppBar is shown without the shell AppBar
      GoRoute(
        path: CuratedListFeedScreen.path,
        name: CuratedListFeedScreen.routeName,
        builder: (ctx, st) {
          final listId = st.pathParameters['listId'];
          if (listId == null || listId.isEmpty) {
            return RouteErrorScreen(message: ctx.l10n.routeInvalidListId);
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

      // CREATE PEOPLE LIST route. Must come before /people-lists/:listId so
      // the literal `new` segment is not captured as a list id.
      // `initialPubkey` query param lets callers (e.g., the share-video
      // "Add to list" sheet) seed the new list with a target person in
      // the same submit so the URL remains reloadable.
      // Gated on FeatureFlag.curatedLists — the PeopleListsBloc this page
      // depends on is only provided in main.dart when the flag is on, so
      // a deep link here with the flag off would crash with
      // ProviderNotFoundException. Redirect home instead.
      GoRoute(
        path: CreatePeopleListPage.path,
        name: CreatePeopleListPage.routeName,
        redirect: (context, state) =>
            _peopleListsRedirectIfDisabled(ref, state),
        builder: (context, state) => CreatePeopleListPage(
          initialPubkey: state.uri.queryParameters['initialPubkey'],
        ),
      ),

      // PEOPLE LIST MEMBERS route (NIP-51 kind 30000 people lists).
      // Addressed by list id so the screen can select the current list
      // from PeopleListsBloc and react to repository updates without a
      // route rebuild. Outside shell — the screen owns its own AppBar.
      // Gated on FeatureFlag.curatedLists (see CreatePeopleListPage route).
      GoRoute(
        path: UserListPeopleScreen.path,
        name: UserListPeopleScreen.routeName,
        redirect: (context, state) =>
            _peopleListsRedirectIfDisabled(ref, state),
        builder: (context, state) {
          final listId = state.pathParameters['listId'];
          if (listId == null || listId.isEmpty) {
            return RouteErrorScreen(
              message: context.l10n.routeInvalidListId,
              title: context.l10n.peopleListsRouteTitle,
              showBackButton: true,
            );
          }
          return UserListPeopleScreen(listId: listId);
        },
      ),

      // ADD PEOPLE TO LIST route. Full-screen picker that batches add
      // requests for the list identified by [listId].
      // Gated on FeatureFlag.curatedLists (see CreatePeopleListPage route).
      GoRoute(
        path: AddPeopleToListScreen.path,
        name: AddPeopleToListScreen.routeName,
        redirect: (context, state) =>
            _peopleListsRedirectIfDisabled(ref, state),
        builder: (context, state) {
          final listId = state.pathParameters['listId'];
          if (listId == null || listId.isEmpty) {
            return RouteErrorScreen(
              message: context.l10n.routeInvalidListId,
              title: context.l10n.peopleListsAddPeopleTitle,
              showBackButton: true,
            );
          }
          return AddPeopleToListScreen(listId: listId);
        },
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
              initialSourceSlug: state.uri.queryParameters['sourceSlug'],
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
            builder: (_, state) => LoginOptionsScreen(
              initialEmail: state.uri.queryParameters['email'],
              initialError: state.uri.queryParameters['error'],
            ),
            routes: [
              // Route for deep link when resetting password
              GoRoute(
                path: 'reset-password',
                name: ResetPasswordScreen.routeName,
                builder: (ctx, st) {
                  final token = st.uri.queryParameters['token'];
                  final email = st.uri.queryParameters['email'];
                  return ResetPasswordScreen(token: token ?? '', email: email);
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
        redirect: (context, state) => rewriteResetPasswordDeepLink(state.uri),
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
        path: BadgesScreen.path,
        name: BadgesScreen.routeName,
        builder: (_, _) => const BadgesScreen(),
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
        path: WebIframeSandboxScreen.path,
        name: WebIframeSandboxScreen.routeName,
        builder: (_, state) {
          final app = state.extra is NostrAppDirectoryEntry
              ? state.extra! as NostrAppDirectoryEntry
              : null;
          if (app == null) {
            // No NostrAppDirectoryEntry passed in — bounce to the apps
            // directory. The web iframe screen needs the entry's
            // launchUrl + origin, which we can't reconstruct from the
            // path parameter alone.
            return const SizedBox.shrink();
          }
          return WebIframeSandboxScreen(app: app);
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
        path: GeneralSettingsScreen.path,
        name: GeneralSettingsScreen.routeName,
        builder: (_, _) => const GeneralSettingsScreen(),
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
        routes: [
          GoRoute(
            path: Nip05SettingsScreen.subpath,
            name: Nip05SettingsScreen.routeName,
            builder: (_, _) => const Nip05SettingsScreen(),
          ),
        ],
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
      GoRoute(
        path: LibraryScreen.clipsOnlyPath,
        name: LibraryScreen.clipsOnlyRouteName,
        builder: (_, _) =>
            const LibraryScreen(tabsMode: LibraryTabsMode.clipsOnly),
      ),
      GoRoute(
        path: LibraryScreen.soundsPath,
        name: LibraryScreen.soundsRouteName,
        builder: (_, _) => const LibraryScreen(initialTabIndex: 2),
      ),
      // Followers screen - routes to My or Others based on pubkey
      GoRoute(
        path: FollowersScreenRouter.path,
        name: FollowersScreenRouter.routeName,
        builder: (ctx, st) {
          final pubkey = st.pathParameters['pubkey'];
          final displayName = st.extra as String?;
          if (pubkey == null || pubkey.isEmpty) {
            return RouteErrorScreen(message: ctx.l10n.routeInvalidUserId);
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
            return RouteErrorScreen(message: ctx.l10n.routeInvalidUserId);
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
            return RouteErrorScreen(message: ctx.l10n.routeInvalidVideoId);
          }
          final extra = st.extra;
          final routeExtra = extra is VideoDetailRouteExtra ? extra : null;
          return VideoDetailScreen(
            videoId: videoId,
            autoOpenComments: routeExtra?.autoOpenComments ?? false,
            fallbackVideoIds: routeExtra?.fallbackVideoIds ?? const [],
            initialVideo: routeExtra?.initialVideo,
            dmReplyContext: routeExtra?.dmReplyContext,
          );
        },
      ),
      // Sound detail route (for audio reuse feature)
      GoRoute(
        path: SoundDetailScreen.path,
        name: SoundDetailScreen.routeName,
        builder: (ctx, st) {
          final soundId = st.pathParameters['id'];
          if (soundId == null || soundId.isEmpty) {
            return RouteErrorScreen(message: ctx.l10n.routeInvalidSoundId);
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
            return SoundDetailScreen(sound: sound, sourceVideo: sourceVideo);
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
            return RouteErrorScreen(message: ctx.l10n.routerInvalidCreator);
          }
          return OriginalSoundDetailScreen(
            creatorPubkey: pubkey,
            sourceVideo: video,
          );
        },
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
        path: '${VideoMetadataEditScreen.path}/:videoId',
        name: VideoMetadataEditScreen.routeName,
        builder: (ctx, st) {
          final videoId = st.pathParameters['videoId'];
          if (videoId == null || videoId.isEmpty) {
            return RouteErrorScreen(message: ctx.l10n.routeInvalidVideoId);
          }
          final prefetched = st.extra as VideoEvent?;
          return VideoMetadataEditScreen(
            videoId: videoId,
            prefetched: prefetched,
          );
        },
      ),
      GoRoute(
        path: '${SubtitleEditorScreen.path}/:videoId',
        name: SubtitleEditorScreen.routeName,
        builder: (ctx, st) {
          final videoId = st.pathParameters['videoId'];
          if (videoId == null || videoId.isEmpty) {
            return RouteErrorScreen(message: ctx.l10n.routeInvalidVideoId);
          }
          final prefetched = st.extra as VideoEvent?;
          return SubtitleEditorScreen(videoId: videoId, prefetched: prefetched);
        },
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
            return RouteErrorScreen(message: ctx.l10n.routeInvalidCategory);
          }

          return CategoryGalleryScreen(category: category);
        },
      ),
      // Fullscreen video feed.
      GoRoute(
        path: PooledFullscreenVideoFeedScreen.path,
        name: PooledFullscreenVideoFeedScreen.routeName,
        redirect: (context, state) => fullscreenFeedRedirect(state.extra),
        builder: buildPooledFullscreenFeed,
      ),
      // Engagement lists for own videos: who liked / reposted this video.
      // Reached when the video owner taps the Like or Repost button on
      // their own video.
      GoRoute(
        path: '/video/:eventId/likers',
        name: VideoEngagementListScreen.likersRouteName,
        builder: (ctx, st) {
          final eventId = st.pathParameters['eventId'];
          if (eventId == null || eventId.isEmpty) {
            return RouteErrorScreen(message: ctx.l10n.routeNoVideosToDisplay);
          }
          final addressableId = st.uri.queryParameters['a'];
          return VideoEngagementListScreen(
            eventId: eventId,
            type: VideoEngagementType.likers,
            addressableId: addressableId,
          );
        },
      ),
      GoRoute(
        path: '/video/:eventId/reposters',
        name: VideoEngagementListScreen.repostersRouteName,
        builder: (ctx, st) {
          final eventId = st.pathParameters['eventId'];
          if (eventId == null || eventId.isEmpty) {
            return RouteErrorScreen(message: ctx.l10n.routeNoVideosToDisplay);
          }
          final addressableId = st.uri.queryParameters['a'];
          return VideoEngagementListScreen(
            eventId: eventId,
            type: VideoEngagementType.reposters,
            addressableId: addressableId,
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
            return RouteErrorScreen(message: ctx.l10n.routeInvalidProfileId);
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

  ref.onDispose(router.dispose);

  return router;
});

List<NavigatorObserver> _buildRouterObservers() {
  final observers = <NavigatorObserver>[
    routeObserver,
    PageLoadObserver(),
    VideoStopNavigatorObserver(),
  ];

  return observers;
}
