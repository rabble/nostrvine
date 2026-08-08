// ABOUTME: Fetches, caches, and gates the server-driven featured Explore tab.
// ABOUTME: Owns TTL/staleness policy so the BLoC consumes a resolved answer.

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:models/models.dart';

/// Resolved featured-tab answer for one refresh.
class FeaturedTabsSnapshot {
  /// Creates a snapshot carrying the renderable tab, if any.
  const FeaturedTabsSnapshot({
    this.tab,
    this.pollInterval = FeaturedTabsResponse.defaultPollInterval,
  });

  /// The single tab that should render, or `null` when none is eligible.
  final FeaturedTabConfig? tab;

  /// Cadence at which the caller should refresh.
  final Duration pollInterval;

  /// Whether a tab should render.
  bool get hasTab => tab != null;
}

/// One page of featured tab videos, in server order.
class FeaturedTabVideosPage {
  /// Creates a page of featured tab videos.
  const FeaturedTabVideosPage({
    required this.videos,
    this.nextCursor,
    this.hasMore = false,
  });

  /// Videos for this page, in the order the server returned them.
  final List<VideoEvent> videos;

  /// Opaque cursor for the following page.
  final String? nextCursor;

  /// Whether another page exists.
  final bool hasMore;
}

/// Composes the featured-tab config source with cache and eligibility rules.
///
/// Owns three policies the layers above must not reimplement:
///
/// * **Staleness.** A successful response is cached. A later failure serves
///   that cache until [cacheTtl] elapses, then drops the tab — so one flaky
///   request cannot flicker the tab out mid-scroll, and a sustained outage
///   cannot strand a killed tab on screen.
/// * **Eligibility.** A tab renders only when it is enabled, inside its
///   window, has server-side content, and passes the viewer audience rule.
/// * **Selection.** The payload is a list; v1 renders at most one tab, so the
///   first eligible entry wins.
class FeaturedTabsRepository {
  /// Creates a repository over [apiClient].
  ///
  /// [now] is injectable so tests can drive the window and TTL clocks.
  FeaturedTabsRepository({
    required FunnelcakeApiClient apiClient,
    DateTime Function()? now,
    this.cacheTtl = defaultCacheTtl,
  }) : _apiClient = apiClient,
       _now = now ?? (() => DateTime.now().toUtc());

  /// How long a cached config keeps serving after a failed refresh.
  static const defaultCacheTtl = Duration(minutes: 5);

  final FunnelcakeApiClient _apiClient;
  final DateTime Function() _now;

  /// Maximum age a cached config may reach before it stops being served.
  final Duration cacheTtl;

  FeaturedTabsResponse? _cached;
  DateTime? _cachedAt;

  /// Fetches and resolves the featured tab for the current viewer.
  ///
  /// Never throws: a failed fetch degrades to the cached config while it is
  /// fresh, and to an empty snapshot once [cacheTtl] has elapsed. Callers get
  /// a resolved answer, not an error to interpret.
  ///
  /// [viewerIsMinor] hides tabs that have not explicitly opted in to a minor
  /// audience. The public config endpoint is shared-cacheable and therefore
  /// not personalized, so this gate is the client's responsibility.
  Future<FeaturedTabsSnapshot> refresh({required bool viewerIsMinor}) async {
    try {
      final response = await _apiClient.getFeaturedTabs();
      _cached = response;
      _cachedAt = _now();
      return _resolve(response, viewerIsMinor: viewerIsMinor);
    } on FunnelcakeException {
      return _fromCache(viewerIsMinor: viewerIsMinor);
    }
  }

  /// Loads one page of videos for the featured tab identified by [tabId].
  ///
  /// The returned order is the server's and is preserved exactly: curated
  /// entries first, then approved newest-first. Callers must not re-sort or
  /// re-filter — the server has already applied audience and moderation
  /// gating. Expired NIP-40 events are the one exception, dropped here at the
  /// REST ingress boundary like every other feed.
  ///
  /// Throws [FunnelcakeException] subclasses on failure; unlike [refresh],
  /// paging errors are surfaced so the tab can show a retry affordance.
  Future<FeaturedTabVideosPage> loadVideos({
    required String tabId,
    String? cursor,
  }) async {
    final response = await _apiClient.getFeaturedTabVideos(
      id: tabId,
      cursor: cursor,
    );
    return FeaturedTabVideosPage(
      videos: response.videos.toVideoEvents(),
      nextCursor: response.nextCursor,
      hasMore: response.hasMore ?? response.nextCursor != null,
    );
  }

  /// Drops any cached config, so the next [refresh] must reach the network.
  void clearCache() {
    _cached = null;
    _cachedAt = null;
  }

  FeaturedTabsSnapshot _fromCache({required bool viewerIsMinor}) {
    final cached = _cached;
    final cachedAt = _cachedAt;
    if (cached == null || cachedAt == null) {
      return const FeaturedTabsSnapshot();
    }
    if (_now().difference(cachedAt) >= cacheTtl) {
      clearCache();
      return const FeaturedTabsSnapshot();
    }
    return _resolve(cached, viewerIsMinor: viewerIsMinor);
  }

  FeaturedTabsSnapshot _resolve(
    FeaturedTabsResponse response, {
    required bool viewerIsMinor,
  }) {
    final now = _now();
    FeaturedTabConfig? eligible;
    for (final tab in response.tabs) {
      if (_isEligible(tab, now: now, viewerIsMinor: viewerIsMinor)) {
        eligible = tab;
        break;
      }
    }
    return FeaturedTabsSnapshot(
      tab: eligible,
      pollInterval: response.pollInterval,
    );
  }

  bool _isEligible(
    FeaturedTabConfig tab, {
    required DateTime now,
    required bool viewerIsMinor,
  }) {
    if (!tab.enabled) return false;
    if (!tab.hasContent) return false;
    if (!tab.isWithinWindow(now)) return false;
    if (viewerIsMinor && !tab.visibleToMinors) return false;
    // A tab with no resolvable label cannot be rendered in the tab bar.
    return tab.labelFor(null).isNotEmpty;
  }
}
