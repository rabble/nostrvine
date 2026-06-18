// ABOUTME: Persists per-pubkey DM sync boundaries so subsequent inbox
// ABOUTME: opens can fetch only new events via a `since:` filter.
//
// Stores per user pubkey in SharedPreferences:
//   - newestSyncedAt: highest `created_at` successfully processed
//   - oldestSyncedAt: lowest `created_at` successfully processed
//   - historyDrainComplete: whether the one-time full-history drain is done
//   - historyDrainCursor: the drain's resumable pagination boundary
//
// Timestamps are unix seconds matching Nostr event timestamps. Used by
// DmRepository to bound subscription and pagination queries so cost is
// proportional to recent activity, not lifetime message count.
// See docs/plans/2026-04-05-dm-scaling-fix-design.md.

import 'package:shared_preferences/shared_preferences.dart';

/// Persists per-pubkey DM sync boundaries in SharedPreferences.
class DmSyncState {
  /// Creates a [DmSyncState] backed by [_prefs].
  DmSyncState(this._prefs);
  final SharedPreferences _prefs;

  static const _newestPrefix = 'dm.newestSyncedAt.';
  static const _oldestPrefix = 'dm.oldestSyncedAt.';
  static const _drainCompletePrefix = 'dm.historyDrainComplete.';
  static const _drainCursorPrefix = 'dm.historyDrainCursor.';
  static const _drainVersionPrefix = 'dm.historyDrainVersion.';

  /// Current history-drain logic version. Installs whose persisted
  /// [drainVersion] is below this re-run the drain once, even if
  /// [historyDrainComplete] is already `true` — this unsticks installs that
  /// completed under an older, buggy drain that could mark complete without
  /// fully recovering history (a cold-start empty page, or a wrap a prior run
  /// failed to decrypt). The re-drain re-fetches and re-decrypts whatever the
  /// relays still serve; gift wraps a relay has since pruned cannot be
  /// recovered (inherent reinstall-recovery limit). Pre-#5202 installs have no
  /// version key (reads as 0). Bump this whenever a drain-correctness fix must
  /// force one more recovery pass. See #5202.
  ///
  /// Bumped to 3 for #5304: combined with the recovery-aware request gate and
  /// the NIP-04 `authors:[self]` recovery pass, a single forced re-drain
  /// unsticks installs whose earlier drain completed before the user's own
  /// historical messages were recovered — which had stranded established chats
  /// under "Message requests".
  static const int currentDrainVersion = 3;

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

  /// Whether the one-time full-history drain has completed for [pubkey].
  ///
  /// `false` after a reinstall (SharedPreferences is wiped) or account
  /// switch, which is what arms `DmRepository.backfillHistoryIfNeeded` to
  /// re-fetch the full conversation backlog. Distinct from
  /// [newestSyncedAt]/[oldestSyncedAt], which the live subscription
  /// advances on its very first event and therefore cannot gate a
  /// "did we drain everything" decision. See #4953.
  bool historyDrainComplete(String pubkey) =>
      _prefs.getBool('$_drainCompletePrefix$pubkey') ?? false;

  /// Records that the one-time full-history drain finished cleanly for
  /// [pubkey] so it never runs again until the state is cleared. Also
  /// clears the resume cursor, which is only meaningful for an
  /// in-progress drain.
  Future<void> markHistoryDrainComplete(String pubkey) async {
    await _prefs.setBool('$_drainCompletePrefix$pubkey', true);
    await _prefs.remove('$_drainCursorPrefix$pubkey');
  }

  /// The history-drain logic version last completed for [pubkey], or `0`
  /// if none has been recorded (pre-#5202 installs, fresh installs).
  int drainVersion(String pubkey) =>
      _prefs.getInt('$_drainVersionPrefix$pubkey') ?? 0;

  /// Records that [pubkey] has been brought up to drain logic [version].
  Future<void> setDrainVersion(String pubkey, int version) async {
    await _prefs.setInt('$_drainVersionPrefix$pubkey', version);
  }

  /// Forces a one-time re-drain for [pubkey] when its persisted
  /// [drainVersion] is below [currentDrainVersion], by clearing the
  /// completion flag and resume cursor, then stamping the current version.
  ///
  /// This is the recovery path for installs stranded by an older drain that
  /// marked [historyDrainComplete] without fully recovering history (#5202).
  /// A no-op for fresh installs (nothing to clear) and for installs already
  /// at the current version. Idempotent: after the bump the version matches,
  /// so it does not loop on every inbox open.
  Future<void> upgradeDrainVersionIfNeeded(String pubkey) async {
    if (drainVersion(pubkey) >= currentDrainVersion) return;
    await _prefs.remove('$_drainCompletePrefix$pubkey');
    await _prefs.remove('$_drainCursorPrefix$pubkey');
    await setDrainVersion(pubkey, currentDrainVersion);
  }

  /// The outer gift-wrap `created_at` (unix seconds) the history drain has
  /// paged down to for [pubkey], or `null` if no drain has persisted a
  /// boundary yet.
  ///
  /// The drain persists this after every page so an interrupted or
  /// page-capped run resumes from the exact boundary on the next inbox
  /// open instead of restarting from [oldestSyncedAt] (and, on a page-cap,
  /// instead of permanently truncating older history). Tracks the
  /// randomized **outer** gift-wrap timestamp that the relay's `until:`
  /// filters on — not the rumor times in [oldestSyncedAt]. Cleared once
  /// the drain completes or the state is reset. See #4953.
  int? historyDrainCursor(String pubkey) =>
      _prefs.getInt('$_drainCursorPrefix$pubkey');

  /// Persists the history drain's pagination [cursor] (an outer gift-wrap
  /// `created_at` in unix seconds) for [pubkey] so the next run resumes
  /// from it.
  Future<void> setHistoryDrainCursor(String pubkey, int cursor) async {
    await _prefs.setInt('$_drainCursorPrefix$pubkey', cursor);
  }

  /// Removes all sync state for [pubkey]. Called on account switch.
  Future<void> clear(String pubkey) async {
    await _prefs.remove('$_newestPrefix$pubkey');
    await _prefs.remove('$_oldestPrefix$pubkey');
    await _prefs.remove('$_drainCompletePrefix$pubkey');
    await _prefs.remove('$_drainCursorPrefix$pubkey');
    await _prefs.remove('$_drainVersionPrefix$pubkey');
  }

  /// Removes all DM sync state entries for every pubkey.
  ///
  /// Called during database cleanup to ensure the next login triggers a
  /// full re-sync from relays instead of using stale `since:` cursors.
  Future<void> clearAll() async {
    final keysToRemove = _prefs
        .getKeys()
        .where(
          (key) =>
              key.startsWith(_newestPrefix) ||
              key.startsWith(_oldestPrefix) ||
              key.startsWith(_drainCompletePrefix) ||
              key.startsWith(_drainCursorPrefix) ||
              key.startsWith(_drainVersionPrefix),
        )
        .toList();
    for (final key in keysToRemove) {
      await _prefs.remove(key);
    }
  }
}
