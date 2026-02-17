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
  final int? publishedAt;
  final int kind;
  final String dTag;
  final String title;
  final String? description; // Video description from event.content (NIP-71)
  final String thumbnail;
  final String videoUrl;
  final String? sha256; // Content hash for Blossom authentication
  final String? authorName; // Display name of classic Vine author
  final String? authorAvatar; // Profile picture URL for author
  final String? blurhash; // Blurhash for placeholder thumbnail
  final int reactions;
  final int comments;
  final int reposts;
  final int engagementScore;
  final double? trendingScore;
  final int? loops; // Original loop count for classic Vines
  final int? views; // Live/new views from Funnelcake analytics

  VideoStats({
    required this.id,
    required this.pubkey,
    required this.createdAt,
    this.publishedAt,
    required this.kind,
    required this.dTag,
    required this.title,
    this.description,
    required this.thumbnail,
    required this.videoUrl,
    this.sha256,
    this.authorName,
    this.authorAvatar,
    this.blurhash,
    required this.reactions,
    required this.comments,
    required this.reposts,
    required this.engagementScore,
    this.trendingScore,
    this.loops,
    this.views,
  });

  factory VideoStats.fromJson(Map<String, dynamic> json) {
    // Handle nested format: { "event": {...}, "stats": {...} }
    final eventData = json['event'] as Map<String, dynamic>? ?? json;
    final statsData = json['stats'] as Map<String, dynamic>? ?? json;

    // Parse id - funnelcake returns as byte array (ASCII codes), not string
    String id;
    final rawId = eventData['id'];
    if (rawId is List) {
      id = String.fromCharCodes(rawId.cast<int>());
    } else {
      id = rawId?.toString() ?? '';
    }
    // Normalize to lowercase per NIP-01 (Funnelcake may return uppercase hex)
    id = id.toLowerCase();

    // Parse pubkey - same format as id
    String pubkey;
    final rawPubkey = eventData['pubkey'];
    if (rawPubkey is List) {
      pubkey = String.fromCharCodes(rawPubkey.cast<int>());
    } else {
      pubkey = rawPubkey?.toString() ?? '';
    }
    // Normalize to lowercase per NIP-01 (Funnelcake may return uppercase hex)
    pubkey = pubkey.toLowerCase();

    // Parse created_at - funnelcake returns Unix timestamp (int), not ISO string
    DateTime createdAt;
    final rawCreatedAt = eventData['created_at'];
    if (rawCreatedAt is int) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(rawCreatedAt * 1000);
    } else if (rawCreatedAt is String) {
      createdAt = DateTime.tryParse(rawCreatedAt) ?? DateTime.now();
    } else {
      createdAt = DateTime.now();
    }

    // Parse loops from multiple possible sources:
    // 1. Direct field in stats or root
    // 2. From event tags array (["loops", "12345"])
    int? loops = findIntDeep(json, {
      'loops',
      'loop_count',
      'original_loops',
      'total_loops',
      'embedded_loops',
      'computed_loops',
    });

    // Also check event tags for loops if not found directly
    if (loops == null && eventData['tags'] is List) {
      final tags = eventData['tags'] as List;
      for (final tag in tags) {
        if (tag is List && tag.length >= 2 && tag[0] == 'loops') {
          loops = int.tryParse(tag[1].toString());
          break;
        }
      }
    }

    // Parse view counts (new/live loop activity in Funnelcake).
    int? views = findIntDeep(json, {
      'views',
      'view_count',
      'total_views',
      'unique_views',
      'unique_viewers',
    });

    // Also check event tags for views if not found directly.
    if (views == null && eventData['tags'] is List) {
      final tags = eventData['tags'] as List;
      for (final tag in tags) {
        if (tag is List && tag.length >= 2 && tag[0] == 'views') {
          views = int.tryParse(tag[1].toString());
          break;
        }
      }
    }

    // Extract title, thumbnail, sha256 from tags if not in root
    String title = eventData['title']?.toString() ?? '';
    String thumbnail = eventData['thumbnail']?.toString() ?? '';
    String videoUrl = eventData['video_url']?.toString() ?? '';
    String dTag = eventData['d_tag']?.toString() ?? '';
    String? sha256 =
        eventData['sha256']?.toString() ?? json['sha256']?.toString();

    // Parse description from event content (NIP-71 standard: content = description)
    // Fall back to summary tag for backward compatibility
    String? description = eventData['content']?.toString();
    if (description != null && description.isEmpty) description = null;

    // Also check for blurhash and summary in tags (NIP-71 standard)
    String? blurhashFromTag;
    String? summaryFromTag;
    int? publishedAt;

    if (eventData['tags'] is List) {
      final tags = eventData['tags'] as List;
      for (final tag in tags) {
        if (tag is List && tag.length >= 2) {
          final tagName = tag[0].toString();
          final tagValue = tag[1].toString();
          if (tagName == 'title' && title.isEmpty) title = tagValue;
          if ((tagName == 'thumb' || tagName == 'thumbnail') &&
              thumbnail.isEmpty) {
            thumbnail = tagValue;
          }
          if (tagName == 'url' && videoUrl.isEmpty) videoUrl = tagValue;
          if (tagName == 'd' && dTag.isEmpty) dTag = tagValue;
          if (tagName == 'x' && (sha256 == null || sha256.isEmpty)) {
            sha256 = tagValue; // x tag often contains sha256 hash
          }
          if (tagName == 'blurhash' && blurhashFromTag == null) {
            blurhashFromTag = tagValue;
          }
          if (tagName == 'summary' && summaryFromTag == null) {
            summaryFromTag = tagValue;
          }
          if (tagName == 'published_at' && publishedAt == null) {
            publishedAt = int.tryParse(tagValue);
          }
        }
      }
    }

    // Fall back to summary tag if content is empty
    description ??= summaryFromTag;

    // Normalize empty sha256 to null
    if (sha256 != null && sha256.isEmpty) sha256 = null;

    // Parse author_name for classic Vines
    String? authorName =
        eventData['author_name']?.toString() ?? json['author_name']?.toString();
    if (authorName != null && authorName.isEmpty) authorName = null;

    // Parse author_avatar for profile pictures
    String? authorAvatar =
        eventData['author_avatar']?.toString() ??
        json['author_avatar']?.toString();
    if (authorAvatar != null && authorAvatar.isEmpty) authorAvatar = null;

    // Parse blurhash for thumbnail placeholders
    // Check direct field first, then fall back to tag
    String? blurhash =
        eventData['blurhash']?.toString() ??
        json['blurhash']?.toString() ??
        blurhashFromTag;
    if (blurhash != null && blurhash.isEmpty) blurhash = null;

    // Parse reactions/likes - check multiple field names
    final reactions =
        statsData['reactions'] ??
        json['reactions'] ??
        json['embedded_likes'] ??
        json['likes'] ??
        0;

    // Parse comments - check multiple field names
    final comments =
        statsData['comments'] ??
        json['comments'] ??
        json['embedded_comments'] ??
        0;

    // Parse reposts - check multiple field names
    final reposts =
        statsData['reposts'] ??
        json['reposts'] ??
        json['embedded_reposts'] ??
        0;

    return VideoStats(
      id: id,
      pubkey: pubkey,
      createdAt: createdAt,
      publishedAt: publishedAt,
      kind: eventData['kind'] ?? 34236,
      dTag: dTag,
      title: title,
      description: description,
      thumbnail: thumbnail,
      videoUrl: videoUrl,
      sha256: sha256,
      authorName: authorName,
      authorAvatar: authorAvatar,
      blurhash: blurhash,
      reactions: reactions is int ? reactions : 0,
      comments: comments is int ? comments : 0,
      reposts: reposts is int ? reposts : 0,
      engagementScore:
          statsData['engagement_score'] ?? json['engagement_score'] ?? 0,
      trendingScore: (statsData['trending_score'] ?? json['trending_score'])
          ?.toDouble(),
      loops: loops,
      views: views,
    );
  }

  /// Convert to VideoEvent for use in the app
  VideoEvent toVideoEvent() {
    final effectiveTimestamp =
        publishedAt ?? createdAt.millisecondsSinceEpoch ~/ 1000;
    final normalizedDTag = dTag.isNotEmpty ? dTag : id;
    return VideoEvent(
      id: id,
      pubkey: pubkey,
      createdAt: effectiveTimestamp,
      content: description ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(effectiveTimestamp * 1000),
      title: title.isNotEmpty ? title : null,
      videoUrl: videoUrl.isNotEmpty ? videoUrl : null,
      thumbnailUrl: thumbnail.isNotEmpty ? thumbnail : null,
      vineId: normalizedDTag,
      publishedAt: publishedAt?.toString(),
      sha256: sha256,
      authorName: authorName,
      authorAvatar: authorAvatar,
      blurhash: blurhash,
      rawTags: {
        if (normalizedDTag.isNotEmpty) 'd': normalizedDTag,
        if (loops != null) 'loops': loops.toString(),
        if (views != null) 'views': views.toString(),
      },
      originalLikes: reactions,
      originalComments: comments,
      originalReposts: reposts,
      originalLoops: loops,
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

/// Pagination result with cursor support for Funnelcake API
class PaginatedVideos {
  final List<VideoEvent> videos;
  final int? nextCursor; // Unix timestamp for next page
  final bool hasMore;

  const PaginatedVideos({
    required this.videos,
    this.nextCursor,
    this.hasMore = false,
  });
}

/// Home feed result with cursor pagination
class HomeFeedResult {
  final List<VideoEvent> videos;
  final int? nextCursor;
  final bool hasMore;

  const HomeFeedResult({
    required this.videos,
    this.nextCursor,
    this.hasMore = false,
  });
}

/// Recommendations result with source attribution
class RecommendationsResult {
  final List<VideoEvent> videos;

  /// Source of recommendations: "personalized", "popular", "recent", or "error"
  final String source;

  const RecommendationsResult({required this.videos, required this.source});

  /// Whether recommendations are personalized (vs fallback)
  bool get isPersonalized => source == 'personalized';
}

/// Social counts result (follower/following counts)
class SocialCounts {
  final String pubkey;
  final int followerCount;
  final int followingCount;

  const SocialCounts({
    required this.pubkey,
    required this.followerCount,
    required this.followingCount,
  });

  factory SocialCounts.fromJson(Map<String, dynamic> json) {
    return SocialCounts(
      pubkey: json['pubkey']?.toString() ?? '',
      followerCount: json['follower_count'] as int? ?? 0,
      followingCount: json['following_count'] as int? ?? 0,
    );
  }
}

/// Paginated pubkey list result (for followers/following)
class PaginatedPubkeys {
  final List<String> pubkeys;
  final int total;
  final bool hasMore;

  const PaginatedPubkeys({
    required this.pubkeys,
    this.total = 0,
    this.hasMore = false,
  });

  factory PaginatedPubkeys.fromJson(Map<String, dynamic> json) {
    // The funnelcake API uses context-specific keys:
    // - /following returns {"following": [...]}
    // - /followers returns {"followers": [...]}
    // - Fall back to "pubkeys" for generic responses
    final pubkeysData =
        json['following'] as List<dynamic>? ??
        json['followers'] as List<dynamic>? ??
        json['pubkeys'] as List<dynamic>? ??
        [];
    return PaginatedPubkeys(
      pubkeys: pubkeysData.map((e) => e.toString()).toList(),
      total: json['total'] as int? ?? pubkeysData.length,
      hasMore: json['has_more'] as bool? ?? false,
    );
  }

  static const empty = PaginatedPubkeys(pubkeys: []);
}

/// Bulk video stats entry for a single video
class BulkVideoStatsEntry {
  final String eventId;
  final int reactions;
  final int comments;
  final int reposts;
  final int? loops;
  final int? views;

  const BulkVideoStatsEntry({
    required this.eventId,
    required this.reactions,
    required this.comments,
    required this.reposts,
    this.loops,
    this.views,
  });

  factory BulkVideoStatsEntry.fromJson(Map<String, dynamic> json) {
    int? parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final normalized = value.replaceAll(',', '').trim();
        final asInt = int.tryParse(normalized);
        if (asInt != null) return asInt;
        final asDouble = double.tryParse(normalized);
        if (asDouble != null) return asDouble.toInt();
      }
      return null;
    }

    int? findIntDeep(dynamic source, Set<String> targetKeys) {
      if (source is Map) {
        // Check current level first.
        for (final entry in source.entries) {
          final key = entry.key.toString().toLowerCase();
          if (targetKeys.contains(key)) {
            final parsed = parseInt(entry.value);
            if (parsed != null) return parsed;
          }
        }

        // Recurse into nested structures.
        for (final value in source.values) {
          final parsed = findIntDeep(value, targetKeys);
          if (parsed != null) return parsed;
        }
      } else if (source is List) {
        for (final value in source) {
          final parsed = findIntDeep(value, targetKeys);
          if (parsed != null) return parsed;
        }
      }
      return null;
    }

    return BulkVideoStatsEntry(
      eventId: (json['event_id'] ?? json['id'] ?? '').toString(),
      reactions:
          findIntDeep(json, {
            'reactions',
            'likes',
            'like_count',
            'total_likes',
          }) ??
          0,
      comments:
          findIntDeep(json, {'comments', 'comment_count', 'total_comments'}) ??
          0,
      reposts:
          findIntDeep(json, {'reposts', 'repost_count', 'total_reposts'}) ?? 0,
      loops: findIntDeep(json, {
        'loops',
        'loop_count',
        'total_loops',
        'embedded_loops',
        'computed_loops',
      }),
      views: findIntDeep(json, {
        'views',
        'view_count',
        'total_views',
        'unique_views',
        'unique_viewers',
      }),
    );
  }
}

