// ABOUTME: Pure resolver from universal-link URIs to internal GoRouter paths
// ABOUTME: Shared source of truth used by the router redirect and tests

import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/screens/search_results/view/search_results_page.dart';
import 'package:openvine/services/deep_link_service.dart';

/// Converts a universal-link [uri] into an internal GoRouter path.
///
/// Returns the internal path (e.g. `/search-results/music`) when the URI is a
/// divine.video universal link that maps to an in-app destination and the
/// mapping should be applied at the router layer. Returns `null` otherwise —
/// either because the URI is not a universal link, or because its handling is
/// deferred to the [DeepLinkService] stream listener.
///
/// Video deep links (`/video/:id`) intentionally return `null`: the listener
/// uses `router.push` to keep the home feed underneath the detail page so
/// back-navigation returns to the main screen. Rewriting in the router
/// redirect would replace the stack instead of stacking on top.
///
/// Only `divine.video` is accepted here, mirroring
/// [DeepLinkService.parseDeepLink]. Paths on `login.divine.video`
/// (OAuth callbacks) already match internal GoRoutes by coincidence of path
/// (e.g. `/reset-password`, `/verify-email`) so no rewrite is needed for them.
String? universalLinkToRouterPath(Uri uri) {
  if (!uri.scheme.startsWith('http')) return null;
  if (uri.host != 'divine.video') return null;

  final deepLink = DeepLinkService.parseDeepLink(uri.toString());
  switch (deepLink.type) {
    case DeepLinkType.profile:
      final npub = deepLink.npub;
      if (npub == null || npub.isEmpty) return null;
      final index = deepLink.index;
      if (index != null) {
        return ProfileScreenRouter.pathForIndex(npub, index);
      }
      return ProfileScreenRouter.pathForNpub(npub);
    case DeepLinkType.hashtag:
      final tag = deepLink.hashtag;
      if (tag == null || tag.isEmpty) return null;
      return HashtagScreenRouter.pathForTag(tag);
    case DeepLinkType.search:
      final term = deepLink.searchTerm;
      if (term == null || term.isEmpty) return null;
      return SearchResultsPage.pathForQuery(term);
    case DeepLinkType.video:
    case DeepLinkType.invite:
    case DeepLinkType.signerCallback:
    case DeepLinkType.unknown:
      return null;
  }
}
