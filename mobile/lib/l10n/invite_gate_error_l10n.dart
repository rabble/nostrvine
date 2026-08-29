// ABOUTME: Maps invite-gate reason codes to localized strings.
// ABOUTME: State stores the reason; the UI layer localizes for display.

import 'package:openvine/blocs/invite_gate/invite_gate_state.dart';
import 'package:openvine/l10n/l10n.dart';

/// Maps invite-gate failure reasons to localized, user-facing copy.
///
/// Follows the project's l10n rule: state carries codes, never English copy.
extension InviteGateErrorL10n on AppLocalizations {
  /// Copy for the error shown against the invite-code field.
  String inviteCodeErrorMessage(InviteCodeError error) {
    switch (error) {
      case InviteCodeError.malformed:
        return authInviteCodeErrorMalformed;
      case InviteCodeError.notFound:
        return authInviteCodeErrorNotFound;
      case InviteCodeError.alreadyUsed:
        return authInviteCodeErrorAlreadyUsed;
    }
  }

  /// Copy for the block-level error shown above the invite-code field.
  String inviteGateErrorMessage(InviteGateError error) {
    switch (error) {
      case InviteGateError.creatorFull:
        return authInviteGateErrorCreatorFull;
      case InviteGateError.inviteUnavailable:
        return authInviteGateErrorUnavailable;
      case InviteGateError.checkFailed:
        return authInviteGateErrorCheckFailed;
      case InviteGateError.unknown:
        return authInviteGateErrorUnknown;
    }
  }
}