class _CachedViewCount {
  final int views;
  final DateTime fetchedAt;

  const _CachedViewCount({required this.views, required this.fetchedAt});
}

/// Service for Funnelcake REST API interactions
///
/// Funnelcake provides pre-computed trending scores and analytics
/// backed by ClickHouse for efficient video discovery queries.
class AnalyticsApiService {
  static const Duration cacheTimeout = Duration(minutes: 5);
  static const Duration _viewCountCacheTimeout = Duration(seconds: 30);

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
  final Map<String, _CachedViewCount> _videoViewsCache = {};

  AnalyticsApiService({required String? baseUrl, http.Client? httpClient})
    : _baseUrl = baseUrl,
      _httpClient = httpClient ?? http.Client();

  /// Whether the API is available (has a configured base URL)
  bool get isAvailable => _baseUrl != null && _baseUrl.isNotEmpty;

  /// Fetch trending videos sorted by engagement score
  ///
  /// Uses funnelcake's pre-computed trending scores for efficient discovery.
  /// Returns VideoEvent objects ready for display.
  ///
  /// [before] - Unix timestamp cursor for pagination (get videos created before this time)
  Future<List<VideoEvent>> getTrendingVideos({
    int limit = 50,
    int? before,
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

    // Check cache only for initial load (no cursor)
    if (before == null &&
        !forceRefresh &&
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
      var url = '$_baseUrl/api/videos?sort=trending&limit=$limit';
      if (before != null) {
        url += '&before=$before';
      }
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

        final videos = data
            .map((v) => VideoStats.fromJson(v as Map<String, dynamic>))
            .where((v) => v.id.isNotEmpty && v.videoUrl.isNotEmpty)
            .toList();

        // Only update cache for initial load (no cursor)
        if (before == null) {
          _trendingVideosCache = videos;
          _lastTrendingVideosFetch = DateTime.now();
        }

        Log.info(
          'Returning ${videos.length} trending videos',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );

        return videos.map((v) => v.toVideoEvent()).toList();
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

  /// Fetch videos sorted by loop count (highest first)
  ///
  /// Uses funnelcake's sort=loops for classic Vines with high engagement.
  /// Returns VideoEvent objects ready for display.
  ///
  /// [before] - Unix timestamp cursor for pagination
  Future<List<VideoEvent>> getVideosByLoops({
    int limit = 50,
    int? before,
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

    try {
      var url = '$_baseUrl/api/videos?sort=loops&limit=$limit';
      if (before != null) {
        url += '&before=$before';
      }
      Log.info(
        'Fetching videos by loops from Funnelcake: $url',
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
          'Received ${data.length} videos sorted by loops from Funnelcake',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );

        final videos = data
            .map((v) => VideoStats.fromJson(v as Map<String, dynamic>))
            .where((v) => v.id.isNotEmpty && v.videoUrl.isNotEmpty)
            .toList();

        // Log first few for debugging
        if (videos.isNotEmpty) {
          final topLoops = videos
              .take(3)
              .map((v) => '${v.loops ?? 0}')
              .join(', ');
          Log.info(
            'Top 3 videos by loops: $topLoops',
            name: 'AnalyticsApiService',
            category: LogCategory.video,
          );
        }

        return videos.map((v) => v.toVideoEvent()).toList();
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
        'Error fetching videos by loops: $e',
        name: 'AnalyticsApiService',
        category: LogCategory.video,
      );
      return [];
    }
  }

  /// Fetch recent videos (newest first)
  ///
  /// [before] - Unix timestamp cursor for pagination (get videos created before this time)
  Future<List<VideoEvent>> getRecentVideos({
    int limit = 50,
    int? before,
    bool forceRefresh = false,
  }) async {
    if (!isAvailable) return [];

    // Check cache only for initial load (no cursor)
    if (before == null &&
        !forceRefresh &&
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
      var url = '$_baseUrl/api/videos?sort=recent&limit=$limit';
      if (before != null) {
        url += '&before=$before';
      }
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

        final videos = data
            .map((v) => VideoStats.fromJson(v as Map<String, dynamic>))
            .where((v) => v.id.isNotEmpty && v.videoUrl.isNotEmpty)
            .toList();

        // Only update cache for initial load (no cursor)
        if (before == null) {
          _recentVideosCache = videos;
          _lastRecentVideosFetch = DateTime.now();
        }

        Log.info(
          'Returning ${videos.length} recent videos',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );

        return videos.map((v) => v.toVideoEvent()).toList();
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
  /// Uses funnelcake's /api/videos?tag= endpoint for hashtag discovery.
  ///
  /// [before] - Unix timestamp cursor for pagination
  Future<List<VideoEvent>> getVideosByHashtag({
    required String hashtag,
    int limit = 50,
    int? before,
    bool forceRefresh = false,
  }) async {
    if (!isAvailable) return [];

    // Normalize hashtag (remove # if present, lowercase)
    final normalizedTag = hashtag.replaceFirst('#', '').toLowerCase();

    // Check cache only for initial load (no cursor)
    final cacheKey = normalizedTag;
    final cachedTime = _hashtagSearchCacheTime[cacheKey];
    if (before == null &&
        !forceRefresh &&
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
      var url =
          '$_baseUrl/api/videos?tag=$normalizedTag&sort=trending&limit=$limit';
      if (before != null) {
        url += '&before=$before';
      }
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

        // Cache results only for initial load
        if (before == null) {
          _hashtagSearchCache[cacheKey] = videos;
          _hashtagSearchCacheTime[cacheKey] = DateTime.now();
        }

        Log.info(
          'Found ${videos.length} videos for #$normalizedTag',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );

        return videos.map((v) => v.toVideoEvent()).toList();
      } else {
        // Log error response body for debugging
        Log.error(
          'Hashtag search failed: ${response.statusCode}\n'
          'URL: $url\n'
          'Response: ${response.body.length > 500 ? response.body.substring(0, 500) : response.body}',
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

  /// Fetch classic/all-time-popular videos for a hashtag
  ///
  /// Uses /api/videos?tag={hashtag}&sort=loops to surface classic vines
  /// and high-engagement content sorted by all-time loop count.
  ///
  /// Separate from [getVideosByHashtag] so both can run in parallel.
  Future<List<VideoEvent>> getClassicVideosByHashtag({
    required String hashtag,
    int limit = 50,
  }) async {
    if (!isAvailable) return [];

    final normalizedTag = hashtag.replaceFirst('#', '').toLowerCase();

    // Check cache
    final cacheKey = 'classics_$normalizedTag';
    final cachedTime = _hashtagSearchCacheTime[cacheKey];
    if (cachedTime != null &&
        DateTime.now().difference(cachedTime) < cacheTimeout &&
        _hashtagSearchCache.containsKey(cacheKey)) {
      Log.debug(
        'Using cached classic hashtag videos for #$normalizedTag',
        name: 'AnalyticsApiService',
        category: LogCategory.video,
      );
      return _hashtagSearchCache[cacheKey]!
          .map((v) => v.toVideoEvent())
          .toList();
    }

    try {
      final url =
          '$_baseUrl/api/videos?tag=$normalizedTag&sort=loops&limit=$limit';
      Log.info(
        'Fetching classic videos by hashtag from Funnelcake: $url',
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
          'Found ${videos.length} classic videos for #$normalizedTag',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );

        return videos.map((v) => v.toVideoEvent()).toList();
      } else {
        Log.error(
          'Classic hashtag search failed: ${response.statusCode}\n'
          'URL: $url',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );
        return [];
      }
    } catch (e) {
      Log.error(
        'Error fetching classic videos by hashtag: $e',
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

  /// Search user profiles by text query
  ///
  /// Uses funnelcake's /api/search/profiles?q= endpoint for profile search.
  /// Returns a list of JSON maps that can be converted to UserProfile.
  Future<List<Map<String, dynamic>>> searchProfiles({
    required String query,
    int limit = 50,
  }) async {
    if (!isAvailable || query.trim().isEmpty) return [];

    try {
      final encodedQuery = Uri.encodeQueryComponent(query.trim());
      final url = '$_baseUrl/api/search/profiles?q=$encodedQuery&limit=$limit';
      Log.info(
        'Searching profiles from Funnelcake: $url',
        name: 'AnalyticsApiService',
        category: LogCategory.system,
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

        final profiles = data
            .whereType<Map<String, dynamic>>()
            .where((p) => p['pubkey'] != null)
            .toList();

        Log.info(
          'Found ${profiles.length} profiles for query "$query"',
          name: 'AnalyticsApiService',
          category: LogCategory.system,
        );

        return profiles;
      } else {
        Log.warning(
          'Profile search failed: ${response.statusCode}',
          name: 'AnalyticsApiService',
          category: LogCategory.system,
        );
        return [];
      }
    } catch (e) {
      Log.error(
        'Error searching profiles: $e',
        name: 'AnalyticsApiService',
        category: LogCategory.system,
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

  /// Get view analytics for a specific video via GET /api/videos/{id}/views
  ///
  /// Returns:
  /// - `int` view count when available (including `0` if explicitly returned)
  /// - `null` when endpoint/data is unavailable
  Future<int?> getVideoViews(String eventId) async {
    if (!isAvailable || eventId.isEmpty) return null;
    final normalizedId = eventId.toLowerCase();
    final now = DateTime.now();
    final cached = _videoViewsCache[normalizedId];
    if (cached != null &&
        now.difference(cached.fetchedAt) < _viewCountCacheTimeout) {
      return cached.views;
    }

    int? parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final normalized = value.replaceAll(',', '').trim();
        final asInt = int.tryParse(normalized);
        if (asInt != null) return asInt;
        final asDouble = double.tryParse(normalized);
        if (asDouble != null) return asDouble.toInt();
      }
      return null;
    }

    try {
      final url = '$_baseUrl/api/videos/$eventId/views';
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
        final data = jsonDecode(response.body);
        int resolvedViews = 0;
        if (data is Map<String, dynamic>) {
          resolvedViews =
              parseInt(data['views']) ??
              parseInt(data['view_count']) ??
              parseInt(data['total_views']) ??
              parseInt(data['unique_views']) ??
              parseInt(data['unique_viewers']) ??
              0;
        }
        _videoViewsCache[normalizedId] = _CachedViewCount(
          views: resolvedViews,
          fetchedAt: now,
        );
        return resolvedViews;
      }

      if (response.statusCode == 404) {
        // Treat as no views for now; many deployments return 404 when view
        // tracking is disabled or no row exists yet.
        _videoViewsCache[normalizedId] = _CachedViewCount(
          views: 0,
          fetchedAt: now,
        );
        return 0;
      }

      return cached?.views;
    } catch (_) {
      return cached?.views;
    }
  }

  /// Fetch view counts for multiple videos by calling /api/videos/{id}/views.
  ///
  /// There is no documented bulk endpoint for views/loops yet, so this method
  /// fans out requests with bounded concurrency and a short-lived cache.
  Future<Map<String, int>> getBulkVideoViews(
    List<String> eventIds, {
    int maxVideos = 20,
    int maxConcurrent = 8,
  }) async {
    if (!isAvailable || eventIds.isEmpty || maxVideos <= 0) {
      return {};
    }

    final uniqueIds = eventIds
        .where((id) => id.isNotEmpty)
        .map((id) => id.toLowerCase())
        .toSet()
        .take(maxVideos)
        .toList();
    if (uniqueIds.isEmpty) {
      return {};
    }

    final result = <String, int>{};
    final now = DateTime.now();
    final idsToFetch = <String>[];

    for (final id in uniqueIds) {
      final cached = _videoViewsCache[id];
      if (cached != null &&
          now.difference(cached.fetchedAt) < _viewCountCacheTimeout) {
        result[id] = cached.views;
      } else {
        idsToFetch.add(id);
      }
    }

    if (idsToFetch.isNotEmpty) {
      for (var i = 0; i < idsToFetch.length; i += maxConcurrent) {
        final end = (i + maxConcurrent < idsToFetch.length)
            ? i + maxConcurrent
            : idsToFetch.length;
        final chunk = idsToFetch.sublist(i, end);
        final chunkResults = await Future.wait(
          chunk.map((id) async {
            final views = await getVideoViews(id);
            if (views == null) return null;
            return MapEntry(id, views);
          }),
        );
        for (final entry in chunkResults.whereType<MapEntry<String, int>>()) {
          result[entry.key] = entry.value;
        }
      }
    }

    Log.debug(
      'Bulk video views fetch: ${result.length}/${uniqueIds.length} resolved '
      '(requested=${eventIds.length}, capped=$maxVideos)',
      name: 'AnalyticsApiService',
      category: LogCategory.video,
    );

    return result;
  }

  /// Get videos by a specific author
  ///
  /// [before] - Unix timestamp cursor for pagination
  Future<List<VideoEvent>> getVideosByAuthor({
    required String pubkey,
    int limit = 50,
    int? before,
  }) async {
    if (!isAvailable || pubkey.isEmpty) return [];

    try {
      var url = '$_baseUrl/api/users/$pubkey/videos?limit=$limit';
      if (before != null) {
        url += '&before=$before';
      }
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

  /// Get user profile data from FunnelCake REST API
  ///
  /// Uses the /api/users/{pubkey} endpoint which returns profile data
  /// along with social stats. This is faster than WebSocket relay queries
  /// for profiles that exist in the ClickHouse database.
  ///
  /// Returns null if user not found or API unavailable.
  Future<Map<String, dynamic>?> getUserProfile(String pubkey) async {
    if (!isAvailable || pubkey.isEmpty) return null;

    try {
      final url = '$_baseUrl/api/users/$pubkey';
      Log.info(
        '🔍 Fetching profile from FunnelCake REST API: $pubkey',
        name: 'AnalyticsApiService',
        category: LogCategory.system,
      );

      final response = await _httpClient
          .get(
            Uri.parse(url),
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'OpenVine-Mobile/1.0',
            },
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final profile = data['profile'] as Map<String, dynamic>?;

        if (profile != null &&
            (profile['name'] != null || profile['display_name'] != null)) {
          Log.info(
            '✅ Got profile from FunnelCake: ${profile['display_name'] ?? profile['name']}',
            name: 'AnalyticsApiService',
            category: LogCategory.system,
          );
          return {
            'pubkey': pubkey,
            'name': profile['name'],
            'display_name': profile['display_name'],
            'about': profile['about'],
            'picture': profile['picture'],
            'banner': profile['banner'],
            'nip05': profile['nip05'],
            'lud16': profile['lud16'],
          };
        }
        Log.debug(
          'FunnelCake returned user but no profile data',
          name: 'AnalyticsApiService',
          category: LogCategory.system,
        );
        return null;
      } else if (response.statusCode == 404) {
        Log.debug(
          'Profile not found in FunnelCake: $pubkey',
          name: 'AnalyticsApiService',
          category: LogCategory.system,
        );
        return null;
      } else {
        Log.warning(
          'FunnelCake profile fetch failed: ${response.statusCode}',
          name: 'AnalyticsApiService',
          category: LogCategory.system,
        );
        return null;
      }
    } catch (e) {
      Log.debug(
        'FunnelCake profile fetch error (will fall back to relay): $e',
        name: 'AnalyticsApiService',
        category: LogCategory.system,
      );
      return null;
    }
  }

  /// Get personalized home feed for a user (videos from followed accounts)
  ///
  /// Uses the /api/users/{pubkey}/feed endpoint which returns videos
  /// from accounts the user follows, with cursor-based pagination.
  ///
  /// [sort] - Sort order: 'recent' or 'trending'
  /// [before] - Unix timestamp cursor for pagination
  Future<HomeFeedResult> getHomeFeed({
    required String pubkey,
    int limit = 50,
    String sort = 'recent',
    int? before,
  }) async {
    if (!isAvailable || pubkey.isEmpty) {
      return const HomeFeedResult(videos: [], hasMore: false);
    }

    try {
      var url =
          '$_baseUrl/api/users/$pubkey/feed'
          '?limit=$limit&sort=$sort&include_collabs=true';
      if (before != null) {
        url += '&before=$before';
      }
      Log.info(
        'Fetching home feed from Funnelcake: $url',
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
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        // Parse videos array
        final videosData = data['videos'] as List<dynamic>? ?? [];
        final videos = videosData
            .map((v) => VideoStats.fromJson(v as Map<String, dynamic>))
            .where((v) => v.id.isNotEmpty && v.videoUrl.isNotEmpty)
            .map((v) => v.toVideoEvent())
            .toList();

        // Parse pagination info
        final nextCursorStr = data['next_cursor'] as String?;
        final nextCursor = nextCursorStr != null
            ? int.tryParse(nextCursorStr)
            : null;
        final hasMore = data['has_more'] as bool? ?? false;

        Log.info(
          'Home feed: ${videos.length} videos, hasMore: $hasMore, nextCursor: $nextCursor',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );

        return HomeFeedResult(
          videos: videos,
          nextCursor: nextCursor,
          hasMore: hasMore,
        );
      } else if (response.statusCode == 404) {
        Log.warning(
          'Home feed not found (user may not have contact list)',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );
        return const HomeFeedResult(videos: [], hasMore: false);
      } else {
        Log.error(
          'Home feed failed: ${response.statusCode}',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );
        return const HomeFeedResult(videos: [], hasMore: false);
      }
    } catch (e) {
      Log.error(
        'Error fetching home feed: $e',
        name: 'AnalyticsApiService',
        category: LogCategory.video,
      );
      return const HomeFeedResult(videos: [], hasMore: false);
    }
  }

  /// Get classic vines (imported Vine videos)
  ///
  /// Uses the /api/videos endpoint with classic=true&platform=vine
  /// to get older videos with high engagement.
  ///
  /// [sort] - Sort order: 'loops' (default, most viral first), 'trending', or 'recent'
  /// [offset] - Pagination offset for rank-based sorting (loops, trending)
  /// [before] - Unix timestamp cursor for time-based pagination (recent)
  Future<List<VideoEvent>> getClassicVines({
    int limit = 50,
    int offset = 0,
    int? before,
    String sort = 'loops', // Most viral first by default
  }) async {
    if (!isAvailable) return [];

    try {
      var url =
          '$_baseUrl/api/videos?classic=true&platform=vine&sort=$sort&limit=$limit';
      // Use offset for rank-based sorting (loops, trending)
      // Use before for time-based sorting (recent)
      if (sort == 'recent' && before != null) {
        url += '&before=$before';
      } else if (offset > 0) {
        url += '&offset=$offset';
      }
      Log.info(
        'Fetching classic vines from Funnelcake: $url',
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
        final decoded = jsonDecode(response.body);

        // Handle both array response and wrapped object response
        List<dynamic> data;
        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map<String, dynamic>) {
          // Try common wrapper keys
          data =
              (decoded['videos'] ?? decoded['data'] ?? decoded['results'] ?? [])
                  as List<dynamic>;
          Log.debug(
            'Classic vines response is wrapped object with keys: ${decoded.keys.toList()}',
            name: 'AnalyticsApiService',
            category: LogCategory.video,
          );
        } else {
          Log.error(
            'Classic vines unexpected response type: ${decoded.runtimeType}',
            name: 'AnalyticsApiService',
            category: LogCategory.video,
          );
          data = [];
        }

        Log.debug(
          'Classic vines raw data count: ${data.length}',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );

        // Log first item structure for debugging
        if (data.isNotEmpty) {
          final firstItem = data.first as Map<String, dynamic>;
          Log.debug(
            'Classic vines first item keys: ${firstItem.keys.toList()}',
            name: 'AnalyticsApiService',
            category: LogCategory.video,
          );
          Log.debug(
            'Classic vines first item id type: ${firstItem['id']?.runtimeType}, video_url type: ${firstItem['video_url']?.runtimeType}',
            name: 'AnalyticsApiService',
            category: LogCategory.video,
          );
          // Log blurhash specifically
          final blurhashValue = firstItem['blurhash'];
          final eventBlurhash =
              (firstItem['event'] as Map<String, dynamic>?)?['blurhash'];
          Log.debug(
            'Classic vines blurhash: direct=${blurhashValue?.runtimeType}/${blurhashValue != null ? (blurhashValue.toString().length) : 0} chars, '
            'event.blurhash=${eventBlurhash?.runtimeType}/${eventBlurhash != null ? (eventBlurhash.toString().length) : 0} chars',
            name: 'AnalyticsApiService',
            category: LogCategory.video,
          );
          // Check tags for blurhash
          final tags =
              firstItem['tags'] ??
              (firstItem['event'] as Map<String, dynamic>?)?['tags'];
          if (tags is List) {
            final blurhashTag = tags.firstWhere(
              (t) => t is List && t.isNotEmpty && t[0] == 'blurhash',
              orElse: () => null,
            );
            Log.debug(
              'Classic vines blurhash tag: $blurhashTag',
              name: 'AnalyticsApiService',
              category: LogCategory.video,
            );
          }
        }

        final videos = data
            .map((v) => VideoStats.fromJson(v as Map<String, dynamic>))
            .where((v) {
              final valid = v.id.isNotEmpty && v.videoUrl.isNotEmpty;
              if (!valid) {
                Log.debug(
                  'Filtering out video: id="${v.id}", videoUrl="${v.videoUrl}"',
                  name: 'AnalyticsApiService',
                  category: LogCategory.video,
                );
              }
              return valid;
            })
            .toList();

        Log.info(
          'Found ${videos.length} classic vines (after filtering from ${data.length} raw)',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );

        // Log first video stats for debugging
        if (videos.isNotEmpty) {
          final first = videos.first;
          Log.info(
            'First classic vine: id=${first.id}, '
            'loops=${first.loops}, likes=${first.reactions}, '
            'comments=${first.comments}, reposts=${first.reposts}, '
            'blurhash=${first.blurhash != null ? '${first.blurhash!.length} chars' : 'null'}, '
            'authorName=${first.authorName}, '
            'title="${first.title.length > 30 ? '${first.title.substring(0, 30)}...' : first.title}"',
            name: 'AnalyticsApiService',
            category: LogCategory.video,
          );
        }

        return videos.map((v) => v.toVideoEvent()).toList();
      } else {
        Log.error(
          'Classic vines failed: ${response.statusCode}',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );
        return [];
      }
    } catch (e) {
      Log.error(
        'Error fetching classic vines: $e',
        name: 'AnalyticsApiService',
        category: LogCategory.video,
      );
      return [];
    }
  }

  /// Fetch a page of classic vines using offset pagination
  ///
  /// Use this for on-demand page loading instead of fetching all 10k at once.
  ///
  /// [page] - Page number (0-indexed)
  /// [pageSize] - Videos per page (default 100)
  /// [sort] - Sort order: 'loops' (default), 'trending', or 'recent'
  Future<List<VideoEvent>> getClassicVinesPage({
    required int page,
    int pageSize = 100,
    String sort = 'loops',
  }) async {
    final offset = page * pageSize;

    Log.info(
      '🎬 Fetching classic vines page $page (offset: $offset, sort: $sort)',
      name: 'AnalyticsApiService',
      category: LogCategory.video,
    );

    return getClassicVines(limit: pageSize, offset: offset, sort: sort);
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

  /// Get personalized video recommendations for a user
  ///
  /// Uses the /api/users/{pubkey}/recommendations endpoint which returns
  /// ML-powered personalized recommendations from Gorse, with fallback
  /// to popular/recent videos for cold-start users.
  ///
  /// [fallback] - Strategy when personalization unavailable: "popular" or "recent"
  /// [category] - Optional hashtag/category filter
  Future<RecommendationsResult> getRecommendations({
    required String pubkey,
    int limit = 20,
    String fallback = 'popular',
    String? category,
  }) async {
    if (!isAvailable || pubkey.isEmpty) {
      return const RecommendationsResult(videos: [], source: 'unavailable');
    }

    try {
      var url =
          '$_baseUrl/api/users/$pubkey/recommendations?limit=$limit&fallback=$fallback';
      if (category != null && category.isNotEmpty) {
        url += '&category=${Uri.encodeQueryComponent(category)}';
      }

      Log.info(
        'Fetching recommendations from Funnelcake: $url',
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
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        // Parse videos array
        final videosData = data['videos'] as List<dynamic>? ?? [];
        final videos = videosData
            .map((v) => VideoStats.fromJson(v as Map<String, dynamic>))
            .where((v) => v.id.isNotEmpty && v.videoUrl.isNotEmpty)
            .map((v) => v.toVideoEvent())
            .toList();

        // Get source (personalized, popular, or recent)
        final source = data['source'] as String? ?? 'unknown';

        Log.info(
          'Recommendations: ${videos.length} videos, source: $source',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );

        return RecommendationsResult(videos: videos, source: source);
      } else if (response.statusCode == 404) {
        Log.warning(
          'Recommendations endpoint not found (may not be deployed yet)',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );
        return const RecommendationsResult(videos: [], source: 'unavailable');
      } else {
        Log.error(
          'Recommendations failed: ${response.statusCode}',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );
        return const RecommendationsResult(videos: [], source: 'error');
      }
    } catch (e) {
      Log.error(
        'Error fetching recommendations: $e',
        name: 'AnalyticsApiService',
        category: LogCategory.video,
      );
      return const RecommendationsResult(videos: [], source: 'error');
    }
  }

  /// Fetch multiple user profiles in bulk via POST /api/users/bulk
  ///
  /// Returns a map of pubkey -> profile data for efficient batch loading.
  /// This is faster than individual profile fetches for video grids.
  ///
  /// Returns empty map if API unavailable or request fails.
  Future<Map<String, Map<String, dynamic>>> getBulkProfiles(
    List<String> pubkeys,
  ) async {
    if (!isAvailable || pubkeys.isEmpty) {
      return {};
    }

    try {
      final url = '$_baseUrl/api/users/bulk';
      Log.info(
        'Fetching ${pubkeys.length} profiles in bulk from Funnelcake',
        name: 'AnalyticsApiService',
        category: LogCategory.system,
      );

      final response = await _httpClient
          .post(
            Uri.parse(url),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'User-Agent': 'OpenVine-Mobile/1.0',
            },
            body: jsonEncode({'pubkeys': pubkeys}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final usersData = data['users'] as List<dynamic>? ?? [];

        final result = <String, Map<String, dynamic>>{};
        for (final user in usersData) {
          if (user is Map<String, dynamic>) {
            final pubkey = user['pubkey']?.toString();
            final profile = user['profile'] as Map<String, dynamic>?;
            if (pubkey != null && pubkey.isNotEmpty && profile != null) {
              result[pubkey] = profile;
            }
          }
        }

        Log.info(
          'Bulk profile fetch: ${result.length}/${pubkeys.length} profiles found',
          name: 'AnalyticsApiService',
          category: LogCategory.system,
        );

        return result;
      } else {
        Log.warning(
          'Bulk profile fetch failed: ${response.statusCode}',
          name: 'AnalyticsApiService',
          category: LogCategory.system,
        );
        return {};
      }
    } catch (e) {
      Log.debug(
        'Bulk profile fetch error (will fall back to relay): $e',
        name: 'AnalyticsApiService',
        category: LogCategory.system,
      );
      return {};
    }
  }

  /// Fetch video stats for multiple videos in bulk via POST /api/videos/stats/bulk
  ///
  /// Returns a map of eventId -> stats for efficient batch loading.
  /// Useful for enriching video grids with engagement counts.
  ///
  /// Returns empty map if API unavailable or request fails.
  Future<Map<String, BulkVideoStatsEntry>> getBulkVideoStats(
    List<String> eventIds,
  ) async {
    if (!isAvailable || eventIds.isEmpty) {
      return {};
    }

    try {
      final url = '$_baseUrl/api/videos/stats/bulk';
      Log.info(
        'Fetching stats for ${eventIds.length} videos in bulk from Funnelcake',
        name: 'AnalyticsApiService',
        category: LogCategory.video,
      );

      final response = await _httpClient
          .post(
            Uri.parse(url),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'User-Agent': 'OpenVine-Mobile/1.0',
            },
            body: jsonEncode({'event_ids': eventIds}),
          )
          .timeout(const Duration(seconds: 10));

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
          // Some API variants return {"stats": {"<eventId>": {...}}}
          for (final mapEntry in statsData.entries) {
            final eventId = mapEntry.key.toString();
            final value = mapEntry.value;
            if (value is Map) {
              final statMap = Map<String, dynamic>.from(value);
              final statWithEventId = {
                'event_id': statMap['event_id'] ?? eventId,
                ...statMap,
              };
              final entry = BulkVideoStatsEntry.fromJson(statWithEventId);
              if (entry.eventId.isNotEmpty) {
                result[entry.eventId] = entry;
              }
            }
          }
        } else {
          Log.warning(
            'Bulk video stats fetch: unexpected stats payload type: '
            '${statsData.runtimeType}',
            name: 'AnalyticsApiService',
            category: LogCategory.video,
          );
        }

        Log.info(
          'Bulk video stats fetch: ${result.length}/${eventIds.length} stats found',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );
        if (result.isNotEmpty) {
          final sample = result.values.first;
          Log.debug(
            'Bulk stats sample: eventId=${sample.eventId}, '
            'loops=${sample.loops}, views=${sample.views}',
            name: 'AnalyticsApiService',
            category: LogCategory.video,
          );
        }

        return result;
      } else {
        Log.warning(
          'Bulk video stats fetch failed: ${response.statusCode}',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );
        return {};
      }
    } catch (e) {
      Log.debug(
        'Bulk video stats fetch error (will fall back to relay): $e',
        name: 'AnalyticsApiService',
        category: LogCategory.video,
      );
      return {};
    }
  }

  /// Get social counts (follower/following) for a user via GET /api/users/{pk}/social
  ///
  /// Returns quick follower/following counts without fetching full lists.
  /// Useful for profile headers.
  ///
  /// Returns null if API unavailable, user not found, or request fails.
  Future<SocialCounts?> getSocialCounts(String pubkey) async {
    if (!isAvailable || pubkey.isEmpty) {
      return null;
    }

    try {
      final url = '$_baseUrl/api/users/$pubkey/social';
      Log.debug(
        'Fetching social counts for $pubkey from Funnelcake',
        name: 'AnalyticsApiService',
        category: LogCategory.system,
      );

      final response = await _httpClient
          .get(
            Uri.parse(url),
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'OpenVine-Mobile/1.0',
            },
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final counts = SocialCounts.fromJson(data);

        Log.debug(
          'Social counts for $pubkey: ${counts.followerCount} followers, ${counts.followingCount} following',
          name: 'AnalyticsApiService',
          category: LogCategory.system,
        );

        return counts;
      } else if (response.statusCode == 404) {
        Log.debug(
          'Social counts not found for $pubkey',
          name: 'AnalyticsApiService',
          category: LogCategory.system,
        );
        return null;
      } else {
        Log.warning(
          'Social counts fetch failed: ${response.statusCode}',
          name: 'AnalyticsApiService',
          category: LogCategory.system,
        );
        return null;
      }
    } catch (e) {
      Log.debug(
        'Social counts fetch error (will fall back to relay): $e',
        name: 'AnalyticsApiService',
        category: LogCategory.system,
      );
      return null;
    }
  }

  /// Get paginated list of followers for a user via GET /api/users/{pk}/followers
  ///
  /// Returns pubkeys of users who follow the target user.
  ///
  /// [limit] - Maximum number of results (default 100)
  /// [offset] - Pagination offset (default 0)
  ///
  /// Returns empty result if API unavailable or request fails.
  Future<PaginatedPubkeys> getFollowers(
    String pubkey, {
    int limit = 100,
    int offset = 0,
  }) async {
    if (!isAvailable || pubkey.isEmpty) {
      return PaginatedPubkeys.empty;
    }

    try {
      final url =
          '$_baseUrl/api/users/$pubkey/followers?limit=$limit&offset=$offset';
      Log.debug(
        'Fetching followers for $pubkey from Funnelcake',
        name: 'AnalyticsApiService',
        category: LogCategory.system,
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
        final result = PaginatedPubkeys.fromJson(data);

        Log.info(
          'Followers for $pubkey: ${result.pubkeys.length} (total: ${result.total}, hasMore: ${result.hasMore})',
          name: 'AnalyticsApiService',
          category: LogCategory.system,
        );

        return result;
      } else if (response.statusCode == 404) {
        Log.debug(
          'Followers not found for $pubkey',
          name: 'AnalyticsApiService',
          category: LogCategory.system,
        );
        return PaginatedPubkeys.empty;
      } else {
        Log.warning(
          'Followers fetch failed: ${response.statusCode}',
          name: 'AnalyticsApiService',
          category: LogCategory.system,
        );
        return PaginatedPubkeys.empty;
      }
    } catch (e) {
      Log.debug(
        'Followers fetch error (will fall back to relay): $e',
        name: 'AnalyticsApiService',
        category: LogCategory.system,
      );
      return PaginatedPubkeys.empty;
    }
  }

  /// Get paginated list of users that a user follows via GET /api/users/{pk}/following
  ///
  /// Returns pubkeys of users that the target user follows.
  ///
  /// [limit] - Maximum number of results (default 100)
  /// [offset] - Pagination offset (default 0)
  ///
  /// Returns empty result if API unavailable or request fails.
  Future<PaginatedPubkeys> getFollowing(
    String pubkey, {
    int limit = 100,
    int offset = 0,
  }) async {
    if (!isAvailable || pubkey.isEmpty) {
      return PaginatedPubkeys.empty;
    }

    try {
      final url =
          '$_baseUrl/api/users/$pubkey/following?limit=$limit&offset=$offset';
      Log.debug(
        'Fetching following for $pubkey from Funnelcake',
        name: 'AnalyticsApiService',
        category: LogCategory.system,
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
        final result = PaginatedPubkeys.fromJson(data);

        Log.info(
          'Following for $pubkey: ${result.pubkeys.length} (total: ${result.total}, hasMore: ${result.hasMore})',
          name: 'AnalyticsApiService',
          category: LogCategory.system,
        );

        return result;
      } else if (response.statusCode == 404) {
        Log.debug(
          'Following not found for $pubkey',
          name: 'AnalyticsApiService',
          category: LogCategory.system,
        );
        return PaginatedPubkeys.empty;
      } else {
        Log.warning(
          'Following fetch failed: ${response.statusCode}',
          name: 'AnalyticsApiService',
          category: LogCategory.system,
        );
        return PaginatedPubkeys.empty;
      }
    } catch (e) {
      Log.debug(
        'Following fetch error (will fall back to relay): $e',
        name: 'AnalyticsApiService',
        category: LogCategory.system,
      );
      return PaginatedPubkeys.empty;
    }
  }

  /// Clear all caches
  void clearCache() {
    _trendingVideosCache.clear();
    _recentVideosCache.clear();
    _trendingHashtagsCache.clear();
    _hashtagSearchCache.clear();
    _hashtagSearchCacheTime.clear();
    _videoViewsCache.clear();
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

int? parseInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    final normalized = value.replaceAll(',', '').trim();
    final asInt = int.tryParse(normalized);
    if (asInt != null) return asInt;
    final asDouble = double.tryParse(normalized);
    if (asDouble != null) return asDouble.toInt();
  }
  return null;
}

int? findIntDeep(dynamic source, Set<String> targetKeys) {
  if (source is Map) {
    for (final entry in source.entries) {
      final key = entry.key.toString().toLowerCase();
      if (targetKeys.contains(key)) {
        final parsed = parseInt(entry.value);
        if (parsed != null) return parsed;
      }
    }

    for (final value in source.values) {
      final parsed = findIntDeep(value, targetKeys);
      if (parsed != null) return parsed;
    }
  } else if (source is List) {
    for (final value in source) {
      final parsed = findIntDeep(value, targetKeys);
      if (parsed != null) return parsed;
    }
  }
  return null;
}
