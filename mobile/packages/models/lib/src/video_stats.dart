// ABOUTME: Data model for Funnelcake API video stats response.
// ABOUTME: Represents video metadata with engagement metrics from the
// ABOUTME: ClickHouse-backed analytics API.

import 'package:meta/meta.dart';
import 'package:models/src/video_event.dart';

/// Video with engagement metrics from Funnelcake API.
///
/// This model represents the combined event data and stats returned
/// by the Funnelcake REST API. It includes both the video metadata
/// (from the Nostr event) and engagement metrics (from ClickHouse).
@immutable
class VideoStats {
  /// Creates a new [VideoStats] instance.
  const VideoStats({
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
    this.publishedAt,
    this.description,
    this.sha256,
    this.authorName,
    this.authorAvatar,
    this.blurhash,
    this.trendingScore,
    this.loops,
    this.views,
    this.rawTags = const {},
  });

  /// Creates a [VideoStats] from JSON response.
  ///
  /// Handles the nested format returned by Funnelcake API:
  /// `{ "event": {...}, "stats": {...} }`
  ///
  /// Also handles the quirks of the Funnelcake response format:
  /// - IDs returned as byte arrays (ASCII codes) instead of strings
  /// - Unix timestamps instead of ISO strings
  /// - Stats in various field name formats
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

