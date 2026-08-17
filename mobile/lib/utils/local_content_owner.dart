// ABOUTME: Resolves which account owns locally recorded drafts and clips
// ABOUTME: Prefers the live session, then the device's pending one, then anonymous

import 'package:openvine/services/auth/known_accounts_registry.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preference holding the account this device is signed into.
///
/// Written on every successful `_setupUserSession` and removed on sign-out, so
/// its presence — not the live auth state — is what says "there is an account
/// here".
///
/// Its *value* is a weaker signal than its presence, because
/// `AuthService._reconnectBunker` and `_reconnectAmber` establish a session
/// without going through `_setupUserSession` and so never update it. See
/// [resolveLocalContentOwnerPubkey].
const currentUserPubkeyHexPrefKey = 'current_user_pubkey_hex';

/// Owner pubkey to stamp on drafts and clips created on this device.
///
/// [currentPubkeyHex] wins whenever a session is live. It is null while one is
/// still being restored, which offline is not a brief window at all: a bunker
/// or Keycast reconnect runs into the startup timeout and the session never
/// arrives. [currentUserPubkeyHexPrefKey] still names an account throughout, so
/// recordings can stay attributed to their owner instead of parking under
/// [DraftStorageService.anonymousOwnerPubkey] — where every owner-scoped query
/// hides them until a later sign-in's legacy-row claim happens to rescue them.
///
/// The preference alone is not enough to name *which* account, though. Only
/// `_setupUserSession` writes it, and the bunker and Amber reconnect paths
/// bypass that, so after switching from account A to a bunker or Amber account
/// B the preference still reads A while B is signed in. Stamping A there would
/// be worse than the marker it replaces: the automatic claim matches
/// `owner IS NULL OR owner = '<anonymous marker>'`, and a real foreign pubkey
/// matches neither, so B would never get the recording back on its own.
///
/// So the value is only used when the registry agrees that this device was last
/// active as that account. Every successful session bumps `lastUsedAt`,
/// reconnects included, which is what makes it a signal the preference is not.
/// When the two disagree the anonymous marker is correct — it is what shipped
/// before this fix, and the next sign-in claims it automatically.
///
/// A device with no registry at all falls back to trusting the preference: the
/// disagreement needs an account switch, switching goes through the picker, and
/// the picker is what writes the registry in the first place.
String resolveLocalContentOwnerPubkey({
  required String? currentPubkeyHex,
  required SharedPreferences preferences,
}) {
  if (currentPubkeyHex != null && currentPubkeyHex.isNotEmpty) {
    return currentPubkeyHex;
  }

  final signedInPubkeyHex = preferences.getString(currentUserPubkeyHexPrefKey);
  if (signedInPubkeyHex != null && signedInPubkeyHex.isNotEmpty) {
    final lastActivePubkeyHex = KnownAccountsRegistry.mostRecentlyUsedPubkeyHex(
      preferences,
    );
    if (lastActivePubkeyHex == null ||
        lastActivePubkeyHex == signedInPubkeyHex) {
      return signedInPubkeyHex;
    }
  }

  return DraftStorageService.anonymousOwnerPubkey;
}
