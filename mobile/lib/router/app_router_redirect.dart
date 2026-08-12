// ABOUTME: Top-level GoRouter redirect + its auth/minor-review helpers and flags
// ABOUTME: `part of` app_router.dart so it shares the library-private navigation flags

part of 'app_router.dart';

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

@visibleForTesting
String? signerCallbackRedirectTarget(Uri uri, AuthService authService) {
  final deepLink = DeepLinkService.parseDeepLink(uri.toString());
  if (deepLink.type != DeepLinkType.signerCallback) {
    return null;
  }

  // The app-links stream handles this too, but GoRouter may see Android
  // custom-scheme callbacks first. Keep this idempotent: it only preserves
  // an already-listening NIP-46 session while routing back to its screen.
  authService.onSignerCallbackReceived(relayUrl: deepLink.signerCallbackRelay);
  return authService.nostrConnectUrl != null
      ? NostrConnectScreen.path
      : WelcomeScreen.path;
}

/// Path prefixes the `divine://` custom scheme is allowed to open.
///
/// Mirrors the universal-link claims in the served apple-app-site-association
/// files, so the custom scheme reaches exactly what a web page can already
/// reach over https — and nothing more. A custom scheme is unauthenticated
/// input (any app can register `divine://`), so without this gate, narrowing
/// the signer-callback predicate would expose all ~70 registered routes,
/// including Developer Options and key management (#6733).
///
/// `invite` is intentionally absent: it has no GoRoute to land on and is
/// handled by the [DeepLinkService] listener for https links only.
const _divineSchemeRoutablePrefixes = <String>{
  'video',
  'profile',
  'hashtag',
  'search',
  'list',
  // Not an AASA claim — added deliberately for #7074. A read-only view of the
  // signed-in user's own bookmarks, which publishes and deletes nothing.
  'saved-videos',
};

/// Resolves a `divine://` app route to an internal path, or bounces it home.
///
/// Returns `null` when [uri] is not a custom-scheme app route, so the rest of
/// the redirect chain runs unchanged. Signer callbacks are consumed earlier by
/// [signerCallbackRedirectTarget] and are not this function's concern.
@visibleForTesting
String? divineSchemeRedirectTarget(Uri uri) {
  if (uri.scheme != divineCustomScheme) return null;
  if (isDivineSignerCallbackUri(uri)) return null;

  final segments = _divineSchemePathSegments(uri);
  if (segments.isEmpty) return null;

  if (!_divineSchemeRoutablePrefixes.contains(segments.first)) {
    Log.warning(
      'Ignoring non-routable custom-scheme deep link: /${segments.first}',
      name: 'AppRouter',
      category: LogCategory.ui,
    );
    return VideoFeedPage.pathForIndex(0);
  }

  // Reuse the one mapper that owns public-URL vs internal-route differences
  // (notably /search/* -> /search-results/:query) so the two cannot drift.
  final canonical = Uri(
    scheme: 'https',
    host: 'divine.video',
    pathSegments: segments,
    queryParameters: uri.queryParameters.isEmpty ? null : uri.queryParameters,
  );
  final mapped = universalLinkToRouterPath(canonical);
  if (mapped != null) return mapped;

  // No public/internal difference (e.g. /video/:id, /saved-videos): the
  // canonical path is already a registered GoRoute.
  return canonical.hasQuery
      ? '${canonical.path}?${canonical.query}'
      : canonical.path;
}

/// Path segments of a `divine://` URL, tolerating both authority forms.
///
/// `divine:///video/abc` parses with an empty host, while `divine://video/abc`
/// puts `video` in the host. Lift the host back into the segments so both
/// forms resolve identically — unless it is a real divine.video host, where
/// the segments are already correct.
List<String> _divineSchemePathSegments(Uri uri) {
  final segments = uri.pathSegments
      .where((segment) => segment.isNotEmpty)
      .toList();
  final host = uri.host.toLowerCase();
  if (host.isEmpty ||
      host == 'divine.video' ||
      host.endsWith('.divine.video')) {
    return segments;
  }
  return <String>[host, ...segments];
}

