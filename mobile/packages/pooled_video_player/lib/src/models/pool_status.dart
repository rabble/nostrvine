import 'package:flutter/foundation.dart';

/// Immutable snapshot of pool status for monitoring and debugging.
///
/// This provides visibility into the current state of the player pool
/// without exposing internal implementation details.
@immutable
class PoolStatus {
  /// Creates a pool status snapshot.
  const PoolStatus({
    required this.availablePlayers,
    required this.inUsePlayers,
    required this.totalPlayers,
    required this.maxPoolSize,
    required this.maxTotalPlayers,
    required this.activeLeaseCount,
    required this.registeredFeedCount,
    required this.isMemoryConstrained,
  });

  /// Number of players available in the pool for immediate reuse.
  final int availablePlayers;

  /// Number of players currently in use.
  final int inUsePlayers;

  /// Total players currently managed (available + in use).
  final int totalPlayers;

  /// Maximum size of the available player pool.
  final int maxPoolSize;

  /// Maximum total players allowed.
  final int maxTotalPlayers;

  /// Number of active leases across all feeds.
  final int activeLeaseCount;

  /// Number of registered feed controllers.
  final int registeredFeedCount;

  /// Whether the system has reported memory pressure.
  final bool isMemoryConstrained;

  /// Percentage of pool capacity in use (0.0 to 1.0).
  double get utilizationPercent =>
      maxTotalPlayers > 0 ? inUsePlayers / maxTotalPlayers : 0.0;

  /// Whether the pool is near capacity (>80% utilized).
  bool get isNearCapacity => utilizationPercent > 0.8;

  /// Whether the pool is at maximum capacity.
  bool get isAtCapacity => inUsePlayers >= maxTotalPlayers;

  @override
  String toString() =>
      'PoolStatus('
      'available: $availablePlayers, '
      'inUse: $inUsePlayers, '
      'total: $totalPlayers, '
      'leases: $activeLeaseCount, '
      'feeds: $registeredFeedCount, '
      'memoryConstrained: $isMemoryConstrained)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PoolStatus &&
          other.availablePlayers == availablePlayers &&
          other.inUsePlayers == inUsePlayers &&
          other.totalPlayers == totalPlayers &&
          other.maxPoolSize == maxPoolSize &&
          other.maxTotalPlayers == maxTotalPlayers &&
          other.activeLeaseCount == activeLeaseCount &&
          other.registeredFeedCount == registeredFeedCount &&
          other.isMemoryConstrained == isMemoryConstrained);

  @override
  int get hashCode => Object.hash(
    availablePlayers,
    inUsePlayers,
    totalPlayers,
    maxPoolSize,
    maxTotalPlayers,
    activeLeaseCount,
    registeredFeedCount,
    isMemoryConstrained,
  );
}
