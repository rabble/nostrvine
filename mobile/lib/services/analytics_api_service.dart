// ABOUTME: Service for interacting with Funnelcake REST API (ClickHouse-backed analytics)
// ABOUTME: Handles trending videos, hashtag search, and video stats from funnelcake relay

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/utils/hashtag_extractor.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Funnelcake API video stats response model
class VideoStats {
  final String id;
  final String pubkey;
  final DateTime createdAt;
  final int kind;
  final String dTag;
  final String title;
  final String thumbnail;
  final String videoUrl;
  final int reactions;
  final int comments;
  final int reposts;
  final int engagementScore;
  final double? trendingScore;

  VideoStats({
    required this.id,
    required this.pubkey,
    required this.createdAt,
    required this.kind,
    required this.dTag,
    required this.title,
    required this.thumbnail,
    required this.videoUrl,
    required this.reactions,
    required this.comments,
    required this.reposts,
    required this.engagementScore,
    this.trendingScore,
  });

  factory VideoStats.fromJson(Map<String, dynamic> json) {
    // Parse id - funnelcake returns as byte array (ASCII codes), not string
    String id;
    if (json['id'] is List) {
      id = String.fromCharCodes((json['id'] as List).cast<int>());
    } else {
      id = json['id']?.toString() ?? '';
    }

    // Parse pubkey - same format as id
    String pubkey;
    if (json['pubkey'] is List) {
      pubkey = String.fromCharCodes((json['pubkey'] as List).cast<int>());
    } else {
      pubkey = json['pubkey']?.toString() ?? '';
    }

    // Parse created_at - funnelcake returns Unix timestamp (int), not ISO string
    DateTime createdAt;
    if (json['created_at'] is int) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(
        (json['created_at'] as int) * 1000,
      );
    } else if (json['created_at'] is String) {
      createdAt = DateTime.tryParse(json['created_at']) ?? DateTime.now();
    } else {
      createdAt = DateTime.now();
    }

    return VideoStats(
      id: id,
      pubkey: pubkey,
      createdAt: createdAt,
      kind: json['kind'] ?? 34236,
      dTag: json['d_tag']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      thumbnail: json['thumbnail']?.toString() ?? '',
      videoUrl: json['video_url']?.toString() ?? '',
      reactions: json['reactions'] ?? 0,
      comments: json['comments'] ?? 0,
      reposts: json['reposts'] ?? 0,
      engagementScore: json['engagement_score'] ?? 0,
      trendingScore: json['trending_score']?.toDouble(),
    );
  }

  /// Convert to VideoEvent for use in the app
  VideoEvent toVideoEvent() {
    return VideoEvent(
      id: id,
      pubkey: pubkey,
      createdAt: createdAt.millisecondsSinceEpoch ~/ 1000,
      content: '',
      timestamp: createdAt,
      title: title.isNotEmpty ? title : null,
      videoUrl: videoUrl.isNotEmpty ? videoUrl : null,
      thumbnailUrl: thumbnail.isNotEmpty ? thumbnail : null,
      vineId: dTag.isNotEmpty ? dTag : null,
      originalLikes: reactions,
      originalComments: comments,
      originalReposts: reposts,
    );
  }
}

class TrendingHashtag {
  final String tag;
  final int videoCount;
  final int uniqueCreators;
  final int totalLoops;
  final DateTime? lastUsed;

  TrendingHashtag({
    required this.tag,
    required this.videoCount,
    this.uniqueCreators = 0,
    this.totalLoops = 0,
    this.lastUsed,
  });

