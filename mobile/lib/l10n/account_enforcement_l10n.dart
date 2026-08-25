// ABOUTME: Maps AccountEnforcementKind to localized copy.
// ABOUTME: State carries the kind; the UI layer localizes for display.

import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/account_enforcement_status.dart';

/// Maps an [AccountEnforcementKind] to user-facing copy.
///
/// Follows the project's l10n rule: state carries codes, never English copy.
///
/// The mapping is exhaustive by design. [AccountEnforcementKind.unverified]
/// resolves to the all-clear: Keycast is not authoritative for relay state, so
/// the claim outruns the evidence, but the relay answers at the moment of
/// action and routes its verdict back here. Telling someone with nothing to
/// see that this screen merely has nothing to show is worse than being wrong
/// on the rare visit that precedes their first blocked action.
extension AccountEnforcementL10n on AppLocalizations {
  String accountEnforcementHeading(AccountEnforcementKind kind) {
    switch (kind) {
      case AccountEnforcementKind.signedOut:
        return accountStatusSignedOutHeading;
      case AccountEnforcementKind.unverified:
        return accountStatusAllClearHeading;
      case AccountEnforcementKind.suspended:
        return accountStatusSuspendedHeading;
      case AccountEnforcementKind.banned:
        return accountStatusBannedHeading;
      case AccountEnforcementKind.unknownRestriction:
        return accountStatusRestrictedHeading;
    }
  }

  /// Body copy for [kind], or null when the heading stands alone.
  ///
  /// The all-clear deliberately has no body. A second sentence there can only
  /// explain how Divine checks an account, which is the system-mechanics talk
  /// the rest of this screen avoids.
  String? accountEnforcementBody(AccountEnforcementKind kind) {
    switch (kind) {
      case AccountEnforcementKind.signedOut:
        return accountStatusSignedOutBody;
      case AccountEnforcementKind.unverified:
        return null;
      case AccountEnforcementKind.suspended:
        return accountStatusSuspendedBody;
      case AccountEnforcementKind.banned:
        return accountStatusBannedBody;
      case AccountEnforcementKind.unknownRestriction:
        return accountStatusRestrictedBody;
    }
  }
}
