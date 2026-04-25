// ABOUTME: HTTP client for the Funnelcake REST API (ClickHouse analytics).
// ABOUTME: Provides methods for fetching video data with engagement metrics.

import 'dart:async';
import 'dart:convert';

import 'package:funnelcake_api_client/src/exceptions.dart';
import 'package:funnelcake_api_client/src/models/models.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:models/models.dart';

/// HTTP client for the Funnelcake REST API.
///
/// Funnelcake provides a ClickHouse-backed analytics API that offers
/// faster queries than Nostr relays for video data and engagement metrics.
///
/// **Stateless:** This client has no in-memory caching — every call hits
/// the network. Callers that need request deduplication or stale-while-
/// revalidate behavior should manage that at a higher layer.
///
/// **Errors:** Unlike the legacy analytics service (which often returned
/// empty lists on HTTP failures), this client throws typed subclasses of
/// `FunnelcakeException` (for example `FunnelcakeApiException`,
/// `FunnelcakeTimeoutException`). Call sites should use `try`/`catch`.
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
    String moderationProfile = defaultModerationProfile,
  }) : _baseUrl = baseUrl.endsWith('/')
           ? baseUrl.substring(0, baseUrl.length - 1)
           : baseUrl,
       _httpClient = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null,
       _timeout = timeout,
       _moderationProfile = moderationProfile;

  /// Default moderation profile sent with video-bearing Funnelcake requests.
  static const String defaultModerationProfile = 'default';

  final String _baseUrl;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final Duration _timeout;
  final String _moderationProfile;

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

  Future<http.Response> _post(Uri uri, {required Object body}) {
    return _httpClient
        .post(
          uri,
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'User-Agent': 'OpenVine-Mobile/1.0',
          },
          body: jsonEncode(body),
        )
        .timeout(_timeout);
  }

  Map<String, String> _videoQueryParameters(Map<String, String> params) {
    return <String, String>{
      ...params,
      'nsfw': 'show',
      'moderation_profile': _moderationProfile,
    };
  }

  /// Builds the notifications endpoint URI for a user.
  ///
  /// The returned URI includes the same query parameters used by
  /// [getNotifications] so callers can sign the exact request URL.
  Uri notificationsUri({
    required String pubkey,
    int limit = 50,
    String? cursor,
  }) {
    // Server timestamps are Unix seconds, not milliseconds.
    final effectiveBefore =
        cursor ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final queryParams = <String, String>{
      'limit': '$limit',
      'before': effectiveBefore,
    };

    return Uri.parse(
      '$_baseUrl/api/users/$pubkey/notifications',
    ).replace(queryParameters: queryParams);
  }

  /// Fetches videos by a specific author.
  ///
  /// [pubkey] is the author's public key (hex format).
  /// [limit] is the maximum number of videos to return (defaults to 50).
  /// [offset] is an optional pagination offset.
  /// [before] is an optional Unix timestamp cursor for pagination.
  ///
  /// Returns a [VideosByAuthorResponse] containing a list of [VideoStats]
  /// and an optional `totalCount` parsed from the `X-Total-Count` response
  /// header.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not configured.
  /// - [FunnelcakeNotFoundException] if the author is not found.
  /// - [FunnelcakeApiException] if the request fails with a non-success status.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<VideosByAuthorResponse> getVideosByAuthor({
    required String pubkey,
    int limit = 50,
    int? offset,
    int? before,
  }) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    if (pubkey.isEmpty) {
      throw const FunnelcakeException('Pubkey cannot be empty');
    }

    final queryParams = _videoQueryParameters({'limit': limit.toString()});
    if (offset != null) {
      queryParams['offset'] = offset.toString();
    }
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

        final videos = data
            .map((v) => VideoStats.fromJson(v as Map<String, dynamic>))
            .where((v) => v.id.isNotEmpty && v.videoUrl.isNotEmpty)
            .toList();

        final totalCountHeader = response.headers['x-total-count'];
        final totalCount = totalCountHeader != null
            ? int.tryParse(totalCountHeader)
            : null;

        return VideosByAuthorResponse(
          videos: videos,
          totalCount: totalCount,
        );
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

    final queryParams = _videoQueryParameters({
      'sort': 'trending',
      'limit': limit.toString(),
    });
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

    final queryParams = _videoQueryParameters({
      'sort': 'recent',
      'limit': limit.toString(),
    });
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

    final queryParams = _videoQueryParameters({
      'limit': limit.toString(),
      'sort': sort,
    });
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
          rawBody: before == null ? response.body : null,
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

  /// Fetches confirmed collaborator videos for a user.
  ///
  /// This endpoint is the canonical confirmed collaborator read path. It is not
  /// a raw Nostr p-tag mention search; pending/unconfirmed collaborator tags
  /// should not be surfaced as profile collabs by callers.
  ///
  /// [pubkey] is the confirmed collaborator's public key (hex format).
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
      throw const FunnelcakeException('Pubkey cannot be empty');
    }

    final queryParams = _videoQueryParameters({'limit': limit.toString()});
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
            .map((v) => VideoStats.fromJson(v as Map<String, dynamic>))
            .where((v) => v.id.isNotEmpty && v.videoUrl.isNotEmpty)
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
      throw FunnelcakeException('Failed to fetch collab videos: $e');
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
    int offset = 0,
  }) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    final queryParams = <String, String>{
      'limit': limit.toString(),
      if (offset > 0) 'offset': offset.toString(),
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

  /// Fetches videos sorted by loop count (highest first).
  ///
  /// [limit] is the maximum number of videos to return (defaults to 50).
  /// [before] is an optional Unix timestamp cursor for pagination.
  ///
  /// Returns a list of [VideoStats] objects sorted by loop count.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not configured.
  /// - [FunnelcakeApiException] if the request fails.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<List<VideoStats>> getVideosByLoops({
    int limit = 50,
    int? before,
  }) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    final queryParams = _videoQueryParameters({
      'sort': 'loops',
      'limit': limit.toString(),
    });
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
          message: 'Failed to fetch videos by loops',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to fetch videos by loops: $e');
    }
  }

  /// Fetches videos by hashtag, sorted by trending score.
  ///
  /// [hashtag] is the hashtag to filter by (without `#` prefix).
  /// [limit] is the maximum number of videos to return (defaults to 50).
  /// [before] is an optional Unix timestamp cursor for pagination.
  ///
  /// Returns a list of [VideoStats] objects sorted by trending score.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not configured.
  /// - [FunnelcakeException] if the hashtag is empty.
  /// - [FunnelcakeApiException] if the request fails.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<List<VideoStats>> getVideosByHashtag({
    required String hashtag,
    int limit = 50,
    int? before,
  }) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    final normalizedTag = hashtag.replaceFirst('#', '').toLowerCase();
    if (normalizedTag.isEmpty) {
      throw const FunnelcakeException('Hashtag cannot be empty');
    }

    final queryParams = _videoQueryParameters({
      'tag': normalizedTag,
      'sort': 'trending',
      'limit': limit.toString(),
    });
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
          message: 'Failed to fetch videos by hashtag',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to fetch videos by hashtag: $e');
    }
  }

  /// Fetches classic/all-time-popular videos for a hashtag.
  ///
  /// Uses `sort=loops` to surface classic vines and high-engagement
  /// content sorted by all-time loop count.
  ///
  /// [hashtag] is the hashtag to filter by (without `#` prefix).
  /// [limit] is the maximum number of videos to return (defaults to 50).
  ///
  /// Returns a list of [VideoStats] objects sorted by loop count.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not configured.
  /// - [FunnelcakeException] if the hashtag is empty.
  /// - [FunnelcakeApiException] if the request fails.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<List<VideoStats>> getClassicVideosByHashtag({
    required String hashtag,
    int limit = 50,
  }) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    final normalizedTag = hashtag.replaceFirst('#', '').toLowerCase();
    if (normalizedTag.isEmpty) {
      throw const FunnelcakeException('Hashtag cannot be empty');
    }

    final uri = Uri.parse('$_baseUrl/api/videos').replace(
      queryParameters: _videoQueryParameters({
        'tag': normalizedTag,
        'sort': 'loops',
        'limit': limit.toString(),
      }),
    );

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
          message: 'Failed to fetch classic videos by hashtag',
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
        'Failed to fetch classic videos by hashtag: $e',
      );
    }
  }

  /// Searches videos by text query.
  ///
  /// [query] is the search term.
  /// [limit] is the maximum number of videos to return (defaults to 50).
  ///
  /// Returns a list of [VideoStats] matching the query.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not configured.
  /// - [FunnelcakeException] if the query is empty.
  /// - [FunnelcakeApiException] if the request fails.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<VideoSearchResponse> searchVideos({
    required String query,
    int limit = 50,
    int offset = 0,
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

    final uri = Uri.parse(
      '$_baseUrl/api/search',
    ).replace(queryParameters: queryParams);

    try {
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;

        final videos = data
            .map((v) => VideoStats.fromJson(v as Map<String, dynamic>))
            .where((v) => v.id.isNotEmpty && v.videoUrl.isNotEmpty)
            .toList();

        final totalCount =
            int.tryParse(response.headers['x-total-count'] ?? '') ??
            videos.length;

        return VideoSearchResponse(
          videos: videos,
          totalCount: totalCount,
        );
      } else {
        throw FunnelcakeApiException(
          message: 'Failed to search videos',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to search videos: $e');
    }
  }

  /// Fetches classic vines (imported Vine platform videos).
  ///
  /// [sort] is the sort order: `'loops'` (most viral),
  /// `'trending'`, or `'recent'` (defaults to `'loops'`).
  /// [limit] is the maximum number of videos to return (defaults to 50).
  /// [offset] is the pagination offset for rank-based sorting.
  /// [before] is a Unix timestamp cursor for time-based pagination.
  ///
  /// Returns a list of [VideoStats] objects.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not configured.
  /// - [FunnelcakeApiException] if the request fails.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<List<VideoStats>> getClassicVines({
    String sort = 'loops',
    int limit = 50,
    int offset = 0,
    int? before,
  }) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    final queryParams = _videoQueryParameters({
      'classic': 'true',
      'platform': 'vine',
      'sort': sort,
      'limit': limit.toString(),
    });
    if (sort == 'recent' && before != null) {
      queryParams['before'] = before.toString();
    } else if (offset > 0) {
      queryParams['offset'] = offset.toString();
    }

    final uri = Uri.parse(
      '$_baseUrl/api/videos',
    ).replace(queryParameters: queryParams);

    try {
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        List<dynamic> data;
        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map<String, dynamic>) {
          data =
              (decoded['videos'] ??
                      decoded['data'] ??
                      decoded['results'] ??
                      <dynamic>[])
                  as List<dynamic>;
        } else {
          data = [];
        }

        return data
            .map((v) => VideoStats.fromJson(v as Map<String, dynamic>))
            .where((v) => v.id.isNotEmpty && v.videoUrl.isNotEmpty)
            .toList();
      } else {
        throw FunnelcakeApiException(
          message: 'Failed to fetch classic vines',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to fetch classic vines: $e');
    }
  }

  /// Fetches trending hashtags.
  ///
  /// [limit] is the maximum number of hashtags to return
  /// (defaults to 20).
  ///
  /// Returns a list of [TrendingHashtag] objects sorted by
  /// popularity.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not
  ///   configured.
  /// - [FunnelcakeApiException] if the request fails.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<List<TrendingHashtag>> fetchTrendingHashtags({
    int limit = 20,
  }) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    final uri = Uri.parse(
      '$_baseUrl/api/hashtags',
    ).replace(queryParameters: {'limit': limit.toString()});

    try {
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;

        return data
            .map((h) => TrendingHashtag.fromJson(h as Map<String, dynamic>))
            .where((h) => h.tag.isNotEmpty)
            .toList();
      } else {
        throw FunnelcakeApiException(
          message: 'Failed to fetch trending hashtags',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to fetch trending hashtags: $e');
    }
  }

  /// Fetches stats for a specific video.
  ///
  /// [eventId] is the Nostr event ID for the video.
  ///
  /// Returns a [VideoStats] if found, or `null` if not found.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not
  ///   configured.
  /// - [FunnelcakeException] if the event ID is empty.
  /// - [FunnelcakeApiException] if the request fails.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<VideoStats?> getVideoStats(String eventId) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    if (eventId.isEmpty) {
      throw const FunnelcakeException('Event ID cannot be empty');
    }

    final uri = Uri.parse('$_baseUrl/api/videos/$eventId/stats');

    try {
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return VideoStats.fromJson(data);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw FunnelcakeApiException(
          message: 'Failed to fetch video stats',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to fetch video stats: $e');
    }
  }

  /// Fetches view count for a specific video.
  ///
  /// [eventId] is the Nostr event ID for the video.
  ///
  /// Returns the view count as an `int`. Returns `0` for 404
  /// responses (video has no views yet).
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not
  ///   configured.
  /// - [FunnelcakeException] if the event ID is empty.
  /// - [FunnelcakeApiException] if the request fails.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<int> getVideoViews(String eventId) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    if (eventId.isEmpty) {
      throw const FunnelcakeException('Event ID cannot be empty');
    }

    final uri = Uri.parse('$_baseUrl/api/videos/$eventId/views');

    try {
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          return _parseViewCount(data);
        }
        return 0;
      } else if (response.statusCode == 404) {
        return 0;
      } else {
        throw FunnelcakeApiException(
          message: 'Failed to fetch video views',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to fetch video views: $e');
    }
  }

  /// Fetches paginated comments for a specific video.
  ///
  /// [videoId] accepts either a video event ID or a d-tag supported by
  /// the FunnelCake API.
  ///
  /// Returns a [VideoCommentsResponse] on success, or `null` when the video
  /// is not found.
  Future<VideoCommentsResponse?> getVideoComments({
    required String videoId,
    String sort = 'newest',
    int limit = 25,
    int offset = 0,
  }) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    if (videoId.isEmpty) {
      throw const FunnelcakeException('Video ID cannot be empty');
    }

    final uri =
        Uri.parse(
          '$_baseUrl/api/videos/$videoId/comments',
        ).replace(
          queryParameters: {
            'sort': sort,
            'limit': limit.toString(),
            'offset': offset.toString(),
          },
        );

    try {
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return VideoCommentsResponse.fromJson(data);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw FunnelcakeApiException(
          message: 'Failed to fetch video comments',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to fetch video comments: $e');
    }
  }

  /// Fetches user profile data.
  ///
  /// [pubkey] is the user's public key (hex format).
  ///
  /// Returns [UserProfileFound] if the user has published a Kind 0 profile,
  /// [UserProfileNotPublished] if the user exists in Funnelcake but has never
  /// published one, or `null` if the user is not found at all (404).
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not
  ///   configured.
  /// - [FunnelcakeException] if the pubkey is empty.
  /// - [FunnelcakeApiException] if the request fails.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<UserProfileResult?> getUserProfile(String pubkey) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    if (pubkey.isEmpty) {
      throw const FunnelcakeException('Pubkey cannot be empty');
    }

    final uri = Uri.parse('$_baseUrl/api/users/$pubkey');

    try {
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final profileJson = data['profile'] as Map<String, dynamic>?;
        final socialJson = data['social'] as Map<String, dynamic>?;
        final statsJson = data['stats'] as Map<String, dynamic>?;
        final engagementJson = data['engagement'] as Map<String, dynamic>?;

        final social = socialJson != null
            ? ProfileSocialData.fromJson(socialJson)
            : null;
        final stats = statsJson != null
            ? ProfileStatsData.fromJson(statsJson)
            : null;
        final engagement = engagementJson != null
            ? ProfileEngagementData.fromJson(engagementJson)
            : null;

        if (profileJson != null &&
            (profileJson['name'] != null ||
                profileJson['display_name'] != null)) {
          return UserProfileFound(
            profile: UserProfileData.fromJson(pubkey, profileJson),
            social: social,
            stats: stats,
            engagement: engagement,
          );
        }

        // User exists in Funnelcake but has never published a Kind 0 event.
        return UserProfileNotPublished(
          pubkey: pubkey,
          social: social,
          stats: stats,
          engagement: engagement,
        );
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw FunnelcakeApiException(
          message: 'Failed to fetch user profile',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to fetch user profile: $e');
    }
  }

  /// Fetches social counts (follower/following) for a user.
  ///
  /// [pubkey] is the user's public key (hex format).
  ///
  /// Returns a [SocialCounts] if found, or `null` if not found.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not
  ///   configured.
  /// - [FunnelcakeException] if the pubkey is empty.
  /// - [FunnelcakeApiException] if the request fails.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<SocialCounts?> getSocialCounts(String pubkey) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    if (pubkey.isEmpty) {
      throw const FunnelcakeException('Pubkey cannot be empty');
    }

    final uri = Uri.parse('$_baseUrl/api/users/$pubkey/social');

    try {
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return SocialCounts.fromJson(data);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw FunnelcakeApiException(
          message: 'Failed to fetch social counts',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to fetch social counts: $e');
    }
  }

  /// Fetches a paginated list of followers for a user.
  ///
  /// [pubkey] is the user's public key (hex format).
  /// [limit] is the maximum number of results (defaults to 100).
  /// [offset] is the pagination offset (defaults to 0).
  ///
  /// Returns a [PaginatedPubkeys] with follower pubkeys.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not
  ///   configured.
  /// - [FunnelcakeException] if the pubkey is empty.
  /// - [FunnelcakeNotFoundException] if not found.
  /// - [FunnelcakeApiException] if the request fails.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<PaginatedPubkeys> getFollowers({
    required String pubkey,
    int limit = 100,
    int offset = 0,
  }) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    if (pubkey.isEmpty) {
      throw const FunnelcakeException('Pubkey cannot be empty');
    }

    final queryParams = <String, String>{'limit': limit.toString()};
    if (offset > 0) {
      queryParams['offset'] = offset.toString();
    }

    final uri = Uri.parse(
      '$_baseUrl/api/users/$pubkey/followers',
    ).replace(queryParameters: queryParams);

    try {
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return PaginatedPubkeys.fromJson(data);
      } else if (response.statusCode == 404) {
        throw FunnelcakeNotFoundException(
          resource: 'Followers',
          url: uri.toString(),
        );
      } else {
        throw FunnelcakeApiException(
          message: 'Failed to fetch followers',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to fetch followers: $e');
    }
  }

  /// Fetches a paginated list of users that a user follows.
  ///
  /// [pubkey] is the user's public key (hex format).
  /// [limit] is the maximum number of results (defaults to 100).
  /// [offset] is the pagination offset (defaults to 0).
  ///
  /// Returns a [PaginatedPubkeys] with following pubkeys.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not
  ///   configured.
  /// - [FunnelcakeException] if the pubkey is empty.
  /// - [FunnelcakeNotFoundException] if not found.
  /// - [FunnelcakeApiException] if the request fails.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<PaginatedPubkeys> getFollowing({
    required String pubkey,
    int limit = 100,
    int offset = 0,
  }) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    if (pubkey.isEmpty) {
      throw const FunnelcakeException('Pubkey cannot be empty');
    }

    final queryParams = <String, String>{'limit': limit.toString()};
    if (offset > 0) {
      queryParams['offset'] = offset.toString();
    }

    final uri = Uri.parse(
      '$_baseUrl/api/users/$pubkey/following',
    ).replace(queryParameters: queryParams);

    try {
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return PaginatedPubkeys.fromJson(data);
      } else if (response.statusCode == 404) {
        throw FunnelcakeNotFoundException(
          resource: 'Following',
          url: uri.toString(),
        );
      } else {
        throw FunnelcakeApiException(
          message: 'Failed to fetch following',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to fetch following: $e');
    }
  }

  /// Fetches personalized video recommendations for a user.
  ///
  /// [pubkey] is the user's public key (hex format).
  /// [limit] is the maximum number of videos (defaults to 20).
  /// [fallback] is the strategy when personalization is unavailable
  /// (`'popular'` or `'recent'`, defaults to `'popular'`).
  /// [category] is an optional hashtag/category filter.
  ///
  /// Returns a [RecommendationsResponse] with videos and source.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not
  ///   configured.
  /// - [FunnelcakeException] if the pubkey is empty.
  /// - [FunnelcakeNotFoundException] if the endpoint is not
  ///   deployed.
  /// - [FunnelcakeApiException] if the request fails.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<RecommendationsResponse> getRecommendations({
    required String pubkey,
    int limit = 20,
    String fallback = 'popular',
    String? category,
  }) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    if (pubkey.isEmpty) {
      throw const FunnelcakeException('Pubkey cannot be empty');
    }

    final queryParams = <String, String>{
      'limit': limit.toString(),
      'fallback': fallback,
    };
    if (category != null && category.isNotEmpty) {
      queryParams['category'] = category;
    }

    final uri = Uri.parse(
      '$_baseUrl/api/users/$pubkey/recommendations',
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

        final source = data['source'] as String? ?? 'unknown';

        return RecommendationsResponse(videos: videos, source: source);
      } else if (response.statusCode == 404) {
        throw FunnelcakeNotFoundException(
          resource: 'Recommendations',
          url: uri.toString(),
        );
      } else {
        throw FunnelcakeApiException(
          message: 'Failed to fetch recommendations',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to fetch recommendations: $e');
    }
  }

  /// Fetches multiple user profiles in bulk.
  ///
  /// [pubkeys] is the list of public keys to fetch.
  ///
  /// Returns a [BulkProfilesResponse] with a map of pubkey to
  /// [UserProfileResult]. Users that exist but have no Kind 0 profile are
  /// included as [UserProfileNotPublished] entries.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not
  ///   configured.
  /// - [FunnelcakeException] if pubkeys list is empty.
  /// - [FunnelcakeApiException] if the request fails.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<BulkProfilesResponse> getBulkProfiles(List<String> pubkeys) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    if (pubkeys.isEmpty) {
      throw const FunnelcakeException('Pubkeys list cannot be empty');
    }

    final uri = Uri.parse('$_baseUrl/api/users/bulk');

    try {
      final response = await _post(uri, body: {'pubkeys': pubkeys});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final usersData = data['users'] as List<dynamic>? ?? [];

        final result = <String, UserProfileResult>{};
        for (final user in usersData) {
          if (user is Map<String, dynamic>) {
            final pubkey = user['pubkey']?.toString();
            if (pubkey == null || pubkey.isEmpty) continue;

            final profileJson = user['profile'] as Map<String, dynamic>?;
            final socialJson = user['social'] as Map<String, dynamic>?;
            final statsJson = user['stats'] as Map<String, dynamic>?;
            final engagementJson = user['engagement'] as Map<String, dynamic>?;

            final social = socialJson != null
                ? ProfileSocialData.fromJson(socialJson)
                : null;
            final stats = statsJson != null
                ? ProfileStatsData.fromJson(statsJson)
                : null;
            final engagement = engagementJson != null
                ? ProfileEngagementData.fromJson(engagementJson)
                : null;

            if (profileJson != null &&
                (profileJson['name'] != null ||
                    profileJson['display_name'] != null)) {
              result[pubkey] = UserProfileFound(
                profile: UserProfileData.fromJson(pubkey, profileJson),
                social: social,
                stats: stats,
                engagement: engagement,
              );
            } else {
              // User exists in Funnelcake but has no Kind 0 profile event.
              result[pubkey] = UserProfileNotPublished(
                pubkey: pubkey,
                social: social,
                stats: stats,
                engagement: engagement,
              );
            }
          }
        }

        return BulkProfilesResponse(profiles: result);
      } else {
        throw FunnelcakeApiException(
          message: 'Failed to fetch bulk profiles',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to fetch bulk profiles: $e');
    }
  }

  /// Fetches video stats for multiple videos in bulk.
  ///
  /// [eventIds] is the list of Nostr event IDs to fetch stats for.
  ///
  /// Returns a [BulkVideoStatsResponse] with a map of event ID to
  /// stats.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not
  ///   configured.
  /// - [FunnelcakeException] if eventIds list is empty.
  /// - [FunnelcakeApiException] if the request fails.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<BulkVideoStatsResponse> getBulkVideoStats(
    List<String> eventIds,
  ) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    if (eventIds.isEmpty) {
      throw const FunnelcakeException('Event IDs list cannot be empty');
    }

    final uri = Uri.parse('$_baseUrl/api/videos/stats/bulk');

    try {
      final response = await _post(uri, body: {'event_ids': eventIds});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final result = <String, BulkVideoStatsEntry>{};
        final statsData = data['stats'];

        if (statsData is List) {
          for (final stat in statsData) {
            if (stat is Map) {
              final statMap = Map<String, dynamic>.from(stat);
              final entry = BulkVideoStatsEntry.fromJson(statMap);
              if (entry.eventId.isNotEmpty) {
                result[entry.eventId] = entry;
              }
            }
          }
        } else if (statsData is Map) {
          for (final mapEntry in statsData.entries) {
            final eventId = mapEntry.key.toString();
            final value = mapEntry.value;
            if (value is Map) {
              final statMap = Map<String, dynamic>.from(value);
              final entry = BulkVideoStatsEntry.fromJson({
                'event_id': statMap['event_id'] ?? eventId,
                ...statMap,
              });
              if (entry.eventId.isNotEmpty) {
                result[entry.eventId] = entry;
              }
            }
          }
        }

        return BulkVideoStatsResponse(stats: result);
      } else {
        throw FunnelcakeApiException(
          message: 'Failed to fetch bulk video stats',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to fetch bulk video stats: $e');
    }
  }

  /// Fetches content categories with video counts.
  ///
  /// [limit] is the maximum number of categories (defaults to 50).
  /// [offset] is the pagination offset (defaults to 0).
  /// [query] is an optional case-insensitive substring filter.
  ///
  /// Returns a list of [VideoCategory] objects.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not configured.
  /// - [FunnelcakeApiException] if the request fails.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<List<VideoCategory>> getCategories({
    int limit = 50,
    int offset = 0,
    String? query,
  }) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    final queryParams = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (query != null && query.isNotEmpty) {
      queryParams['q'] = query;
    }

    final uri = Uri.parse(
      '$_baseUrl/api/categories',
    ).replace(queryParameters: queryParams);

    try {
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        return data
            .map((item) => VideoCategory.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        throw FunnelcakeApiException(
          message: 'Failed to fetch categories',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to fetch categories: $e');
    }
  }

  /// Fetches videos filtered by category.
  ///
  /// [category] is the category name (e.g., "music", "comedy").
  /// [limit] is the maximum number of videos (defaults to 50).
  /// [before] is an optional Unix timestamp cursor for pagination.
  /// [sort] is the sort order (defaults to "trending").
  ///
  /// Returns a list of [VideoStats] objects.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not configured.
  /// - [FunnelcakeException] if the category is empty.
  /// - [FunnelcakeApiException] if the request fails.
  /// - [FunnelcakeTimeoutException] if the request times out.
  /// - [FunnelcakeException] for other errors.
  Future<List<VideoStats>> getVideosByCategory({
    required String category,
    int limit = 50,
    int? before,
    String sort = 'trending',
    String? platform,
  }) async {
    if (!isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }

    if (category.isEmpty) {
      throw const FunnelcakeException('Category cannot be empty');
    }

    final queryParams = _videoQueryParameters({
      'category': category.toLowerCase(),
      'sort': sort,
      'limit': limit.toString(),
    });
    if (before != null) {
      queryParams['before'] = before.toString();
    }
    if (platform != null) {
      queryParams['platform'] = platform;
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
          message: 'Failed to fetch videos by category',
          statusCode: response.statusCode,
          url: uri.toString(),
        );
      }
    } on TimeoutException {
      throw FunnelcakeTimeoutException(uri.toString());
    } on FunnelcakeException {
      rethrow;
    } catch (e) {
      throw FunnelcakeException('Failed to fetch videos by category: $e');
    }
  }

  /// Fetches notifications for a user from the relay REST API.
  ///
  /// Uses NIP-98 authentication. The [cursor] parameter enables pagination
  /// via the `before` query param. The [authHeaders] parameter allows the
  /// caller to provide pre-built NIP-98 auth headers.
  ///
  /// Returns an empty [NotificationResponse] on errors instead of throwing.
  Future<NotificationResponse> getNotifications({
    required String pubkey,
    int limit = 50,
    String? cursor,
    Uri? requestUri,
    Map<String, String>? authHeaders,
  }) async {
    final url =
        requestUri ??
        notificationsUri(
          pubkey: pubkey,
          limit: limit,
          cursor: cursor,
        );

    try {
      final response = await _httpClient
          .get(
            url,
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'OpenVine-Mobile/1.0',
              ...?authHeaders,
            },
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        return const NotificationResponse(
          notifications: [],
          unreadCount: 0,
          hasMore: false,
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return NotificationResponse.fromJson(json);
    } on Object {
      return const NotificationResponse(
        notifications: [],
        unreadCount: 0,
        hasMore: false,
      );
    }
  }

  /// Marks notifications as read for a user.
  ///
  /// Pass [notificationIds] to mark specific notifications, or omit to
  /// mark all as read. The [authHeaders] parameter allows the caller to
  /// provide pre-built NIP-98 auth headers.
  ///
  /// Returns a failure [MarkReadResponse] on errors instead of throwing.
  Future<MarkReadResponse> markNotificationsRead({
    required String pubkey,
    List<String>? notificationIds,
    Map<String, String>? authHeaders,
  }) async {
    final url = Uri.parse('$_baseUrl/api/users/$pubkey/notifications/read');

    final payload = jsonEncode({
      'notification_ids': ?notificationIds,
    });

    try {
      final response = await _httpClient
          .post(
            url,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'User-Agent': 'OpenVine-Mobile/1.0',
              ...?authHeaders,
            },
            body: payload,
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        return const MarkReadResponse(success: false, markedCount: 0);
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return MarkReadResponse.fromJson(json);
    } on Object {
      return const MarkReadResponse(success: false, markedCount: 0);
    }
  }

  /// Disposes of the HTTP client if it was created internally.
  void dispose() {
    if (_ownsHttpClient) {
      _httpClient.close();
    }
  }
}

/// Parses a dynamic value to int for view count extraction.
int _parseViewCount(Map<String, dynamic> data) {
  final views =
      data['views'] ??
      data['view_count'] ??
      data['total_views'] ??
      data['unique_views'] ??
      data['unique_viewers'];
  if (views is int) return views;
  if (views is num) return views.toInt();
  if (views is String) return int.tryParse(views) ?? 0;
  return 0;
}
