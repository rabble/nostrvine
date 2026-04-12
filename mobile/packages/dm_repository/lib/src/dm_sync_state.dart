// ABOUTME: Persists per-pubkey DM sync boundaries so subsequent inbox
// ABOUTME: opens can fetch only new events via a `since:` filter.
//
// Stores two integers per user pubkey in SharedPreferences:
//   - newestSyncedAt: highest `created_at` successfully processed
//   - oldestSyncedAt: lowest `created_at` successfully processed
//
// Both values are unix seconds matching Nostr event timestamps. Used
// by DmRepository to bound subscription and pagination queries so
// cost is proportional to recent activity, not lifetime message count.
// See docs/plans/2026-04-05-dm-scaling-fix-design.md.

import 'package:shared_preferences/shared_preferences.dart';

/// Persists per-pubkey DM sync boundaries in SharedPreferences.
class DmSyncState {
  /// Creates a [DmSyncState] backed by [_prefs].
  DmSyncState(this._prefs);
  final SharedPreferences _prefs;

  static const _newestPrefix = 'dm.newestSyncedAt.';
  static const _oldestPrefix = 'dm.oldestSyncedAt.';

  /// Returns the newest (highest) `created_at` unix timestamp we have
  /// successfully processed for [pubkey], or `null` if nothing has been
  /// processed yet.
  int? newestSyncedAt(String pubkey) => _prefs.getInt('$_newestPrefix$pubkey');

  /// Returns the oldest (lowest) `created_at` unix timestamp we have
  /// successfully processed for [pubkey], or `null` if nothing has been
  /// processed yet.
  int? oldestSyncedAt(String pubkey) => _prefs.getInt('$_oldestPrefix$pubkey');

  /// Records that a DM with the given [createdAt] unix seconds has been
  /// successfully processed for [pubkey]. Advances `newestSyncedAt`
  /// upward and `oldestSyncedAt` downward monotonically — older events
  /// never roll back `newest`, and newer events never roll back `oldest`.
  Future<void> recordSeen(String pubkey, {required int createdAt}) async {
    final newest = newestSyncedAt(pubkey);
    if (newest == null || createdAt > newest) {
      await _prefs.setInt('$_newestPrefix$pubkey', createdAt);
    }
    final oldest = oldestSyncedAt(pubkey);
    if (oldest == null || createdAt < oldest) {
      await _prefs.setInt('$_oldestPrefix$pubkey', createdAt);
    }
  }

  /// Removes all sync state for [pubkey]. Called on account switch.
  Future<void> clear(String pubkey) async {
    await _prefs.remove('$_newestPrefix$pubkey');
    await _prefs.remove('$_oldestPrefix$pubkey');
  }
}
