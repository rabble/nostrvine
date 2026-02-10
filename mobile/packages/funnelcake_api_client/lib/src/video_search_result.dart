// ABOUTME: Lightweight model for Funnelcake /api/search endpoint response.
// ABOUTME: Contains video metadata for grid display but NOT video URLs.
// ABOUTME: Can convert to stub VideoEvent via toVideoEvent().

import 'package:meta/meta.dart';
import 'package:models/models.dart' show VideoEvent;

/// A video search result from the Funnelcake `/api/search` endpoint.
///
/// This is a lightweight model representing the flat response format:
/// ```json
/// {
///   "event_id": "04c8316e...",
///   "hashtag": "vine",
///   "created_at": 1766887545,
///   "pubkey": "2440b9ee...",
///   "kind": 34236,
///   "title": "Late Night Cope",
///   "thumbnail": "https://media.divine.video/...",
///   "d_tag": "c27596c3...",
///   "author_name": "",
///   "author_avatar": ""
/// }
/// ```
///
/// Note: This response does NOT include `video_url`. To get playable
/// video events, build an addressable ID from [kind], [pubkey], and
/// [dTag], then fetch the full event via relay or Funnelcake.
@immutable
class VideoSearchResult {
  /// Creates a new [VideoSearchResult].
  const VideoSearchResult({
    required this.eventId,
    required this.pubkey,
    required this.kind,
    required this.dTag,
    required this.createdAt,
    this.hashtag,
    this.title,
    this.thumbnail,
    this.authorName,
    this.authorAvatar,
  });

  /// Parses a [VideoSearchResult] from the JSON response.
  ///
  /// Handles both the actual API response format (`event_id`) and the
  /// Swagger-documented format (`id`).
  factory VideoSearchResult.fromJson(Map<String, dynamic> json) {
    // Handle both `event_id` (actual) and `id` (swagger spec)
    final eventId =
        json['event_id']?.toString() ?? json['id']?.toString() ?? '';

    return VideoSearchResult(
      eventId: eventId,
      pubkey: json['pubkey']?.toString() ?? '',
      kind: (json['kind'] as int?) ?? 34236,
      dTag: json['d_tag']?.toString() ?? '',
      createdAt: (json['created_at'] as int?) ?? 0,
      hashtag: json['hashtag']?.toString(),
      title: _nonEmpty(json['title']?.toString()),
      thumbnail: _nonEmpty(json['thumbnail']?.toString()),
      authorName: _nonEmpty(json['author_name']?.toString()),
      authorAvatar: _nonEmpty(json['author_avatar']?.toString()),
    );
  }

  /// Nostr event ID.
  final String eventId;

  /// Author's public key (hex format).
  final String pubkey;

  /// Nostr event kind (typically 34236 for vertical videos).
  final int kind;

  /// The `d` tag value (addressable event identifier).
  final String dTag;

  /// Unix timestamp when the video was created.
  final int createdAt;

  /// The hashtag this result matched.
  final String? hashtag;

  /// Video title.
  final String? title;

  /// Thumbnail URL.
  final String? thumbnail;

  /// Display name of author.
  final String? authorName;

  /// Profile picture URL for author.
  final String? authorAvatar;

  /// Builds the Nostr addressable ID (`kind:pubkey:dTag`).
  ///
  /// Used with `VideosRepository.getVideosByAddressableIds` to fetch
  /// the full video event with playable URL.
  String get addressableId => '$kind:$pubkey:$dTag';

  /// Converts this search result to a stub [VideoEvent].
  ///
  /// The resulting event has metadata (thumbnail, title, author) but
  /// an empty [VideoEvent.videoUrl]. Use this for grid display where
  /// only thumbnails are needed. Fetch the full event via addressable
  /// ID when the video URL is required for playback.
  VideoEvent toVideoEvent() {
    return VideoEvent(
      id: eventId,
      pubkey: pubkey,
      createdAt: createdAt,
      content: '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
      title: title,
      thumbnailUrl: thumbnail,
      vineId: dTag,
      hashtags: hashtag != null ? [hashtag!] : const [],
      authorName: authorName,
      authorAvatar: authorAvatar,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VideoSearchResult && other.eventId == eventId;
  }

  @override
  int get hashCode => eventId.hashCode;

  @override
  String toString() =>
      'VideoSearchResult(eventId: $eventId, dTag: $dTag, title: $title)';
}

/// Returns null for empty strings, otherwise the string.
String? _nonEmpty(String? value) {
  if (value == null || value.isEmpty) return null;
  return value;
}
