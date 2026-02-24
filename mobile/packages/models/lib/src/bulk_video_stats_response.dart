import 'package:meta/meta.dart';
import 'package:models/src/bulk_video_stats_entry.dart';

/// Response from the bulk video stats endpoint.
///
/// Contains a map of event IDs to their engagement stats.
@immutable
class BulkVideoStatsResponse {
  /// Creates a new [BulkVideoStatsResponse].
  const BulkVideoStatsResponse({required this.stats});

  /// Stats keyed by Nostr event ID.
  final Map<String, BulkVideoStatsEntry> stats;
}
