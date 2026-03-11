// ABOUTME: Repository for searching hashtags via the Funnelcake API.
// ABOUTME: Delegates to FunnelcakeApiClient for server-side hashtag search.

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:hashtag_repository/src/hashtag_extractor.dart';
import 'package:models/models.dart';

/// Callback for searching locally cached hashtags.
typedef LocalHashtagSearch = List<String> Function(String query, int limit);

/// Repository for searching hashtags.
///
/// Provides a clean abstraction over the Funnelcake API for hashtag search.
/// This layer owns caching for trending hashtags and falls back to
/// [HashtagExtractor.suggestedHashtags] when the API is unavailable.
class HashtagRepository {
  /// Creates a new [HashtagRepository] instance.
  HashtagRepository({
    required FunnelcakeApiClient funnelcakeApiClient,
    LocalHashtagSearch? localSearch,
    Duration cacheDuration = const Duration(minutes: 5),
  }) : _funnelcakeApiClient = funnelcakeApiClient,
       _localSearch = localSearch,
       _cacheDuration = cacheDuration;

  final FunnelcakeApiClient _funnelcakeApiClient;
  final LocalHashtagSearch? _localSearch;
  final Duration _cacheDuration;

  List<TrendingHashtag> _trendingHashtagsCache = [];
  DateTime? _lastTrendingHashtagsFetch;

  /// Searches for hashtags matching [query].
  ///
  /// Returns a list of hashtag name strings sorted by popularity/trending.
  /// When [query] is null or empty, returns popular hashtags without filtering.
  /// [limit] defaults to 20.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not configured.
  /// - [FunnelcakeApiException] if the request fails with a non-success status.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<List<String>> searchHashtags({
    String? query,
    int limit = 20,
  }) => _funnelcakeApiClient.searchHashtags(
    query: query,
    limit: limit,
  );

  /// Searches locally cached hashtags without performing a network request.
  List<String> searchHashtagsLocally({
    required String query,
    int limit = 20,
  }) {
    final trimmed = query.trim();
    if (trimmed.isEmpty || _localSearch == null) return const [];
    return _localSearch(trimmed, limit);
  }

  /// Counts locally cached hashtag matches.
  int countHashtagsLocally({required String query}) {
    return searchHashtagsLocally(query: query, limit: 1000).length;
  }

  /// Fetches trending hashtags.
  ///
  /// Returns a list of [TrendingHashtag] sorted by popularity.
  /// [limit] defaults to 20.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not configured.
  /// - [FunnelcakeApiException] on server error.
  /// - [FunnelcakeTimeoutException] on timeout.
  /// - [FunnelcakeException] for other errors.
  Future<List<TrendingHashtag>> fetchTrendingHashtags({
    int limit = 20,
  }) => _funnelcakeApiClient.fetchTrendingHashtags(limit: limit);

  /// Returns trending hashtags, using an in-memory cache to avoid redundant
  /// network calls.
  ///
  /// When [forceRefresh] is `false` (default) and a non-expired cache exists,
  /// the cached result is returned immediately without a network call. Cache
  /// expires after the duration provided at construction time (default 5 min).
  ///
  /// When [forceRefresh] is `true` the cache is bypassed and a fresh request
  /// is made. On success the cache is updated.
  ///
  /// If the API is not configured ([FunnelcakeNotConfiguredException]), returns
  /// a built-in list of default hashtags so callers always get a usable result
  /// without needing to handle that exception themselves.
  ///
  /// Throws:
  /// - [FunnelcakeApiException] on server error.
  /// - [FunnelcakeTimeoutException] on timeout.
  /// - [FunnelcakeException] for other errors.
  Future<List<TrendingHashtag>> getTrendingHashtags({
    bool forceRefresh = false,
    int limit = 20,
  }) async {
    if (!forceRefresh &&
        _lastTrendingHashtagsFetch != null &&
        DateTime.now().difference(_lastTrendingHashtagsFetch!) <
            _cacheDuration &&
        _trendingHashtagsCache.isNotEmpty) {
      return _trendingHashtagsCache.take(limit).toList();
    }

    try {
      final results = await _funnelcakeApiClient.fetchTrendingHashtags(
        limit: limit,
      );
      _trendingHashtagsCache = results;
      _lastTrendingHashtagsFetch = DateTime.now();
      return results;
    } on FunnelcakeNotConfiguredException {
      return _buildDefaultHashtags(limit);
    }
  }

  List<TrendingHashtag> _buildDefaultHashtags(int limit) {
    final tags = HashtagExtractor.suggestedHashtags.take(limit).toList();
    return [
      for (var i = 0; i < tags.length; i++)
        TrendingHashtag(tag: tags[i], videoCount: 50 - (i * 2)),
    ];
  }
}