  factory TrendingHashtag.fromJson(Map<String, dynamic> json) {
    // Parse last_used timestamp
    DateTime? lastUsed;
    if (json['last_used'] != null) {
      if (json['last_used'] is int) {
        lastUsed = DateTime.fromMillisecondsSinceEpoch(
          (json['last_used'] as int) * 1000,
        );
      } else if (json['last_used'] is String) {
        lastUsed = DateTime.tryParse(json['last_used'] as String);
      }
    }

    return TrendingHashtag(
      tag: json['hashtag'] ?? json['tag'] ?? '',
      videoCount: json['video_count'] ?? json['videoCount'] ?? 0,
      uniqueCreators: json['unique_creators'] ?? json['uniqueCreators'] ?? 0,
      totalLoops: json['total_loops'] ?? json['totalLoops'] ?? 0,
      lastUsed: lastUsed,
    );
  }
}

/// Sort options for funnelcake video API
enum VideoSortOption {
  recent('recent'),
  trending('trending');

  const VideoSortOption(this.value);
  final String value;
}

/// Service for Funnelcake REST API interactions
///
/// Funnelcake provides pre-computed trending scores and analytics
/// backed by ClickHouse for efficient video discovery queries.
class AnalyticsApiService {
  static const Duration cacheTimeout = Duration(minutes: 5);

  final String? _baseUrl;
  final http.Client _httpClient;

  // Cache for API responses
  List<VideoStats> _trendingVideosCache = [];
  List<VideoStats> _recentVideosCache = [];
  List<TrendingHashtag> _trendingHashtagsCache = [];
  DateTime? _lastTrendingVideosFetch;
  DateTime? _lastRecentVideosFetch;
  DateTime? _lastTrendingHashtagsFetch;

  // Cache for hashtag search results
  final Map<String, List<VideoStats>> _hashtagSearchCache = {};
  final Map<String, DateTime> _hashtagSearchCacheTime = {};

  AnalyticsApiService({required String? baseUrl, http.Client? httpClient})
    : _baseUrl = baseUrl,
      _httpClient = httpClient ?? http.Client();

  /// Whether the API is available (has a configured base URL)
  bool get isAvailable => _baseUrl != null && _baseUrl.isNotEmpty;

  /// Fetch trending videos sorted by engagement score
  ///
  /// Uses funnelcake's pre-computed trending scores for efficient discovery.
  /// Returns VideoEvent objects ready for display.
  Future<List<VideoEvent>> getTrendingVideos({
    int limit = 50,
    bool forceRefresh = false,
  }) async {
    if (!isAvailable) {
      Log.warning(
        'Funnelcake API not available (no base URL configured)',
        name: 'AnalyticsApiService',
        category: LogCategory.video,
      );
      return [];
    }

    // Check cache
    if (!forceRefresh &&
        _lastTrendingVideosFetch != null &&
        DateTime.now().difference(_lastTrendingVideosFetch!) < cacheTimeout &&
        _trendingVideosCache.isNotEmpty) {
      Log.debug(
        'Using cached trending videos (${_trendingVideosCache.length} items)',
        name: 'AnalyticsApiService',
        category: LogCategory.video,
      );
      return _trendingVideosCache.map((v) => v.toVideoEvent()).toList();
    }

    try {
      final url = '$_baseUrl/api/videos?sort=trending&limit=$limit';
      Log.info(
        'Fetching trending videos from Funnelcake: $url',
        name: 'AnalyticsApiService',
        category: LogCategory.video,
      );

      final response = await _httpClient
          .get(
            Uri.parse(url),
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'OpenVine-Mobile/1.0',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        Log.info(
          'Received ${data.length} trending videos from Funnelcake',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );

        _trendingVideosCache = data
            .map((v) => VideoStats.fromJson(v as Map<String, dynamic>))
            .where((v) => v.id.isNotEmpty && v.videoUrl.isNotEmpty)
            .toList();

        _lastTrendingVideosFetch = DateTime.now();

        Log.info(
          'Returning ${_trendingVideosCache.length} trending videos',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );

        return _trendingVideosCache.map((v) => v.toVideoEvent()).toList();
      } else {
        Log.error(
          'Funnelcake API error: ${response.statusCode}',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );
        Log.error(
          '   URL: $url',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );
        return [];
      }
    } catch (e) {
      Log.error(
        'Error fetching trending videos: $e',
        name: 'AnalyticsApiService',
        category: LogCategory.video,
      );
      return [];
    }
  }

