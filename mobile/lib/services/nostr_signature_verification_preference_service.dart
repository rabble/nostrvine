// ABOUTME: Persists the user's Nostr relay signature verification policy.
// ABOUTME: Maps app settings onto the nostr_sdk relay-pool verification modes.

import 'package:nostr_sdk/nostr_sdk.dart' as nostr_sdk;
import 'package:shared_preferences/shared_preferences.dart';

enum NostrSignatureVerificationPolicy {
  all('all'),
  untrustedRelays('untrusted_relays'),
  nonDivineRelays('non_divine_relays');

  const NostrSignatureVerificationPolicy(this.storageValue);

  final String storageValue;

  nostr_sdk.SignatureVerificationPolicy toSdkPolicy() {
    switch (this) {
      case NostrSignatureVerificationPolicy.all:
        return nostr_sdk.SignatureVerificationPolicy.all;
      case NostrSignatureVerificationPolicy.untrustedRelays:
        return nostr_sdk.SignatureVerificationPolicy.untrustedRelays;
      case NostrSignatureVerificationPolicy.nonDivineRelays:
        return nostr_sdk.SignatureVerificationPolicy.nonDivineRelays;
    }
  }

  static NostrSignatureVerificationPolicy fromStorage(String? value) {
    for (final policy in values) {
      if (policy.storageValue == value) return policy;
    }
    return NostrSignatureVerificationPreferenceService.defaultPolicy;
  }
}

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
