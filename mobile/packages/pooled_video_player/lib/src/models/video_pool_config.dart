import 'package:flutter/foundation.dart';

import 'package:pooled_video_player/src/constants/pool_constants.dart';
import 'package:pooled_video_player/src/controllers/player_pool_manager.dart';
import 'package:pooled_video_player/src/controllers/video_feed_controller.dart';
import 'package:pooled_video_player/src/utils/device_memory_util.dart';

/// Configuration for video pool controllers.
///
/// Allows customization of preloading behavior, pool sizes, timing,
/// and error retry behavior.
/// Used by [PlayerPoolManager] and [VideoFeedController].
@immutable
class VideoPoolConfig {
  /// Creates a video pool configuration with custom values.
  ///
  /// Throws [AssertionError] in debug mode if values are invalid:
  /// - [preloadAhead] and [preloadBehind] must be non-negative
  /// - [maxActivePlayers] and [poolSize] must be at least 1
  /// - [poolSize] must not exceed [maxActivePlayers]
  /// - [maxRetryAttempts] must be non-negative
  const VideoPoolConfig({
    this.preloadAhead = 2,
    this.preloadBehind = 1,
    this.maxActivePlayers = 5,
    this.poolSize = 3,
    this.preloadDebounceDelay = const Duration(milliseconds: 150),
    this.maxRetryAttempts = 3,
    this.initialRetryDelay = const Duration(milliseconds: 500),
    this.maxRetryDelay = const Duration(seconds: 8),
    this.retryBackoffMultiplier = 2.0,
    this.enableAutoRetry = true,
  }) : assert(preloadAhead >= 0, 'preloadAhead must be non-negative'),
       assert(preloadBehind >= 0, 'preloadBehind must be non-negative'),
       assert(maxActivePlayers >= 1, 'maxActivePlayers must be at least 1'),
       assert(poolSize >= 1, 'poolSize must be at least 1'),
       assert(
         poolSize <= maxActivePlayers,
         'poolSize must not exceed maxActivePlayers',
       ),
       assert(maxRetryAttempts >= 0, 'maxRetryAttempts must be non-negative'),
       assert(
         retryBackoffMultiplier >= 1.0,
         'retryBackoffMultiplier must be at least 1.0',
       );

  /// Creates a configuration optimized for the given memory tier.
  ///
  /// - Low tier: Smaller pool and preload window for limited memory
  /// - Medium tier: Balanced configuration for mid-range devices
  /// - High tier: Larger pool and preload window for high-end devices
  factory VideoPoolConfig.forTier(MemoryTier tier) => switch (tier) {
    MemoryTier.low => const VideoPoolConfig(
      poolSize: MemoryTierConfig.lowMemoryPoolSize,
      preloadAhead: MemoryTierConfig.lowMemoryPreloadAhead,
      maxActivePlayers: MemoryTierConfig.lowMemoryMaxActivePlayers,
    ),
    MemoryTier.medium => const VideoPoolConfig(),
    MemoryTier.high => const VideoPoolConfig(
      poolSize: MemoryTierConfig.highMemoryPoolSize,
      preloadAhead: MemoryTierConfig.highMemoryPreloadAhead,
      preloadBehind: MemoryTierConfig.highMemoryPreloadBehind,
      maxActivePlayers: MemoryTierConfig.highMemoryMaxActivePlayers,
    ),
  };

  /// Number of videos to preload ahead of current index.
  final int preloadAhead;

  /// Number of videos to preload behind current index.
  final int preloadBehind;

  /// Maximum number of active players at once.
  final int maxActivePlayers;

  /// Size of the player pool for reuse.
  final int poolSize;

  /// Debounce delay for preloading during fast scrolling.
  final Duration preloadDebounceDelay;

  /// Maximum number of automatic retry attempts for failed preloads.
  final int maxRetryAttempts;

  /// Initial delay before first retry attempt.
  final Duration initialRetryDelay;

  /// Maximum delay between retry attempts (caps exponential backoff).
  final Duration maxRetryDelay;

  /// Multiplier for exponential backoff (delay = initial * multiplier^attempt).
  final double retryBackoffMultiplier;

  /// Whether to automatically retry failed preloads.
  final bool enableAutoRetry;

  /// Creates a copy with the given fields replaced.
  VideoPoolConfig copyWith({
    int? preloadAhead,
    int? preloadBehind,
    int? maxActivePlayers,
    int? poolSize,
    Duration? preloadDebounceDelay,
    int? maxRetryAttempts,
    Duration? initialRetryDelay,
    Duration? maxRetryDelay,
    double? retryBackoffMultiplier,
    bool? enableAutoRetry,
  }) {
    return VideoPoolConfig(
      preloadAhead: preloadAhead ?? this.preloadAhead,
      preloadBehind: preloadBehind ?? this.preloadBehind,
      maxActivePlayers: maxActivePlayers ?? this.maxActivePlayers,
      poolSize: poolSize ?? this.poolSize,
      preloadDebounceDelay: preloadDebounceDelay ?? this.preloadDebounceDelay,
      maxRetryAttempts: maxRetryAttempts ?? this.maxRetryAttempts,
      initialRetryDelay: initialRetryDelay ?? this.initialRetryDelay,
      maxRetryDelay: maxRetryDelay ?? this.maxRetryDelay,
      retryBackoffMultiplier:
          retryBackoffMultiplier ?? this.retryBackoffMultiplier,
      enableAutoRetry: enableAutoRetry ?? this.enableAutoRetry,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VideoPoolConfig &&
          other.preloadAhead == preloadAhead &&
          other.preloadBehind == preloadBehind &&
          other.maxActivePlayers == maxActivePlayers &&
          other.poolSize == poolSize &&
          other.preloadDebounceDelay == preloadDebounceDelay &&
          other.maxRetryAttempts == maxRetryAttempts &&
          other.initialRetryDelay == initialRetryDelay &&
          other.maxRetryDelay == maxRetryDelay &&
          other.retryBackoffMultiplier == retryBackoffMultiplier &&
          other.enableAutoRetry == enableAutoRetry);

  @override
  int get hashCode => Object.hash(
    preloadAhead,
    preloadBehind,
    maxActivePlayers,
    poolSize,
    preloadDebounceDelay,
    maxRetryAttempts,
    initialRetryDelay,
    maxRetryDelay,
    retryBackoffMultiplier,
    enableAutoRetry,
  );
}
