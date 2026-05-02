// ABOUTME: Tests for invite activation error classification and mapping.

import 'package:flutter_test/flutter_test.dart';
import 'package:invite_api_client/invite_api_client.dart';
import 'package:openvine/blocs/email_verification/email_verification_cubit.dart'
    show EmailVerificationError;
import 'package:openvine/utils/invite_error_utils.dart';

void main() {
  InviteApiException makeException({
    String message = 'test',
    int? statusCode,
    String? code,
  }) {
    return InviteApiException(message, statusCode: statusCode, code: code);
  }

  group('activationFailureReason', () {
    test('classifies auth-related server codes first', () {
      for (final code in [
        InviteApiErrorCode.authRequired,
        InviteApiErrorCode.authInvalid,
        InviteApiErrorCode.authExpired,
        InviteApiErrorCode.authInvalidBinding,
      ]) {
        expect(
          InviteErrorUtils.activationFailureReason(
            makeException(code: code, statusCode: 401),
          ),
          InviteActivationFailureReason.authFailure,
        );
      }
    });

    test('classifies client auth failures as retryable auth failures', () {
      expect(
        InviteErrorUtils.activationFailureReason(
          makeException(code: InviteApiErrorCode.clientAuthFailed),
        ),
        InviteActivationFailureReason.authFailure,
      );
    });

    test('classifies invalid and used codes ahead of status fallback', () {
      expect(
        InviteErrorUtils.activationFailureReason(
          makeException(
            code: InviteApiErrorCode.inviteRevoked,
            statusCode: 409,
          ),
        ),
        InviteActivationFailureReason.invalid,
      );
      expect(
        InviteErrorUtils.activationFailureReason(
          makeException(
            code: InviteApiErrorCode.userAlreadyJoined,
            statusCode: 401,
          ),
        ),
        InviteActivationFailureReason.alreadyUsed,
      );
    });

    test('classifies client timeout and network failures as temporary', () {
      expect(
        InviteErrorUtils.activationFailureReason(
          makeException(code: InviteApiErrorCode.clientTimeout),
        ),
        InviteActivationFailureReason.temporary,
      );
      expect(
        InviteErrorUtils.activationFailureReason(
          makeException(code: InviteApiErrorCode.clientNetworkError),
        ),
        InviteActivationFailureReason.temporary,
      );
    });

    test('falls back to 401 when no code is present', () {
      expect(
        InviteErrorUtils.activationFailureReason(
          makeException(statusCode: 401),
        ),
        InviteActivationFailureReason.authFailure,
      );
    });

    test('keeps keyword fallback for invalid and temporary messages', () {
      expect(
        InviteErrorUtils.activationFailureReason(
          makeException(message: 'Invalid invite code'),
        ),
        InviteActivationFailureReason.invalid,
      );
      expect(
        InviteErrorUtils.activationFailureReason(
          makeException(message: 'Socket connection failed'),
        ),
        InviteActivationFailureReason.temporary,
      );
    });
  });

  group('toEmailVerificationError', () {
    test('maps auth failures to retryable inviteTemporary', () {
      expect(
        InviteErrorUtils.toEmailVerificationError(
          makeException(code: InviteApiErrorCode.clientAuthFailed),
        ),
        EmailVerificationError.inviteTemporary,
      );
    });

    test('maps unknown client errors to inviteUnknown', () {
      expect(
        InviteErrorUtils.toEmailVerificationError(
          makeException(code: InviteApiErrorCode.clientError),
        ),
        EmailVerificationError.inviteUnknown,
      );
    });
  });

  group('activationFailureMessage', () {
    test('auth failures reuse the retry-oriented message', () {
      final message = InviteErrorUtils.activationFailureMessage(
        makeException(code: InviteApiErrorCode.clientAuthFailed),
      );
      expect(message, contains('try again'));
      expect(message, isNot(contains("couldn't activate")));
    });
  });
}
