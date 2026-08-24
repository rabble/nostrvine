// ABOUTME: Client-side account enforcement state derived from Keycast's
// ABOUTME: account_status. Carries no moderation internals (s-t-s#200 R-7).

import 'package:keycast_flutter/keycast_flutter.dart';

enum AccountEnforcementKind {
  /// No signal: the status could not be read. Transient, so retrying helps.
  unknown,

  /// There is no signed-in account whose status can be checked.
  signedOut,

  /// Divine holds no enforcement state for this account.
  ///
  /// The key is self-custodied (imported, generated locally, or held by a
  /// remote signer), so there is no Divine account to be suspended. Distinct
  /// from [unknown]: this is a settled answer, not a failed lookup, and
  /// retrying will never change it.
  noAccountState,

  /// Confirmed in good standing.
  none,

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

  factory AccountEnforcementStatus.unknown() =>
      const AccountEnforcementStatus(kind: AccountEnforcementKind.unknown);

  /// Maps a Keycast account status to enforcement state.
  ///
  /// A null [status] (fetch failed, or no OAuth session) is preserved as
  /// [AccountEnforcementKind.unknown] rather than "none", so an absent signal
  /// never reads as a positive all-clear.
  factory AccountEnforcementStatus.fromKeycast(KeycastAccountStatus? status) {
    if (status == null) {
      return AccountEnforcementStatus.unknown();
    }
    final raw = status.accountStatus;
    if (raw == null) {
      // Keycast populates account_status only when the account is NOT active,
      // so its absence is a positive "active" signal.
      return const AccountEnforcementStatus(kind: AccountEnforcementKind.none);
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

  bool get isKnown => kind != AccountEnforcementKind.unknown;

  bool get isEnforced => kind.isEnforced;
}