  /// Fetch recent videos (newest first)
  Future<List<VideoEvent>> getRecentVideos({
    int limit = 50,
    bool forceRefresh = false,
  }) async {
    if (!isAvailable) return [];

    // Check cache
    if (!forceRefresh &&
        _lastRecentVideosFetch != null &&
        DateTime.now().difference(_lastRecentVideosFetch!) < cacheTimeout &&
        _recentVideosCache.isNotEmpty) {
      Log.debug(
        'Using cached recent videos (${_recentVideosCache.length} items)',
        name: 'AnalyticsApiService',
        category: LogCategory.video,
      );
      return _recentVideosCache.map((v) => v.toVideoEvent()).toList();
    }

    try {
      final url = '$_baseUrl/api/videos?sort=recent&limit=$limit';
      Log.info(
        'Fetching recent videos from Funnelcake: $url',
        name: 'AnalyticsApiService',
        category: LogCategory.video,
      );

      final response = await _httpClient
          .get(
            Uri.parse(url),
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'OpenVine-Mobile/1.0',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        _recentVideosCache = data
            .map((v) => VideoStats.fromJson(v as Map<String, dynamic>))
            .where((v) => v.id.isNotEmpty && v.videoUrl.isNotEmpty)
            .toList();

        _lastRecentVideosFetch = DateTime.now();

        Log.info(
          'Returning ${_recentVideosCache.length} recent videos',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );

        return _recentVideosCache.map((v) => v.toVideoEvent()).toList();
      } else {
        Log.error(
          'Funnelcake API error: ${response.statusCode}',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );
        return [];
      }
    } catch (e) {
      Log.error(
        'Error fetching recent videos: $e',
        name: 'AnalyticsApiService',
        category: LogCategory.video,
      );
      return [];
    }
  }

  /// Search videos by hashtag
  ///
  /// Uses funnelcake's /api/search?tag= endpoint for hashtag discovery.
  Future<List<VideoEvent>> getVideosByHashtag({
    required String hashtag,
    int limit = 50,
    bool forceRefresh = false,
  }) async {
    if (!isAvailable) return [];

    // Normalize hashtag (remove # if present, lowercase)
    final normalizedTag = hashtag.replaceFirst('#', '').toLowerCase();

    // Check cache
    final cacheKey = normalizedTag;
    final cachedTime = _hashtagSearchCacheTime[cacheKey];
    if (!forceRefresh &&
        cachedTime != null &&
        DateTime.now().difference(cachedTime) < cacheTimeout &&
        _hashtagSearchCache.containsKey(cacheKey)) {
      Log.debug(
        'Using cached hashtag search for #$normalizedTag',
        name: 'AnalyticsApiService',
        category: LogCategory.video,
      );
      return _hashtagSearchCache[cacheKey]!
          .map((v) => v.toVideoEvent())
          .toList();
    }

    try {
      final url = '$_baseUrl/api/search?tag=$normalizedTag&limit=$limit';
      Log.info(
        'Searching videos by hashtag from Funnelcake: $url',
        name: 'AnalyticsApiService',
        category: LogCategory.video,
      );

      final response = await _httpClient
          .get(
            Uri.parse(url),
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'OpenVine-Mobile/1.0',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        final videos = data
            .map((v) => VideoStats.fromJson(v as Map<String, dynamic>))
            .where((v) => v.id.isNotEmpty && v.videoUrl.isNotEmpty)
            .toList();

        // Cache results
        _hashtagSearchCache[cacheKey] = videos;
        _hashtagSearchCacheTime[cacheKey] = DateTime.now();

        Log.info(
          'Found ${videos.length} videos for #$normalizedTag',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );

        return videos.map((v) => v.toVideoEvent()).toList();
      } else {
        Log.error(
          'Hashtag search failed: ${response.statusCode}',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );
        return [];
      }
    } catch (e) {
      Log.error(
        'Error searching by hashtag: $e',
        name: 'AnalyticsApiService',
        category: LogCategory.video,
      );
      return [];
    }
  }

