// ABOUTME: Repository for video categories from the Funnelcake REST API.
// ABOUTME: Owns the in-memory TTL cache for the categories list.

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:models/models.dart';

/// Returns `true` when content from [pubkey] should be hidden.
typedef CategoryVideoBlockFilter = bool Function(String pubkey);

/// A page of category videos plus pagination metadata.
final class CategoryVideosPage {
  /// Creates a [CategoryVideosPage].
  const CategoryVideosPage({required this.videos, required this.hasMore});

  /// The filtered videos for this page.
  final List<VideoEvent> videos;

  /// Whether the API returned a full page and may have more results.
  final bool hasMore;
}

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
    CategoryVideoBlockFilter? blockFilter,
    Duration cacheDuration = const Duration(minutes: 10),
  }) : _funnelcakeApiClient = funnelcakeApiClient,
       _blockFilter = blockFilter,
       _cacheDuration = cacheDuration;

  final FunnelcakeApiClient _funnelcakeApiClient;
  final CategoryVideoBlockFilter? _blockFilter;
  final Duration _cacheDuration;

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

  /// Returns a filtered page of videos for [category].
  Future<CategoryVideosPage> getVideosForCategory({
    required String category,
    int? before,
    String sort = 'trending',
    String? platform,
  }) async {
    final videoStats = await _funnelcakeApiClient.getVideosByCategory(
      category: category,
      before: before,
      sort: sort,
      platform: platform,
    );

    return CategoryVideosPage(
      videos: _filterVideos(videoStats.toVideoEvents()),
      hasMore: videoStats.length >= 50,
    );
  }

  /// Returns filtered personalized recommendations for [pubkey].
  Future<List<VideoEvent>> getRecommendedVideos({
    required String pubkey,
    String? category,
    int limit = 50,
  }) async {
    final response = await _funnelcakeApiClient.getRecommendations(
      pubkey: pubkey,
      category: category,
      limit: limit,
    );
    return _filterVideos(response.videos.toVideoEvents());
  }

  List<VideoEvent> _filterVideos(List<VideoEvent> videos) {
    final blockFilter = _blockFilter;
    if (blockFilter == null) return videos;
    return videos.where((video) => !blockFilter(video.pubkey)).toList();
  }

  /// Clears the in-memory cache so the next call fetches fresh data.
  void invalidateCache() {
    _cache = null;
    _cachedAt = null;
  }
}
