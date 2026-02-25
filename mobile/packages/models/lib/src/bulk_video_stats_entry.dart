import 'package:meta/meta.dart';

/// Engagement stats for a single video from a bulk stats response.
///
/// Used when fetching stats for multiple videos at once from the
/// Funnelcake API's bulk endpoint.
@immutable
class BulkVideoStatsEntry {
  /// Creates a new [BulkVideoStatsEntry] instance.
  const BulkVideoStatsEntry({
    required this.eventId,
    required this.reactions,
    required this.comments,
    required this.reposts,
    this.loops,
    this.views,
  });

  /// Creates a [BulkVideoStatsEntry] from JSON response.
  ///
  /// Uses deep search to find stats values under various field names
  /// and nested structures returned by the Funnelcake API.
  factory BulkVideoStatsEntry.fromJson(Map<String, dynamic> json) {
    return BulkVideoStatsEntry(
      eventId: (json['event_id'] ?? json['id'] ?? '').toString(),
      reactions:
          _findIntDeep(json, {
            'reactions',
            'likes',
            'like_count',
            'total_likes',
          }) ??
          0,
      comments:
          _findIntDeep(json, {'comments', 'comment_count', 'total_comments'}) ??
          0,
      reposts:
          _findIntDeep(json, {'reposts', 'repost_count', 'total_reposts'}) ?? 0,
      loops: _findIntDeep(json, {
        'loops',
        'loop_count',
        'total_loops',
        'embedded_loops',
        'computed_loops',
      }),
      views: _findIntDeep(json, {
        'views',
        'view_count',
        'total_views',
        'unique_views',
        'unique_viewers',
      }),
    );
  }

  /// The Nostr event ID for this video.
  final String eventId;

  /// Reaction/like count.
  final int reactions;

  /// Comment count.
  final int comments;

  /// Repost count.
  final int reposts;

  /// Loop/play count (if available).
  final int? loops;

  /// View count (if available).
  final int? views;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BulkVideoStatsEntry && other.eventId == eventId;
  }

  @override
  int get hashCode => eventId.hashCode;

  @override
  String toString() =>
      'BulkVideoStatsEntry(eventId: $eventId, '
      'reactions: $reactions, comments: $comments)';
}

/// Safely parses a dynamic value to int, handling various formats.
int? _parseInt(dynamic value) {
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

/// Recursively searches a JSON structure for any key in [targetKeys]
/// and returns the first successfully parsed int value.
int? _findIntDeep(dynamic source, Set<String> targetKeys) {
  if (source is Map) {
    for (final entry in source.entries) {
      final key = entry.key.toString().toLowerCase();
      if (targetKeys.contains(key)) {
        final parsed = _parseInt(entry.value);
        if (parsed != null) return parsed;
      }
    }
    for (final value in source.values) {
      final result = _findIntDeep(value, targetKeys);
      if (result != null) return result;
    }
  } else if (source is List) {
    for (final value in source) {
      final result = _findIntDeep(value, targetKeys);
      if (result != null) return result;
    }
  }
  return null;
}
