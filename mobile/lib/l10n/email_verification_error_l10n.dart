// ABOUTME: Maps EmailVerificationError reason codes to localized strings.
// ABOUTME: State stores the code; the UI layer localizes for display.

import 'package:openvine/blocs/email_verification/email_verification_cubit.dart';
import 'package:openvine/l10n/l10n.dart';

/// Maps [EmailVerificationError] reason codes to localized user-facing
/// strings.
///
/// Follows the project's l10n rule: BLoC state carries codes, never English
/// copy. Call this from widgets (where a [AppLocalizations] is available) to
/// render the correct translated message.
extension EmailVerificationErrorL10n on AppLocalizations {
  String emailVerificationErrorMessage(EmailVerificationError error) {
    switch (error) {
      case EmailVerificationError.timeout:
        return authVerificationErrorTimeout;
      case EmailVerificationError.missingAuthCode:
        return authVerificationErrorMissingCode;
      case EmailVerificationError.pollFailed:
        return authVerificationErrorPollFailed;
      case EmailVerificationError.networkExchange:
        return authVerificationErrorNetworkExchange;
      case EmailVerificationError.oauthExchange:
        return authVerificationErrorOAuthExchange;
      case EmailVerificationError.signInFailed:
        return authVerificationErrorSignInFailed;
      case EmailVerificationError.verificationLinkExpired:
        return authVerificationLinkExpired;
      case EmailVerificationError.verificationConnectionError:
        return authVerificationConnectionError;
      case EmailVerificationError.inviteAlreadyUsed:
        return authInviteErrorAlreadyUsed;
      case EmailVerificationError.inviteInvalid:
        return authInviteErrorInvalid;
      case EmailVerificationError.inviteTemporary:
        return authInviteErrorTemporary;
      case EmailVerificationError.inviteUnknown:
        return authInviteErrorUnknown;
    }
  }
}
