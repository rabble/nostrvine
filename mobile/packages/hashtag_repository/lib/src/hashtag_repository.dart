// ABOUTME: Repository for searching hashtags via the Funnelcake API.
// ABOUTME: Delegates to FunnelcakeApiClient for server-side hashtag search.

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:models/models.dart';

/// Repository for searching hashtags.
///
/// Provides a clean abstraction over the Funnelcake API for hashtag search.
/// This layer can be extended with caching or additional data sources.
class HashtagRepository {
  /// Creates a new [HashtagRepository] instance.
  const HashtagRepository({
    FunnelcakeApiClient? funnelcakeApiClient,
  }) : _funnelcakeApiClient = funnelcakeApiClient;

  final FunnelcakeApiClient? _funnelcakeApiClient;

  /// Searches for hashtags matching [query].
  ///
  /// Returns a list of hashtag name strings sorted by popularity/trending.
  /// When [query] is null or empty, returns popular hashtags without filtering.
  /// Returns an empty list if the API client is not available.
  /// [limit] defaults to 20.
  ///
  /// Throws [FunnelcakeException] subtypes on API errors.
  Future<List<String>> searchHashtags({
    String? query,
    int limit = 20,
  }) async {
    if (_funnelcakeApiClient == null || !_funnelcakeApiClient.isAvailable) {
      return [];
    }
    return _funnelcakeApiClient.searchHashtags(
      query: query,
      limit: limit,
    );
  }

  /// Fetches trending hashtags.
  ///
  /// Returns a list of [TrendingHashtag] sorted by popularity.
  /// Returns an empty list if the API client is not available.
  /// [limit] defaults to 20.
  ///
  /// Throws [FunnelcakeException] subtypes on API errors.
  Future<List<TrendingHashtag>> fetchTrendingHashtags({
    int limit = 20,
  }) async {
    if (_funnelcakeApiClient == null || !_funnelcakeApiClient.isAvailable) {
      return [];
    }
    return _funnelcakeApiClient.fetchTrendingHashtags(limit: limit);
  }
}
