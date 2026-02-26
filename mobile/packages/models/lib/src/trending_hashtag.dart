// ABOUTME: Data model for trending hashtag from Funnelcake API.
// ABOUTME: Represents a hashtag with usage metrics for discovery features.

import 'package:meta/meta.dart';

/// A trending hashtag with associated metrics from the Funnelcake API.
///
/// Used for hashtag discovery and the trending hashtags feed.
@immutable
class TrendingHashtag {
  /// Creates a new [TrendingHashtag] instance.
  const TrendingHashtag({
    required this.tag,
    required this.videoCount,
    this.uniqueCreators = 0,
    this.totalLoops = 0,
    this.lastUsed,
  });

  /// Creates a [TrendingHashtag] from JSON response.
  ///
  /// Handles multiple field name formats from the Funnelcake API:
  /// - `hashtag` or `tag` for the tag name
  /// - `video_count` or `videoCount` for the count
  /// - `unique_creators` or `uniqueCreators` for creator count
  /// - `total_loops` or `totalLoops` for loop count
  /// - `last_used` as Unix timestamp (int) or ISO string
  factory TrendingHashtag.fromJson(Map<String, dynamic> json) {
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
      tag: (json['hashtag'] ?? json['tag'] ?? '').toString(),
      videoCount:
          (json['video_count'] as int?) ?? (json['videoCount'] as int?) ?? 0,
      uniqueCreators:
          (json['unique_creators'] as int?) ??
          (json['uniqueCreators'] as int?) ??
          0,
      totalLoops:
          (json['total_loops'] as int?) ?? (json['totalLoops'] as int?) ?? 0,
      lastUsed: lastUsed,
    );
  }

  /// The hashtag name (without the `#` prefix).
  final String tag;

  /// Number of videos using this hashtag.
  final int videoCount;

  /// Number of unique creators who used this hashtag.
  final int uniqueCreators;

  /// Total loop count across all videos with this hashtag.
  final int totalLoops;

  /// When this hashtag was last used.
  final DateTime? lastUsed;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TrendingHashtag && other.tag == tag;
  }

  @override
  int get hashCode => tag.hashCode;

  @override
  String toString() => 'TrendingHashtag(tag: $tag, videoCount: $videoCount)';
}
