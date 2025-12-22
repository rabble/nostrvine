// ABOUTME: Unit tests for ReservedUsernameRequestState
// ABOUTME: Tests validation logic, status getters, copyWith, and Equatable equality

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/state/reserved_username_request_state.dart';

void main() {
  group('ReservedUsernameRequestState', () {
    group('default state', () {
      test('has empty strings and idle status', () {
        const state = ReservedUsernameRequestState();

        expect(state.email, '');
        expect(state.justification, '');
        expect(state.status, ReservedUsernameRequestStatus.idle);
        expect(state.errorMessage, isNull);
      });
    });

    group('status getters', () {
      test('isSubmitting returns true only for submitting status', () {
        const submitting = ReservedUsernameRequestState(
          email: 'test@example.com',
          justification: 'I am the creator',
          status: ReservedUsernameRequestStatus.submitting,
        );
        const idle = ReservedUsernameRequestState(
          email: 'test@example.com',
          justification: 'I am the creator',
          status: ReservedUsernameRequestStatus.idle,
        );

        expect(submitting.isSubmitting, true);
        expect(idle.isSubmitting, false);
      });

      test('isSuccess returns true only for success status', () {
        const success = ReservedUsernameRequestState(
          email: 'test@example.com',
          justification: 'I am the creator',
          status: ReservedUsernameRequestStatus.success,
        );
        const idle = ReservedUsernameRequestState(
          email: 'test@example.com',
          justification: 'I am the creator',
          status: ReservedUsernameRequestStatus.idle,
        );

        expect(success.isSuccess, true);
        expect(idle.isSuccess, false);
      });

      test('hasError returns true only for error status', () {
        const error = ReservedUsernameRequestState(
          email: 'test@example.com',
          justification: 'I am the creator',
          status: ReservedUsernameRequestStatus.error,
          errorMessage: 'Something went wrong',
        );
        const idle = ReservedUsernameRequestState(
          email: 'test@example.com',
          justification: 'I am the creator',
          status: ReservedUsernameRequestStatus.idle,
        );

        expect(error.hasError, true);
        expect(idle.hasError, false);
      });
    });

    group('copyWith', () {
      test('preserves original fields when no parameters provided', () {
        const original = ReservedUsernameRequestState(
          email: 'test@example.com',
          justification: 'I am the creator',
          status: ReservedUsernameRequestStatus.idle,
          errorMessage: 'error',
        );

        final copied = original.copyWith();

        expect(copied.email, 'test@example.com');
        expect(copied.justification, 'I am the creator');
        expect(copied.status, ReservedUsernameRequestStatus.idle);
        expect(copied.errorMessage, isNull);
      });

      test('updates email when provided', () {
        const original = ReservedUsernameRequestState(
          email: 'test@example.com',
          justification: 'I am the creator',
        );

        final copied = original.copyWith(email: 'new@example.com');

        expect(copied.email, 'new@example.com');
        expect(copied.justification, 'I am the creator');
      });

      test('updates justification when provided', () {
        const original = ReservedUsernameRequestState(
          email: 'test@example.com',
          justification: 'I am the creator',
        );

        final copied = original.copyWith(justification: 'New reason');

        expect(copied.email, 'test@example.com');
        expect(copied.justification, 'New reason');
      });

      test('updates status when provided', () {
        const original = ReservedUsernameRequestState(
          email: 'test@example.com',
          justification: 'I am the creator',
          status: ReservedUsernameRequestStatus.idle,
        );

        final copied = original.copyWith(
          status: ReservedUsernameRequestStatus.submitting,
        );

        expect(copied.status, ReservedUsernameRequestStatus.submitting);
      });

      test('clears errorMessage when copyWith is called without it', () {
        const original = ReservedUsernameRequestState(
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
          email: 'test@example.com',
          justification: 'I am the creator',
        );

        final copied = original.copyWith(
          status: ReservedUsernameRequestStatus.submitting,
        );

        expect(original.status, ReservedUsernameRequestStatus.idle);
        expect(copied.status, ReservedUsernameRequestStatus.submitting);
        expect(original, isNot(equals(copied)));
      });
    });

    group('equality (via Equatable)', () {
      test('equal states are equal', () {
        const state1 = ReservedUsernameRequestState(
          email: 'test@example.com',
          justification: 'I am the creator',
          status: ReservedUsernameRequestStatus.idle,
        );
        const state2 = ReservedUsernameRequestState(
          email: 'test@example.com',
          justification: 'I am the creator',
          status: ReservedUsernameRequestStatus.idle,
        );

        expect(state1, equals(state2));
      });

      test('states with different emails are not equal', () {
        const state1 = ReservedUsernameRequestState(
          email: 'test@example.com',
          justification: 'I am the creator',
        );
        const state2 = ReservedUsernameRequestState(
          email: 'other@example.com',
          justification: 'I am the creator',
        );

        expect(state1, isNot(equals(state2)));
      });

      test('states with different justifications are not equal', () {
        const state1 = ReservedUsernameRequestState(
          email: 'test@example.com',
          justification: 'I am the creator',
        );
        const state2 = ReservedUsernameRequestState(
          email: 'test@example.com',
          justification: 'Different reason',
        );

        expect(state1, isNot(equals(state2)));
      });

      test('states with different statuses are not equal', () {
        const state1 = ReservedUsernameRequestState(
          email: 'test@example.com',
          justification: 'I am the creator',
          status: ReservedUsernameRequestStatus.idle,
        );
        const state2 = ReservedUsernameRequestState(
          email: 'test@example.com',
          justification: 'I am the creator',
          status: ReservedUsernameRequestStatus.submitting,
        );

        expect(state1, isNot(equals(state2)));
      });

      test('states with different errorMessages are not equal', () {
        const state1 = ReservedUsernameRequestState(
          email: 'test@example.com',
          justification: 'I am the creator',
          status: ReservedUsernameRequestStatus.error,
          errorMessage: 'Error 1',
        );
        const state2 = ReservedUsernameRequestState(
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
            email: 'test@example.com',
            justification: 'I am the creator',
          );
          const state2 = ReservedUsernameRequestState(
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
