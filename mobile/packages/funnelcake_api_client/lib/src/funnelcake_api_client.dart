// ABOUTME: HTTP client for the Funnelcake REST API (ClickHouse analytics).
// ABOUTME: Provides methods for fetching video data with engagement metrics.

import 'dart:async';
import 'dart:convert';

import 'package:funnelcake_api_client/src/exceptions.dart';
import 'package:funnelcake_api_client/src/models/models.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:models/models.dart'
    show HashtagSearchResult, ProfileSearchResult, VideoStats;

/// HTTP client for the Funnelcake REST API.
///
/// Funnelcake provides a ClickHouse-backed analytics API that offers
/// faster queries than Nostr relays for video data and engagement metrics.
///
/// This client handles HTTP requests only. Caching should be implemented
/// by consumers of this client.
///
/// Example usage:
/// ```dart
/// final client = FunnelcakeApiClient(
///   baseUrl: 'https://api.example.com',
/// );
///
/// final videos = await client.getVideosByAuthor(pubkey: 'abc123');
/// ```
class FunnelcakeApiClient {
  /// Creates a new [FunnelcakeApiClient] instance.
  ///
  /// [baseUrl] is the base URL for the Funnelcake API
  /// (e.g., 'https://api.example.com').
  /// [httpClient] is an optional HTTP client for making requests.
  /// [timeout] is the request timeout duration (defaults to 15 seconds).
  FunnelcakeApiClient({
    required String baseUrl,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 15),
  }) : _baseUrl = baseUrl.endsWith('/')
           ? baseUrl.substring(0, baseUrl.length - 1)
           : baseUrl,
       _httpClient = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null,
       _timeout = timeout;

  final String _baseUrl;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final Duration _timeout;

  /// Whether the API is available (has a non-empty base URL).
  bool get isAvailable => _baseUrl.isNotEmpty;

  /// The base URL for the API.
  @visibleForTesting
  String get baseUrl => _baseUrl;

  Future<http.Response> _get(Uri uri) {
    return _httpClient
        .get(
          uri,
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'OpenVine-Mobile/1.0',
          },
        )
        .timeout(_timeout);
  }

  /// Fetches videos by a specific author.
  ///
  /// [pubkey] is the author's public key (hex format).
  /// [limit] is the maximum number of videos to return (defaults to 50).
  /// [before] is an optional Unix timestamp cursor for pagination.
  ///
  /// Returns a list of [VideoStats] objects.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not configured.
  /// - [FunnelcakeNotFoundException] if the author is not found.
  /// - [FunnelcakeApiException] if the request fails with a non-success status.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<List<VideoStats>> getVideosByAuthor({
    required String pubkey,
    int limit = 50,
    int? before,
  }) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    if (pubkey.isEmpty) {
      throw const FunnelcakeException('Pubkey cannot be empty');
    }

    final queryParams = <String, String>{
      'limit': limit.toString(),
    };
    if (before != null) {
      queryParams['before'] = before.toString();
    }

    final uri = Uri.parse(
      '$_baseUrl/api/users/$pubkey/videos',
    ).replace(queryParameters: queryParams);

    try {
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;

        return data
            .map((v) => VideoStats.fromJson(v as Map<String, dynamic>))
            .where((v) => v.id.isNotEmpty && v.videoUrl.isNotEmpty)
            .toList();
      } else if (response.statusCode == 404) {
        throw FunnelcakeNotFoundException(
          resource: 'Author videos',
          url: uri.toString(),
        );
      } else {
        throw FunnelcakeApiException(
          message: 'Failed to fetch author videos',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to fetch author videos: $e');
    }
  }

  /// Fetches trending videos sorted by engagement score.
  ///
  /// [limit] is the maximum number of videos to return (defaults to 50).
  /// [before] is an optional Unix timestamp cursor for pagination.
  ///
  /// Returns a list of [VideoStats] objects sorted by trending score.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not configured.
  /// - [FunnelcakeApiException] if the request fails with a non-success status.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<List<VideoStats>> getTrendingVideos({
    int limit = 50,
    int? before,
  }) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    final queryParams = <String, String>{
      'sort': 'trending',
      'limit': limit.toString(),
    };
    if (before != null) {
      queryParams['before'] = before.toString();
    }

    final uri = Uri.parse(
      '$_baseUrl/api/videos',
    ).replace(queryParameters: queryParams);

    try {
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;

        return data
            .map((v) => VideoStats.fromJson(v as Map<String, dynamic>))
            .where((v) => v.id.isNotEmpty && v.videoUrl.isNotEmpty)
            .toList();
      } else {
        throw FunnelcakeApiException(
          message: 'Failed to fetch trending videos',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to fetch trending videos: $e');
    }
  }

  /// Fetches recent videos sorted by creation time (newest first).
  ///
  /// [limit] is the maximum number of videos to return (defaults to 50).
  /// [before] is an optional Unix timestamp cursor for pagination.
  ///
  /// Returns a list of [VideoStats] objects sorted by recency.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not configured.
  /// - [FunnelcakeApiException] if the request fails with a non-success status.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<List<VideoStats>> getRecentVideos({
    int limit = 50,
    int? before,
  }) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    final queryParams = <String, String>{
      'sort': 'recent',
      'limit': limit.toString(),
    };
    if (before != null) {
      queryParams['before'] = before.toString();
    }

    final uri = Uri.parse(
      '$_baseUrl/api/videos',
    ).replace(queryParameters: queryParams);

    try {
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;

        return data
            .map((v) => VideoStats.fromJson(v as Map<String, dynamic>))
            .where((v) => v.id.isNotEmpty && v.videoUrl.isNotEmpty)
            .toList();
      } else {
        throw FunnelcakeApiException(
          message: 'Failed to fetch recent videos',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to fetch recent videos: $e');
    }
  }

  /// Fetches the home feed for a specific user.
  ///
  /// Returns videos from accounts the user follows, with cursor-based
  /// pagination.
  ///
  /// [pubkey] is the user's public key (hex format).
  /// [limit] is the maximum number of videos to return (defaults to 50).
  /// [sort] is the sort order ('recent' or 'trending', defaults to 'recent').
  /// [before] is an optional Unix timestamp cursor for pagination.
  ///
  /// Returns a [HomeFeedResponse] containing videos and pagination info.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not configured.
  /// - [FunnelcakeNotFoundException] if the user's feed is not found.
  /// - [FunnelcakeApiException] if the request fails with a non-success status.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<HomeFeedResponse> getHomeFeed({
    required String pubkey,
    int limit = 50,
    String sort = 'recent',
    int? before,
  }) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    if (pubkey.isEmpty) {
      throw const FunnelcakeException('Pubkey cannot be empty');
    }

    final queryParams = <String, String>{
      'limit': limit.toString(),
      'sort': sort,
    };
    if (before != null) {
      queryParams['before'] = before.toString();
    }

    final uri = Uri.parse(
      '$_baseUrl/api/users/$pubkey/feed',
    ).replace(queryParameters: queryParams);

    try {
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        final videosData = data['videos'] as List<dynamic>? ?? [];
        final videos = videosData
            .map((v) => VideoStats.fromJson(v as Map<String, dynamic>))
            .where((v) => v.id.isNotEmpty && v.videoUrl.isNotEmpty)
            .toList();

        // Parse pagination cursor (may be string or int)
        final rawCursor = data['next_cursor'];
        final nextCursor = switch (rawCursor) {
          final int value => value,
          final String value => int.tryParse(value),
          _ => null,
        };
        final hasMore = data['has_more'] as bool? ?? false;

        return HomeFeedResponse(
          videos: videos,
          nextCursor: nextCursor,
          hasMore: hasMore,
        );
      } else if (response.statusCode == 404) {
        throw FunnelcakeNotFoundException(
          resource: 'Home feed',
          url: uri.toString(),
        );
      } else {
        throw FunnelcakeApiException(
          message: 'Failed to fetch home feed',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to fetch home feed: $e');
    }
  }

  /// Searches for user profiles by query string.
  ///
  /// [query] is the search term to look for in profile names, display names,
  /// and NIP-05 identifiers.
  /// [limit] is the maximum number of profiles to return (defaults to 50).
  /// [offset] is the number of results to skip for pagination.
  /// [sortBy] optionally sorts results server-side (e.g., 'followers').
  /// [hasVideos] when true, filters to only users who have published videos.
  ///
  /// Returns a list of [ProfileSearchResult] objects.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not configured.
  /// - [FunnelcakeException] if the query is empty.
  /// - [FunnelcakeApiException] if the request fails with a non-success status.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<List<ProfileSearchResult>> searchProfiles({
    required String query,
    int limit = 50,
    int offset = 0,
    String? sortBy,
    bool hasVideos = false,
  }) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      throw const FunnelcakeException('Search query cannot be empty');
    }

    final queryParams = <String, String>{
      'q': trimmedQuery,
      'limit': limit.toString(),
    };
    if (offset > 0) {
      queryParams['offset'] = offset.toString();
    }
    if (sortBy != null) {
      queryParams['sort_by'] = sortBy;
    }
    if (hasVideos) {
      queryParams['has_videos'] = 'true';
    }

    final uri = Uri.parse(
      '$_baseUrl/api/search/profiles',
    ).replace(queryParameters: queryParams);

    try {
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;

        return data
            .map((p) => ProfileSearchResult.fromJson(p as Map<String, dynamic>))
            .where((p) => p.pubkey.isNotEmpty)
            .toList();
      } else {
        throw FunnelcakeApiException(
          message: 'Failed to search profiles',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to search profiles: $e');
    }
  }

  /// Fetches videos where a user is tagged as collaborator.
  ///
  /// [pubkey] is the collaborator's public key (hex format).
  /// [limit] is the maximum number of videos to return
  /// (defaults to 50).
  /// [before] is an optional Unix timestamp cursor for
  /// pagination.
  ///
  /// Returns a list of [VideoStats] objects.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is
  ///   not configured.
  /// - [FunnelcakeNotFoundException] if no collabs found.
  /// - [FunnelcakeApiException] if the request fails.
  /// - [FunnelcakeTimeoutException] on timeout.
  /// - [FunnelcakeException] for other errors.
  Future<List<VideoStats>> getCollabVideos({
    required String pubkey,
    int limit = 50,
    int? before,
  }) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    if (pubkey.isEmpty) {
      throw const FunnelcakeException(
        'Pubkey cannot be empty',
      );
    }

    final queryParams = <String, String>{
      'limit': limit.toString(),
    };
    if (before != null) {
      queryParams['before'] = before.toString();
    }

    final uri = Uri.parse(
      '$_baseUrl/api/users/$pubkey/collabs',
    ).replace(queryParameters: queryParams);

    try {
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;

        return data
            .map(
              (v) => VideoStats.fromJson(
                v as Map<String, dynamic>,
              ),
            )
            .where(
              (v) => v.id.isNotEmpty && v.videoUrl.isNotEmpty,
            )
            .toList();
      } else if (response.statusCode == 404) {
        throw FunnelcakeNotFoundException(
          resource: 'Collab videos',
          url: uri.toString(),
        );
      } else {
        throw FunnelcakeApiException(
          message: 'Failed to fetch collab videos',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException(
        'Failed to fetch collab videos: $e',
      );
    }
  }

  /// Searches for hashtags matching the query.
  ///
  /// [query] is the search term to match against hashtag names.
  /// When null or empty, returns popular hashtags without filtering.
  /// [limit] is the maximum number of hashtags to return (defaults to 20).
  ///
  /// Returns a list of hashtag name strings sorted by popularity/trending.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not configured.
  /// - [FunnelcakeApiException] if the request fails with a non-success status.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<List<String>> searchHashtags({
    String? query,
    int limit = 20,
  }) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    final queryParams = <String, String>{
      'limit': limit.toString(),
      if (query != null && query.isNotEmpty) 'q': query,
    };

    final uri = Uri.parse(
      '$_baseUrl/api/hashtags/trending',
    ).replace(queryParameters: queryParams);

    try {
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;

        return data
            .map((item) {
              if (item is Map<String, dynamic>) {
                return HashtagSearchResult.fromJson(item).tag;
              }
              return item.toString();
            })
            .where((tag) => tag.isNotEmpty)
            .toList();
      } else {
        throw FunnelcakeApiException(
          message: 'Failed to search hashtags',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to search hashtags: $e');
    }
  }

  /// Disposes of the HTTP client if it was created internally.
  void dispose() {
    if (_ownsHttpClient) {
      _httpClient.close();
    }
  }
}
