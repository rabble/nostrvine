// ABOUTME: Riverpod provider for content curation with reactive updates
// ABOUTME: Manages only editor picks - trending/popular handled by infinite feeds

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart'
    hide LogCategory, CurationSet, CurationSetType, SampleCurationSets;
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/models/curation_set.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/video_events_providers.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:openvine/services/analytics_api_service.dart';
import 'package:openvine/state/curation_state.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'curation_providers.g.dart';

/// Provider for analytics API service
@riverpod
AnalyticsApiService analyticsApiService(Ref ref) {
  final environmentConfig = ref.watch(currentEnvironmentProvider);

  return AnalyticsApiService(baseUrl: environmentConfig.apiBaseUrl);
}

/// Provider for FunnelcakeApiClient (typed client for Funnelcake REST API)
@riverpod
FunnelcakeApiClient funnelcakeApiClient(Ref ref) {
  final environmentConfig = ref.watch(currentEnvironmentProvider);
  return FunnelcakeApiClient(baseUrl: environmentConfig.apiBaseUrl ?? '');
}

/// Single source of truth for Funnelcake REST API availability.
///
/// Uses capability detection - actually probes the API to verify it works.
/// Re-checks when environment or relay configuration changes.
///
/// All feed providers should watch this instead of checking
/// `analyticsService.isAvailable` directly.
@Riverpod(keepAlive: true)
class FunnelcakeAvailable extends _$FunnelcakeAvailable {
  @override
  Future<bool> build() async {
    final analyticsService = ref.watch(analyticsApiServiceProvider);

    // Quick check: is the API configured at all?
    if (!analyticsService.isAvailable) {
      Log.debug(
        '🔌 Funnelcake: API not configured',
        name: 'FunnelcakeAvailable',
        category: LogCategory.system,
      );
      return false;
    }

    // Watch relay changes to re-probe when relays change
    final nostrService = ref.watch(nostrServiceProvider);
    // Access relayStatuses to establish dependency (triggers rebuild on change)
    final relayCount = nostrService.relayStatuses.length;

    // Capability detection: try a lightweight API call
    try {
      Log.debug(
        '🔌 Funnelcake: Probing API availability (relays: $relayCount)',
        name: 'FunnelcakeAvailable',
        category: LogCategory.system,
      );
      // Use trending endpoint with limit=1 as lightweight probe
      await analyticsService.getTrendingVideos(limit: 1);
      Log.info(
        '✅ Funnelcake: API available',
        name: 'FunnelcakeAvailable',
        category: LogCategory.system,
      );
      return true;
    } catch (e) {
      Log.info(
        '❌ Funnelcake: API unavailable - $e',
        name: 'FunnelcakeAvailable',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Force re-check of Funnelcake availability
  void refresh() {
    ref.invalidateSelf();
  }
}

/// Main curation provider that manages curated content sets
/// keepAlive ensures provider persists across tab navigation
@Riverpod(keepAlive: true)
class Curation extends _$Curation {
  @override
  CurationState build() {
    // Auto-refresh when video events change
    ref.listen(videoEventsProvider, (previous, next) {
      // Only refresh if we have new video events
      final prevLength = previous?.hasValue == true
          ? (previous!.value?.length ?? 0)
          : 0;
      final nextLength = (next.hasValue) ? (next.value?.length ?? 0) : 0;
      if (next.hasValue && prevLength != nextLength) {
        _refreshCurationSets();
      }
    });

    // Initialize with empty state
    _initializeCuration();

    return CurationState(editorsPicks: [], isLoading: true);
  }

  Future<void> _initializeCuration() async {
    try {
      final service = ref.read(curationServiceProvider);

      Log.debug(
        'Curation: Initializing curation sets',
        name: 'CurationProvider',
        category: LogCategory.system,
      );

      // CurationService initializes itself in constructor
      // Just get the current data
      state = CurationState(
        editorsPicks: service.getVideosForSetType(CurationSetType.editorsPicks),
        isLoading: false,
      );

      Log.info(
        'Curation: Loaded ${state.editorsPicks.length} editor picks',
        name: 'CurationProvider',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Curation: Initialization error: $e',
        name: 'CurationProvider',
        category: LogCategory.system,
      );

      state = CurationState(
        editorsPicks: [],
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> _refreshCurationSets() async {
    final service = ref.read(curationServiceProvider);

    try {
      service.refreshIfNeeded();

      // Update state with refreshed data
      state = state.copyWith(
        editorsPicks: service.getVideosForSetType(CurationSetType.editorsPicks),
        error: null,
      );

      Log.debug(
        'Curation: Refreshed curation sets',
        name: 'CurationProvider',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Curation: Refresh error: $e',
        name: 'CurationProvider',
        category: LogCategory.system,
      );

      state = state.copyWith(error: e.toString());
    }
  }

  /// Refresh all curation sets (currently just Editor's Picks)
  Future<void> refreshAll() async {
    await _refreshCurationSets();
  }

  /// Force refresh all curation sets
  Future<void> forceRefresh() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true);

    try {
      final service = ref.read(curationServiceProvider);

      // Force refresh from remote
      await service.refreshCurationSets();

      // Update state
      state = CurationState(
        editorsPicks: service.getVideosForSetType(CurationSetType.editorsPicks),
        isLoading: false,
      );

      Log.info(
        'Curation: Force refreshed editor picks',
        name: 'CurationProvider',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Curation: Force refresh error: $e',
        name: 'CurationProvider',
        category: LogCategory.system,
      );

      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

/// Provider to check if curation is loading
@riverpod
bool curationLoading(Ref ref) => ref.watch(curationProvider).isLoading;

/// Provider to get editor's picks
@riverpod
List<VideoEvent> editorsPicks(Ref ref) =>
    ref.watch(curationProvider.select((state) => state.editorsPicks));

/// Provider for analytics-based trending videos with cursor pagination
@riverpod
class AnalyticsTrending extends _$AnalyticsTrending {
  int? _nextCursor;
  bool _hasMore = true;
  bool _isLoading = false;

  @override
  List<VideoEvent> build() {
    // Initialize empty list, will be populated on refresh
    _nextCursor = null;
    _hasMore = true;
    _isLoading = false;
    return [];
  }

  /// Refresh trending videos from analytics API
  Future<void> refresh() async {
    if (_isLoading) return;
    _isLoading = true;

    Log.info(
      'AnalyticsTrending: Refreshing trending videos from analytics API',
      name: 'AnalyticsTrendingProvider',
      category: LogCategory.system,
    );

    try {
      final service = ref.read(analyticsApiServiceProvider);
      final videos = await service.getTrendingVideos(forceRefresh: true);

      // Check if provider is still mounted after async gap
      if (!ref.mounted) return;

      // Reset pagination state
      _nextCursor = _getOldestTimestamp(videos);
      _hasMore = videos.length >= AppConstants.paginationBatchSize;

      // Update state with new trending videos
      state = videos;

      Log.info(
        'AnalyticsTrending: Loaded ${state.length} trending videos, hasMore: $_hasMore',
        name: 'AnalyticsTrendingProvider',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'AnalyticsTrending: Error refreshing: $e',
        name: 'AnalyticsTrendingProvider',
        category: LogCategory.system,
      );
      // Keep existing state on error
    } finally {
      _isLoading = false;
    }
  }

  /// Load more trending videos using cursor-based pagination
  Future<void> loadMore() async {
    if (_isLoading || !_hasMore) {
      Log.debug(
        'AnalyticsTrending: Skipping loadMore (isLoading: $_isLoading, hasMore: $_hasMore)',
        name: 'AnalyticsTrendingProvider',
        category: LogCategory.system,
      );
      return;
    }

    _isLoading = true;
    final currentCount = state.length;

    Log.info(
      'AnalyticsTrending: Loading more trending videos (current: $currentCount, cursor: $_nextCursor)',
      name: 'AnalyticsTrendingProvider',
      category: LogCategory.system,
    );

    try {
      final service = ref.read(analyticsApiServiceProvider);

      // Use cursor-based pagination with 'before' parameter
      final videos = await service.getTrendingVideos(
        limit: 50,
        before: _nextCursor,
      );

      // Check if provider is still mounted after async gap
      if (!ref.mounted) return;

      if (videos.isNotEmpty) {
        // Deduplicate and merge (case-insensitive for Nostr IDs)
        final existingIds = state.map((v) => v.id.toLowerCase()).toSet();
        final newVideos = videos
            .where((v) => !existingIds.contains(v.id.toLowerCase()))
            .toList();

        if (newVideos.isNotEmpty) {
          state = [...state, ...newVideos];
          _nextCursor = _getOldestTimestamp(videos);
          _hasMore = videos.length >= AppConstants.paginationBatchSize;

          Log.info(
            'AnalyticsTrending: Loaded ${newVideos.length} more videos (total: ${state.length})',
            name: 'AnalyticsTrendingProvider',
            category: LogCategory.system,
          );
        } else {
          _hasMore = false;
          Log.info(
            'AnalyticsTrending: All returned videos already in state, stopping pagination',
            name: 'AnalyticsTrendingProvider',
            category: LogCategory.system,
          );
        }
      } else {
        _hasMore = false;
        Log.info(
          'AnalyticsTrending: No more videos available',
          name: 'AnalyticsTrendingProvider',
          category: LogCategory.system,
        );
      }
    } catch (e) {
      Log.error(
        'AnalyticsTrending: Error loading more: $e',
        name: 'AnalyticsTrendingProvider',
        category: LogCategory.system,
      );
    } finally {
      _isLoading = false;
    }
  }

  /// Get oldest timestamp from videos for cursor pagination
  int? _getOldestTimestamp(List<VideoEvent> videos) {
    if (videos.isEmpty) return null;
    return videos.map((v) => v.createdAt).reduce((a, b) => a < b ? a : b);
  }
}

/// Provider for analytics-based popular videos
@riverpod
class AnalyticsPopular extends _$AnalyticsPopular {
  @override
  List<VideoEvent> build() {
    // Initialize empty list, will be populated on refresh
    return [];
  }

  /// Refresh popular videos from analytics API
  Future<void> refresh() async {
    Log.info(
      'AnalyticsPopular: Refreshing popular videos from analytics API',
      name: 'AnalyticsPopularProvider',
      category: LogCategory.system,
    );

    try {
      final service = ref.read(analyticsApiServiceProvider);
      // Popular uses the trending videos API
      final videos = await service.getTrendingVideos(forceRefresh: true);

      // Update state with new popular videos
      state = videos;

      Log.info(
        'AnalyticsPopular: Loaded ${state.length} popular videos',
        name: 'AnalyticsPopularProvider',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'AnalyticsPopular: Error refreshing: $e',
        name: 'AnalyticsPopularProvider',
        category: LogCategory.system,
      );
      // Keep existing state on error
    }
  }
}

/// Provider for trending hashtags
@riverpod
class TrendingHashtags extends _$TrendingHashtags {
  @override
  List<TrendingHashtag> build() {
    // Get initial trending hashtags (synchronous, uses defaults when API unavailable)
    final service = ref.watch(analyticsApiServiceProvider);
    return service.getTrendingHashtags();
  }

  /// Refresh trending hashtags from REST API
  ///
  /// This fetches fresh data from the API with forceRefresh to bypass cache.
  Future<void> refresh() async {
    final service = ref.read(analyticsApiServiceProvider);
    // Fetch from API with force refresh to bypass 5-minute cache
    final hashtags = await service.fetchTrendingHashtags(forceRefresh: true);
    state = hashtags;
  }
}
