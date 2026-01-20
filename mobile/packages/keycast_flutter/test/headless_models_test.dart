// ABOUTME: Tests for headless authentication response models
// ABOUTME: Verifies JSON parsing, factory constructors, and error handling

import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/src/oauth/headless_models.dart';

void main() {
  group('HeadlessRegisterResult', () {
    group('constructor', () {
      test('creates instance with required fields', () {
        final result = HeadlessRegisterResult(
          success: true,
          pubkey: 'test_pubkey',
          verificationRequired: true,
        );

        expect(result.success, isTrue);
        expect(result.pubkey, 'test_pubkey');
        expect(result.verificationRequired, isTrue);
        expect(result.deviceCode, isNull);
        expect(result.email, isNull);
        expect(result.error, isNull);
      });

      test('creates instance with all optional fields', () {
        final result = HeadlessRegisterResult(
          success: true,
          pubkey: 'test_pubkey',
          verificationRequired: true,
          deviceCode: 'device_123',
          email: 'test@example.com',
          error: null,
        );

        expect(result.deviceCode, 'device_123');
        expect(result.email, 'test@example.com');
      });
    });

    group('fromJson', () {
      test('parses complete JSON response', () {
        final json = {
          'success': true,
          'pubkey': 'abc123',
          'verification_required': true,
          'device_code': 'dev_code',
          'email': 'user@test.com',
          'error': null,
        };

        final result = HeadlessRegisterResult.fromJson(json);

        expect(result.success, isTrue);
        expect(result.pubkey, 'abc123');
        expect(result.verificationRequired, isTrue);
        expect(result.deviceCode, 'dev_code');
        expect(result.email, 'user@test.com');
        expect(result.error, isNull);
      });

      test('uses defaults for missing fields', () {
        final json = <String, dynamic>{};

        final result = HeadlessRegisterResult.fromJson(json);

        expect(result.success, isFalse);
        expect(result.pubkey, '');
        expect(result.verificationRequired, isTrue);
        expect(result.deviceCode, isNull);
        expect(result.email, isNull);
        expect(result.error, isNull);
      });

      test('parses error field', () {
        final json = {
          'success': false,
          'pubkey': '',
          'verification_required': false,
          'error': 'email_taken',
        };

        final result = HeadlessRegisterResult.fromJson(json);

        expect(result.success, isFalse);
        expect(result.error, 'email_taken');
      });
    });

    group('error factory', () {
      test('creates error result with message', () {
        final result = HeadlessRegisterResult.error('Registration failed');

        expect(result.success, isFalse);
        expect(result.pubkey, '');
        expect(result.verificationRequired, isFalse);
        expect(result.error, 'Registration failed');
      });
    });
  });

  group('HeadlessLoginResult', () {
    group('constructor', () {
      test('creates instance with required fields', () {
        final result = HeadlessLoginResult(success: true);

        expect(result.success, isTrue);
        expect(result.code, isNull);
        expect(result.pubkey, isNull);
        expect(result.state, isNull);
        expect(result.error, isNull);
        expect(result.errorDescription, isNull);
      });

      test('creates instance with all optional fields', () {
        final result = HeadlessLoginResult(
          success: true,
          code: 'auth_code',
          pubkey: 'user_pubkey',
          state: 'state_123',
          error: null,
          errorDescription: null,
        );

        expect(result.code, 'auth_code');
        expect(result.pubkey, 'user_pubkey');
        expect(result.state, 'state_123');
      });
    });

    group('fromJson', () {
      test('parses complete JSON response', () {
        final json = {
          'success': true,
          'code': 'auth_code_xyz',
          'pubkey': 'user_pk',
          'state': 'my_state',
          'error': null,
          'error_description': null,
        };

        final result = HeadlessLoginResult.fromJson(json);

        expect(result.success, isTrue);
        expect(result.code, 'auth_code_xyz');
        expect(result.pubkey, 'user_pk');
        expect(result.state, 'my_state');
        expect(result.error, isNull);
        expect(result.errorDescription, isNull);
      });

      test('uses defaults for missing fields', () {
        final json = <String, dynamic>{};

        final result = HeadlessLoginResult.fromJson(json);

        expect(result.success, isFalse);
        expect(result.code, isNull);
        expect(result.pubkey, isNull);
        expect(result.state, isNull);
        expect(result.error, isNull);
        expect(result.errorDescription, isNull);
      });

      test('parses error fields', () {
        final json = {
          'success': false,
          'error': 'invalid_credentials',
          'error_description': 'Wrong password',
        };

        final result = HeadlessLoginResult.fromJson(json);

        expect(result.success, isFalse);
        expect(result.error, 'invalid_credentials');
        expect(result.errorDescription, 'Wrong password');
      });
    });

    group('error factory', () {
      test('creates error result with message and default code', () {
        final result = HeadlessLoginResult.error('Login failed');

        expect(result.success, isFalse);
        expect(result.error, 'client_error');
        expect(result.errorDescription, 'Login failed');
      });

      test('creates error result with custom code', () {
        final result = HeadlessLoginResult.error(
          'Network error',
          code: 'connection_error',
        );

        expect(result.success, isFalse);
        expect(result.error, 'connection_error');
        expect(result.errorDescription, 'Network error');
      });
    });
  });

  group('PollResult', () {
    group('constructor', () {
      test('creates instance with required status', () {
        final result = PollResult(status: PollStatus.pending);

        expect(result.status, PollStatus.pending);
        expect(result.code, isNull);
        expect(result.error, isNull);
      });

      test('creates instance with all fields', () {
        final result = PollResult(
          status: PollStatus.complete,
          code: 'auth_code',
          error: null,
        );

        expect(result.status, PollStatus.complete);
        expect(result.code, 'auth_code');
      });
    });

    group('pending factory', () {
      test('creates pending result', () {
        final result = PollResult.pending();

        expect(result.status, PollStatus.pending);
        expect(result.code, isNull);
        expect(result.error, isNull);
      });
    });

    group('complete factory', () {
      test('creates complete result with code', () {
        final result = PollResult.complete('my_auth_code');

        expect(result.status, PollStatus.complete);
        expect(result.code, 'my_auth_code');
        expect(result.error, isNull);
      });
    });

    group('error factory', () {
      test('creates error result with message', () {
        final result = PollResult.error('Token expired');

        expect(result.status, PollStatus.error);
        expect(result.code, isNull);
        expect(result.error, 'Token expired');
      });
    });
  });

  group('ForgotPasswordResult', () {
    group('constructor', () {
      test('creates instance with required fields', () {
        final result = ForgotPasswordResult(success: true);

        expect(result.success, isTrue);
        expect(result.message, isNull);
        expect(result.error, isNull);
      });

      test('creates instance with all fields', () {
        final result = ForgotPasswordResult(
          success: true,
          message: 'Email sent',
          error: null,
        );

        expect(result.success, isTrue);
        expect(result.message, 'Email sent');
      });
    });

    group('fromJson', () {
      test('parses complete JSON response', () {
        final json = {
          'success': true,
          'message': 'Password reset email sent',
          'error': null,
        };

        final result = ForgotPasswordResult.fromJson(json);

        expect(result.success, isTrue);
        expect(result.message, 'Password reset email sent');
        expect(result.error, isNull);
      });

      test('uses defaults for missing fields', () {
        final json = <String, dynamic>{};

        final result = ForgotPasswordResult.fromJson(json);

        expect(result.success, isFalse);
        expect(result.message, isNull);
        expect(result.error, isNull);
      });

      test('parses error field', () {
        final json = {'success': false, 'error': 'user_not_found'};

        final result = ForgotPasswordResult.fromJson(json);

        expect(result.success, isFalse);
        expect(result.error, 'user_not_found');
      });
    });

    group('error factory', () {
      test('creates error result with message', () {
        final result = ForgotPasswordResult.error('Network error');

        expect(result.success, isFalse);
        expect(result.error, 'Network error');
        expect(result.message, isNull);
      });
    });
  });

  group('ResetPasswordResult', () {
    group('constructor', () {
      test('creates instance with required fields', () {
        final result = ResetPasswordResult(success: true);

        expect(result.success, isTrue);
        expect(result.message, isNull);
      });

      test('creates instance with all fields', () {
        final result = ResetPasswordResult(
          success: true,
          message: 'Password updated',
        );

        expect(result.success, isTrue);
        expect(result.message, 'Password updated');
      });
    });

    group('fromJson', () {
      test('parses complete JSON response', () {
        final json = {'success': true, 'message': 'Password has been reset'};

        final result = ResetPasswordResult.fromJson(json);

        expect(result.success, isTrue);
        expect(result.message, 'Password has been reset');
      });

      test('uses defaults for missing fields', () {
        final json = <String, dynamic>{};

        final result = ResetPasswordResult.fromJson(json);

        expect(result.success, isFalse);
        expect(result.message, isNull);
      });
    });

    group('error factory', () {
      test('creates error result with message', () {
        final result = ResetPasswordResult.error('Token expired');

        expect(result.success, isFalse);
        expect(result.message, 'Token expired');
      });
    });
  });

  group('DeleteAccountResult', () {
    group('constructor', () {
      test('creates instance with required fields', () {
        final result = DeleteAccountResult(success: true);

        expect(result.success, isTrue);
        expect(result.message, isNull);
        expect(result.error, isNull);
      });

      test('creates instance with all fields', () {
        final result = DeleteAccountResult(
          success: true,
          message: 'Account deleted',
          error: null,
        );

        expect(result.success, isTrue);
        expect(result.message, 'Account deleted');
      });
    });

    group('fromJson', () {
      test('parses complete JSON response', () {
        final json = {
          'success': true,
          'message': 'Account successfully deleted',
          'error': null,
        };

        final result = DeleteAccountResult.fromJson(json);

        expect(result.success, isTrue);
        expect(result.message, 'Account successfully deleted');
        expect(result.error, isNull);
      });

      test('uses defaults for missing fields', () {
        final json = <String, dynamic>{};

        final result = DeleteAccountResult.fromJson(json);

        expect(result.success, isFalse);
        expect(result.message, isNull);
        expect(result.error, isNull);
      });

      test('parses error field', () {
        final json = {'success': false, 'error': 'unauthorized'};

        final result = DeleteAccountResult.fromJson(json);

        expect(result.success, isFalse);
        expect(result.error, 'unauthorized');
      });
    });

    group('error factory', () {
      test('creates error result with message', () {
        final result = DeleteAccountResult.error('Deletion failed');

        expect(result.success, isFalse);
        expect(result.error, 'Deletion failed');
        expect(result.message, isNull);
      });
    });
  });
}