    // Parse created_at - funnelcake returns Unix timestamp (int), not ISO
    DateTime createdAt;
    final rawCreatedAt = eventData['created_at'];
    if (rawCreatedAt is int) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(rawCreatedAt * 1000);
    } else if (rawCreatedAt is String) {
      createdAt = DateTime.tryParse(rawCreatedAt) ?? DateTime.now();
    } else {
      createdAt = DateTime.now();
    }

    // Parse loops from multiple possible sources
    int? loops;
    final directLoops =
        statsData['loops'] ?? json['loops'] ?? json['original_loops'];
    if (directLoops is int) {
      loops = directLoops;
    } else if (directLoops is double) {
      loops = directLoops.toInt();
    } else if (directLoops is String) {
      loops = int.tryParse(directLoops);
    }

    // Also check event tags for loops if not found directly
    if (loops == null && eventData['tags'] is List) {
      final tags = eventData['tags'] as List<dynamic>;
      for (final tag in tags) {
        if (tag is List && tag.length >= 2 && tag[0] == 'loops') {
          loops = int.tryParse(tag[1].toString());
          break;
        }
      }
    }

    // Extract title, thumbnail, sha256 from tags if not in root
    var title = eventData['title']?.toString() ?? '';
    var thumbnail = eventData['thumbnail']?.toString() ?? '';
    var videoUrl = eventData['video_url']?.toString() ?? '';
    var dTag = eventData['d_tag']?.toString() ?? '';
    var sha256 = eventData['sha256']?.toString() ?? json['sha256']?.toString();

    // Parse description from event content (NIP-71: content = description)
    var description = eventData['content']?.toString();
    if (description != null && description.isEmpty) description = null;

    // Parse view counts from multiple possible sources
    int? views;
    final directViews =
        statsData['views'] ?? json['views'] ?? json['view_count'];
    if (directViews is int) {
      views = directViews;
    } else if (directViews is double) {
      views = directViews.toInt();
    } else if (directViews is String) {
      views = int.tryParse(directViews);
    }

    // Also check for blurhash and summary in tags (NIP-71 standard)
    // Collect ALL tags into rawTags so nothing is lost (ProofMode, C2PA, etc.)
    String? blurhashFromTag;
    String? summaryFromTag;
    int? publishedAt;
    final rawTags = <String, String>{};

    if (eventData['tags'] is List) {
      final tags = eventData['tags'] as List<dynamic>;
      for (final tag in tags) {
        if (tag is List && tag.length >= 2) {
          final tagName = tag[0].toString();
          final tagValue = tag[1].toString();

          // Store every tag in rawTags for downstream consumers
          rawTags[tagName] = tagValue;

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
          if (tagName == 'views' && views == null) {
            views = int.tryParse(tagValue);
          }
        }
      }
    }

    // Fall back to summary tag if content is empty
    description ??= summaryFromTag;

    // Normalize empty sha256 to null
    if (sha256 != null && sha256.isEmpty) sha256 = null;

    // Parse author_name for classic Vines
    var authorName =
        eventData['author_name']?.toString() ?? json['author_name']?.toString();
    if (authorName != null && authorName.isEmpty) authorName = null;

    // Parse author_avatar for profile pictures
    var authorAvatar =
        eventData['author_avatar']?.toString() ??
        json['author_avatar']?.toString();
    if (authorAvatar != null && authorAvatar.isEmpty) authorAvatar = null;

    // Parse blurhash for thumbnail placeholders
    var blurhash =
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
      kind: (eventData['kind'] as int?) ?? 34236,
      dTag: dTag,
      title: title,
      description: description,
      thumbnail: thumbnail,
      videoUrl: videoUrl,
      sha256: sha256,
      authorName: authorName,
      authorAvatar: authorAvatar,
      blurhash: blurhash,
      reactions: _parseInt(reactions),
      comments: _parseInt(comments),
      reposts: _parseInt(reposts),
      engagementScore: _parseInt(
        statsData['engagement_score'] ?? json['engagement_score'],
      ),
      trendingScore: _parseDouble(
        statsData['trending_score'] ?? json['trending_score'],
      ),
      loops: loops,
      views: views,
      rawTags: rawTags,
    );
  }

  /// Nostr event ID.
  final String id;

  /// Author's public key (hex format).
  final String pubkey;

  /// When the video was created.
  final DateTime createdAt;

  /// Unix timestamp of when the video was published (`published_at` tag).
  ///
  /// May differ from [createdAt] when the event was updated after initial
  /// publication.
  final int? publishedAt;

  /// Nostr event kind (typically 34236 for vertical videos).
  final int kind;

  /// The `d` tag value (addressable event identifier).
  final String dTag;

  /// Video title.
  final String title;

  /// Video description from event content (NIP-71).
  final String? description;

  /// Thumbnail URL.
  final String thumbnail;

  /// Video URL.
  final String videoUrl;

  /// Content hash for Blossom authentication.
  final String? sha256;

  /// Display name of classic Vine author.
  final String? authorName;

  /// Profile picture URL for author.
  final String? authorAvatar;

  /// Blurhash for placeholder thumbnail.
  final String? blurhash;

  /// Reaction/like count.
  final int reactions;

  /// Comment count.
  final int comments;

  /// Repost count.
  final int reposts;

  /// Combined engagement score.
  final int engagementScore;

  /// Trending score (if available).
  final double? trendingScore;

  /// Original loop count for classic Vines.
  final int? loops;

  /// Live/new view count from Funnelcake analytics.
  final int? views;

  /// All Nostr event tags as a flat map, preserving tags (like ProofMode,
  /// C2PA, verification) that don't have dedicated fields on this model.
  final Map<String, String> rawTags;

  /// Converts this [VideoStats] to a [VideoEvent] for use in the app.
  ///
  /// Maps the Funnelcake API response fields to the corresponding
  /// [VideoEvent] fields used throughout the application.
  ///
  /// Uses [publishedAt] as the effective timestamp when available,
  /// falling back to [createdAt].
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
      vineId: normalizedDTag.isNotEmpty ? normalizedDTag : null,
      publishedAt: publishedAt?.toString(),
      sha256: sha256,
      authorName: authorName,
      authorAvatar: authorAvatar,
      blurhash: blurhash,
      originalLikes: reactions,
      originalComments: comments,
      originalReposts: reposts,
      originalLoops: loops,
      rawTags: {
        ...rawTags,
        if (loops != null) 'loops': loops.toString(),
        if (views != null) 'views': views.toString(),
      },
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VideoStats && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'VideoStats(id: $id, title: $title)';
}

/// Safely parses a dynamic value to double.
double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

int _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
