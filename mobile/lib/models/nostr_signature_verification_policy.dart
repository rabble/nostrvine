// ABOUTME: App-level Nostr relay signature verification policy.
// ABOUTME: Shared by settings UI, preference persistence, and nostr_sdk mapping.

import 'package:nostr_sdk/nostr_sdk.dart' as nostr_sdk;

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
    return all;
  }
}
