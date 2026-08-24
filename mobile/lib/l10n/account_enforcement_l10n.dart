// ABOUTME: Maps AccountEnforcementKind to localized copy.
// ABOUTME: State carries the kind; the UI layer localizes for display.

import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/account_enforcement_status.dart';

/// Maps an [AccountEnforcementKind] to user-facing copy.
///
/// Follows the project's l10n rule: state carries codes, never English copy.
///
/// The mapping is exhaustive by design. Every kind, including
/// [AccountEnforcementKind.unknown], gets its own wording — "we could not
/// check" and "you are in good standing" are different claims, and collapsing
/// them would reassure a restricted user whose status fetch merely failed.
extension AccountEnforcementL10n on AppLocalizations {
  String accountEnforcementHeading(AccountEnforcementKind kind) {
    switch (kind) {
      case AccountEnforcementKind.unknown:
        return accountStatusUnknownHeading;
      case AccountEnforcementKind.signedOut:
        return accountStatusSignedOutHeading;
      case AccountEnforcementKind.noAccountState:
        return accountStatusNoAccountStateHeading;
      case AccountEnforcementKind.none:
        return accountStatusOkHeading;
      case AccountEnforcementKind.suspended:
        return accountStatusSuspendedHeading;
      case AccountEnforcementKind.banned:
        return accountStatusBannedHeading;
      case AccountEnforcementKind.restricted:
        return accountStatusRestrictedHeading;
    }
  }

  String accountEnforcementBody(AccountEnforcementKind kind) {
    switch (kind) {
      case AccountEnforcementKind.unknown:
        return accountStatusUnknownBody;
      case AccountEnforcementKind.signedOut:
        return accountStatusSignedOutBody;
      case AccountEnforcementKind.noAccountState:
        return accountStatusNoAccountStateBody;
      case AccountEnforcementKind.none:
        return accountStatusOkBody;
      case AccountEnforcementKind.suspended:
        return accountStatusSuspendedBody;
      case AccountEnforcementKind.banned:
        return accountStatusBannedBody;
      case AccountEnforcementKind.restricted:
        return accountStatusRestrictedBody;
    }
  }
}
