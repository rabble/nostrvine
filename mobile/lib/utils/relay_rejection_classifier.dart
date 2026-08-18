import 'package:nostr_sdk/relay/publish_outcome.dart';

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
