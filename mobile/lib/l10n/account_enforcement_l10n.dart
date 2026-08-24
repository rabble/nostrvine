// ABOUTME: Maps AccountEnforcementKind to localized copy.
// ABOUTME: State carries the kind; the UI layer localizes for display.

import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/account_enforcement_status.dart';

/// Maps an [AccountEnforcementKind] to user-facing copy.
///
/// Follows the project's l10n rule: state carries codes, never English copy.
///
/// The mapping is exhaustive by design. No resolved kind makes a positive
/// good-standing claim because Keycast is not authoritative for relay state.
extension AccountEnforcementL10n on AppLocalizations {
  String accountEnforcementHeading(AccountEnforcementKind kind) {
    switch (kind) {
      case AccountEnforcementKind.signedOut:
        return accountStatusSignedOutHeading;
      case AccountEnforcementKind.unverified:
        return accountStatusUnverifiedHeading;
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
      case AccountEnforcementKind.signedOut:
        return accountStatusSignedOutBody;
      case AccountEnforcementKind.unverified:
        return accountStatusUnverifiedBody;
      case AccountEnforcementKind.suspended:
        return accountStatusSuspendedBody;
      case AccountEnforcementKind.banned:
        return accountStatusBannedBody;
      case AccountEnforcementKind.restricted:
        return accountStatusRestrictedBody;
    }
  }
}
