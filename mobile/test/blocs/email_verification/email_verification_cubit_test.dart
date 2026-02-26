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

class _FakeKeycastSession extends Fake implements KeycastSession {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeKeycastSession());
  });

  group('EmailVerificationCubit', () {
    late _MockKeycastOAuth mockOAuth;
    late _MockAuthService mockAuthService;

    const testDeviceCode = 'test-device-code-abc123';
    const testVerifier = 'test-verifier-xyz789';
    const testEmail = 'test@example.com';

    setUp(() {
      mockOAuth = _MockKeycastOAuth();
      mockAuthService = _MockAuthService();
      // Reset static state to ensure test isolation
      EmailVerificationCubit.resetCompletedDeviceCode();
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

      blocTest<EmailVerificationCubit, EmailVerificationState>(
        'preserves success state to avoid UI flash',
        build: buildCubit,
        seed: () => const EmailVerificationState(
          status: EmailVerificationStatus.success,
        ),
        act: (cubit) => cubit.stopPolling(),
        expect: () => <EmailVerificationState>[],
        verify: (cubit) {
          expect(cubit.state.status, EmailVerificationStatus.success);
        },
      );
    });

    group('zombie cubit detection', () {
      const testCode = 'auth-code-from-server';

      test(
        'zombie cubit stops polling when device code already completed',
        () async {
          // Simulate cubit #1 (the one that completed verification)
          when(() => mockAuthService.isAuthenticated).thenReturn(false);
          when(() => mockAuthService.isAnonymous).thenReturn(false);
          when(
            () => mockOAuth.pollForCode(testDeviceCode),
          ).thenAnswer((_) async => PollResult.complete(testCode));
          when(
            () =>
                mockOAuth.exchangeCode(code: testCode, verifier: testVerifier),
          ).thenAnswer(
            (_) async => const TokenResponse(bunkerUrl: 'wss://relay.test'),
          );
          when(
            () => mockAuthService.signInWithDivineOAuth(any()),
          ).thenAnswer((_) async {});

          final cubit1 = buildCubit();
          cubit1.startPolling(
            deviceCode: testDeviceCode,
            verifier: testVerifier,
            email: testEmail,
          );

          // Let the first poll cycle complete (exchange succeeds)
          await Future<void>.delayed(const Duration(seconds: 4));

          // Cubit #1 should have completed and set the static field
          expect(cubit1.state.status, EmailVerificationStatus.success);

          // Simulate cubit #2 (zombie from engine restart, different
          // auth service that doesn't know about the sign-in)
          final zombieOAuth = _MockKeycastOAuth();
          final zombieAuthService = _MockAuthService();
          when(() => zombieAuthService.isAuthenticated).thenReturn(false);
          when(
            () => zombieOAuth.pollForCode(testDeviceCode),
          ).thenAnswer((_) async => PollResult.pending());

          final cubit2 = EmailVerificationCubit(
            oauthClient: zombieOAuth,
            authService: zombieAuthService,
          );
          cubit2.startPolling(
            deviceCode: testDeviceCode,
            verifier: testVerifier,
            email: testEmail,
          );

          // Let the zombie's first poll cycle run
          await Future<void>.delayed(const Duration(seconds: 4));

          // Zombie should have emitted success (so the screen navigates)
          expect(cubit2.state.status, EmailVerificationStatus.success);

          // pollForCode should NOT have been called on the zombie
          // because the static guard fires before the network call
          verifyNever(() => zombieOAuth.pollForCode(any()));

          await cubit1.close();
          await cubit2.close();
        },
      );

      test('different device code is not affected by completed code', () async {
        // Simulate cubit #1 completing with one device code
        when(() => mockAuthService.isAuthenticated).thenReturn(false);
        when(() => mockAuthService.isAnonymous).thenReturn(false);
        when(
          () => mockOAuth.pollForCode(testDeviceCode),
        ).thenAnswer((_) async => PollResult.complete(testCode));
        when(
          () => mockOAuth.exchangeCode(code: testCode, verifier: testVerifier),
        ).thenAnswer(
          (_) async => const TokenResponse(bunkerUrl: 'wss://relay.test'),
        );
        when(
          () => mockAuthService.signInWithDivineOAuth(any()),
        ).thenAnswer((_) async {});

        final cubit1 = buildCubit();
        cubit1.startPolling(
          deviceCode: testDeviceCode,
          verifier: testVerifier,
          email: testEmail,
        );
        await Future<void>.delayed(const Duration(seconds: 4));

        // Now a NEW registration with a different device code should
        // NOT be blocked
        const newDeviceCode = 'new-device-code-different';
        final newOAuth = _MockKeycastOAuth();
        final newAuthService = _MockAuthService();
        when(() => newAuthService.isAuthenticated).thenReturn(false);
        when(
          () => newOAuth.pollForCode(newDeviceCode),
        ).thenAnswer((_) async => PollResult.pending());

        final cubit2 = EmailVerificationCubit(
          oauthClient: newOAuth,
          authService: newAuthService,
        );
        cubit2.startPolling(
          deviceCode: newDeviceCode,
          verifier: testVerifier,
          email: testEmail,
        );
        await Future<void>.delayed(const Duration(seconds: 4));

        // pollForCode SHOULD have been called — different device code
        verify(() => newOAuth.pollForCode(newDeviceCode)).called(1);

        await cubit1.close();
        await cubit2.close();
      });
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
        const EmailVerificationState().isPolling,
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
              const EmailVerificationState(),
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
