// ABOUTME: Classifies deterministic relay rejections from publish outcomes.
// ABOUTME: Trusts account restrictions only when the configured relay says so.

import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:openvine/utils/relay_url_utils.dart';

// These reason strings are the divine relay's verbatim OK-frame messages,
// produced by divine-funnelcake `crates/relay/src/rejection.rs` (Display for
// the SuspendedPubkey / BannedPubkey / rate-limit variants). This match is
// exact, so a reword on the relay side silently reverts suspended users to the
// retry path — change both repos together, or add a cross-repo contract test.

/// True only for explicit account-level publishing restrictions.
bool isAccountRestrictedReason(String reason) {
  final normalized = reason.trim().toLowerCase();
  return normalized == 'blocked: pubkey is suspended' ||
      normalized == 'blocked: pubkey is banned';
}

/// Whether the configured authoritative relay rejected a publish because the
/// account is restricted and no other relay accepted it.
///
/// Deletion publishes fan out to user-discovered relays. Their reason text is
/// untrusted and must not decide Divine account standing or stop a vanish
/// request. Relay URLs are compared by normalized endpoint identity so a
/// harmless trailing slash does not discard the authoritative response.
bool isAccountRestrictedOutcome(
  PublishOutcome outcome, {
  required String trustedRelayUrl,
}) =>
    outcome.acceptedBy.isEmpty &&
    outcome.rejectedBy.entries.any(
      (entry) =>
          relayUrlsEquivalent(entry.key, trustedRelayUrl) &&
          isAccountRestrictedReason(entry.value),
    );

/// Whether at least one relay rate-limited a publish that none accepted.
bool isRateLimitedOutcome(PublishOutcome outcome) =>
    outcome.acceptedBy.isEmpty &&
    outcome.rejectedBy.values.any(
      (reason) => reason.trim().toLowerCase().startsWith('rate-limited:'),
    );
