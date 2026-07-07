// ABOUTME: Defines relay-origin policy for inbound Nostr event signature checks.
// ABOUTME: Lets clients trade trusted-relay performance against full verification.

enum SignatureVerificationPolicy {
  /// Verify every inbound relay EVENT signature.
  all,

  /// Verify only relay EVENT signatures from relays outside the configured pool.
  untrustedRelays,

  /// Verify only relay EVENT signatures from non-Divine relay hosts.
  nonDivineRelays,
}
