// ABOUTME: Client-side account enforcement state derived from Funnelcake's relay-backed status.
// ABOUTME: Carries no moderation internals; the API deliberately returns status only.

import 'package:openvine/services/account_status_api_client.dart';

enum AccountEnforcementKind {
  /// There is no signed-in account whose status can be checked.
  signedOut,

  /// Funnelcake successfully reported that the account is active.
  noRestrictionReported,

  /// Reversible: content is hidden, not deleted.
  suspended,

  /// Content has been removed from Divine-operated surfaces.
  banned,

  /// Relay publishing confirmed a restriction whose exact state is unknown.
  ///
  /// This is not used for unknown status API values, which remain indeterminate
  /// because a future value is not necessarily a restriction.
  unknownRestriction;

  bool get isEnforced =>
      this == AccountEnforcementKind.suspended ||
      this == AccountEnforcementKind.banned ||
      this == AccountEnforcementKind.unknownRestriction;
}

/// Enforcement state for the authenticated account, as reported by
/// Funnelcake's self-authenticated status endpoint.
///
/// Deliberately carries no reason or moderation metadata, for two reasons that
/// are worth keeping apart because only the first survives a change of backend:
///
/// 1. A stored moderation reason is free text written by whatever called an
///    admin API, so rendering it would leak moderation internals to the user
///    (support-trust-safety#200 R-7). This is why the omission is deliberate.
/// 2. Funnelcake's self-status API happens not to return one today, and asserts
///    that in its own suite. This is why the omission is currently free.
///
/// Reason (2) arrived with the move from Keycast to Funnelcake and reads like
/// the whole story; it is not. Copy is chosen from [kind] alone. See #8304 for
/// the open question of whether a *user-facing* reason should exist at all, and
/// `account_status_api_client_test.dart` for the client-side guard.
class AccountEnforcementStatus {
  const AccountEnforcementStatus({required this.kind});

  factory AccountEnforcementStatus.fromFunnelcake(
    FunnelcakeAccountStatus status,
  ) {
    switch (status) {
      case FunnelcakeAccountStatus.active:
        return const AccountEnforcementStatus(
          kind: AccountEnforcementKind.noRestrictionReported,
        );
      case FunnelcakeAccountStatus.suspended:
        return const AccountEnforcementStatus(
          kind: AccountEnforcementKind.suspended,
        );
      case FunnelcakeAccountStatus.banned:
        return const AccountEnforcementStatus(
          kind: AccountEnforcementKind.banned,
        );
    }
  }

  final AccountEnforcementKind kind;

  bool get isEnforced => kind.isEnforced;
}
