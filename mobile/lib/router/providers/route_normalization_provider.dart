// ABOUTME: Route normalization provider - ensures canonical URL format
// ABOUTME: Redirects to canonical URLs for negative indices, encoding, unknown paths

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/auth/email_verification_screen.dart';
import 'package:openvine/screens/auth/nostr_connect_screen.dart';
import 'package:openvine/screens/auth/reset_password.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/screens/search_results/view/search_results_page.dart';
import 'package:openvine/services/deep_link_service.dart';
import 'package:unified_logger/unified_logger.dart';

@visibleForTesting
bool shouldSkipRouteNormalization(String loc) {
  // Skip normalization for auth-related routes.
  // EmailVerificationScreen supports both token mode (?token=) and polling
  // mode (?deviceCode=). Use contains() to handle both path-only and full URL
  // formats (deep links include host).
  if (loc.startsWith(WelcomeScreen.path) ||
      loc.startsWith(NostrConnectScreen.path) ||
      RegExp(r'^/apps/[^/]+/sandbox$').hasMatch(loc) ||
      loc.contains('${ResetPasswordScreen.path}?token=') ||
      loc.contains('${EmailVerificationScreen.path}?') ||
      loc.startsWith(SearchResultsPage.pathPrefix)) {
    return true;
  }

  final uri = Uri.tryParse(loc);
  if (uri == null || !uri.scheme.startsWith('http')) {
    return false;
  }

  final host = uri.host.toLowerCase();
  final isCanonicalDivineHost =
      host == 'divine.video' || host == 'www.divine.video';
  if (!isCanonicalDivineHost) {
    return false;
  }

  // Full divine.video universal links are resolved either in GoRouter's
  // redirect or in the app-wide DeepLinkService listener. They are not part
  // of the internal parseRoute/buildRoute contract, so normalizing them here
  // can rewrite a valid deep link into an unrelated internal fallback.
  return DeepLinkService.parseDeepLink(loc).type != DeepLinkType.unknown;
}

/// Watches router location changes and redirects to canonical URLs when needed.
/// Safe to watch at app root; contains guards to avoid loops.
final routeNormalizationProvider = Provider<void>((ref) {
  final router = ref.read(goRouterProvider);

  // Set up listener on router delegate to detect navigation changes
  void listener() {
    final loc = router.routeInformationProvider.value.uri.toString();
    if (shouldSkipRouteNormalization(loc)) {
      Log.info(
        '🔄 RouteNormalizationProvider: skipping normalization for $loc',
        name: 'RouteNormalizationProvider',
      );
      return;
    }

    // Parse and rebuild to get canonical form
    final parsed = parseRoute(loc);
    final canonical = buildRoute(parsed);

    // If not canonical, schedule post-frame redirect
    if (canonical != loc) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        // Check again before redirecting to avoid loops if location changed
        final now = router.routeInformationProvider.value.uri.toString();
        if (now != canonical) {
          Log.info(
            '🔄 Normalizing route from $now to $canonical',
            name: 'RouteNormalizationProvider',
          );
          router.go(canonical);
        }
      });
    }
  }

  // Attach listener and ensure cleanup on dispose
  router.routerDelegate.addListener(listener);
  ref.onDispose(() => router.routerDelegate.removeListener(listener));

  return;
});
