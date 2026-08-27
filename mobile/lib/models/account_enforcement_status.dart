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
/// Deliberately carries no reason or moderation metadata. The self-status API
/// returns only the public enforcement state, and copy is chosen from [kind].
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
