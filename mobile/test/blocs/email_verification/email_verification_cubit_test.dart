// ABOUTME: Tests for EmailVerificationCubit
// ABOUTME: Verifies polling lifecycle, state transitions, and error handling

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/email_verification/email_verification_cubit.dart';
import 'package:openvine/services/auth_service.dart';

class _MockKeycastOAuth extends Mock implements KeycastOAuth {}

class _MockAuthService extends Mock implements AuthService {}

void main() {
  group('EmailVerificationCubit', () {
    late _MockKeycastOAuth mockOAuth;
    late _MockAuthService mockAuthService;

    const testDeviceCode = 'test-device-code-abc123';
    const testVerifier = 'test-verifier-xyz789';
    const testEmail = 'test@example.com';

    setUp(() {
      mockOAuth = _MockKeycastOAuth();
      mockAuthService = _MockAuthService();
    });

    EmailVerificationCubit buildCubit() {
      return EmailVerificationCubit(
        oauthClient: mockOAuth,
        authService: mockAuthService,
      );
    }

    group('initial state', () {
      test('has correct initial state', () {
        final cubit = buildCubit();

        expect(cubit.state, const EmailVerificationState());
        expect(cubit.state.status, EmailVerificationStatus.initial);
        expect(cubit.state.isPolling, isFalse);
        expect(cubit.state.pendingEmail, isNull);
        expect(cubit.state.error, isNull);

        cubit.close();
      });
    });

    group('startPolling', () {
      blocTest<EmailVerificationCubit, EmailVerificationState>(
        'emits polling state with email',
        build: buildCubit,
        act: (cubit) => cubit.startPolling(
          deviceCode: testDeviceCode,
          verifier: testVerifier,
          email: testEmail,
        ),
        expect: () => [
          const EmailVerificationState(
            status: EmailVerificationStatus.polling,
            pendingEmail: testEmail,
          ),
        ],
      );

      blocTest<EmailVerificationCubit, EmailVerificationState>(
        'sets isPolling to true',
        build: buildCubit,
        act: (cubit) => cubit.startPolling(
          deviceCode: testDeviceCode,
          verifier: testVerifier,
          email: testEmail,
        ),
        verify: (cubit) {
          expect(cubit.state.isPolling, isTrue);
          expect(cubit.state.pendingEmail, testEmail);
        },
      );
    });

    group('stopPolling', () {
      blocTest<EmailVerificationCubit, EmailVerificationState>(
        'clears state and stops polling',
        build: buildCubit,
        seed: () => const EmailVerificationState(
          status: EmailVerificationStatus.polling,
          pendingEmail: testEmail,
        ),
        act: (cubit) => cubit.stopPolling(),
        expect: () => [const EmailVerificationState()],
        verify: (cubit) {
          expect(cubit.state.isPolling, isFalse);
          expect(cubit.state.pendingEmail, isNull);
          expect(cubit.state.error, isNull);
        },
      );
    });

    group('close', () {
      test('cleans up timers on close', () async {
        final cubit = buildCubit();

        cubit.startPolling(
          deviceCode: testDeviceCode,
          verifier: testVerifier,
          email: testEmail,
        );

        expect(cubit.state.isPolling, isTrue);

        await cubit.close();

        // Cubit should be closed without errors
        // (verifying no lingering timers cause issues)
      });
    });
  });

  group('EmailVerificationState', () {
    test('creates with default values', () {
      const state = EmailVerificationState();

      expect(state.status, EmailVerificationStatus.initial);
      expect(state.isPolling, isFalse);
      expect(state.pendingEmail, isNull);
      expect(state.error, isNull);
    });

    test('creates with custom values', () {
      const state = EmailVerificationState(
        status: EmailVerificationStatus.polling,
        pendingEmail: 'test@example.com',
        error: 'Some error',
      );

      expect(state.status, EmailVerificationStatus.polling);
      expect(state.isPolling, isTrue);
      expect(state.pendingEmail, 'test@example.com');
      expect(state.error, 'Some error');
    });

    test('isPolling returns true only when status is polling', () {
      expect(
        const EmailVerificationState(
          status: EmailVerificationStatus.initial,
        ).isPolling,
        isFalse,
      );
      expect(
        const EmailVerificationState(
          status: EmailVerificationStatus.polling,
        ).isPolling,
        isTrue,
      );
      expect(
        const EmailVerificationState(
          status: EmailVerificationStatus.success,
        ).isPolling,
        isFalse,
      );
      expect(
        const EmailVerificationState(
          status: EmailVerificationStatus.failure,
        ).isPolling,
        isFalse,
      );
    });

    test('copyWith creates new state with updated values', () {
      const original = EmailVerificationState(
        status: EmailVerificationStatus.polling,
        pendingEmail: 'original@example.com',
      );

      final updated = original.copyWith(
        status: EmailVerificationStatus.success,
      );

      expect(updated.status, EmailVerificationStatus.success);
      expect(updated.pendingEmail, 'original@example.com');
      expect(updated.error, isNull);
    });

    test('copyWith clears error when not provided', () {
      const original = EmailVerificationState(
        status: EmailVerificationStatus.failure,
        error: 'Some error',
      );

      final updated = original.copyWith(
        status: EmailVerificationStatus.polling,
      );

      expect(updated.status, EmailVerificationStatus.polling);
      expect(updated.error, isNull);
    });

    group('equality', () {
      test('states with same values are equal', () {
        expect(
          const EmailVerificationState(),
          equals(const EmailVerificationState()),
        );

        expect(
          const EmailVerificationState(
            status: EmailVerificationStatus.polling,
            pendingEmail: 'test@example.com',
          ),
          equals(
            const EmailVerificationState(
              status: EmailVerificationStatus.polling,
              pendingEmail: 'test@example.com',
            ),
          ),
        );
      });

      test('states with different values are not equal', () {
        expect(
          const EmailVerificationState(status: EmailVerificationStatus.polling),
          isNot(
            equals(
              const EmailVerificationState(
                status: EmailVerificationStatus.initial,
              ),
            ),
          ),
        );

        expect(
          const EmailVerificationState(pendingEmail: 'a@example.com'),
          isNot(
            equals(const EmailVerificationState(pendingEmail: 'b@example.com')),
          ),
        );
      });
    });
  });

  group('EmailVerificationStatus', () {
    test('has all expected values', () {
      expect(EmailVerificationStatus.values, hasLength(4));
      expect(
        EmailVerificationStatus.values,
        containsAll([
          EmailVerificationStatus.initial,
          EmailVerificationStatus.polling,
          EmailVerificationStatus.success,
          EmailVerificationStatus.failure,
        ]),
      );
    });
  });
}
