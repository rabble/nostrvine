// ABOUTME: Unit tests for ReservedUsernameRequestState
// ABOUTME: Tests validation logic, status getters, copyWith, and Equatable equality

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/state/reserved_username_request_state.dart';

void main() {
  group('ReservedUsernameRequestState', () {
    group('default state', () {
      test('has empty strings and idle status', () {
        const state = ReservedUsernameRequestState();

        expect(state.username, '');
        expect(state.email, '');
        expect(state.justification, '');
        expect(state.status, ReservedUsernameRequestStatus.idle);
        expect(state.errorMessage, isNull);
      });
    });

    group('status getters', () {
      test('isSubmitting returns true only for submitting status', () {
        const submitting = ReservedUsernameRequestState(
          username: 'test',
          email: 'test@example.com',
          justification: 'I am the creator',
          status: ReservedUsernameRequestStatus.submitting,
        );
        const idle = ReservedUsernameRequestState(
          username: 'test',
          email: 'test@example.com',
          justification: 'I am the creator',
          status: ReservedUsernameRequestStatus.idle,
        );

        expect(submitting.isSubmitting, true);
        expect(idle.isSubmitting, false);
      });

      test('isSuccess returns true only for success status', () {
        const success = ReservedUsernameRequestState(
          username: 'test',
          email: 'test@example.com',
          justification: 'I am the creator',
          status: ReservedUsernameRequestStatus.success,
        );
        const idle = ReservedUsernameRequestState(
          username: 'test',
          email: 'test@example.com',
          justification: 'I am the creator',
          status: ReservedUsernameRequestStatus.idle,
        );

        expect(success.isSuccess, true);
        expect(idle.isSuccess, false);
      });

      test('hasError returns true only for error status', () {
        const error = ReservedUsernameRequestState(
          username: 'test',
          email: 'test@example.com',
          justification: 'I am the creator',
          status: ReservedUsernameRequestStatus.error,
          errorMessage: 'Something went wrong',
        );
        const idle = ReservedUsernameRequestState(
          username: 'test',
          email: 'test@example.com',
          justification: 'I am the creator',
          status: ReservedUsernameRequestStatus.idle,
        );

        expect(error.hasError, true);
        expect(idle.hasError, false);
      });
    });

    group('isEmailValid', () {
      test('returns true when email is empty', () {
        const state = ReservedUsernameRequestState(email: '');

        expect(state.isEmailValid, true);
      });

      test('returns true for valid email formats', () {
        const validEmails = [
          'test@example.com',
          'user.name@domain.co.uk',
          'first-last@test-domain.org',
          'username@subdomain.example.com',
        ];

        for (final email in validEmails) {
          final state = ReservedUsernameRequestState(email: email);
          expect(state.isEmailValid, true, reason: '$email should be valid');
        }
      });

      test('returns false for invalid email formats', () {
        const invalidEmails = [
          'notanemail',
          '@example.com',
          'user@',
          'user@domain',
          'user @example.com',
          'user@domain .com',
        ];

        for (final email in invalidEmails) {
          final state = ReservedUsernameRequestState(email: email);
          expect(state.isEmailValid, false, reason: '$email should be invalid');
        }
      });
    });

    group('canSubmit', () {
      test('returns false when username is empty', () {
        const state = ReservedUsernameRequestState(
          username: '',
          email: 'test@example.com',
          justification: 'I am the creator',
          status: ReservedUsernameRequestStatus.idle,
        );

        expect(state.canSubmit, false);
      });

      test('returns false when email is empty', () {
        const state = ReservedUsernameRequestState(
          username: 'test',
          email: '',
          justification: 'I am the creator',
          status: ReservedUsernameRequestStatus.idle,
        );

        expect(state.canSubmit, false);
      });

      test('returns false when email format is invalid', () {
        const state = ReservedUsernameRequestState(
          username: 'test',
          email: 'notanemail',
          justification: 'I am the creator',
          status: ReservedUsernameRequestStatus.idle,
        );

        expect(state.canSubmit, false);
      });

      test('returns false when justification is empty', () {
        const state = ReservedUsernameRequestState(
          username: 'test',
          email: 'test@example.com',
          justification: '',
          status: ReservedUsernameRequestStatus.idle,
        );

        expect(state.canSubmit, false);
      });

      test('returns false when isSubmitting', () {
        const state = ReservedUsernameRequestState(
          username: 'test',
          email: 'test@example.com',
          justification: 'I am the creator',
          status: ReservedUsernameRequestStatus.submitting,
        );

        expect(state.canSubmit, false);
      });

      test('returns true when all fields valid and not submitting', () {
        const state = ReservedUsernameRequestState(
          username: 'test',
          email: 'test@example.com',
          justification: 'I am the creator',
          status: ReservedUsernameRequestStatus.idle,
        );

        expect(state.canSubmit, true);
      });

      test('returns true for success status with valid fields', () {
        const state = ReservedUsernameRequestState(
          username: 'test',
          email: 'test@example.com',
          justification: 'I am the creator',
          status: ReservedUsernameRequestStatus.success,
        );

        expect(state.canSubmit, true);
      });

      test('returns true for error status with valid fields', () {
        const state = ReservedUsernameRequestState(
          username: 'test',
          email: 'test@example.com',
          justification: 'I am the creator',
          status: ReservedUsernameRequestStatus.error,
          errorMessage: 'Network error',
        );

        expect(state.canSubmit, true);
      });
    });

    group('copyWith', () {
      test('preserves original fields when no parameters provided', () {
        const original = ReservedUsernameRequestState(
          username: 'test',
          email: 'test@example.com',
          justification: 'I am the creator',
          status: ReservedUsernameRequestStatus.idle,
          errorMessage: 'error',
        );

        final copied = original.copyWith();

        expect(copied.username, 'test');
        expect(copied.email, 'test@example.com');
        expect(copied.justification, 'I am the creator');
        expect(copied.status, ReservedUsernameRequestStatus.idle);
        expect(copied.errorMessage, isNull);
      });

      test('updates username when provided', () {
        const original = ReservedUsernameRequestState(
          username: 'test',
          email: 'test@example.com',
          justification: 'I am the creator',
        );

        final copied = original.copyWith(username: 'newuser');

        expect(copied.username, 'newuser');
        expect(copied.email, 'test@example.com');
        expect(copied.justification, 'I am the creator');
      });

      test('updates email when provided', () {
        const original = ReservedUsernameRequestState(
          username: 'test',
          email: 'test@example.com',
          justification: 'I am the creator',
        );

        final copied = original.copyWith(email: 'new@example.com');

        expect(copied.username, 'test');
        expect(copied.email, 'new@example.com');
        expect(copied.justification, 'I am the creator');
      });

      test('updates justification when provided', () {
        const original = ReservedUsernameRequestState(
          username: 'test',
          email: 'test@example.com',
          justification: 'I am the creator',
        );

        final copied = original.copyWith(justification: 'New reason');

        expect(copied.username, 'test');
        expect(copied.email, 'test@example.com');
        expect(copied.justification, 'New reason');
      });

      test('updates status when provided', () {
        const original = ReservedUsernameRequestState(
          username: 'test',
          email: 'test@example.com',
          justification: 'I am the creator',
          status: ReservedUsernameRequestStatus.idle,
        );

        final copied = original.copyWith(
          status: ReservedUsernameRequestStatus.submitting,
        );

        expect(copied.username, 'test');
        expect(copied.status, ReservedUsernameRequestStatus.submitting);
      });

      test('clears errorMessage when copyWith is called without it', () {
        const original = ReservedUsernameRequestState(
          username: 'test',
          email: 'test@example.com',
          justification: 'I am the creator',
          status: ReservedUsernameRequestStatus.error,
          errorMessage: 'error',
        );

        final copied = original.copyWith(
          status: ReservedUsernameRequestStatus.idle,
        );

        expect(copied.errorMessage, isNull);
      });

      test('updates errorMessage when explicitly provided', () {
        const original = ReservedUsernameRequestState(
          username: 'test',
          email: 'test@example.com',
          justification: 'I am the creator',
        );

        final copied = original.copyWith(
          status: ReservedUsernameRequestStatus.error,
          errorMessage: 'Network error',
        );

        expect(copied.status, ReservedUsernameRequestStatus.error);
        expect(copied.errorMessage, 'Network error');
      });

      test('creates independent copy (immutability)', () {
        const original = ReservedUsernameRequestState(
          username: 'test',
          email: 'test@example.com',
          justification: 'I am the creator',
        );

        final copied = original.copyWith(username: 'newuser');

        expect(original.username, 'test');
        expect(copied.username, 'newuser');
        expect(original, isNot(equals(copied)));
      });
    });

    group('equality (via Equatable)', () {
      test('equal states are equal', () {
        const state1 = ReservedUsernameRequestState(
          username: 'test',
          email: 'test@example.com',
          justification: 'I am the creator',
          status: ReservedUsernameRequestStatus.idle,
        );
        const state2 = ReservedUsernameRequestState(
          username: 'test',
          email: 'test@example.com',
          justification: 'I am the creator',
          status: ReservedUsernameRequestStatus.idle,
        );

        expect(state1, equals(state2));
      });

      test('states with different usernames are not equal', () {
        const state1 = ReservedUsernameRequestState(
          username: 'test',
          email: 'test@example.com',
          justification: 'I am the creator',
        );
        const state2 = ReservedUsernameRequestState(
          username: 'different',
          email: 'test@example.com',
          justification: 'I am the creator',
        );

        expect(state1, isNot(equals(state2)));
      });

      test('states with different emails are not equal', () {
        const state1 = ReservedUsernameRequestState(
          username: 'test',
          email: 'test@example.com',
          justification: 'I am the creator',
        );
        const state2 = ReservedUsernameRequestState(
          username: 'test',
          email: 'other@example.com',
          justification: 'I am the creator',
        );

        expect(state1, isNot(equals(state2)));
      });

      test('states with different justifications are not equal', () {
        const state1 = ReservedUsernameRequestState(
          username: 'test',
          email: 'test@example.com',
          justification: 'I am the creator',
        );
        const state2 = ReservedUsernameRequestState(
          username: 'test',
          email: 'test@example.com',
          justification: 'Different reason',
        );

        expect(state1, isNot(equals(state2)));
      });

      test('states with different statuses are not equal', () {
        const state1 = ReservedUsernameRequestState(
          username: 'test',
          email: 'test@example.com',
          justification: 'I am the creator',
          status: ReservedUsernameRequestStatus.idle,
        );
        const state2 = ReservedUsernameRequestState(
          username: 'test',
          email: 'test@example.com',
          justification: 'I am the creator',
          status: ReservedUsernameRequestStatus.submitting,
        );

        expect(state1, isNot(equals(state2)));
      });

      test('states with different errorMessages are not equal', () {
        const state1 = ReservedUsernameRequestState(
          username: 'test',
          email: 'test@example.com',
          justification: 'I am the creator',
          status: ReservedUsernameRequestStatus.error,
          errorMessage: 'Error 1',
        );
        const state2 = ReservedUsernameRequestState(
          username: 'test',
          email: 'test@example.com',
          justification: 'I am the creator',
          status: ReservedUsernameRequestStatus.error,
          errorMessage: 'Error 2',
        );

        expect(state1, isNot(equals(state2)));
      });

      test(
        'state with null errorMessage equals state without errorMessage',
        () {
          const state1 = ReservedUsernameRequestState(
            username: 'test',
            email: 'test@example.com',
            justification: 'I am the creator',
          );
          const state2 = ReservedUsernameRequestState(
            username: 'test',
            email: 'test@example.com',
            justification: 'I am the creator',
            errorMessage: null,
          );

          expect(state1, equals(state2));
        },
      );
    });
  });
}
