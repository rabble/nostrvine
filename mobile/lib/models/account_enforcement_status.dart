// ABOUTME: Client-side account enforcement state derived from Keycast's
// ABOUTME: account_status. Carries no moderation internals (s-t-s#200 R-7).

import 'package:keycast_flutter/keycast_flutter.dart';

enum AccountEnforcementKind {
  /// There is no signed-in account whose status can be checked.
  signedOut,

  /// The client has no authoritative relay-backed status for this account.
  /// Keycast may confirm a restriction, but an absent Keycast mirror cannot
  /// prove that relay enforcement is absent.
  unverified,

  /// Reversible: content is hidden, not deleted.
  suspended,

  /// Content has been removed from Divine-operated surfaces.
  banned,

  /// Restricted, but by a state this client build does not recognize.
  ///
  /// Keycast sets `account_status` only for a non-active account, so an
  /// unrecognized value still means restricted. Mapping it to [none] would
  /// tell a restricted user their account is fine, so newer server states
  /// degrade to generic restriction copy rather than to an all-clear.
  restricted,
  ;

  bool get isEnforced =>
      this == AccountEnforcementKind.suspended ||
      this == AccountEnforcementKind.banned ||
      this == AccountEnforcementKind.restricted;
}

/// Enforcement state for the *authenticated* account, as reported by Keycast's
/// `GET /api/user/account`.
///
/// Deliberately carries no `suspendedReason`. Keycast stores that as free text
/// written by whatever called its admin API, so rendering it would leak
/// moderation internals to the user (s-t-s#200 R-7). Copy is chosen from
/// [kind] alone.
class AccountEnforcementStatus {
  const AccountEnforcementStatus({required this.kind});

  /// Maps a Keycast account status to enforcement state.
  factory AccountEnforcementStatus.fromKeycast(KeycastAccountStatus status) {
    final raw = status.accountStatus;
    if (raw == null) {
      // Keycast is a best-effort mirror of relay enforcement. Its absence is
      // not authoritative evidence that the relay considers this account
      // unrestricted, so never turn it into a positive all-clear.
      return const AccountEnforcementStatus(
        kind: AccountEnforcementKind.unverified,
      );
    }
    switch (raw) {
      case 'suspended':
        return const AccountEnforcementStatus(
          kind: AccountEnforcementKind.suspended,
        );
      case 'banned':
        return const AccountEnforcementStatus(
          kind: AccountEnforcementKind.banned,
        );
    }
    // Fail closed: a value we do not recognize is still a non-active account.
    return const AccountEnforcementStatus(
      kind: AccountEnforcementKind.restricted,
    );
  }

  final AccountEnforcementKind kind;

  bool get isEnforced => kind.isEnforced;
}
