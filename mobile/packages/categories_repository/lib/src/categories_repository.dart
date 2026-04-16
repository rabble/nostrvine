// ABOUTME: Repository for video categories from the Funnelcake REST API.
// ABOUTME: Owns the in-memory TTL cache for the categories list.

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:models/models.dart' show VideoCategory;

/// Repository for fetching and caching video categories.
///
/// Wraps [FunnelcakeApiClient.getCategories] and applies
/// featured-first ordering. Results are cached in memory for
/// 10 minutes so repeated screen opens do not fire redundant
/// network requests.
class CategoriesRepository {
  /// Creates a [CategoriesRepository].
  CategoriesRepository({
    required FunnelcakeApiClient funnelcakeApiClient,
    Duration cacheDuration = const Duration(minutes: 10),
  }) : _funnelcakeApiClient = funnelcakeApiClient,
       _cacheDuration = cacheDuration;

  final FunnelcakeApiClient _funnelcakeApiClient;
  final Duration _cacheDuration;

  /// Exposes the underlying API client so callers can make video-level requests
  /// (e.g. [FunnelcakeApiClient.getVideosByCategory]) directly without going
  /// through this repository.
  FunnelcakeApiClient get apiClient => _funnelcakeApiClient;

  List<VideoCategory>? _cache;
  DateTime? _cachedAt;

  bool get _isCacheValid =>
      _cache != null &&
      _cachedAt != null &&
      DateTime.now().difference(_cachedAt!) < _cacheDuration;

  /// Returns the ordered list of categories.
  ///
  /// Returns the in-memory cached result when available and not expired.
  /// When [forceRefresh] is `true` the cache is bypassed and a fresh request
  /// is made. On success the cache is updated.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not configured.
  /// - [FunnelcakeApiException] on server error.
  /// - [FunnelcakeTimeoutException] on timeout.
  /// - [FunnelcakeException] for other errors.
  Future<List<VideoCategory>> getCategories({bool forceRefresh = false}) async {
    if (!forceRefresh && _isCacheValid) {
      return _cache!;
    }

    final categories = (await _funnelcakeApiClient.getCategories(
      limit: 100,
    )).where((c) => c.name.isNotEmpty && c.videoCount > 0).toList();

    final indexedCategories = categories.indexed.toList()
      ..sort((left, right) {
        final featuredComparison = left.$2.featuredRank.compareTo(
          right.$2.featuredRank,
        );
        if (featuredComparison != 0) {
          return featuredComparison;
        }
        return left.$1.compareTo(right.$1);
      });

    final ordered = indexedCategories.map((entry) => entry.$2).toList();

    _cache = ordered;
    _cachedAt = DateTime.now();

    return ordered;
  }

  /// Clears the in-memory cache so the next call fetches fresh data.
  void invalidateCache() {
    _cache = null;
    _cachedAt = null;
  }
}
