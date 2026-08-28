// ABOUTME: Maps AccountEnforcementKind to localized copy.
// ABOUTME: State carries the kind; the UI layer localizes for display.

import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/account_enforcement_status.dart';

/// Maps an [AccountEnforcementKind] to user-facing copy.
///
/// Follows the project's l10n rule: state carries codes, never English copy.
///
/// The mapping is exhaustive by design. A successful active response resolves
/// to [AccountEnforcementKind.noRestrictionReported] and the all-clear copy.
extension AccountEnforcementL10n on AppLocalizations {
  String accountEnforcementHeading(AccountEnforcementKind kind) {
    switch (kind) {
      case AccountEnforcementKind.signedOut:
        return accountStatusSignedOutHeading;
      case AccountEnforcementKind.noRestrictionReported:
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
      case AccountEnforcementKind.noRestrictionReported:
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