  /// Search videos by text query
  ///
  /// Uses funnelcake's /api/search?q= endpoint for full-text search.
  Future<List<VideoEvent>> searchVideos({
    required String query,
    int limit = 50,
  }) async {
    if (!isAvailable || query.trim().isEmpty) return [];

    try {
      final encodedQuery = Uri.encodeQueryComponent(query.trim());
      final url = '$_baseUrl/api/search?q=$encodedQuery&limit=$limit';
      Log.info(
        'Searching videos from Funnelcake: $url',
        name: 'AnalyticsApiService',
        category: LogCategory.video,
      );

      final response = await _httpClient
          .get(
            Uri.parse(url),
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'OpenVine-Mobile/1.0',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        final videos = data
            .map((v) => VideoStats.fromJson(v as Map<String, dynamic>))
            .where((v) => v.id.isNotEmpty && v.videoUrl.isNotEmpty)
            .toList();

        Log.info(
          'Found ${videos.length} videos for query "$query"',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );

        return videos.map((v) => v.toVideoEvent()).toList();
      } else {
        Log.error(
          'Search failed: ${response.statusCode}',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );
        return [];
      }
    } catch (e) {
      Log.error(
        'Error searching videos: $e',
        name: 'AnalyticsApiService',
        category: LogCategory.video,
      );
      return [];
    }
  }

  /// Get stats for a specific video
  Future<VideoStats?> getVideoStats(String eventId) async {
    if (!isAvailable || eventId.isEmpty) return null;

    try {
      final url = '$_baseUrl/api/videos/$eventId/stats';
      Log.debug(
        'Fetching video stats from Funnelcake: $url',
        name: 'AnalyticsApiService',
        category: LogCategory.video,
      );

      final response = await _httpClient
          .get(
            Uri.parse(url),
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'OpenVine-Mobile/1.0',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return VideoStats.fromJson(data);
      } else {
        Log.warning(
          'Video stats not found: ${response.statusCode}',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );
        return null;
      }
    } catch (e) {
      Log.error(
        'Error fetching video stats: $e',
        name: 'AnalyticsApiService',
        category: LogCategory.video,
      );
      return null;
    }
  }

  /// Get videos by a specific author
  Future<List<VideoEvent>> getVideosByAuthor({
    required String pubkey,
    int limit = 50,
  }) async {
    if (!isAvailable || pubkey.isEmpty) return [];

    try {
      final url = '$_baseUrl/api/users/$pubkey/videos?limit=$limit';
      Log.info(
        'Fetching author videos from Funnelcake: $url',
        name: 'AnalyticsApiService',
        category: LogCategory.video,
      );

      final response = await _httpClient
          .get(
            Uri.parse(url),
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'OpenVine-Mobile/1.0',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        final videos = data
            .map((v) => VideoStats.fromJson(v as Map<String, dynamic>))
            .where((v) => v.id.isNotEmpty && v.videoUrl.isNotEmpty)
            .toList();

        Log.info(
          'Found ${videos.length} videos for author',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );

        return videos.map((v) => v.toVideoEvent()).toList();
      } else {
        Log.error(
          'Author videos failed: ${response.statusCode}',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );
        return [];
      }
    } catch (e) {
      Log.error(
        'Error fetching author videos: $e',
        name: 'AnalyticsApiService',
        category: LogCategory.video,
      );
      return [];
    }
  }

