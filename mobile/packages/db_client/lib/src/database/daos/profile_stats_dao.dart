// ABOUTME: Data Access Object for profile statistics cache operations.
// ABOUTME: Provides upsert with expiry checking.

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';

part 'profile_stats_dao.g.dart';

/// Default cache duration for profile stats (5 minutes)
const profileStatsCacheDuration = Duration(minutes: 5);

@DriftAccessor(tables: [ProfileStats, VanishedProfiles])
class ProfileStatsDao extends DatabaseAccessor<AppDatabase>
    with _$ProfileStatsDaoMixin {
  ProfileStatsDao(super.attachedDatabase);

  /// Upsert profile stats (insert or update).
  ///
  /// Only overwrites fields that are explicitly provided (non-null).
  /// Null parameters are left unchanged in the existing row, preventing
  /// partial REST responses from zeroing out previously cached values.
  ///
  /// No-ops for a pubkey carrying a `vanished_profiles` tombstone, so counters
  /// cannot be re-cached for an account that asked to be erased. Same rule and
  /// same reason as `UserProfilesDao.upsertProfile`: the writers span layers
  /// that cannot all reach `ProfileRepository` — the classic-viner seed import
  /// re-runs on every manifest bump.
  Future<void> upsertStats({
    required String pubkey,
    int? videoCount,
    int? followerCount,
    int? followingCount,
    int? totalViews,
    int? totalLikes,
  }) async {
    final tombstone = await (select(
      vanishedProfiles,
    )..where((t) => t.pubkey.equals(pubkey))).getSingleOrNull();
    if (tombstone != null) return;

    final existing = await (select(
      profileStats,
    )..where((t) => t.pubkey.equals(pubkey))).getSingleOrNull();
    final countsUpdatedAt = followerCount != null || followingCount != null
        ? DateTime.now()
        : existing?.followerCountsUpdatedAt;

    final companion = ProfileStatsCompanion.insert(
      pubkey: pubkey,
      videoCount: Value(videoCount ?? existing?.videoCount),
      followerCount: Value(followerCount ?? existing?.followerCount),
      followingCount: Value(followingCount ?? existing?.followingCount),
      totalViews: Value(totalViews ?? existing?.totalViews),
      totalLikes: Value(totalLikes ?? existing?.totalLikes),
      cachedAt: DateTime.now(),
      followerCountsUpdatedAt: Value(countsUpdatedAt),
    );

    await into(profileStats).insertOnConflictUpdate(companion);
  }

  /// Get stats for a pubkey (returns null if not found or expired)
  Future<ProfileStatRow?> getStats(
    String pubkey, {
    Duration expiry = profileStatsCacheDuration,
  }) async {
    final query = select(profileStats)..where((t) => t.pubkey.equals(pubkey));
    final result = await query.getSingleOrNull();

    if (result == null) return null;

    // Check expiry
    final expiryTime = DateTime.now().subtract(expiry);
    if (result.cachedAt.isBefore(expiryTime)) {
      // Expired - delete and return null
      await deleteStats(pubkey);
      return null;
    }

    return result;
  }

  /// Delete stats for a pubkey
  Future<int> deleteStats(String pubkey) {
    return (delete(profileStats)..where((t) => t.pubkey.equals(pubkey))).go();
  }

  /// Delete all expired stats
  Future<int> deleteExpired({Duration expiry = profileStatsCacheDuration}) {
    final expiryTime = DateTime.now().subtract(expiry);
    return (delete(profileStats)..where(
          (t) => t.cachedAt.isSmallerThan(
            Variable(expiryTime),
          ),
        ))
        .go();
  }

  /// Read the stats row without expiry checking.
  ///
  /// Unlike [getStats], this never deletes expired rows.
  /// Use this when the consumer manages its own staleness logic
  /// (e.g., hysteresis with a custom stale duration).
  Future<ProfileStatRow?> getStatsRaw(String pubkey) async {
    final query = select(profileStats)..where((t) => t.pubkey.equals(pubkey));
    return query.getSingleOrNull();
  }

  /// Watch stats for a pubkey.
  ///
  /// Returns a stream that emits the current [ProfileStatRow] whenever
  /// the row changes in the database. Emits `null` if no row exists.
  ///
  /// Unlike [getStats], this does not check expiry — consumers are
  /// responsible for interpreting [ProfileStatRow.cachedAt].
  Stream<ProfileStatRow?> watchStats(String pubkey) {
    final query = select(profileStats)..where((t) => t.pubkey.equals(pubkey));
    return query.watchSingleOrNull();
  }

  /// Clear all profile stats
  Future<int> clearAll() {
    return delete(profileStats).go();
  }
}
