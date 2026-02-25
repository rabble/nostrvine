// ABOUTME: Service to clear user-specific cached data when identity changes
// ABOUTME: Prevents data leakage between different Nostr accounts after reinstall

import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to clean up user-specific data from SharedPreferences.
///
/// When a user reinstalls the app (without proper logout) and creates a new
/// identity, cached data from the previous user may persist. This service
/// detects identity changes and clears user-specific data to prevent
/// data leakage between accounts.
class UserDataCleanupService {
  UserDataCleanupService(this._prefs);

  final SharedPreferences _prefs;

  /// Keys that store user-specific data and should be cleared on identity change.
  /// Device/app settings like relay URLs, analytics preferences are NOT included.
  static const List<String> userSpecificKeys = [
    // List services
    'curated_lists',
    'subscribed_list_ids',
    'user_lists',
    // Bookmark services
    'bookmark_sets',
    'global_bookmarks',
    'bookmark_published_hashes',
    'bookmark_pending_changes',
    // Mute/moderation services
    'muted_items',
    'content_moderation_local_mutes',
    'content_moderation_subscribed_lists',
    // Content history
    'content_reports_history',
    'content_deletions_history',
    // Viewing history
    'seen_video_ids',
    'seen_video_metrics',
    // Drafts
    'vine_drafts',
    // Labeler subscriptions
    'subscribed_labelers',
    'label_cache',
    // Report aggregation
    'trusted_reporters',
    'report_cache',
    // TOS acceptance (user must re-accept on new account)
    'age_verified_16_plus',
    'terms_accepted_at',
  ];

  /// Key prefixes for dynamic user-specific data (keys that embed pubkey/npub).
  /// Only cleared on identity change (different user), NOT on same-user logout.
  /// These caches are keyed by pubkey so they can't leak between users, and the
  /// redirect logic needs following_list_ at login time before relay responds.
  static const List<String> identityChangePrefixes = [
    'following_list_', // follow cache per pubkey
    'relay_discovery_', // relay discovery cache per npub
  ];

  /// Checks if user-specific data should be cleared for the given pubkey.
  ///
  /// Returns true if:
  /// - A different user was previously logged in (pubkey mismatch)
  /// - No pubkey stored but user-specific data exists (orphaned data)
  ///
  /// Returns false if:
  /// - Same user is logging in (pubkey matches)
  /// - Fresh install with no existing data
  bool shouldClearDataForUser(String currentPubkeyHex) {
    final storedPubkey = _prefs.getString('current_user_pubkey_hex');

    // If same user, no cleanup needed
    if (storedPubkey == currentPubkeyHex) {
      return false;
    }

    // If different user was stored, cleanup needed
    if (storedPubkey != null && storedPubkey != currentPubkeyHex) {
      return true;
    }

    // No stored pubkey - check if orphaned user data exists
    for (final key in userSpecificKeys) {
      if (_prefs.containsKey(key)) {
        return true;
      }
    }

    // Fresh install, no cleanup needed
    return false;
  }

  /// Clears all user-specific data from SharedPreferences.
  ///
  /// This removes cached lists, bookmarks, mutes, viewing history,
  /// and other user-specific data while preserving device/app settings
  /// like relay URLs, analytics preferences, etc.
  ///
  /// Returns the number of keys that were cleared for tracking purposes.
  /// Clears user-specific data from SharedPreferences.
  ///
  /// When [isIdentityChange] is true (different user logging in), also clears
  /// dynamic pubkey-keyed caches (following_list_, relay/blossom discovery).
  /// On same-user logout these are preserved so the redirect logic can use them
  /// at login time before relay data is available.
  Future<int> clearUserSpecificData({
    String? reason,
    bool isIdentityChange = false,
  }) async {
    final cleanupReason = reason ?? 'unspecified';
    Log.info(
      'Starting user data cleanup (reason: $cleanupReason, '
      'identityChange: $isIdentityChange, '
      'checking ${userSpecificKeys.length} keys'
      '${isIdentityChange ? ' + ${identityChangePrefixes.length} prefixes' : ''})',
      name: 'UserDataCleanupService',
      category: LogCategory.auth,
    );

    int clearedCount = 0;
    final clearedKeys = <String>[];

    // Clear exact-match keys (always)
    for (final key in userSpecificKeys) {
      if (_prefs.containsKey(key)) {
        await _prefs.remove(key);
        clearedCount++;
        clearedKeys.add(key);
      }
    }

    // Clear prefix-matched dynamic keys only on identity change
    // These are keyed by pubkey so they can't leak, and the redirect
    // logic needs following_list_ at login time before relay responds
    if (isIdentityChange) {
      final allKeys = _prefs.getKeys();
      for (final key in allKeys) {
        for (final prefix in identityChangePrefixes) {
          if (key.startsWith(prefix)) {
            await _prefs.remove(key);
            clearedCount++;
            clearedKeys.add(key);
            break;
          }
        }
      }
    }

    // Log detailed cleanup results for observability
    if (clearedCount > 0) {
      Log.info(
        'User data cleanup complete: cleared $clearedCount entries',
        name: 'UserDataCleanupService',
        category: LogCategory.auth,
      );
      Log.debug(
        'Cleared keys: ${clearedKeys.join(", ")}',
        name: 'UserDataCleanupService',
        category: LogCategory.auth,
      );
    } else {
      Log.debug(
        'User data cleanup: no data to clear',
        name: 'UserDataCleanupService',
        category: LogCategory.auth,
      );
    }

    return clearedCount;
  }
}