  /// Fetch trending hashtags from funnelcake /api/hashtags endpoint
  ///
  /// Returns popular hashtags sorted by total video count (most-used first).
  /// Falls back to static defaults if API is unavailable.
  Future<List<TrendingHashtag>> fetchTrendingHashtags({
    int limit = 20,
    bool forceRefresh = false,
  }) async {
    if (!isAvailable) {
      Log.warning(
        'Funnelcake API not available, using default hashtags',
        name: 'AnalyticsApiService',
        category: LogCategory.video,
      );
      return _getDefaultHashtags(limit);
    }

    // Check cache
    if (!forceRefresh &&
        _lastTrendingHashtagsFetch != null &&
        DateTime.now().difference(_lastTrendingHashtagsFetch!) < cacheTimeout &&
        _trendingHashtagsCache.isNotEmpty) {
      Log.debug(
        'Using cached trending hashtags (${_trendingHashtagsCache.length} items)',
        name: 'AnalyticsApiService',
        category: LogCategory.video,
      );
      return _trendingHashtagsCache.take(limit).toList();
    }

    try {
      final url = '$_baseUrl/api/hashtags?limit=$limit';
      Log.info(
        'Fetching trending hashtags from Funnelcake: $url',
        name: 'AnalyticsApiService',
        category: LogCategory.video,
      );

      final response = await _httpClient
          .get(
            Uri.parse(url),
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'OpenVine-Mobile/1.0',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        Log.info(
          'Received ${data.length} trending hashtags from Funnelcake',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );

        _trendingHashtagsCache = data
            .map((h) => TrendingHashtag.fromJson(h as Map<String, dynamic>))
            .where((h) => h.tag.isNotEmpty)
            .toList();

        _lastTrendingHashtagsFetch = DateTime.now();

        return _trendingHashtagsCache;
      } else {
        Log.warning(
          'Funnelcake hashtags API error: ${response.statusCode}, using defaults',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );
        return _getDefaultHashtags(limit);
      }
    } catch (e) {
      Log.warning(
        'Error fetching trending hashtags: $e, using defaults',
        name: 'AnalyticsApiService',
        category: LogCategory.video,
      );
      return _getDefaultHashtags(limit);
    }
  }

  /// Get default trending hashtags as fallback when API is unavailable
  List<TrendingHashtag> _getDefaultHashtags(int limit) {
    final defaultTags = HashtagExtractor.suggestedHashtags.take(limit).toList();

    Log.debug(
      'Using ${defaultTags.length} default trending hashtags',
      name: 'AnalyticsApiService',
      category: LogCategory.video,
    );

    return defaultTags.asMap().entries.map((entry) {
      final index = entry.key;
      final tag = entry.value;
      return TrendingHashtag(tag: tag, videoCount: 50 - (index * 2));
    }).toList();
  }

  /// Get trending hashtags synchronously (returns cached or defaults)
  ///
  /// This is a synchronous method for use in providers that need immediate
  /// results. Returns cached hashtags if available, otherwise defaults.
  /// Call [fetchTrendingHashtags] to refresh from the API.
  List<TrendingHashtag> getTrendingHashtags({int limit = 25}) {
    if (_trendingHashtagsCache.isNotEmpty) {
      return _trendingHashtagsCache.take(limit).toList();
    }
    return _getDefaultHashtags(limit);
  }

  /// Clear all caches
  void clearCache() {
    _trendingVideosCache.clear();
    _recentVideosCache.clear();
    _trendingHashtagsCache.clear();
    _hashtagSearchCache.clear();
    _hashtagSearchCacheTime.clear();
    _lastTrendingVideosFetch = null;
    _lastRecentVideosFetch = null;
    _lastTrendingHashtagsFetch = null;

    Log.info(
      'Cleared all Funnelcake API cache',
      name: 'AnalyticsApiService',
      category: LogCategory.system,
    );
  }

  /// Dispose of resources
  void dispose() {
    clearCache();
    _httpClient.close();
  }
}
