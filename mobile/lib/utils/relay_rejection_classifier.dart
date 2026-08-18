import 'package:nostr_sdk/relay/publish_outcome.dart';

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

bool isAccountRestrictedOutcome(PublishOutcome outcome) =>
    outcome.acceptedBy.isEmpty &&
    outcome.rejectedBy.isNotEmpty &&
    outcome.rejectedBy.values.every(isAccountRestrictedReason);

bool isRateLimitedOutcome(PublishOutcome outcome) =>
    outcome.acceptedBy.isEmpty &&
    outcome.rejectedBy.values.any(
      (reason) => reason.trim().toLowerCase().startsWith('rate-limited:'),
    );
