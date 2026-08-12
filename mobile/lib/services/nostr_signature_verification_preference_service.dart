// ABOUTME: Persists the user's Nostr relay signature verification policy.
// ABOUTME: Maps app settings onto the nostr_sdk relay-pool verification modes.

import 'package:openvine/models/nostr_signature_verification_policy.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NostrSignatureVerificationPreferenceService {
  NostrSignatureVerificationPreferenceService(this._prefs);

  static const prefsKey = 'nostr_signature_verification_policy';

  static const NostrSignatureVerificationPolicy defaultPolicy =
      NostrSignatureVerificationPolicy.all;

  final SharedPreferences _prefs;

  NostrSignatureVerificationPolicy get currentPolicy =>
      NostrSignatureVerificationPolicy.fromStorage(_prefs.getString(prefsKey));

  Future<void> setPolicy(NostrSignatureVerificationPolicy policy) async {
    await _prefs.setString(prefsKey, policy.storageValue);
  }
}
