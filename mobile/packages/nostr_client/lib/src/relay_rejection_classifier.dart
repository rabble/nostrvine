// ABOUTME: Classifies deterministic relay rejections from publish outcomes.
// ABOUTME: Trusts account restrictions only when the configured relay says so.

import 'package:nostr_client/src/relay_manager.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

// These reason strings are Funnelcake's verbatim NIP-01 OK-false messages.
// Exact matching deliberately fails closed if the producer wording changes.
/// Whether [reason] exactly matches a known account restriction.
bool isAccountRestrictedReason(String reason) {
  final normalized = reason.trim().toLowerCase();
  return normalized == 'blocked: pubkey is suspended' ||
      normalized == 'blocked: pubkey is banned';
}

/// Whether two relay URLs normalize to the same endpoint identity.
bool relayUrlsEquivalent(String a, String b) {
  final normalizedA = normalizeRelayUrl(a);
  final normalizedB = normalizeRelayUrl(b);
  return normalizedA != null &&
      normalizedB != null &&
      normalizedA == normalizedB;
}

/// Whether only the trusted relay confirms an account restriction.
bool isAccountRestrictedOutcome(
  PublishOutcome outcome, {
  required String trustedRelayUrl,
}) =>
    accountRestrictedReasonFromOutcome(
      outcome,
      trustedRelayUrl: trustedRelayUrl,
    ) !=
    null;

/// Returns the trusted relay's exact restriction reason, if authoritative.
String? accountRestrictedReasonFromOutcome(
  PublishOutcome outcome, {
  required String trustedRelayUrl,
}) {
  if (outcome.acceptedBy.isNotEmpty) return null;
  for (final entry in outcome.rejectedBy.entries) {
    if (relayUrlsEquivalent(entry.key, trustedRelayUrl) &&
        isAccountRestrictedReason(entry.value)) {
      return entry.value;
    }
  }
  return null;
}

/// Whether no relay accepted and at least one relay returned a rate limit.
bool isRateLimitedOutcome(PublishOutcome outcome) =>
    outcome.acceptedBy.isEmpty &&
    outcome.rejectedBy.values.any(
      (reason) => reason.trim().toLowerCase().startsWith('rate-limited:'),
    );
