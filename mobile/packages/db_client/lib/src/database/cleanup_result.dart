// ABOUTME: Result model for database startup cleanup operations.
// ABOUTME: Contains counts of expired data deleted during cleanup.

/// Result of database startup cleanup operations.
///
/// Contains counts of how many expired/old records were deleted
/// from each table during the cleanup process.
class CleanupResult {
  /// Creates a cleanup result with the given deletion counts.
  const CleanupResult({
    required this.expiredEventsDeleted,
    required this.expiredProfileStatsDeleted,
    required this.expiredHashtagStatsDeleted,
    required this.oldNotificationsDeleted,
  });

  /// Number of expired Nostr events deleted (includes events with NULL expiry).
  final int expiredEventsDeleted;

  /// Number of expired profile stats deleted.
  final int expiredProfileStatsDeleted;

  /// Number of expired hashtag stats deleted.
  final int expiredHashtagStatsDeleted;

  /// Number of old notifications deleted.
  final int oldNotificationsDeleted;

  /// Total number of records deleted across all tables.
  int get totalDeleted =>
      expiredEventsDeleted +
      expiredProfileStatsDeleted +
      expiredHashtagStatsDeleted +
      oldNotificationsDeleted;

  @override
  String toString() {
    return 'CleanupResult('
        'events: $expiredEventsDeleted, '
        'profileStats: $expiredProfileStatsDeleted, '
        'hashtagStats: $expiredHashtagStatsDeleted, '
        'notifications: $oldNotificationsDeleted)';
  }
}
