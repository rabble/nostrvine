// ABOUTME: Iterable extensions for converting VideoStats into VideoEvents
// ABOUTME: with the standard client-side filtering applied.

import 'package:models/src/video_event.dart';
import 'package:models/src/video_stats.dart';

/// Filters applied uniformly to any [VideoEvent] stream entering the UI.
extension VideoStatsIterableFilters on Iterable<VideoStats> {
  /// Converts each [VideoStats] to a [VideoEvent] and drops videos whose
  /// NIP-40 `expiration` timestamp has already passed.
  ///
  /// Use this at every REST ingress point so the app never renders content
  /// the server considers expired. If a future filter is needed (e.g.
  /// blocklist, content warnings), chain it on the returned list rather than
  /// adding parameters here.
  List<VideoEvent> toVideoEvents() =>
      map((s) => s.toVideoEvent()).where((v) => !v.isExpired).toList();
}
