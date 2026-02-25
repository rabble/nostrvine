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
    required FunnelcakeApiClient funnelcakeApiClient,
  }) : _funnelcakeApiClient = funnelcakeApiClient;

  final FunnelcakeApiClient _funnelcakeApiClient;

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
}
