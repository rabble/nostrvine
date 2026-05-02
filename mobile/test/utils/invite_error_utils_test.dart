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

  group('server error code classification', () {
    test('creator_page_full maps to creatorFull', () {
      expect(
        InviteErrorUtils.activationFailureReason(
          makeException(
            code: InviteApiErrorCode.creatorPageFull,
            statusCode: 409,
          ),
        ),
        InviteActivationFailureReason.creatorFull,
      );
    });

    for (final code in [
      InviteApiErrorCode.authRequired,
      InviteApiErrorCode.authInvalid,
      InviteApiErrorCode.authExpired,
      InviteApiErrorCode.authInvalidBinding,
      InviteApiErrorCode.clientAuthFailed,
    ]) {
      test('$code maps to authFailure', () {
        expect(
          InviteErrorUtils.activationFailureReason(
            makeException(code: code, statusCode: 401),
          ),
          InviteActivationFailureReason.authFailure,
        );
      });
    }

    for (final code in [
      InviteApiErrorCode.inviteAlreadyUsed,
      InviteApiErrorCode.userAlreadyJoined,
    ]) {
      test('$code maps to alreadyUsed', () {
        expect(
          InviteErrorUtils.activationFailureReason(
            makeException(code: code, statusCode: 409),
          ),
          InviteActivationFailureReason.alreadyUsed,
        );
      });
    }

    for (final code in [
      InviteApiErrorCode.inviteNotFound,
      InviteApiErrorCode.inviteInvalidFormat,
      InviteApiErrorCode.inviteRevoked,
      InviteApiErrorCode.inviteCodeRotated,
      InviteApiErrorCode.creatorPageDisabled,
    ]) {
      test('$code maps to invalid', () {
        expect(
          InviteErrorUtils.activationFailureReason(makeException(code: code)),
          InviteActivationFailureReason.invalid,
        );
      });
    }

    for (final code in [
      InviteApiErrorCode.tooManyRequests,
      InviteApiErrorCode.storageError,
      InviteApiErrorCode.internalError,
      InviteApiErrorCode.clientTimeout,
      InviteApiErrorCode.clientNetworkError,
    ]) {
      test('$code maps to temporary', () {
        expect(
          InviteErrorUtils.activationFailureReason(
            makeException(code: code, statusCode: 429),
          ),
          InviteActivationFailureReason.temporary,
        );
      });
    }
  });

  group('status code fallback classification', () {
    test('401 without error code maps to authFailure', () {
      expect(
        InviteErrorUtils.activationFailureReason(
          makeException(statusCode: 401),
        ),
        InviteActivationFailureReason.authFailure,
      );
    });

    test('409 without error code maps to alreadyUsed', () {
      expect(
        InviteErrorUtils.activationFailureReason(
          makeException(statusCode: 409),
        ),
        InviteActivationFailureReason.alreadyUsed,
      );
    });

    test('404 without error code maps to invalid', () {
      expect(
        InviteErrorUtils.activationFailureReason(
          makeException(statusCode: 404),
        ),
        InviteActivationFailureReason.invalid,
      );
    });

    test('500 without error code maps to temporary', () {
      expect(
        InviteErrorUtils.activationFailureReason(
          makeException(statusCode: 500),
        ),
        InviteActivationFailureReason.temporary,
      );
    });

    test('429 without error code maps to temporary', () {
      expect(
        InviteErrorUtils.activationFailureReason(
          makeException(statusCode: 429),
        ),
        InviteActivationFailureReason.temporary,
      );
    });
  });

  group('keyword fallback classification', () {
    test('timeout in message maps to temporary', () {
      expect(
        InviteErrorUtils.activationFailureReason(
          makeException(message: 'Invite activation timed out'),
        ),
        InviteActivationFailureReason.temporary,
      );
    });

    test('network error in message maps to temporary', () {
      expect(
        InviteErrorUtils.activationFailureReason(
          makeException(message: 'network error'),
        ),
        InviteActivationFailureReason.temporary,
      );
    });

    test('invalid in message maps to invalid', () {
      expect(
        InviteErrorUtils.activationFailureReason(
          makeException(message: 'Invalid invite code'),
        ),
        InviteActivationFailureReason.invalid,
      );
    });

    test('expired in message maps to invalid', () {
      expect(
        InviteErrorUtils.activationFailureReason(
          makeException(message: 'Invite code expired'),
        ),
        InviteActivationFailureReason.invalid,
      );
    });

    test('unrecognized error falls to unknown', () {
      expect(
        InviteErrorUtils.activationFailureReason(
          makeException(message: 'something completely unexpected'),
        ),
        InviteActivationFailureReason.unknown,
      );
    });
  });

  group('server error code takes priority over status code', () {
    test('auth_invalid at 401 maps to authFailure not invalid', () {
      expect(
        InviteErrorUtils.activationFailureReason(
          makeException(code: InviteApiErrorCode.authInvalid, statusCode: 401),
        ),
        InviteActivationFailureReason.authFailure,
      );
    });

    test('invite_revoked at 409 maps to invalid not alreadyUsed', () {
      expect(
        InviteErrorUtils.activationFailureReason(
          makeException(
            code: InviteApiErrorCode.inviteRevoked,
            statusCode: 409,
          ),
        ),
        InviteActivationFailureReason.invalid,
      );
    });
  });

  group('client-synthesized codes', () {
    test('client_error code maps to unknown', () {
      expect(
        InviteErrorUtils.activationFailureReason(
          makeException(code: InviteApiErrorCode.clientError),
        ),
        InviteActivationFailureReason.unknown,
      );
    });
  });

  group('toEmailVerificationError', () {
    test('authFailure maps to inviteTemporary', () {
      expect(
        InviteErrorUtils.toEmailVerificationError(
          makeException(code: InviteApiErrorCode.authInvalid, statusCode: 401),
        ),
        EmailVerificationError.inviteTemporary,
      );
    });

    test('creatorFull maps to inviteInvalid', () {
      expect(
        InviteErrorUtils.toEmailVerificationError(
          makeException(
            code: InviteApiErrorCode.creatorPageFull,
            statusCode: 409,
          ),
        ),
        EmailVerificationError.inviteInvalid,
      );
    });

    test('unknown maps to inviteUnknown', () {
      expect(
        InviteErrorUtils.toEmailVerificationError(
          makeException(code: InviteApiErrorCode.clientError),
        ),
        EmailVerificationError.inviteUnknown,
      );
    });
  });

  group('activationFailureMessage', () {
    test('authFailure message suggests trying again', () {
      final message = InviteErrorUtils.activationFailureMessage(
        makeException(
          code: InviteApiErrorCode.clientAuthFailed,
          statusCode: 401,
        ),
      );
      expect(message, contains('try again'));
    });

    test('unknown message is the generic dead-end', () {
      final message = InviteErrorUtils.activationFailureMessage(
        makeException(message: 'something unexpected'),
      );
      expect(message, contains("couldn't activate"));
    });
  });
}
