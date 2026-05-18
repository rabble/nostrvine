// ABOUTME: Result model for Explore Popular's v2 popular feed path.
// ABOUTME: Carries videos plus cursor metadata so provider state can
// ABOUTME: continue server-backed pagination across client-side filtering.

import 'package:equatable/equatable.dart';
import 'package:models/models.dart';

/// Result of a popular-feed fetch, including pagination metadata.
class PopularVideosPage extends Equatable {
  /// Creates a popular page result.
  const PopularVideosPage({
    required this.videos,
    required this.hasMore,
    this.nextCursor,
  });

  /// Videos for the requested page.
  final List<VideoEvent> videos;

  /// Whether the upstream feed can continue from [nextCursor].
  final bool hasMore;

  /// Cursor for the next page request.
  final String? nextCursor;

  @override
  List<Object?> get props => [videos, hasMore, nextCursor];
}
