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
/// * **Staleness.** A successful response is cached. A later failure keeps
///   serving that cache for a grace window derived from the cadence in use
///   (floor [cacheTtl]), then drops the tab — so one flaky request cannot
///   flicker the tab out mid-scroll, and a sustained outage cannot strand a
///   killed tab on screen.
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

  /// Floor for how long a cached config keeps serving after a failed refresh.
  static const defaultCacheTtl = Duration(minutes: 5);

  final FunnelcakeApiClient _apiClient;
  final DateTime Function() _now;

  /// Shortest grace window a cached config gets after a failed refresh.
  ///
  /// The window actually applied also scales with the server's poll cadence;
  /// see the private grace calculation below.
  final Duration cacheTtl;

  FeaturedTabsResponse? _cached;
  DateTime? _cachedAt;

  /// Sequence number of the newest started [refresh].
  ///
  /// Request bookkeeping, not cached data: it decides which response is
  /// allowed to become the cache, and nothing reads it back out.
  int _refreshSequence = 0;

  /// Fetches and resolves the featured tab for the current viewer.
  ///
  /// Never throws: a failed fetch degrades to the cached config while it is
  /// inside its grace window, and to an empty snapshot once that window has
  /// elapsed. Callers get a resolved answer, not an error to interpret.
  ///
  /// [viewerIsMinor] hides tabs that have not explicitly opted in to a minor
  /// audience. The public config endpoint is shared-cacheable and therefore
  /// not personalized, so this gate is the client's responsibility.
  Future<FeaturedTabsSnapshot> refresh({required bool viewerIsMinor}) async {
    final sequence = ++_refreshSequence;
    try {
      final response = await _apiClient.getFeaturedTabs();
      // Callers can have several refreshes in flight — a poll, a foreground
      // resume, an age-gate change. Only the newest may become the cache:
      // otherwise a request issued before a server kill can land after the one
      // that removed the tab, and the stale config it leaves behind is served
      // to the next failed refresh, putting the killed tab back on screen.
      if (sequence == _refreshSequence) {
        _cached = response;
        _cachedAt = _now();
      }
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
    if (_now().difference(cachedAt) >= _graceFor(cached)) {
      clearCache();
      return const FeaturedTabsSnapshot();
    }
    return _resolve(cached, viewerIsMinor: viewerIsMinor);
  }

  /// How stale a cached config may be before a failed refresh drops the tab.
  ///
  /// [cacheTtl] alone cannot deliver the anti-flicker half of this policy. The
  /// cache is only ever consulted from a *failed* refresh, and the refresh that
  /// fails is almost always the scheduled poll — by which point the cache is
  /// already one full poll interval old. At the default 5-minute cadence
  /// against a 5-minute TTL, the very first transient failure finds an
  /// already-expired cache and the tab blinks out, which is the behaviour this
  /// class exists to prevent. Any server-configured cadence at or above the TTL
  /// has the same problem.
  ///
  /// So the floor is [cacheTtl] and the grace scales with the cadence actually
  /// in use. Above the floor that means one missed poll is survived and two
  /// consecutive ones are not; below it the floor dominates and buys more
  /// retries, which is the point of having a floor at all. Either way the
  /// window is bounded, so a sustained outage cannot strand a killed tab.
  Duration _graceFor(FeaturedTabsResponse cached) {
    final scaled = cached.pollInterval * 1.5;
    return scaled > cacheTtl ? scaled : cacheTtl;
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
