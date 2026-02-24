// ABOUTME: Data model for Funnelcake API hashtag search response.
// ABOUTME: Represents hashtag data returned from the search/trending endpoints.

import 'package:meta/meta.dart';

/// Hashtag result from Funnelcake search API.
///
/// This model represents the hashtag data returned by the Funnelcake
/// `/api/hashtags` and `/analytics/hashtags/trending` endpoints.
/// It handles both response formats:
/// - `/api/hashtags`: `{"hashtag": "bitcoin", "video_count": 156}`
/// - `/analytics/hashtags/trending`: `{"tag": "funny", "score": 95.2, ...}`
@immutable
class HashtagSearchResult {
  /// Creates a new [HashtagSearchResult] instance.
  const HashtagSearchResult({
    required this.tag,
    this.videoCount,
    this.score,
    this.totalViews,
    this.momentum,
  });

  /// Creates a [HashtagSearchResult] from JSON response.
  ///
  /// Handles the Funnelcake API response format with flexible field parsing:
  /// - Tag name can be in `hashtag` or `tag` field
  /// - `video_count`/`videoCount` can be int or string
  /// - Numeric fields (`score`, `totalViews`, `momentum`) parsed as double
  factory HashtagSearchResult.fromJson(Map<String, dynamic> json) {
    final rawTag = json['hashtag'] ?? json['tag'] ?? '';

    int? videoCount;
    final rawVideoCount = json['video_count'] ?? json['videoCount'];
    if (rawVideoCount is int) {
      videoCount = rawVideoCount;
    } else if (rawVideoCount is String) {
      videoCount = int.tryParse(rawVideoCount);
    }

    return HashtagSearchResult(
      tag: rawTag.toString(),
      videoCount: videoCount,
      score: (json['score'] as num?)?.toDouble(),
      totalViews: ((json['total_views'] ?? json['totalViews']) as num?)
          ?.toDouble(),
      momentum: (json['momentum'] as num?)?.toDouble(),
    );
  }

  /// Hashtag name (without the `#` prefix).
  final String tag;

  /// Number of videos using this hashtag.
  final int? videoCount;

  /// Trending score for this hashtag.
  final double? score;

  /// Total views across all videos with this hashtag.
  final double? totalViews;

  /// Trending momentum factor.
  final double? momentum;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HashtagSearchResult && other.tag == tag;
  }

  @override
  int get hashCode => tag.hashCode;

  @override
  String toString() =>
      'HashtagSearchResult(tag: $tag, videoCount: $videoCount)';
}
