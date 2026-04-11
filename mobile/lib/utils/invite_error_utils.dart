// ABOUTME: Shared invite activation error mapping for auth and onboarding flows

import 'package:invite_api_client/invite_api_client.dart';
import 'package:openvine/blocs/email_verification/email_verification_cubit.dart'
    show EmailVerificationError;

/// Classification for an invite activation failure.
///
/// Callers in the BLoC/Cubit layer must store one of these reasons (or a
/// mapped [EmailVerificationError]) — never a raw English string.
enum InviteActivationFailureReason {
  /// Invite code has already been used / claimed.
  alreadyUsed,

  /// Invite code is invalid, revoked, expired, or not eligible.
  invalid,

  /// Temporary server or network problem (retryable).
  temporary,

  /// Unspecified activation failure.
  unknown,
}

class InviteErrorUtils {
  /// Classifies an [InviteApiException] into a reason code.
  ///
  /// Use this from the cubit/BLoC layer so state never carries English copy.
  /// The UI layer maps the reason to a localized string.
  static InviteActivationFailureReason activationFailureReason(
    InviteApiException error,
  ) {
    final statusCode = error.statusCode;
    final normalizedMessage = error.message.toLowerCase();

    final isUsedError =
        statusCode == 409 ||
        normalizedMessage.contains('already used') ||
        normalizedMessage.contains('already claimed') ||
        normalizedMessage.contains('already been used') ||
        normalizedMessage.contains('already joined');

    if (isUsedError) {
      return InviteActivationFailureReason.alreadyUsed;
    }

    final isInvalidError =
        statusCode == 403 ||
        statusCode == 404 ||
        normalizedMessage.contains('invalid') ||
        normalizedMessage.contains('revoked') ||
        normalizedMessage.contains('expired') ||
        normalizedMessage.contains('not eligible');

    if (isInvalidError) {
      return InviteActivationFailureReason.invalid;
    }

    final isTemporaryError =
        statusCode == 429 ||
        (statusCode != null && statusCode >= 500) ||
        normalizedMessage.contains('timed out') ||
        normalizedMessage.contains('timeout') ||
        normalizedMessage.contains('network') ||
        normalizedMessage.contains('socket') ||
        normalizedMessage.contains('connection');

    if (isTemporaryError) {
      return InviteActivationFailureReason.temporary;
    }

    return InviteActivationFailureReason.unknown;
  }

  /// Maps an invite activation failure to an [EmailVerificationError] reason
  /// that the email verification cubit can emit.
  static EmailVerificationError toEmailVerificationError(
    InviteApiException error,
  ) {
    switch (activationFailureReason(error)) {
      case InviteActivationFailureReason.alreadyUsed:
        return EmailVerificationError.inviteAlreadyUsed;
      case InviteActivationFailureReason.invalid:
        return EmailVerificationError.inviteInvalid;
      case InviteActivationFailureReason.temporary:
        return EmailVerificationError.inviteTemporary;
      case InviteActivationFailureReason.unknown:
        return EmailVerificationError.inviteUnknown;
    }
  }

  /// Legacy string-based helper retained for pre-existing callers
  /// (`DivineAuthCubit`) that still store English strings in state.
  ///
  /// New callers must use [activationFailureReason] or
  /// [toEmailVerificationError] instead and localize in the UI layer.
  /// When `DivineAuthCubit` is migrated to the reason-code pattern, this
  /// helper can be removed.
  static String activationFailureMessage(InviteApiException error) {
    switch (activationFailureReason(error)) {
      case InviteActivationFailureReason.alreadyUsed:
        return 'That invite code is no longer available. '
            'Go back to your invite code, join the waitlist, '
            'or contact support.';
      case InviteActivationFailureReason.invalid:
        return 'That invite code cannot be used right now. '
            'Go back to your invite code, join the waitlist, '
            'or contact support.';
      case InviteActivationFailureReason.temporary:
        return "We couldn't confirm your invite right now. "
            'Go back to your invite code and try again, or contact support.';
      case InviteActivationFailureReason.unknown:
        return "We couldn't activate your invite. "
            'Go back to your invite code, join the waitlist, '
            'or contact support.';
    }
  }
}
