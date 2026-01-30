import 'package:flutter/foundation.dart';

/// Configuration for video pool and preloading.
@immutable
class VideoPoolConfig {
  /// Creates a video pool configuration.
  const VideoPoolConfig({
    this.maxPlayers = 5,
    this.preloadAhead = 2,
    this.preloadBehind = 1,
  }) : assert(maxPlayers >= 1, 'maxPlayers must be at least 1'),
       assert(preloadAhead >= 0, 'preloadAhead must be non-negative'),
       assert(preloadBehind >= 0, 'preloadBehind must be non-negative');

  /// Maximum number of players in the pool.
  final int maxPlayers;

  /// Number of videos to preload ahead of current.
  final int preloadAhead;

  /// Number of videos to preload behind current.
  final int preloadBehind;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VideoPoolConfig &&
          other.maxPlayers == maxPlayers &&
          other.preloadAhead == preloadAhead &&
          other.preloadBehind == preloadBehind);

  @override
  int get hashCode => Object.hash(maxPlayers, preloadAhead, preloadBehind);
}
