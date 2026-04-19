// ABOUTME: Iterable extensions for filtering VideoEvent collections.
// ABOUTME: Provides reusable filters for expiration and related concerns.

import 'package:models/src/video_event.dart';

/// Filters applied uniformly to any [VideoEvent] stream entering the UI.
extension VideoEventIterableFilters on Iterable<VideoEvent> {
  /// Drops videos whose NIP-40 `expiration` timestamp has passed.
  ///
  /// Use this at every ingress point (REST responses, relay subscriptions,
  /// cache reads) so the app never renders content the server considers
  /// expired.
  Iterable<VideoEvent> whereNotExpired() => where((v) => !v.isExpired);
}
