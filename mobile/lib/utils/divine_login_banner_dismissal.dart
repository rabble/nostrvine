// ABOUTME: Per-account dismissal state for the Divine login banner.
// ABOUTME: Owns the preference key, the 30-day TTL, and the reads and writes.

import 'package:openvine/utils/local_content_owner.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How long a dismissal keeps the banner hidden.
const Duration divineLoginBannerDismissalTtl = Duration(days: 30);

const _dismissedDivineLoginBannerPrefix = 'dismissed_divine_login_banner_';

/// Whether the Divine login banner is hidden for one account.
///
/// Scoped to a single account at construction, so a call site cannot pair the
/// key with the wrong pubkey.
///
/// [isDismissed] is synchronous, and a [dismiss] is visible through it before
/// the returned future completes — `setInt` updates the in-memory
/// [SharedPreferences] cache synchronously. The session-expired sheet pops
/// before awaiting the write and depends on that ordering (#7297), so keep
/// both methods free of any debounce or extra async hop.
class DivineLoginBannerDismissalStore {
  const DivineLoginBannerDismissalStore({
    required SharedPreferences prefs,
    required String userIdHex,
  }) : _prefs = prefs,
       _userIdHex = userIdHex;

  final SharedPreferences _prefs;
  final String _userIdHex;

  /// Preference holding the dismissal timestamp for [userIdHex].
  static String keyFor(String userIdHex) =>
      '$_dismissedDivineLoginBannerPrefix$userIdHex';

  /// Preference holding this store's dismissal timestamp.
  String get key => keyFor(_userIdHex);

  /// Whether a dismissal is stored and still within
  /// [divineLoginBannerDismissalTtl] as of [now], defaulting to the wall clock.
  ///
  /// A missing or non-integer value reads as "not dismissed".
  bool isDismissed({DateTime? now}) {
    final rawValue = _prefs.get(key);
    if (rawValue is! int) {
      return false;
    }

    final dismissedAt = DateTime.fromMillisecondsSinceEpoch(rawValue);
    final comparisonTime = now ?? DateTime.now();
    return comparisonTime.difference(dismissedAt) <
        divineLoginBannerDismissalTtl;
  }

  /// Hides the banner as of [now], defaulting to the wall clock.
  Future<void> dismiss({DateTime? now}) {
    final dismissedAt = now ?? DateTime.now();
    return _prefs.setInt(key, dismissedAt.millisecondsSinceEpoch);
  }

  /// Drops the stored dismissal so the banner can show again.
  Future<void> clear() => _prefs.remove(key);
}

/// Clears the dismissal for [publicKeyHex], or for the account named by
/// [currentUserPubkeyHexPrefKey] when it is omitted.
///
/// Resolves [SharedPreferences] itself rather than taking one, because
/// `AuthService` holds no instance and calls this from five session-recovery
/// paths. Pass [publicKeyHex] whenever the caller knows it: the stored pubkey
/// is a weaker signal than it looks, as [currentUserPubkeyHexPrefKey]
/// documents.
Future<void> clearDismissedDivineLoginBannerForCurrentUser([
  String? publicKeyHex,
]) async {
  final prefs = await SharedPreferences.getInstance();
  final targetPubkey =
      publicKeyHex ?? prefs.getString(currentUserPubkeyHexPrefKey);
  if (targetPubkey == null || targetPubkey.isEmpty) {
    return;
  }
  await DivineLoginBannerDismissalStore(
    prefs: prefs,
    userIdHex: targetPubkey,
  ).clear();
}