/// Reset navigation state for testing purposes
@visibleForTesting
void resetNavigationState() {
  _hasNavigated = false;
  _suppressNextAuthenticatedAuthRouteRedirect = false;
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

bool _isPublicRecorderLocation(String location) =>
    location == VideoRecorderScreen.path ||
    location.startsWith('${VideoRecorderScreen.path}?');

/// The slice of [MinorAccountReviewStatus] (plus its async loading shape)
/// that [appRouterRedirect] actually branches on. Two emissions with an
/// equal signature always produce the same redirect decision.
///
/// Keep this in sync with the review-status reads in [appRouterRedirect]: if
/// the redirect starts branching on another field, add it here or the refresh
/// gate will swallow genuine changes to it. The coupling is guarded by
/// `test/router/router_refresh_gate_coupling_test.dart`.
typedef _MinorReviewRoutingSignature = ({
  bool loadingWithoutValue,
  bool isRestricted,
  bool hasCase,
  String? moderationConversationPubkey,
  String? moderationConversationId,
  bool allowsParentVideoOrEmail,
});

_MinorReviewRoutingSignature _minorReviewRoutingSignature(
  AsyncValue<MinorAccountReviewStatus>? status,
) {
  // `value` (not `asData?.value`) mirrors `appRouterRedirect`, which reads the
  // previous value that Riverpod carries through a background refetch.
  final review = status?.value;
  final reviewCase = review?.currentCase;
  return (
    loadingWithoutValue:
        (status?.isLoading ?? false) && !(status?.hasValue ?? false),
    isRestricted: review?.isRestricted ?? false,
    hasCase: reviewCase != null,
    moderationConversationPubkey: reviewCase?.moderationConversationPubkey,
    moderationConversationId: reviewCase?.moderationConversationId,
    allowsParentVideoOrEmail: reviewCase?.allowsParentVideoOrEmail ?? false,
  );
}

/// Whether a review-status emission can change the router's redirect outcome.
///
/// The router refreshes on every [currentMinorAccountReviewStatusProvider]
/// emission, but a background/resume refetch usually resolves to a routing-
/// identical value (active → active). Refreshing for those churns the whole
/// route pipeline while a video reel is pushed on top — reverting the reported
/// location to the shell branch and firing a spurious `didPushNext` that pauses
/// and tears down the reel's just-created player mid-initialization. Gating the
/// refresh on this predicate keeps genuine restriction flips reactive while
/// leaving an already-open reel untouched.
///
/// [previous] is nullable only for defensiveness and the first-emission tests;
/// the production `ref.listen` at [goRouterProvider] omits `fireImmediately`,
/// so Riverpod only ever invokes it with a real prior [AsyncValue].
@visibleForTesting
bool minorAccountReviewStatusAffectsRouting(
  AsyncValue<MinorAccountReviewStatus>? previous,
  AsyncValue<MinorAccountReviewStatus> next,
) {
  return _minorReviewRoutingSignature(previous) !=
      _minorReviewRoutingSignature(next);
}

/// Top-level GoRouter redirect: signer-callback → universal-link rewrite →
/// minor-account-review gating → auth-route gating → unauthenticated gating.
///
/// The order of these checks is load-bearing; reordering risks the
/// loading-screen ↔ review-screen loop (issue #5195) or feeding an
/// un-rewritten universal-link URL into the matcher (Page Not Found).
String? appRouterRedirect(Ref ref, GoRouterState state) {
  final authService = ref.read(authServiceProvider);
  final signerCallbackRedirect = signerCallbackRedirectTarget(
    state.uri,
    authService,
  );
  if (signerCallbackRedirect != null) {
    Log.info(
      'Router redirect: signer callback '
      '${redactUriStringForLogs(state.uri.toString())} -> '
      '$signerCallbackRedirect',
      name: 'AppRouter',
      category: LogCategory.auth,
    );
    return signerCallbackRedirect;
  }

  // Resolve divine:// app routes to internal paths, and bounce anything
  // outside the universal-link path set. GoRouter matches a custom-scheme
  // location on uri.path alone, so without this gate every registered route
  // would be openable by any app or web page (#6733).
  final customSchemeRedirect = divineSchemeRedirectTarget(state.uri);
  if (customSchemeRedirect != null) {
    Log.info(
      'Router redirect: custom scheme '
      '${redactUriStringForLogs(state.uri.toString())} -> '
      '$customSchemeRedirect',
      name: 'AppRouter',
      category: LogCategory.ui,
    );
    return customSchemeRedirect;
  }

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
  final authState = authService.authState;

  // Screenshot capture runs drive each screen via an imperative
  // `router.go(screenshotRoute)`. Once authenticated, suppress all redirect
  // gating (minor-account-review interstitial, empty-following bounce) so
  // the router honors that route instead of resolving to the home feed.
  // Only bypass when a capture route is actually set — otherwise fall
  // through so an authenticated launch with no route still leaves /welcome
  // for the home feed. Compile-time false outside SCREENSHOT_MODE debug
  // builds.
  if (ScreenshotMode.enabled &&
      authState == AuthState.authenticated &&
      ScreenshotMode.initialRoute != null) {
    return null;
  }

  final reviewStatusAsync = ref.read(currentMinorAccountReviewStatusProvider);
  final reviewStatus = reviewStatusAsync.value;
  final moderationConversationId = _moderationConversationId(
    authService,
    reviewStatus?.currentCase,
  );

  final isReviewRoute = location == MinorAccountReviewScreen.path;
  final isPublicReviewRoute = location == MinorAccountReviewScreen.welcomePath;
  final isReviewLoadingRoute = location == MinorAccountReviewLoadingScreen.path;
  final isPublicParentConsentRoute =
      location == MinorAccountReviewParentConsentScreen.path;
  final isParentContactRoute =
      location == MinorAccountReviewParentContactScreen.path;
  final isPublicUnder13Route = location == MinorAccountReviewUnder13Screen.path;
  final isUnder13SupportRoute =
      location == MinorAccountReviewUnder13SupportScreen.path;
  final isSupportRoute =
      location == SupportCenterScreen.path ||
      location == BugReportScreen.path ||
      location == FeatureRequestScreen.path;
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
  // tears down and rebuilds the video feed.
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
  // awaitingTosAcceptance has no dedicated screen, so treat it like
  // unauthenticated.
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
}
