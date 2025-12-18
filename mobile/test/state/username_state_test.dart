// ABOUTME: Unit tests for UsernameState
// ABOUTME: Tests status getters, copyWith, and Equatable equality

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/state/username_state.dart';

void main() {
  group('UsernameState', () {
    group('status getters', () {
      test('isAvailable returns true only for available status', () {
        const available = UsernameState(
          username: 'test',
          status: UsernameCheckStatus.available,
        );
        const taken = UsernameState(
          username: 'test',
          status: UsernameCheckStatus.taken,
        );

        expect(available.isAvailable, true);
        expect(taken.isAvailable, false);
      });

      test('isReserved returns true only for reserved status', () {
        const reserved = UsernameState(
          username: 'test',
          status: UsernameCheckStatus.reserved,
        );
        const taken = UsernameState(
          username: 'test',
          status: UsernameCheckStatus.taken,
        );

        expect(reserved.isReserved, true);
        expect(taken.isReserved, false);
      });

      test('isTaken returns true only for taken status', () {
        const taken = UsernameState(
          username: 'test',
          status: UsernameCheckStatus.taken,
        );
        const available = UsernameState(
          username: 'test',
          status: UsernameCheckStatus.available,
        );

        expect(taken.isTaken, true);
        expect(available.isTaken, false);
      });

      test('isChecking returns true only for checking status', () {
        const checking = UsernameState(
          username: 'test',
          status: UsernameCheckStatus.checking,
        );
        const idle = UsernameState(
          username: 'test',
          status: UsernameCheckStatus.idle,
        );

        expect(checking.isChecking, true);
        expect(idle.isChecking, false);
      });

      test('hasError returns true only for error status', () {
        const error = UsernameState(
          username: 'test',
          status: UsernameCheckStatus.error,
          errorMessage: 'Something went wrong',
        );
        const available = UsernameState(
          username: 'test',
          status: UsernameCheckStatus.available,
        );

        expect(error.hasError, true);
        expect(available.hasError, false);
      });
    });

    group('canRegister', () {
      test('is true only when available and username is not empty', () {
        const availableWithUsername = UsernameState(
          username: 'test',
          status: UsernameCheckStatus.available,
        );
        expect(availableWithUsername.canRegister, true);

        const availableEmpty = UsernameState(
          username: '',
          status: UsernameCheckStatus.available,
        );
        expect(availableEmpty.canRegister, false);

        const takenWithUsername = UsernameState(
          username: 'test',
          status: UsernameCheckStatus.taken,
        );
        expect(takenWithUsername.canRegister, false);
      });
    });

    group('copyWith', () {
      test('preserves status when only username changes', () {
        const original = UsernameState(
          username: 'test',
          status: UsernameCheckStatus.available,
        );

        final copied = original.copyWith(username: 'newuser');

        expect(copied.username, 'newuser');
        expect(copied.status, UsernameCheckStatus.available);
      });

      test('preserves username when only status changes', () {
        const original = UsernameState(
          username: 'test',
          status: UsernameCheckStatus.available,
          errorMessage: 'error',
        );

        final copied = original.copyWith(status: UsernameCheckStatus.taken);

        expect(copied.username, 'test');
        expect(copied.status, UsernameCheckStatus.taken);
        // errorMessage should be cleared because it wasn't passed
        expect(copied.errorMessage, isNull);
      });
    });

    group('equality (via Equatable)', () {
      test('equal states are equal', () {
        const state1 = UsernameState(
          username: 'test',
          status: UsernameCheckStatus.available,
        );
        const state2 = UsernameState(
          username: 'test',
          status: UsernameCheckStatus.available,
        );

        expect(state1, equals(state2));
      });

      test('different states are not equal', () {
        const state1 = UsernameState(
          username: 'test',
          status: UsernameCheckStatus.available,
        );
        const state2 = UsernameState(
          username: 'different',
          status: UsernameCheckStatus.available,
        );

        expect(state1, isNot(equals(state2)));
      });
    });
  });
}
