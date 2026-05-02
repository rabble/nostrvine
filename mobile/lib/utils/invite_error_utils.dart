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

  /// Creator invite cap has been reached.
  creatorFull,

  /// NIP-98 auth failed (signing, clock skew, or binding mismatch).
  authFailure,

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
  static const _authCodes = {
    'auth_required',
    'auth_invalid',
    'auth_expired',
    'auth_invalid_binding',
  };

  static const _invalidCodes = {
    'invite_not_found',
    'invite_invalid_format',
    'invite_revoked',
    'invite_code_rotated',
    'creator_page_disabled',
  };

  static const _usedCodes = {
    'invite_already_used',
    'user_already_joined',
  };

  static InviteActivationFailureReason activationFailureReason(
    InviteApiException error,
  ) {
    final statusCode = error.statusCode;
    final normalizedMessage = error.message.toLowerCase();
    final code = error.code;

    // Server error code takes priority over keyword matching.
    if (code != null) {
      if (code == 'creator_page_full') {
        return InviteActivationFailureReason.creatorFull;
      }
      if (_authCodes.contains(code)) {
        return InviteActivationFailureReason.authFailure;
      }
      if (_usedCodes.contains(code)) {
        return InviteActivationFailureReason.alreadyUsed;
      }
      if (_invalidCodes.contains(code)) {
        return InviteActivationFailureReason.invalid;
      }
      if (code == 'too_many_requests' ||
          code == 'timeout' ||
          code == 'storage_error' ||
          code == 'internal_error') {
        return InviteActivationFailureReason.temporary;
      }
      if (code == 'client_error') {
        return InviteActivationFailureReason.unknown;
      }
    }

    // Fall back to status code + keyword matching for exceptions that
    // don't carry a server error code (timeouts, network errors, etc.).
    if (statusCode == 401) {
      return InviteActivationFailureReason.authFailure;
    }

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
        normalizedMessage.contains('revoked') ||
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
      case InviteActivationFailureReason.creatorFull:
        return EmailVerificationError.inviteInvalid;
      case InviteActivationFailureReason.authFailure:
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
      case InviteActivationFailureReason.creatorFull:
        return "This creator's invites are full. Join the waitlist and "
            "we'll send an invite when there's room.";
      case InviteActivationFailureReason.authFailure:
        return "We couldn't verify your account for this invite. "
            'Go back to your invite code and try again, or contact support.';
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
