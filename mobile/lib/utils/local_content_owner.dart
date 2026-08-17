// ABOUTME: Resolves which account owns locally recorded drafts and clips
// ABOUTME: Prefers the live session, then the device's pending one, then anonymous

import 'package:openvine/services/draft_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preference holding the account this device is signed into.
///
/// Written on every successful session setup and removed on sign-out, so its
/// presence — not the live auth state — is what says "there is an account
/// here".
const currentUserPubkeyHexPrefKey = 'current_user_pubkey_hex';

/// Owner pubkey to stamp on drafts and clips created on this device.
///
/// [currentPubkeyHex] wins whenever a session is live. It is null while one is
/// still being restored, which offline is not a brief window at all: a bunker
/// or Keycast reconnect runs into the startup timeout and the session never
/// arrives. [currentUserPubkeyHexPrefKey] still names the account the device is
/// signed into throughout, so recordings stay attributed to their owner instead
/// of parking under [DraftStorageService.anonymousOwnerPubkey] — where every
/// owner-scoped query hides them until a later sign-in's legacy-row claim
/// happens to rescue them.
///
/// The fallback cannot mis-attribute across accounts: a live session always
/// takes the first branch, and sign-out clears the preference. What is left for
/// the anonymous marker is what it was meant for — a device with no account at
/// all.
String resolveLocalContentOwnerPubkey({
  required String? currentPubkeyHex,
  required SharedPreferences preferences,
}) {
  if (currentPubkeyHex != null && currentPubkeyHex.isNotEmpty) {
    return currentPubkeyHex;
  }

  final pendingSessionPubkeyHex = preferences.getString(
    currentUserPubkeyHexPrefKey,
  );
  if (pendingSessionPubkeyHex != null && pendingSessionPubkeyHex.isNotEmpty) {
    return pendingSessionPubkeyHex;
  }

  return DraftStorageService.anonymousOwnerPubkey;
}
