// ABOUTME: Result model for Explore Popular's native-only feed path.
// ABOUTME: Carries videos plus pagination metadata so provider state
// ABOUTME: can preserve server pagination semantics across filtering.

import 'package:equatable/equatable.dart';
import 'package:models/models.dart';

/// Result of a native-popular fetch, including pagination metadata.
class NativePopularVideosPage extends Equatable {
  /// Creates a native-popular page result.
  const NativePopularVideosPage({
    required this.videos,
    this.consumedItemCount,
    this.nextOffset,
  });

  /// Videos for the requested page.
  final List<VideoEvent> videos;

  /// Number of raw upstream items consumed to produce [videos].
  final int? consumedItemCount;

  /// Next raw leaderboard offset to request when using the native endpoint.
  final int? nextOffset;

  @override
  List<Object?> get props => [
    videos,
    consumedItemCount,
    nextOffset,
  ];
}
